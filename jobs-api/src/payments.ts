// Course fees through Razorpay (orders API). Prices live here on the server, never in the app.
//
// Flow: app asks POST /payments/order → we create a Razorpay order for the right amount →
// the app opens Razorpay Checkout → on success the app sends the signature to POST /payments/verify,
// and Razorpay also calls POST /payments/webhook. Either one marks the payment paid (whichever comes first)
// and updates the student's registration in Firestore exactly like Admin → Registrations does.
import { createHmac, timingSafeEqual } from "node:crypto";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { adminApp, canSendPush } from "./firebase.js";
import { query, exec } from "./db.js";
import { HttpError } from "./errors.js";
import { notifyUser, SITE } from "./notify.js";
import { reportExternal } from "./play.js";

const env = process.env;
export const razorpayConfig = () => ({
  keyId: env.RAZORPAY_KEY_ID || "",
  keySecret: env.RAZORPAY_KEY_SECRET || "",
  webhookSecret: env.RAZORPAY_WEBHOOK_SECRET || "",
});
export const paymentsEnabled = () => { const c = razorpayConfig(); return !!(c.keyId && c.keySecret); };

// ---------- Plans (same as the website: Admin → Registrations uses the same names and prices) ----------
export type PlanId = "early-bird" | "regular" | "booking" | "balance";
const rupees = (name: string, fallback: number) => Number(env[name] || fallback);
/** Full course price for each plan (what "paid in full" means). */
export const coursePrice = (plan: string) => ({ "early-bird": rupees("PRICE_EARLY_BIRD", 3499), regular: rupees("PRICE_REGULAR", 4999), booking: rupees("PRICE_REGULAR", 4999) } as Record<string, number>)[plan] ?? 0;
export const bookingAmount = () => rupees("PRICE_BOOKING", 2500);
export const COURSE = "Flutter in 10 Days";

export interface Registration { name?: string; email?: string; phone?: string; plan?: string | null; payStatus?: string; amountPaid?: number; batch?: string }
export interface Plan { id: PlanId; title: string; note: string; amount: number; fullPrice: number; recommended?: boolean }

const paidStatuses = new Set(["paid", "full", "completed"]);
const closedStatuses = new Set(["refunded", "cancelled"]);

/** What this student can pay right now, based on their registration. */
export async function plansFor(reg: Registration | null): Promise<{ plans: Plan[]; due: number; status: string }> {
  const status = !reg ? "unregistered" : closedStatuses.has(reg.payStatus ?? "") ? reg.payStatus! : paidStatuses.has(reg.payStatus ?? "") ? "paid" : (reg.amountPaid ?? 0) > 0 ? "part-paid" : "unpaid";
  if (status === "paid" || closedStatuses.has(status) || status === "unregistered") return { plans: [], due: 0, status };
  if (status === "part-paid") {
    const plan = reg!.plan && coursePrice(reg!.plan) ? reg!.plan : "booking";
    const due = Math.max(0, coursePrice(plan) - (reg!.amountPaid ?? 0));
    return due > 0
      ? { plans: [{ id: "balance", title: "Pay the balance", note: `You've paid ₹${(reg!.amountPaid ?? 0).toLocaleString("en-IN")}. Pay the rest to complete your fee.`, amount: due, fullPrice: coursePrice(plan) }], due, status }
      : { plans: [], due: 0, status: "paid" };
  }
  const plans: Plan[] = [];
  if (await store().earlyBirdOpen()) plans.push({ id: "early-bird", title: "Early bird", note: "Full fee at the early-bird price. Limited seats.", amount: coursePrice("early-bird"), fullPrice: coursePrice("early-bird"), recommended: true });
  plans.push({ id: "regular", title: "Pay in full", note: "One payment, seat confirmed.", amount: coursePrice("regular"), fullPrice: coursePrice("regular"), recommended: plans.length === 0 });
  plans.push({ id: "booking", title: "Book with a part payment", note: `Pay ₹${bookingAmount().toLocaleString("en-IN")} now and ₹${(coursePrice("booking") - bookingAmount()).toLocaleString("en-IN")} before the course starts.`, amount: bookingAmount(), fullPrice: coursePrice("booking") });
  return { plans, due: plans[0]?.amount ?? 0, status };
}

