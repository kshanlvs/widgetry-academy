// Course fee payments from the app (Razorpay Checkout + orders API). See src/payments.ts for the flow.
import { Router, type Request } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { z } from "zod";
import { query } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { INDIA_STATES, PLAY_PRODUCTS, planForProduct, playAccountId, playApi, playConfig } from "../play.js";
import { COURSE, PLAN_TITLE, bookingAmount, coursePrice, fulfil, gateway, paymentsEnabled, plansFor, razorpayConfig, reconcile, store, validPaymentSignature, validWebhookSignature } from "../payments.js";

/**
 * Google Play products have fixed prices (set once in Play Console). A plan is offered through Google's
 * choice screen only when its amount is that standard price; an amount adjusted by hand (rare) is paid with Razorpay.
 */
export const playPrice = (plan: string) =>
  ({ "early-bird": coursePrice("early-bird"), regular: coursePrice("regular"), booking: bookingAmount(), balance: coursePrice("booking") - bookingAmount() } as Record<string, number>)[plan];
const playProductFor = (pl: { id: string; amount: number }) => (pl.amount === playPrice(pl.id) ? PLAY_PRODUCTS[pl.id] : undefined);

export const paymentsRouter = Router();

const orderLimit = rateLimit({ windowMs: 10 * 60 * 1000, limit: 20, keyGenerator: (req: Request) => req.user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "Too many payment attempts. Please wait a few minutes." }) });

const needsPayments = () => { if (!paymentsEnabled()) throw new HttpError(503, "Online payment is opening soon. Please contact us on WhatsApp to pay."); };

/** What the signed-in student can pay. */
paymentsRouter.get("/payments/plans", requireAuth, wrap(async (req, res) => {
  await reconcile(req.user!.uid);
  const reg = await store().get(req.user!.uid);
  const p = await plansFor(reg);
  res.json({
    enabled: paymentsEnabled(), course: COURSE, status: p.status, amountPaid: reg?.amountPaid ?? 0,
    plans: p.plans.map(pl => ({ ...pl, playProductId: playProductFor(pl) })),
    // Android: Google's choice screen (Google Play or Razorpay); see src/play.ts
    android: { billing: playConfig().androidBilling, accountId: playAccountId(req.user!.uid), states: INDIA_STATES },
  });
}));

const orderBody = z.object({
  plan: z.enum(["early-bird", "regular", "booking", "balance"]),
  // Set when the student picked Razorpay on Google Play's choice screen (Android)
  externalTransactionToken: z.string().trim().min(10).max(4000).optional(),
  state: z.enum(INDIA_STATES).optional(),
}).refine(b => !b.externalTransactionToken || b.state, { path: ["state"], message: "Choose your state" });

paymentsRouter.post("/payments/order", requireAuth, orderLimit, wrap(async (req, res) => {
  needsPayments();
  const { plan, externalTransactionToken, state } = orderBody.parse(req.body);
  const u = req.user!;
  // An earlier attempt may have gone through without being confirmed: never charge twice
  await reconcile(u.uid);
  const reg = await store().get(u.uid);
  if (!reg) throw new HttpError(409, "Please register for the course first.");
  const { plans, status } = await plansFor(reg);
  if (status === "paid") throw new HttpError(409, "Your fee is already paid. See you in class!");
  const chosen = plans.find(p => p.id === plan);
  if (!chosen) throw new HttpError(400, "That payment option isn't available any more. Please pick another.");

  const amount = chosen.amount * 100;
  const order = await gateway().createOrder({
    amount,
    receipt: `wa_${u.uid.slice(0, 20)}_${Date.now().toString(36)}`.slice(0, 40),
    notes: { uid: u.uid, plan, course: COURSE, email: u.email ?? "" },
  });
  await query("INSERT INTO payments (order_id, uid, email, plan, amount, currency, channel, ext_token, tax_state) VALUES (?,?,?,?,?,?,?,?,?)",
    [order.id, u.uid, u.email, plan, order.amount, order.currency || "INR", "razorpay", externalTransactionToken ?? null, state ?? null]);

  res.status(201).json({
    orderId: order.id,
    amount: order.amount,
    currency: order.currency || "INR",
    keyId: razorpayConfig().keyId,
    name: "Widgetry Academy",
    description: `${COURSE}: ${chosen.title}`,
    prefill: { name: reg.name ?? u.name ?? "", email: reg.email ?? u.email ?? "", contact: reg.phone ?? "" },
  });
}));

const verifyBody = z.object({
  orderId: z.string().trim().regex(/^order_[A-Za-z0-9]+$/),
  paymentId: z.string().trim().regex(/^pay_[A-Za-z0-9]+$/),
  signature: z.string().trim().regex(/^[a-f0-9]{64}$/),
});

/** Called by the app right after Checkout succeeds. */
paymentsRouter.post("/payments/verify", requireAuth, wrap(async (req, res) => {
  needsPayments();
  const { orderId, paymentId, signature } = verifyBody.parse(req.body);
  const [row] = await query<{ uid: string; amount: number }>("SELECT uid, amount FROM payments WHERE order_id = ?", [orderId]);
  if (!row || row.uid !== req.user!.uid) throw new HttpError(404, "We couldn't find this payment.");
  if (!validPaymentSignature(orderId, paymentId, signature)) throw new HttpError(400, "We couldn't confirm this payment. If money was taken, it will be confirmed automatically within a few minutes.");
  // Double-check with Razorpay that the money really arrived for this order
  const pay = await gateway().fetchPayment(paymentId);
  if (pay.order_id !== orderId || pay.amount !== row.amount || !["captured", "authorized"].includes(pay.status)) {
    throw new HttpError(400, "This payment hasn't completed yet. If money was taken, it will be confirmed automatically within a few minutes.");
  }
  const r = await fulfil(orderId, paymentId, pay.method);
  res.json({ ok: true, status: r?.status ?? "paid", paymentId, amount: row.amount });
}));

