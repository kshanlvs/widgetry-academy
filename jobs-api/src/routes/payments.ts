// Course fee payments from the app (Razorpay Checkout + orders API). See src/payments.ts for the flow.
import { Router, type Request } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { z } from "zod";
import { query } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { COURSE, fulfil, gateway, paymentsEnabled, plansFor, razorpayConfig, store, validPaymentSignature, validWebhookSignature } from "../payments.js";

export const paymentsRouter = Router();

const orderLimit = rateLimit({ windowMs: 10 * 60 * 1000, limit: 20, keyGenerator: (req: Request) => req.user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "Too many payment attempts. Please wait a few minutes." }) });

const needsPayments = () => { if (!paymentsEnabled()) throw new HttpError(503, "Online payment is opening soon. Please contact us on WhatsApp to pay."); };

/** What the signed-in student can pay. */
paymentsRouter.get("/payments/plans", requireAuth, wrap(async (req, res) => {
  const reg = await store().get(req.user!.uid);
  const p = await plansFor(reg);
  res.json({ enabled: paymentsEnabled(), course: COURSE, status: p.status, plans: p.plans, amountPaid: reg?.amountPaid ?? 0 });
}));

const orderBody = z.object({ plan: z.enum(["early-bird", "regular", "booking", "balance"]) });

paymentsRouter.post("/payments/order", requireAuth, orderLimit, wrap(async (req, res) => {
  needsPayments();
  const { plan } = orderBody.parse(req.body);
  const u = req.user!;
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
  await query("INSERT INTO payments (order_id, uid, email, plan, amount, currency) VALUES (?,?,?,?,?,?)", [order.id, u.uid, u.email, plan, order.amount, order.currency || "INR"]);

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

/** The signed-in student's own payments, newest first. */
paymentsRouter.get("/payments/mine", requireAuth, wrap(async (req, res) => {
  const rows = await query<any>("SELECT order_id, plan, amount, status, payment_id, created_at, paid_at FROM payments WHERE uid = ? AND status = 'paid' ORDER BY paid_at DESC LIMIT 20", [req.user!.uid]);
  res.json({ items: rows.map(r => ({ orderId: r.order_id, plan: r.plan, amount: r.amount, paymentId: r.payment_id, paidAt: r.paid_at })) });
}));