// ---------- Outside services (replaced in tests) ----------
export interface Gateway {
  createOrder(o: { amount: number; receipt: string; notes: Record<string, string> }): Promise<{ id: string; amount: number; currency: string }>;
  fetchPayment(id: string): Promise<{ id: string; order_id: string | null; amount: number; status: string; method?: string }>;
  /** All payment attempts on an order (used to recover payments the app couldn't confirm). */
  orderPayments(orderId: string): Promise<{ id: string; order_id: string | null; amount: number; status: string; method?: string }[]>;
}
export interface RegistrationStore {
  get(uid: string): Promise<Registration | null>;
  /** Adds a payment to the registration and returns the new pay status. */
  addPayment(uid: string, p: { plan: PlanId; amount: number; paymentId: string }): Promise<string>;
  earlyBirdOpen(): Promise<boolean>;
}

const razorpayGateway: Gateway = {
  async createOrder(o) {
    return rzp("POST", "/v1/orders", { amount: o.amount, currency: "INR", receipt: o.receipt, notes: o.notes });
  },
  async fetchPayment(id) {
    return rzp("GET", `/v1/payments/${encodeURIComponent(id)}`);
  },
  async orderPayments(orderId) {
    const r = await rzp("GET", `/v1/orders/${encodeURIComponent(orderId)}/payments`);
    return Array.isArray(r?.items) ? r.items : [];
  },
};

async function rzp(method: string, path: string, body?: unknown) {
  const { keyId, keySecret } = razorpayConfig();
  const r = await fetch("https://api.razorpay.com" + path, {
    method,
    headers: { authorization: "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64"), "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(15000),
  });
  const json: any = await r.json().catch(() => ({}));
  if (!r.ok) {
    console.error(`[razorpay] ${method} ${path} → ${r.status}`, json?.error?.description ?? "");
    throw new HttpError(502, "The payment service is not responding. Please try again in a minute.");
  }
  return json;
}

const firestoreStore: RegistrationStore = {
  async get(uid) {
    const d = await getFirestore(adminApp()).collection("registrations").doc(uid).get();
    return d.exists ? (d.data() as Registration) : null;
  },
  async addPayment(uid, p) {
    const db = getFirestore(adminApp());
    const ref = db.collection("registrations").doc(uid);
    return db.runTransaction(async t => {
      const d = await t.get(ref);
      if (!d.exists) throw new Error(`registration ${uid} not found`);
      const reg = d.data() as Registration;
      const plan = p.plan === "balance" ? (reg.plan || "booking") : p.plan;
      const amountPaid = (reg.amountPaid ?? 0) + p.amount;
      const payStatus = amountPaid >= coursePrice(plan) ? "paid" : "part-paid";
      t.update(ref, { plan, amountPaid, payStatus, paymentId: p.paymentId, adminUpdatedAt: FieldValue.serverTimestamp() });
      return payStatus;
    });
  },
  async earlyBirdOpen() {
    if (env.EARLY_BIRD === "off") return false;
    if (!canSendPush()) return true; // no Firebase service account (tests, local dev): nothing to ask
    try {
      const d = await getFirestore(adminApp()).collection("settings").doc("batch").get();
      const seats = d.data()?.seatsLeft;
      return !(typeof seats === "number" && seats <= 0);
    } catch { return true; }
  },
};

let gw: Gateway | null = null, rs: RegistrationStore | null = null;
/** Tests replace Razorpay and Firestore with fakes. */
export function setPaymentServices(g: Gateway | null, s: RegistrationStore | null) { gw = g; rs = s; }
export const gateway = () => gw ?? razorpayGateway;
export const store = () => rs ?? firestoreStore;