/**
 * Razorpay webhook (Dashboard → Webhooks → https://api.widgetryacademy.in/api/payments/webhook,
 * events payment.captured and order.paid). Confirms payments even if the app closed before /verify.
 * The raw body is kept by app.ts so the signature can be checked.
 */
paymentsRouter.post("/payments/webhook", wrap(async (req, res) => {
  const raw = (req as any).rawBody as Buffer | undefined;
  const sig = req.get("x-razorpay-signature") || "";
  if (!raw || !validWebhookSignature(raw, sig)) throw new HttpError(400, "Invalid signature.");
  const event = JSON.parse(raw.toString("utf8"));
  const p = event?.payload?.payment?.entity;
  if (["payment.captured", "order.paid"].includes(event?.event) && p?.order_id && p?.id && p?.status === "captured") {
    const [row] = await query<{ amount: number }>("SELECT amount FROM payments WHERE order_id = ?", [p.order_id]);
    if (row && row.amount === p.amount) await fulfil(p.order_id, p.id, p.method);
  }
  if (event?.event === "payment.failed" && p?.order_id) {
    await query("UPDATE payments SET status = 'failed' WHERE order_id = ? AND status = 'created'", [p.order_id]);
  }
  res.json({ ok: true }); // always 200 for events we don't use, so Razorpay doesn't retry them
}));

/** The signed-in student's fee summary and receipts (payments made in the app), newest first. */
paymentsRouter.get("/payments/mine", requireAuth, wrap(async (req, res) => {
  const uid = req.user!.uid;
  await reconcile(uid);
  const reg = await store().get(uid);
  const { status, plans } = await plansFor(reg);
  const total = reg?.plan && coursePrice(reg.plan) ? coursePrice(reg.plan) : null;
  const rows = await query<any>("SELECT order_id, plan, amount, currency, payment_id, method, created_at, paid_at FROM payments WHERE uid = ? AND status = 'paid' ORDER BY paid_at DESC LIMIT 50", [uid]);
  res.json({
    course: COURSE,
    summary: {
      status,
      plan: reg?.plan ?? null,
      amountPaid: reg?.amountPaid ?? 0,
      total,
      due: plans[0]?.id === "balance" ? plans[0].amount : status === "paid" ? 0 : null,
      name: reg?.name ?? null,
      email: reg?.email ?? req.user!.email,
      phone: reg?.phone ?? null,
    },
    items: rows.map(r => ({
      orderId: r.order_id,
      paymentId: r.payment_id,
      plan: r.plan,
      title: PLAN_TITLE[r.plan] ?? r.plan,
      amount: Math.round(r.amount / 100),
      currency: r.currency,
      method: r.method,
      paidAt: r.paid_at,
    })),
  });
}));

const playBody = z.object({ productId: z.string().trim().min(3).max(100), purchaseToken: z.string().trim().min(10).max(600) });

/**
 * The student paid with Google Play on the choice screen. We check the purchase with Google,
 * record it exactly like a Razorpay payment (same receipts, same admin view), then consume it.
 */
paymentsRouter.post("/payments/play/verify", requireAuth, wrap(async (req, res) => {
  const { productId, purchaseToken } = playBody.parse(req.body);
  const uid = req.user!.uid;
  const plan = planForProduct(productId);
  if (!plan) throw new HttpError(400, "Unknown product.");
  const p = await playApi().getPurchase(productId, purchaseToken);
  if (p.obfuscatedExternalAccountId && p.obfuscatedExternalAccountId !== playAccountId(uid)) throw new HttpError(403, "This purchase belongs to another account.");
  if (p.purchaseState === 2) return res.status(202).json({ ok: true, status: "pending" });
  if (p.purchaseState !== 0 || !p.orderId) throw new HttpError(400, "This purchase was not completed.");
  const orderId = p.orderId.slice(0, 40);

  const [existing] = await query<{ uid: string }>("SELECT uid FROM payments WHERE order_id = ?", [orderId]);
  if (existing && existing.uid !== uid) throw new HttpError(403, "This purchase belongs to another account.");
  if (!existing) {
    const reg = await store().get(uid);
    if (!reg) throw new HttpError(409, "Please register for the course first.");
    const offered = (await plansFor(reg)).plans.find(x => x.id === plan && playProductFor(x) === productId);
    if (!offered) {
      // Paid for something no longer due (e.g. paid twice from two phones): keep a record for a refund
      // Not consumed or acknowledged, so Google refunds it automatically after 3 days
      console.warn(`[play] ${uid} bought ${productId} but it is not due; order ${orderId} is left for Google to refund`);
      throw new HttpError(409, "This payment isn't due any more, so Google refunds it to you automatically within 3 days.");
    }
    await query("INSERT IGNORE INTO payments (order_id, uid, email, plan, amount, currency, channel, purchase_token) VALUES (?,?,?,?,?,?,?,?)",
      [orderId, uid, req.user!.email, plan, offered.amount * 100, "INR", "google_play", purchaseToken]);
  }
  const r = await fulfil(orderId, orderId, "google_play");
  // Consuming also acknowledges the purchase (unacknowledged purchases are refunded by Google after 3 days)
  if (p.consumptionState !== 1) await playApi().consume(productId, purchaseToken).catch(e => console.warn(`[play] consume ${orderId} failed: ${e?.message}`));
  res.json({ ok: true, status: r?.status ?? "paid", paymentId: orderId });
}));
