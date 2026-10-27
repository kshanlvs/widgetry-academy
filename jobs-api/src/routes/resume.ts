// Resume Premium: price and status, Razorpay checkout, AI writing help, and saving the AI's suggestions.
import { Router } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { z } from "zod";
import { exec, query } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { gateway, paymentsEnabled, razorpayConfig, validPaymentSignature } from "../payments.js";
import { aiDailyLimit, aiUsedToday, applyVersion, fulfilResumePremium, isResumeProduct, MAX_VERSIONS, premiumDays, premiumFor, premiumPrice, reconcileResume, resumePlayProduct, runResumeAi, versionFor, versionOut } from "../resume.js";
import { INDIA_STATES, playAccountId, playApi, playConfig } from "../play.js";
import { DENSITIES, HIDEABLE, ACCENTS } from "../validate.js";
import { fileBase, htmlToPdf, needsWatermark, resumeDocx, resumeHtml, type ResumeLook } from "../resumeDoc.js";
import { atsCheck } from "../shared/resume-ats.js";
import { TEMPLATES } from "../shared/resume-render.js";
import { extractText, fileKind, MAX_UPLOAD, parseQuick, parseWithAi } from "../resumeImport.js";
import { loadProfile } from "./talent.js";

export const resumeRouter = Router();

/** Price for everyone; for a signed-in person also whether they have Premium and how many AI requests are left today. */
resumeRouter.get("/resume/premium", wrap(async (req, res) => {
  const base = { price: premiumPrice(), days: premiumDays(), paymentsEnabled: paymentsEnabled(), aiDailyLimit: aiDailyLimit(),
    // Android app: Google's choice screen (Google Play or Razorpay) when billing is "user_choice"
    playProductId: playConfig().androidBilling === "user_choice" ? resumePlayProduct() : null, maxVersions: MAX_VERSIONS() };
  if (!req.user) return res.json({ ...base, active: false, expiresAt: null });
  await reconcileResume(req.user.uid);
  const [p, used] = await Promise.all([premiumFor(req.user.uid), aiUsedToday(req.user.uid)]);
  res.set("Cache-Control", "private, no-store");
  res.json({ ...base, ...p, aiLeftToday: Math.max(0, aiDailyLimit() - used),
    // The Android app: Google's choice screen needs these (same as short courses)
    android: { billing: playConfig().androidBilling, accountId: playAccountId(req.user.uid), states: INDIA_STATES } });
}));

const orderLimit = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10, standardHeaders: "draft-7", legacyHeaders: false,
  keyGenerator: req => (req as any).user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "Too many attempts. Please wait a few minutes and try again." }) });

const orderBody = z.object({
  // Android app: "play" records the purchase before Google's purchase screen; "razorpay" (default) creates a Razorpay order
  mode: z.enum(["razorpay", "play"]).default("razorpay"),
  // Set when the person picked Razorpay on Google Play's choice screen
  externalTransactionToken: z.string().trim().min(10).max(4000).optional(),
  state: z.enum(INDIA_STATES).optional(),
}).refine(b => !b.externalTransactionToken || b.state, { path: ["state"], message: "Choose your state" });

