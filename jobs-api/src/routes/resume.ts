// Resume Premium: price and status, Razorpay checkout, AI writing help, and saving the AI's suggestions.
import { Router } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { z } from "zod";
import { exec, query } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { gateway, paymentsEnabled, razorpayConfig, validPaymentSignature } from "../payments.js";
import { aiDailyLimit, aiUsedToday, fulfilResumePremium, premiumDays, premiumFor, premiumPrice, reconcileResume, runResumeAi } from "../resume.js";
import { loadProfile } from "./talent.js";

export const resumeRouter = Router();

/** Price for everyone; for a signed-in person also whether they have Premium and how many AI requests are left today. */
resumeRouter.get("/resume/premium", wrap(async (req, res) => {
  const base = { price: premiumPrice(), days: premiumDays(), paymentsEnabled: paymentsEnabled(), aiDailyLimit: aiDailyLimit() };
  if (!req.user) return res.json({ ...base, active: false, expiresAt: null });
  await reconcileResume(req.user.uid);
  const [p, used] = await Promise.all([premiumFor(req.user.uid), aiUsedToday(req.user.uid)]);
  res.set("Cache-Control", "private, no-store");
  res.json({ ...base, ...p, aiLeftToday: Math.max(0, aiDailyLimit() - used) });
}));

const orderLimit = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: "draft-7", legacyHeaders: false,
  keyGenerator: req => (req as any).user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "Too many attempts. Please wait a few minutes and try again." }) });

resumeRouter.post("/resume/premium/order", requireAuth, orderLimit, wrap(async (req, res) => {
  if (!paymentsEnabled()) throw new HttpError(503, "Online payment opens soon. Please try again later.");
  const u = req.user!;
  await reconcileResume(u.uid);
  const amount = Math.round(premiumPrice() * 100), days = premiumDays();
  const ins = await exec("INSERT INTO resume_premium (uid, email, amount, days) VALUES (?,?,?,?)", [u.uid, u.email ?? null, amount, days]);
  const id = Number(ins.insertId);
  let order;
  try {
    order = await gateway().createOrder({ amount, receipt: `rp_${id}`, notes: { uid: u.uid, type: "resume_premium", days: String(days) } });
  } catch (e) {
    await exec("UPDATE resume_premium SET status = 'failed' WHERE id = ?", [id]);
    throw e;
  }
  await exec("UPDATE resume_premium SET order_id = ? WHERE id = ?", [order.id, id]);
  res.status(201).json({
    orderId: order.id, amount: order.amount, currency: order.currency || "INR", keyId: razorpayConfig().keyId,
    name: "Widgetry Academy", description: `Resume Premium · ${days} days`, prefill: { name: u.name ?? "", email: u.email ?? "" },
  });
}));

const verifyBody = z.object({
  orderId: z.string().trim().regex(/^order_[A-Za-z0-9]+$/),
  paymentId: z.string().trim().regex(/^pay_[A-Za-z0-9]+$/),
  signature: z.string().trim().regex(/^[a-f0-9]{64}$/),
});

resumeRouter.post("/resume/premium/verify", requireAuth, wrap(async (req, res) => {
  const { orderId, paymentId, signature } = verifyBody.parse(req.body);
  const [row] = await query<any>("SELECT uid, amount FROM resume_premium WHERE order_id = ?", [orderId]);
  if (!row || row.uid !== req.user!.uid) throw new HttpError(404, "We couldn't find this order.");
  if (!validPaymentSignature(orderId, paymentId, signature)) throw new HttpError(400, "We couldn't confirm this payment. If money was taken, Premium turns on automatically within a few minutes.");
  const pay = await gateway().fetchPayment(paymentId);
  if (pay.order_id !== orderId || pay.amount !== row.amount || !["captured", "authorized"].includes(pay.status))
    throw new HttpError(400, "This payment hasn't completed yet. If money was taken, Premium turns on automatically within a few minutes.");
  await fulfilResumePremium(orderId, paymentId, pay.method);
  res.json({ ok: true, ...(await premiumFor(req.user!.uid)) });
}));

