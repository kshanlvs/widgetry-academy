// Short live courses ("workshops") such as the Bloc crash course. Each has its own price, seats and
// dates, set by the admin. Paid on the website through Razorpay Checkout:
//   POST /workshops/:slug/enroll → Razorpay order → Checkout → POST /workshops/verify
// The Razorpay webhook and a recovery check (when the student opens the page again) also confirm payments.
import { Router } from "express";
import rateLimit from "express-rate-limit";
import { z } from "zod";
import { exec, query } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { gateway, paymentsEnabled, razorpayConfig, validPaymentSignature } from "../payments.js";
import { notifyUser } from "../notify.js";

const HOLD_MINUTES = 15;   // an unpaid enrolment keeps a seat this long
const minutesAgo = (m: number) => new Date(Date.now() - m * 60_000);
const rupees = (paise: number | null) => (paise == null ? null : Math.round(Number(paise) / 100));

async function bySlug(slug: string) {
  const [w] = await query<any>("SELECT * FROM workshops WHERE slug = ?", [String(slug).slice(0, 60)]);
  if (!w) throw new HttpError(404, "This course doesn't exist.");
  return w;
}

/** Seats taken (paid, plus unpaid ones still within their hold) and early-bird seats sold. */
async function seatInfo(w: any) {
  const [r] = await query<{ taken: number; early: number }>(
    `SELECT SUM(status = 'confirmed' OR (status = 'created' AND created_at > ?)) AS taken,
            SUM(status = 'confirmed' AND early = 1) AS early
     FROM workshop_enrollments WHERE workshop_id = ?`, [minutesAgo(HOLD_MINUTES), w.id]);
  const taken = Number(r?.taken ?? 0), early = Number(r?.early ?? 0);
  return { taken, seatsLeft: Math.max(0, Number(w.seats) - taken), earlySold: early };
}

function earlyActive(w: any, earlySold: number) {
  if (w.early_price == null) return false;
  if (w.early_until && new Date(w.early_until) <= new Date()) return false;
  if (w.early_seats != null && earlySold >= Number(w.early_seats)) return false;
  return true;
}

const workshopOut = (w: any, s: { seatsLeft: number; earlySold: number }) => {
  const early = earlyActive(w, s.earlySold);
  return {
    slug: w.slug, title: w.title, status: w.status,
    startsAt: w.starts_at ? new Date(w.starts_at).toISOString() : null,
    schedule: w.schedule ?? null, durationMin: Number(w.duration_min),
    price: rupees(w.price), earlyPrice: early ? rupees(w.early_price) : null,
    earlySeatsLeft: early && w.early_seats != null ? Math.max(0, Number(w.early_seats) - s.earlySold) : null,
    earlyUntil: early && w.early_until ? new Date(w.early_until).toISOString() : null,
    seatsLeft: s.seatsLeft,
  };
};

// ---------- Confirming a payment (idempotent) ----------
export async function fulfilWorkshop(orderId: string, paymentId: string, method?: string): Promise<{ status: string; first: boolean } | null> {
  const [e] = await query<any>("SELECT e.*, w.title, w.schedule FROM workshop_enrollments e JOIN workshops w ON w.id = e.workshop_id WHERE e.order_id = ?", [orderId]);
  if (!e) return null;
  // A late payment for an enrolment we'd already let go is still honoured: the student paid
  const r = await exec("UPDATE workshop_enrollments SET status = 'confirmed', payment_id = ?, method = ?, paid_at = CURRENT_TIMESTAMP WHERE id = ? AND status IN ('created','cancelled') AND paid_at IS NULL",
    [paymentId, method ?? null, e.id]);
  if (r.affectedRows === 0) return { status: e.status, first: false };
  // Any other unpaid attempts by the same person for this course are no longer needed
  await exec("UPDATE workshop_enrollments SET status = 'cancelled' WHERE workshop_id = ? AND uid = ? AND status = 'created' AND id <> ?", [e.workshop_id, e.uid, e.id]);
  void notifyUser(e.uid, { title: "You're enrolled 🎉", body: `${e.title}${e.schedule ? " · " + e.schedule : ""}. The joining link will be on the course page.`, data: { type: "workshop" } });
  return { status: "confirmed", first: true };
}

