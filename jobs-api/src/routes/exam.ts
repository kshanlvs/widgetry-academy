// Exam Center: anyone can take a Junior, Mid level or Senior Flutter exam; signed-in people who pass get a badge.
// Questions are drawn and graded here, so the answers never reach the browser before submitting.
// An attempt is a signed token (works for guests, no row until submit). Each token can be submitted once.
// A guest who passes gets a claim token, and turns it into a badge after signing up.
import { Router } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { createHmac, randomBytes, randomInt, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { query, tx } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { config } from "../config.js";
import { hashIp, publicId } from "../validate.js";
import { LEVELS, QUESTIONS, byId, levelInfo, type Level, type Question } from "../exam/questions.js";

export const examRouter = Router();
examRouter.use("/exam", (_req, res, next) => { res.set("Cache-Control", "private, no-store"); next(); });

const GRACE_SECONDS = 90;            // network and clock slack after the timer ends
const CLAIM_DAYS = 7;                // a guest has a week to sign up and claim
const DISTINCTION = 90;              // percent for "with distinction"

// ---------- signed tokens ----------
const b64 = (s: string) => Buffer.from(s).toString("base64url");
const sig = (body: string) => createHmac("sha256", config.examSecret).update(body).digest("base64url");
function sign(payload: object) { const body = b64(JSON.stringify(payload)); return `${body}.${sig(body)}`; }
function verify<T>(token: unknown, kind: string): T {
  if (typeof token !== "string" || token.length > 4000) throw new HttpError(400, "This exam link isn't valid. Please start again.");
  const [body, mac] = token.split(".");
  const want = sig(body || "");
  if (!mac || mac.length !== want.length || !timingSafeEqual(Buffer.from(mac), Buffer.from(want))) throw new HttpError(400, "This exam link isn't valid. Please start again.");
  const p = JSON.parse(Buffer.from(body, "base64url").toString());
  if (p.k !== kind) throw new HttpError(400, "This exam link isn't valid. Please start again.");
  return p as T;
}
interface AttemptToken { k: "attempt"; l: Level; q: string[]; o: Record<string, string[]>; t: number; n: string }
interface ClaimToken { k: "claim"; a: number; e: number }

function shuffle<T>(a: T[]): T[] {
  const x = a.slice();
  for (let i = x.length - 1; i > 0; i--) { const j = randomInt(i + 1); [x[i], x[j]] = [x[j], x[i]]; }
  return x;
}

/** What the browser sees: no answers, no explanations. Options shuffled; an order question never starts solved. */
function publicQuestion(qn: Question, order: string[]) {
  const opt = new Map(qn.options.map(o => [o.id, o]));
  return { id: qn.id, topic: qn.topic, type: qn.type, prompt: qn.prompt, code: qn.code ?? null, options: order.map(id => opt.get(id)!) };
}
function optionOrder(qn: Question) {
  const ids = qn.options.map(o => o.id);
  let order = shuffle(ids);
  if (qn.type === "order") for (let i = 0; i < 5 && order.join() === qn.answer.join(); i++) order = shuffle(ids);
  return order;
}

const who = (req: any) => req.user?.uid ? { col: "uid", val: req.user.uid as string } : { col: "ip_hash", val: hashIp(req.ip ?? "unknown") };
async function attemptsToday(req: any, level: Level) {
  const w = who(req);
  const [r] = await query<{ n: number }>(`SELECT COUNT(*) AS n FROM exam_attempts WHERE ${w.col} = ? AND level = ? AND created_at > NOW() - INTERVAL 1 DAY`, [w.val, level]);
  return Number(r.n);
}

const nameFor = (req: any, given?: string | null) => {
  const n = (given || req.user?.name || (req.user?.email || "").split("@")[0] || "").replace(/\s+/g, " ").trim().slice(0, 60);
  return n || "Widgetry learner";
};

function badgeOut(b: any) {
  const lv = levelInfo(b.level);
  return {
    id: b.public_id, name: b.name, level: b.level, levelName: lv?.name ?? b.level,
    score: Number(b.score), correct: Number(b.correct), total: Number(b.total), distinction: Number(b.score) >= DISTINCTION,
    issuedAt: new Date(b.issued_at).toISOString(), updatedAt: new Date(b.updated_at).toISOString(),
  };
}

/** Gives (or improves) the user's badge for a level from a passed attempt. Keeps the same badge link. */
async function award(uid: string, name: string, a: { id: number; level: string; score: number; correct: number; total: number }) {
  await query(
    `INSERT INTO exam_badges (public_id, uid, name, level, score, correct, total, attempt_id) VALUES (?,?,?,?,?,?,?,?)
     ON DUPLICATE KEY UPDATE name = VALUES(name),
       attempt_id = IF(VALUES(score) > score, VALUES(attempt_id), attempt_id),
       correct = IF(VALUES(score) > score, VALUES(correct), correct),
       total = IF(VALUES(score) > score, VALUES(total), total),
       score = GREATEST(score, VALUES(score))`,
    [publicId(10), uid, name, a.level, a.score, a.correct, a.total, a.id]);
  const [b] = await query("SELECT * FROM exam_badges WHERE uid = ? AND level = ?", [uid, a.level]);
  return badgeOut(b);
}

// ---------- routes ----------

examRouter.get("/exam/levels", wrap(async (_req, res) => {
  res.json({
    levels: LEVELS.map(l => ({ ...l, bank: QUESTIONS.filter(x => x.level === l.id).length })),
    attemptsPerDay: config.examAttemptsPerDay, distinction: DISTINCTION,
  });
}));

const startLimit = rateLimit({ windowMs: 60 * 60 * 1000, limit: 30, standardHeaders: "draft-7", legacyHeaders: false,
  keyGenerator: req => (req as any).user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "Too many exams started. Please try again in a while." }) });