// ---------- Signatures ----------
const hmac = (secret: string, data: string | Buffer) => createHmac("sha256", secret).update(data).digest("hex");
function safeEqual(a: string, b: string) {
  const x = Buffer.from(a), y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}
/** Checkout success: HMAC(order_id|payment_id) with the API key secret. */
export const validPaymentSignature = (orderId: string, paymentId: string, signature: string) =>
  safeEqual(hmac(razorpayConfig().keySecret, `${orderId}|${paymentId}`), signature);
/** Webhook: HMAC(raw body) with the webhook secret. */
export const validWebhookSignature = (raw: Buffer, signature: string) =>
  !!razorpayConfig().webhookSecret && safeEqual(hmac(razorpayConfig().webhookSecret, raw), signature);

// ---------- Marking a payment paid (idempotent) ----------
export async function fulfil(orderId: string, paymentId: string, method?: string): Promise<{ status: string; first: boolean } | null> {
  const [order] = await query<{ uid: string; plan: PlanId; amount: number; status: string; payment_id: string | null }>("SELECT uid, plan, amount, status, payment_id FROM payments WHERE order_id = ?", [orderId]);
  if (!order) return null;
  // Only the first caller (app or webhook) updates the registration
  const res = await exec("UPDATE payments SET status = 'paid', payment_id = ?, method = ?, paid_at = CURRENT_TIMESTAMP WHERE order_id = ? AND status <> 'paid'", [paymentId, method ?? null, orderId]);
  if (res.affectedRows === 0) {
    const reg = await store().get(order.uid);
    return { status: (await plansFor(reg)).status, first: false };
  }
  let status: string;
  try {
    status = await store().addPayment(order.uid, { plan: order.plan, amount: Math.round(order.amount / 100), paymentId });
  } catch (e) {
    // Couldn't update the registration: undo, so the webhook (or a retry) can try again
    await exec("UPDATE payments SET status = 'created', payment_id = NULL, method = NULL, paid_at = NULL WHERE order_id = ?", [orderId]);
    throw e;
  }
  // Razorpay chosen on Google's choice screen: Google must be told within 24 hours (retried if this fails)
  void reportExternal(orderId).catch(e => console.warn(`[play] report ${orderId} failed: ${e?.message}`));
  void notifyUser(order.uid, {
    title: status === "paid" ? "Payment received. Your seat is confirmed" : "Booking received. Your seat is held",
    body: status === "paid" ? `Thank you! You're all set for ${COURSE}. Batch details come on WhatsApp.` : `We received ₹${Math.round(order.amount / 100).toLocaleString("en-IN")}. Pay the balance from the app before the course starts.`,
    link: `${SITE}/#fees`,
    data: { type: "payment" },
  });
  return { status, first: true };
}

/**
 * Recovers payments that went through but were never confirmed (app closed, network dropped,
 * webhook delayed): asks Razorpay about this student's recent unconfirmed orders.
 * Runs before showing what is due and before creating a new order, so nobody pays twice.
 */
export async function reconcile(uid: string): Promise<number> {
  if (!paymentsEnabled()) return 0;
  let fixed = 0;
  try {
    const rows = await query<{ order_id: string; amount: number }>(
      "SELECT order_id, amount FROM payments WHERE uid = ? AND status = 'created' AND channel = 'razorpay' AND created_at > (CURRENT_TIMESTAMP - INTERVAL 3 DAY) ORDER BY created_at DESC LIMIT 3", [uid]);
    for (const r of rows) {
      const items = await gateway().orderPayments(r.order_id);
      const paid = items.find(p => p.status === "captured" && p.amount === r.amount && (p.order_id ?? r.order_id) === r.order_id);
      if (paid) { const res = await fulfil(r.order_id, paid.id, paid.method); if (res?.first) fixed++; }
    }
  } catch (e: any) {
    console.warn(`[payments] reconcile ${uid} failed: ${e?.message}`);
  }
  return fixed;
}

export const PLAN_TITLE: Record<string, string> = { "early-bird": "Early bird (full fee)", regular: "Full fee", booking: "Booking (part payment)", balance: "Balance payment" };