/** Confirms this person's recent unpaid enrolments that Razorpay says were actually paid. */
export async function reconcileWorkshops(uid: string): Promise<void> {
  if (!paymentsEnabled()) return;
  try {
    const rows = await query<{ order_id: string; amount: number }>(
      "SELECT order_id, amount FROM workshop_enrollments WHERE uid = ? AND status IN ('created','cancelled') AND paid_at IS NULL AND order_id IS NOT NULL AND created_at > ? ORDER BY created_at DESC LIMIT 3",
      [uid, minutesAgo(3 * 24 * 60)]);
    for (const r of rows) {
      const paid = (await gateway().orderPayments(r.order_id)).find(p => p.status === "captured" && p.amount === r.amount);
      if (paid) await fulfilWorkshop(r.order_id, paid.id, paid.method);
    }
  } catch (e: any) { console.warn(`[workshops] reconcile ${uid} failed: ${e?.message}`); }
}

export const workshopsRouter = Router();

/** Course details for the course page. Signed in: also your enrolment, and the joining link once paid. */
workshopsRouter.get("/workshops/:slug", wrap(async (req, res) => {
  const w = await bySlug(String(req.params.slug));
  let mine: unknown = null;
  if (req.user) {
    await reconcileWorkshops(req.user.uid);
    const [e] = await query<any>("SELECT * FROM workshop_enrollments WHERE workshop_id = ? AND uid = ? AND status IN ('confirmed','refunded') ORDER BY id DESC LIMIT 1", [w.id, req.user.uid]);
    if (e) mine = { status: e.status, amount: rupees(e.amount), paidAt: e.paid_at ? new Date(e.paid_at).toISOString() : null, paymentId: e.payment_id,
      meetingLink: e.status === "confirmed" ? w.meeting_link ?? null : null };
  }
  res.set("Cache-Control", "private, no-store");
  res.json({ workshop: workshopOut(w, await seatInfo(w)), mine, paymentsOpen: paymentsEnabled() });
}));

const enrollLimit = rateLimit({ windowMs: 60 * 60 * 1000, limit: 15, standardHeaders: "draft-7", legacyHeaders: false,
  handler: (_req, res) => res.status(429).json({ error: "Too many attempts. Please try again in a while." }) });

const enrollBody = z.object({
  name: z.string().trim().min(2, "Please enter your full name").max(99),
  phone: z.string().trim().transform(v => v.replace(/[\s()-]/g, "")).transform(v => (/^[6-9]\d{9}$/.test(v) ? "+91" + v : /^91[6-9]\d{9}$/.test(v) ? "+" + v : v))
    .refine(v => /^\+[1-9]\d{9,14}$/.test(v), "Enter your WhatsApp number, e.g. 98765 43210"),
});

workshopsRouter.post("/workshops/:slug/enroll", requireAuth, enrollLimit, wrap(async (req, res) => {
  if (!paymentsEnabled()) throw new HttpError(503, "Online payment opens soon. Message us on WhatsApp to enrol meanwhile.");
  const b = enrollBody.parse(req.body);
  const u = req.user!;
  const w = await bySlug(String(req.params.slug));
  if (w.status !== "open") throw new HttpError(409, w.status === "draft" ? "Enrolment opens once the dates are announced." : "Enrolment for this course is closed.");
  if (w.starts_at && new Date(w.starts_at) <= new Date()) throw new HttpError(409, "This batch has already started.");
  await reconcileWorkshops(u.uid);
  const [done] = await query("SELECT id FROM workshop_enrollments WHERE workshop_id = ? AND uid = ? AND status = 'confirmed'", [w.id, u.uid]);
  if (done) throw new HttpError(409, "You're already enrolled in this course.");
  // Starting again releases your earlier unpaid seat
  await exec("UPDATE workshop_enrollments SET status = 'cancelled' WHERE workshop_id = ? AND uid = ? AND status = 'created'", [w.id, u.uid]);
  const s = await seatInfo(w);
  if (s.seatsLeft <= 0) throw new HttpError(409, "All seats are taken. Message us on WhatsApp to join the waiting list.");
  const early = earlyActive(w, s.earlySold);
  const amount = Number(early ? w.early_price : w.price);
  const ins = await exec("INSERT INTO workshop_enrollments (workshop_id, uid, email, name, phone, amount, early) VALUES (?,?,?,?,?,?,?)",
    [w.id, u.uid, u.email, b.name, b.phone, amount, early ? 1 : 0]);
  const id = Number(ins.insertId);
  let order;
  try {
    order = await gateway().createOrder({ amount, receipt: `ws_${id}`, notes: { uid: u.uid, enrollment: String(id), type: "workshop", course: w.slug } });
  } catch (e) {
    await exec("UPDATE workshop_enrollments SET status = 'cancelled' WHERE id = ?", [id]);
    throw e;
  }
  await exec("UPDATE workshop_enrollments SET order_id = ? WHERE id = ?", [order.id, id]);
  res.status(201).json({
    orderId: order.id, amount: order.amount, currency: order.currency || "INR", keyId: razorpayConfig().keyId,
    name: "Widgetry Academy", description: w.title, prefill: { name: b.name, email: u.email ?? "", contact: b.phone },
  });
}));