const levelId = z.enum(LEVELS.map(l => l.id) as [Level, ...Level[]]);

examRouter.post("/exam/start", startLimit, wrap(async (req, res) => {
  const { level } = z.object({ level: levelId }).parse(req.body);
  const info = levelInfo(level)!;
  if (await attemptsToday(req, level) >= config.examAttemptsPerDay)
    throw new HttpError(429, `You've used your ${config.examAttemptsPerDay} attempts for the ${info.name} exam today. Go through your answers and try again tomorrow.`);
  const picked = shuffle(QUESTIONS.filter(x => x.level === level)).slice(0, info.questions);
  const o: Record<string, string[]> = {};
  for (const qn of picked) o[qn.id] = optionOrder(qn);
  const startedAt = Date.now();
  const token = sign({ k: "attempt", l: level, q: picked.map(x => x.id), o, t: startedAt, n: randomBytes(12).toString("hex") } satisfies AttemptToken);
  res.status(201).json({
    token, level, levelName: info.name, minutes: info.minutes, pass: info.pass,
    startedAt: new Date(startedAt).toISOString(), endsAt: new Date(startedAt + info.minutes * 60_000).toISOString(),
    questions: picked.map(x => publicQuestion(x, o[x.id])),
  });
}));

const submitBody = z.object({
  token: z.string().max(4000),
  answers: z.record(z.string().max(40), z.array(z.string().max(4)).max(10)).default({}),
  name: z.string().max(60).optional(),
});

examRouter.post("/exam/submit", wrap(async (req, res) => {
  const body = submitBody.parse(req.body);
  const t = verify<AttemptToken>(body.token, "attempt");
  const info = levelInfo(t.l);
  if (!info) throw new HttpError(400, "This exam link isn't valid. Please start again.");
  const seconds = Math.round((Date.now() - t.t) / 1000);
  if (seconds > info.minutes * 60 + GRACE_SECONDS) throw new HttpError(410, "Time ran out for this attempt. Start a new one when you're ready.");

  let correct = 0;
  const review = t.q.map(id => {
    const qn = byId.get(id)!;
    const given = (body.answers[id] || []).filter(a => qn.options.some(o => o.id === a));
    const ok = qn.type === "order"
      ? given.join() === qn.answer.join()
      : given.length === qn.answer.length && qn.answer.every(a => given.includes(a));
    if (ok) correct++;
    return { id, topic: qn.topic, correct: ok, given, answer: qn.answer, explain: qn.explain };
  });
  const total = t.q.length;
  const score = Math.round((correct / total) * 100);
  const passed = (correct / total) * 100 >= info.pass;
  const uid = req.user?.uid ?? null;

  let attemptId: number;
  try {
    const r: any = await query("INSERT INTO exam_attempts (nonce, uid, ip_hash, level, correct, total, score, passed, seconds) VALUES (?,?,?,?,?,?,?,?,?)",
      [t.n, uid, hashIp(req.ip ?? "unknown"), t.l, correct, total, score, passed ? 1 : 0, seconds]);
    attemptId = Number(r.insertId);
  } catch (e: any) {
    if (e?.code === "ER_DUP_ENTRY") throw new HttpError(409, "This attempt was already submitted. Start a new one to try again.");
    throw e;
  }

  const out: any = { level: t.l, levelName: info.name, correct, total, score, pass: info.pass, passed, distinction: passed && score >= DISTINCTION, seconds, review };
  if (passed && uid) out.badge = await award(uid, nameFor(req, body.name), { id: attemptId, level: t.l, score, correct, total });
  else if (passed) out.claim = sign({ k: "claim", a: attemptId, e: Date.now() + CLAIM_DAYS * 86_400_000 } satisfies ClaimToken);
  res.json(out);
}));