// ---------- AI ----------
const aiBody = z.object({
  action: z.enum(["bullets", "summary", "tailor", "cover"]),
  experienceIndex: z.coerce.number().int().min(0).max(9).optional(),
  jobText: z.string().trim().max(12000).optional().transform(v => (v ? v : undefined)),
  jobTitle: z.string().trim().max(140).optional(),
  company: z.string().trim().max(120).optional(),
});

const aiBurst = rateLimit({ windowMs: 60 * 1000, limit: 6, standardHeaders: "draft-7", legacyHeaders: false,
  keyGenerator: req => (req as any).user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "One moment: please wait a few seconds between AI requests." }) });

resumeRouter.post("/resume/ai", requireAuth, aiBurst, wrap(async (req, res) => {
  const uid = req.user!.uid;
  const input = aiBody.parse(req.body);
  if (input.jobText && input.jobText.length < 80) throw new HttpError(400, "That job description is too short. Paste the full description.");
  const prem = await premiumFor(uid);
  if (!prem.active) throw new HttpError(402, "AI writing help is part of Resume Premium.");
  const used = await aiUsedToday(uid);
  if (used >= aiDailyLimit()) throw new HttpError(429, `You've used today's ${aiDailyLimit()} AI requests. They refresh over the next 24 hours.`);
  const profile = await loadProfile(uid);
  if (!profile) throw new HttpError(404, "Create your profile first.");
  const out = await runResumeAi(profile, input);
  await exec("INSERT INTO resume_ai_usage (uid, action, input_tokens, output_tokens) VALUES (?,?,?,?)", [uid, input.action, out.inputTokens, out.outputTokens]);
  res.json({ action: input.action, result: out.result, truncated: out.truncated, aiLeftToday: Math.max(0, aiDailyLimit() - used - 1) });
}));

// ---------- Saving suggestions into the profile ----------
// Only the summary and achievement points change; everything else in the profile stays as it is.
const contentBody = z.object({
  about: z.string().trim().max(2000).optional(),
  points: z.array(z.object({ index: z.number().int().min(0).max(9), points: z.string().trim().max(1500) })).max(10).optional(),
  addSkills: z.array(z.string().trim().min(1).max(40)).max(15).optional(),
}).refine(b => b.about !== undefined || b.points?.length || b.addSkills?.length, { message: "Nothing to save." });

resumeRouter.patch("/talent/me/resume-content", requireAuth, wrap(async (req, res) => {
  const b = contentBody.parse(req.body);
  const [c] = await query<any>("SELECT id, experience FROM candidates WHERE uid = ?", [req.user!.uid]);
  if (!c) throw new HttpError(404, "Create your profile first.");
  const exp = typeof c.experience === "string" ? JSON.parse(c.experience || "[]") : (c.experience ?? []);
  for (const p of b.points ?? []) {
    if (!exp[p.index]) throw new HttpError(400, "That job is no longer in your profile. Please refresh.");
    exp[p.index].points = p.points || null;
  }
  if (b.points?.length) await exec("UPDATE candidates SET experience = ? WHERE id = ?", [JSON.stringify(exp), c.id]);
  if (b.about !== undefined) await exec("UPDATE candidates SET about = ? WHERE id = ?", [b.about || null, c.id]);
  if (b.addSkills?.length) {
    const have = new Set((await query<{ skill: string }>("SELECT skill FROM candidate_skills WHERE candidate_id = ?", [c.id])).map(r => r.skill.toLowerCase()));
    // A profile holds up to 15 skills (the same limit as the profile form)
    const wanted = [...new Set(b.addSkills)].filter(s => !have.has(s.toLowerCase()));
    const add = wanted.slice(0, Math.max(0, 15 - have.size));
    if (wanted.length && !add.length) throw new HttpError(400, "Your profile already has 15 skills. Remove some in your profile to add these.");
    if (add.length) await query("INSERT INTO candidate_skills (candidate_id, skill) VALUES ?", [add.map(s => [c.id, s])]);
  }
  res.json({ profile: await loadProfile(req.user!.uid), message: "Saved to your profile." });
}));