resumeRouter.post("/resume/premium/order", requireAuth, orderLimit, wrap(async (req, res) => {
  const b = orderBody.parse(req.body ?? {});
  const u = req.user!;
  const amount = Math.round(premiumPrice() * 100), days = premiumDays();
  if (b.mode === "play") {
    if (playConfig().androidBilling !== "user_choice") throw new HttpError(409, "Google Play isn't available here. Please pay with Razorpay.");
    const ins = await exec("INSERT INTO resume_premium (uid, email, amount, days, channel) VALUES (?,?,?,?,'google_play')", [u.uid, u.email ?? null, amount, days]);
    return res.status(201).json({ id: Number(ins.insertId), productId: resumePlayProduct(), amount });
  }
  if (!paymentsEnabled()) throw new HttpError(503, "Online payment opens soon. Please try again later.");
  await reconcileResume(u.uid);
  const ins = await exec("INSERT INTO resume_premium (uid, email, amount, days, ext_token, tax_state) VALUES (?,?,?,?,?,?)",
    [u.uid, u.email ?? null, amount, days, b.externalTransactionToken ?? null, b.state ?? null]);
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

const playBody = z.object({
  productId: z.string().trim().refine(isResumeProduct, "Unknown product."),
  purchaseToken: z.string().trim().min(10).max(500),
});

/**
 * Paid with Google Play in the app. Matched to the purchase this person started for that price, checked with
 * Google, then consumed (so Premium can be bought again later). A purchase we can't match is left unconsumed,
 * so Google refunds it after 3 days.
 */
resumeRouter.post("/resume/premium/play/verify", requireAuth, wrap(async (req, res) => {
  const { productId, purchaseToken } = playBody.parse(req.body);
  const uid = req.user!.uid;
  const rupees = Number(productId.split("_").pop());
  const p = await playApi().getPurchase(productId, purchaseToken);
  if (p.obfuscatedExternalAccountId && p.obfuscatedExternalAccountId !== playAccountId(uid)) throw new HttpError(403, "This purchase belongs to another account.");
  if (p.purchaseState === 2) return res.status(202).json({ ok: true, status: "pending" });
  if (p.purchaseState !== 0 || !p.orderId) throw new HttpError(400, "This purchase was not completed.");
  const orderId = p.orderId.slice(0, 40);
  const consume = () => (p.consumptionState === 1 ? Promise.resolve() : playApi().consume(productId, purchaseToken).catch(e => console.warn(`[play] consume ${orderId} failed: ${e?.message}`)));
  const [done] = await query<any>("SELECT uid FROM resume_premium WHERE order_id = ?", [orderId]);
  if (done) {
    if (done.uid !== uid) throw new HttpError(403, "This purchase belongs to another account.");
    await consume();
    return res.json({ ok: true, status: "paid", ...(await premiumFor(uid)) });
  }
  const [row] = await query<any>(
    `SELECT id FROM resume_premium WHERE uid = ? AND channel = 'google_play' AND status IN ('created','failed') AND order_id IS NULL AND amount = ? AND created_at > ?
     ORDER BY id DESC LIMIT 1`, [uid, rupees * 100, new Date(Date.now() - 3 * 86_400_000)]);
  if (!row) {
    console.warn(`[play] ${uid} bought ${productId} (${orderId}) with nothing to match; left for Google to refund`);
    throw new HttpError(409, "We couldn't match this payment, so Google refunds it to you automatically within 3 days.");
  }
  await exec("UPDATE resume_premium SET order_id = ?, purchase_token = ? WHERE id = ?", [orderId, purchaseToken, row.id]);
  await fulfilResumePremium(orderId, orderId, "google_play");
  await consume();
  res.json({ ok: true, status: "paid", ...(await premiumFor(uid)) });
}));

// ---------- Downloads: PDF and Word, made on the server ----------
const lookBody = z.object({
  versionId: z.coerce.number().int().positive().optional(),
  // Unsaved changes from the preview; anything left out comes from the saved settings
  template: z.string().refine(t => t in TEMPLATES, "Unknown template").optional(),
  accent: z.enum(ACCENTS).optional(),
  title: z.string().trim().max(140).optional(),
  showPhoto: z.boolean().optional(),
  hide: z.array(z.enum(HIDEABLE)).max(HIDEABLE.length).optional(),
  density: z.enum(DENSITIES).optional(),
});

/** The resume to print: the profile (or a saved copy of it) and how it should look. */
async function resumeFor(uid: string, body: unknown) {
  const b = lookBody.parse(body ?? {});
  const profile = await loadProfile(uid);
  if (!profile) throw new HttpError(404, "Create your resume first.");
  let p = profile, look: ResumeLook = { template: "modern", ...(profile.resumeSettings || {}) };
  if (b.versionId) {
    const v = await versionFor(uid, b.versionId);
    p = applyVersion(profile, v.data);
    look = { ...look, ...(v.settings || {}), ...(v.data.title ? { title: v.data.title } : {}) };
  }
  const { versionId: _v, ...over } = b;
  look = { ...look, ...Object.fromEntries(Object.entries(over).filter(([, x]) => x !== undefined)) };
  return { p, look };
}

const fileLimit = rateLimit({ windowMs: 10 * 60 * 1000, limit: 40, standardHeaders: "draft-7", legacyHeaders: false,
  keyGenerator: req => (req as any).user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "Too many downloads. Please wait a few minutes." }) });

resumeRouter.post("/resume/pdf", requireAuth, fileLimit, wrap(async (req, res) => {
  const uid = req.user!.uid;
  const { p, look } = await resumeFor(uid, req.body);
  const premium = (await premiumFor(uid)).active;
  const watermark = needsWatermark(look.template, premium);
  let out;
  try { out = await htmlToPdf(resumeHtml(p, look, watermark)); }
  catch (e: any) { console.error(`[resume] pdf failed: ${e?.message}`); throw new HttpError(503, "We couldn't make the PDF right now. Please try again in a minute."); }
  res.set({ "Content-Type": "application/pdf", "Content-Disposition": `attachment; filename="${fileBase(p.fullName)}.pdf"`,
    "X-Resume-Pages": String(out.pages), "X-Resume-Watermark": watermark ? "1" : "0", "Access-Control-Expose-Headers": "X-Resume-Pages, X-Resume-Watermark, Content-Disposition" });
  res.send(out.pdf);
}));

resumeRouter.post("/resume/docx", requireAuth, fileLimit, wrap(async (req, res) => {
  const { p, look } = await resumeFor(req.user!.uid, req.body);
  const buf = await resumeDocx(p, look);
  res.set({ "Content-Type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "Content-Disposition": `attachment; filename="${fileBase(p.fullName)}.docx"`, "Access-Control-Expose-Headers": "Content-Disposition" });
  res.send(buf);
}));

// ---------- ATS check of the saved resume (the app; the website runs the same code in the browser) ----------
const atsBody = z.object({
  versionId: z.coerce.number().int().positive().optional(),
  jobId: z.string().trim().max(20).optional(),
  jobText: z.string().trim().max(12000).optional(),
  jobTitle: z.string().trim().max(140).optional(),
});
resumeRouter.post("/resume/ats", requireAuth, wrap(async (req, res) => {
  const b = atsBody.parse(req.body ?? {});
  const { p, look } = await resumeFor(req.user!.uid, b.versionId ? { versionId: b.versionId } : {});
  let job: { title: string; text: string; company?: string; id?: string } | null = null;
  if (b.jobId) {
    const [j] = await query<any>("SELECT j.public_id, j.title, j.description, c.name AS company FROM jobs j JOIN companies c ON c.id = j.company_id WHERE j.public_id = ?", [b.jobId]);
    if (!j) throw new HttpError(404, "That job is no longer available.");
    const skills = (await query<{ skill: string }>("SELECT s.skill FROM job_skills s JOIN jobs j ON j.id = s.job_id WHERE j.public_id = ?", [b.jobId])).map(s => s.skill);
    job = { id: j.public_id, title: j.title, company: j.company, text: `${j.title}\n${j.description || ""}\nSkills: ${skills.join(", ")}` };
  } else if (b.jobText) {
    if (b.jobText.length < 80) throw new HttpError(400, "Paste the full job description (at least a few lines).");
    job = { title: b.jobTitle || b.jobText.split("\n")[0]!.slice(0, 90), text: b.jobText };
  }
  res.json({ job: job && { id: job.id ?? null, title: job.title, company: job.company ?? null }, result: (atsCheck as any)(p, job, look) });
}));

// ---------- Reading an existing resume (import) ----------
// Body: the file itself (Content-Type application/pdf or the Word type, ?name=resume.pdf), or JSON { text }.
// Add ?ai=1 (or { ai: true }) to have AI read it: slower, better on unusual layouts, limited per day.
const importLimit = rateLimit({ windowMs: 60 * 60 * 1000, limit: 30, standardHeaders: "draft-7", legacyHeaders: false,
  keyGenerator: req => (req as any).user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "Too many imports. Please wait a while and try again." }) });
const importAiDaily = () => Number(process.env.RESUME_IMPORT_AI_DAILY || 3);          // per person (or network) per day
const importAiGlobal = () => Number(process.env.RESUME_IMPORT_AI_GLOBAL || 400);      // for everyone per day: a cost ceiling

resumeRouter.post("/resume/import", importLimit, wrap(async (req, res) => {
  let text: string, pages = 1, kind: string;
  if (Buffer.isBuffer(req.body)) {
    const bytes = req.body as Buffer;
    if (!bytes.length) throw new HttpError(400, "Choose a PDF or Word (.docx) file.");
    if (bytes.length > MAX_UPLOAD) throw new HttpError(413, "That file is over 5 MB. Choose a smaller PDF or Word file.");
    const k = fileKind(bytes);
    if (!k) throw new HttpError(400, "Choose a PDF or a Word (.docx) file. Old .doc files: save as .docx first.");
    ({ text, pages } = await extractText(bytes, k)); kind = k;
  } else {
    text = z.object({ text: z.string().max(40000) }).parse(req.body ?? {}).text; kind = "text";
  }
  if (text.replace(/\s+/g, "").length < 40)
    return res.json({ profile: null, kind, pages, readable: false, message: "We couldn't read text from this file. It may be a scanned image: try the Word file or your LinkedIn PDF, or fill in the form." });
  const wantAi = req.query.ai === "1" || (req.body && !Buffer.isBuffer(req.body) && req.body.ai === true);
  if (!wantAi) return res.json({ profile: parseQuick(text), kind, pages, readable: true, ai: false });
  const who = req.user?.uid ?? `ip:${playAccountId(String(req.ip)).slice(0, 32)}`;
  const since = new Date(Date.now() - 86_400_000);
  const [[mine], [all]] = await Promise.all([
    query<{ n: number }>("SELECT COUNT(*) AS n FROM resume_ai_usage WHERE uid = ? AND action = 'import' AND created_at > ?", [who, since]),
    query<{ n: number }>("SELECT COUNT(*) AS n FROM resume_ai_usage WHERE action = 'import' AND created_at > ?", [since]),
  ]);
  if (Number(mine!.n) >= importAiDaily() || Number(all!.n) >= importAiGlobal())
    throw new HttpError(429, "AI reading is busy today. Your resume was read the quick way: check the highlighted fields.");
  const out = await parseWithAi(text);
  await exec("INSERT INTO resume_ai_usage (uid, action, input_tokens, output_tokens) VALUES (?,?,?,?)", [who, "import", out.inputTokens, out.outputTokens]);
  res.json({ profile: out.profile, kind, pages, readable: true, ai: true });
}));

// ---------- Saved copies of the resume (Resume Premium) ----------
const versionData = z.object({
  title: z.string().trim().max(140).nullable().optional(),
  about: z.string().trim().max(2000).nullable().optional(),
  skills: z.array(z.string().trim().min(1).max(40)).max(15).nullable().optional(),
  points: z.array(z.object({ index: z.number().int().min(0).max(9), points: z.string().trim().max(1500) })).max(10).optional(),
});
const versionSettings = z.object({
  template: z.string().refine(t => t in TEMPLATES).optional(), accent: z.enum(ACCENTS).optional(),
  density: z.enum(DENSITIES).optional(), hide: z.array(z.enum(HIDEABLE)).max(HIDEABLE.length).optional(), showPhoto: z.boolean().optional(),
}).nullable().optional();
const versionBody = z.object({
  name: z.string().trim().min(1, "Give this copy a name").max(80),
  jobId: z.string().trim().max(20).nullable().optional(), jobTitle: z.string().trim().max(140).nullable().optional(), company: z.string().trim().max(120).nullable().optional(),
  data: versionData.default({}), settings: versionSettings,
});

resumeRouter.get("/resume/versions", requireAuth, wrap(async (req, res) => {
  const rows = await query<any>("SELECT * FROM resume_versions WHERE uid = ? ORDER BY updated_at DESC LIMIT 20", [req.user!.uid]);
  res.set("Cache-Control", "private, no-store");
  res.json({ items: rows.map(versionOut), max: MAX_VERSIONS() });
}));

resumeRouter.post("/resume/versions", requireAuth, wrap(async (req, res) => {
  const uid = req.user!.uid;
  const b = versionBody.parse(req.body);
  if (!(await premiumFor(uid)).active) throw new HttpError(402, "Saved copies for each job are part of Resume Premium.");
  if (!(await loadProfile(uid))) throw new HttpError(404, "Create your resume first.");
  const [c] = await query<{ n: number }>("SELECT COUNT(*) AS n FROM resume_versions WHERE uid = ?", [uid]);
  if (Number(c!.n) >= MAX_VERSIONS()) throw new HttpError(409, `You can keep up to ${MAX_VERSIONS()} copies. Delete one to save another.`);
  const ins = await exec("INSERT INTO resume_versions (uid, name, job_id, job_title, company, data, settings) VALUES (?,?,?,?,?,?,?)",
    [uid, b.name, b.jobId ?? null, b.jobTitle ?? null, b.company ?? null, JSON.stringify(b.data), b.settings ? JSON.stringify(b.settings) : null]);
  res.status(201).json({ version: await versionFor(uid, Number(ins.insertId)), message: "Saved as a copy." });
}));

resumeRouter.patch("/resume/versions/:id", requireAuth, wrap(async (req, res) => {
  const uid = req.user!.uid, id = Number(req.params.id) || 0;
  const v = await versionFor(uid, id);
  const b = versionBody.partial().parse(req.body);
  // Editing the content of a copy needs Premium; renaming and deleting never do
  if ((b.data || b.settings) && !(await premiumFor(uid)).active) throw new HttpError(402, "Editing saved copies is part of Resume Premium.");
  await exec("UPDATE resume_versions SET name = ?, data = ?, settings = ? WHERE id = ? AND uid = ?",
    [b.name ?? v.name, JSON.stringify(b.data ? { ...v.data, ...b.data } : v.data), JSON.stringify(b.settings === undefined ? v.settings : b.settings), id, uid]);
  res.json({ version: await versionFor(uid, id), message: "Saved." });
}));

resumeRouter.delete("/resume/versions/:id", requireAuth, wrap(async (req, res) => {
  await exec("DELETE FROM resume_versions WHERE id = ? AND uid = ?", [Number(req.params.id) || 0, req.user!.uid]);
  res.json({ ok: true, message: "Copy deleted." });
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