/** A guest passed, then signed up: the attempt becomes theirs and they get the badge. */
examRouter.post("/exam/claim", requireAuth, wrap(async (req, res) => {
  const body = z.object({ claim: z.string().max(1000), name: z.string().max(60).optional() }).parse(req.body);
  const c = verify<ClaimToken>(body.claim, "claim");
  if (Date.now() > c.e) throw new HttpError(410, "This result is too old to claim. Take the exam again while signed in.");
  const uid = req.user!.uid;
  const a = await tx(async conn => {
    const [rows]: any = await conn.query("SELECT * FROM exam_attempts WHERE id = ? FOR UPDATE", [c.a]);
    const row = rows[0];
    if (!row || !row.passed) throw new HttpError(404, "We couldn't find that result.");
    if (row.uid && row.uid !== uid) throw new HttpError(409, "This result was already claimed by another account.");
    if (!row.uid) await conn.query("UPDATE exam_attempts SET uid = ?, claimed_at = NOW() WHERE id = ?", [uid, row.id]);
    return row;
  });
  const badge = await award(uid, nameFor(req, body.name), { id: Number(a.id), level: a.level, score: Number(a.score), correct: Number(a.correct), total: Number(a.total) });
  res.json({ badge });
}));

examRouter.get("/exam/mine", requireAuth, wrap(async (req, res) => {
  const uid = req.user!.uid;
  const badges = await query("SELECT * FROM exam_badges WHERE uid = ? ORDER BY FIELD(level, 'junior', 'mid', 'senior')", [uid]);
  const attempts = await query("SELECT level, score, passed, created_at FROM exam_attempts WHERE uid = ? ORDER BY created_at DESC LIMIT 20", [uid]);
  res.json({
    badges: badges.map(badgeOut),
    attempts: attempts.map(a => ({ level: a.level, score: Number(a.score), passed: !!a.passed, at: new Date(a.created_at).toISOString() })),
  });
}));

/** The public, shareable badge page reads this. Shows only the name on the badge, level, score and date. */
examRouter.get("/exam/badges/:id", wrap(async (req, res) => {
  const id = String(req.params.id || "");
  if (!/^[A-Za-z0-9]{6,12}$/.test(id)) throw new HttpError(404, "Badge not found.");
  const [b] = await query("SELECT * FROM exam_badges WHERE public_id = ?", [id]);
  if (!b) throw new HttpError(404, "Badge not found.");
  res.set("Cache-Control", "public, max-age=300");
  res.json({ badge: badgeOut(b) });
}));

/** Change the name printed on your badges (e.g. full name instead of a nickname). */
examRouter.patch("/exam/badges/name", requireAuth, wrap(async (req, res) => {
  const { name } = z.object({ name: z.string().trim().min(2, "Enter your name.").max(60) }).parse(req.body);
  await query("UPDATE exam_badges SET name = ? WHERE uid = ?", [name.replace(/\s+/g, " "), req.user!.uid]);
  const badges = await query("SELECT * FROM exam_badges WHERE uid = ? ORDER BY FIELD(level, 'junior', 'mid', 'senior')", [req.user!.uid]);
  res.json({ badges: badges.map(badgeOut) });
}));