const verifyBody = z.object({
  orderId: z.string().trim().regex(/^order_[A-Za-z0-9]+$/),
  paymentId: z.string().trim().regex(/^pay_[A-Za-z0-9]+$/),
  signature: z.string().trim().regex(/^[a-f0-9]{64}$/),
});

workshopsRouter.post("/workshops/verify", requireAuth, wrap(async (req, res) => {
  const { orderId, paymentId, signature } = verifyBody.parse(req.body);
  const [e] = await query<any>("SELECT uid, amount FROM workshop_enrollments WHERE order_id = ?", [orderId]);
  if (!e || e.uid !== req.user!.uid) throw new HttpError(404, "We couldn't find this enrolment.");
  if (!validPaymentSignature(orderId, paymentId, signature)) throw new HttpError(400, "We couldn't confirm this payment. If money was taken, it will be confirmed automatically within a few minutes.");
  const pay = await gateway().fetchPayment(paymentId);
  if (pay.order_id !== orderId || pay.amount !== e.amount || !["captured", "authorized"].includes(pay.status))
    throw new HttpError(400, "This payment hasn't completed yet. If money was taken, it will be confirmed automatically within a few minutes.");
  const r = await fulfilWorkshop(orderId, paymentId, pay.method);
  res.json({ ok: true, status: r?.status ?? "confirmed" });
}));

// ---------- Admin (mounted under /admin with requireAdmin) ----------
export const workshopsAdminRouter = Router();

const paise = (v: number | null | undefined) => (v == null ? null : Math.round(v * 100));
const workshopEdit = z.object({
  title: z.string().trim().min(4).max(140),
  startsAt: z.string().datetime({ offset: true }).nullable().optional(),
  schedule: z.string().trim().max(200).nullable().optional().transform(v => (v ? v : null)),
  durationMin: z.coerce.number().int().min(30).max(6000).default(300),
  price: z.coerce.number().int().min(1).max(500000),
  earlyPrice: z.coerce.number().int().min(1).max(500000).nullable().optional(),
  earlyUntil: z.string().datetime({ offset: true }).nullable().optional(),
  earlySeats: z.coerce.number().int().min(1).max(10000).nullable().optional(),
  seats: z.coerce.number().int().min(1).max(10000),
  meetingLink: z.string().trim().max(500).nullable().optional().transform(v => (v ? v : null))
    .refine(v => !v || /^https:\/\/\S+$/i.test(v), "The joining link must start with https://"),
  status: z.enum(["draft", "open", "closed", "done"]),
}).superRefine((b, ctx) => {
  if (b.earlyPrice != null && b.earlyPrice >= b.price) ctx.addIssue({ code: "custom", path: ["earlyPrice"], message: "The early-bird price must be lower than the full price" });
  if (b.status === "open" && !b.startsAt) ctx.addIssue({ code: "custom", path: ["startsAt"], message: "Set the start date before opening enrolment" });
});
const slugBody = z.object({ slug: z.string().trim().regex(/^[a-z0-9][a-z0-9-]{2,58}$/, "Use lowercase letters, numbers and dashes, e.g. riverpod-crash-course") });

workshopsAdminRouter.get("/workshops", wrap(async (_req, res) => {
  const rows = await query<any>("SELECT * FROM workshops ORDER BY (status = 'done'), COALESCE(starts_at, '2999-01-01') DESC, id DESC");
  const counts = await query<any>("SELECT workshop_id, SUM(status = 'confirmed') AS paid, SUM(CASE WHEN status = 'confirmed' THEN amount ELSE 0 END) AS revenue, SUM(status = 'refunded') AS refunded FROM workshop_enrollments GROUP BY workshop_id");
  res.json({ items: rows.map(w => {
    const c = counts.find(x => Number(x.workshop_id) === Number(w.id));
    return {
      id: Number(w.id), slug: w.slug, title: w.title, status: w.status,
      startsAt: w.starts_at ? new Date(w.starts_at).toISOString() : null, schedule: w.schedule, durationMin: Number(w.duration_min),
      price: rupees(w.price), earlyPrice: rupees(w.early_price), earlyUntil: w.early_until ? new Date(w.early_until).toISOString() : null,
      earlySeats: w.early_seats == null ? null : Number(w.early_seats), seats: Number(w.seats), meetingLink: w.meeting_link,
      enrolled: Number(c?.paid ?? 0), refunded: Number(c?.refunded ?? 0), revenue: rupees(Number(c?.revenue ?? 0)),
    };
  }) });
}));

workshopsAdminRouter.post("/workshops", wrap(async (req, res) => {
  const { slug } = slugBody.parse(req.body);
  const b = workshopEdit.parse({ status: "draft", ...req.body });
  const [dup] = await query("SELECT id FROM workshops WHERE slug = ?", [slug]);
  if (dup) throw new HttpError(409, "A course with this link name already exists.");
  const r = await exec(`INSERT INTO workshops (slug, title, starts_at, schedule, duration_min, price, early_price, early_until, early_seats, seats, meeting_link, status)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
    [slug, b.title, b.startsAt ? new Date(b.startsAt) : null, b.schedule, b.durationMin, paise(b.price), paise(b.earlyPrice), b.earlyUntil ? new Date(b.earlyUntil) : null, b.earlySeats ?? null, b.seats, b.meetingLink, b.status]);
  res.status(201).json({ id: Number(r.insertId) });
}));

workshopsAdminRouter.put("/workshops/:id", wrap(async (req, res) => {
  const b = workshopEdit.parse(req.body);
  const r = await exec(`UPDATE workshops SET title = ?, starts_at = ?, schedule = ?, duration_min = ?, price = ?, early_price = ?, early_until = ?, early_seats = ?, seats = ?, meeting_link = ?, status = ? WHERE id = ?`,
    [b.title, b.startsAt ? new Date(b.startsAt) : null, b.schedule, b.durationMin, paise(b.price), paise(b.earlyPrice), b.earlyUntil ? new Date(b.earlyUntil) : null, b.earlySeats ?? null, b.seats, b.meetingLink, b.status, Number(req.params.id) || 0]);
  if (!r.affectedRows) throw new HttpError(404, "Course not found.");
  res.json({ ok: true });
}));

workshopsAdminRouter.get("/workshops/:id/enrollments", wrap(async (req, res) => {
  const rows = await query<any>("SELECT * FROM workshop_enrollments WHERE workshop_id = ? AND status IN ('confirmed','refunded') ORDER BY paid_at DESC", [Number(req.params.id) || 0]);
  res.json({ items: rows.map(e => ({ id: Number(e.id), name: e.name, email: e.email, phone: e.phone, amount: rupees(e.amount), early: !!e.early, status: e.status, paymentId: e.payment_id, paidAt: e.paid_at })) });
}));

workshopsAdminRouter.patch("/workshop-enrollments/:id", wrap(async (req, res) => {
  const { status } = z.object({ status: z.enum(["refunded"]) }).parse(req.body);
  const r = await exec("UPDATE workshop_enrollments SET status = ? WHERE id = ? AND status = 'confirmed'", [status, Number(req.params.id) || 0]);
  if (!r.affectedRows) throw new HttpError(404, "Only a paid enrolment can be marked refunded.");
  res.json({ ok: true });
}));
