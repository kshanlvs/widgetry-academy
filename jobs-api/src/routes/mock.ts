// Mock interviews: options, open slots, booking and payment, my bookings, interviewer tools, admin.
import { Router } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { z } from "zod";
import { query, exec, tx } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { gateway, paymentsEnabled, razorpayConfig, validPaymentSignature } from "../payments.js";
import { notifyUser } from "../notify.js";
import { loadProfile } from "./talent.js";
import {
  AREAS, CANCEL_HOURS, FORMATS, HOLD_MINUTES, LEVELS, MIN_NOTICE_HOURS, RECOMMENDATIONS, TRACKS,
  fulfilMock, interviewerFor, levelPrice, mockTitle, publicInterviewer, reconcileMock, releaseHold, trackName, users,
} from "../mock.js";

export const mockRouter = Router();
mockRouter.use("/mock", (_req, res, next) => { res.set("Cache-Control", "private, no-store"); next(); });

const addMinutes = (d: Date, m: number) => new Date(d.getTime() + m * 60_000);
const trackId = z.enum(TRACKS.map(t => t.id) as [string, ...string[]]);
const optUrl = z.preprocess(v => (typeof v === "string" ? v.trim() : v), z.union([z.string().max(400).url("Enter a full link starting with https://").refine(u => /^https:\/\//i.test(u), "Enter a full link starting with https://"), z.literal("")]).optional().nullable()).transform(v => (v ? v : null));
const id = z.coerce.number().int().positive();

function bookingOut(b: any, opts: { interviewer?: any; scorecard?: any; forInterviewer?: boolean } = {}) {
  const start = new Date(b.starts_at);
  const now = new Date();
  const out: any = {
    id: Number(b.id),
    status: b.status,
    startsAt: start.toISOString(),
    durationMin: Number(b.duration_min),
    track: b.track, level: b.level, format: b.format,
    title: mockTitle(b),
    focus: b.focus ?? null,
    amount: Math.round(Number(b.amount) / 100),
    paymentId: b.payment_id ?? null,
    method: b.method ?? null,
    paidAt: b.paid_at ?? null,
    // Candidates can cancel for a refund until 24 hours before
    canCancel: (b.status === "confirmed" && start.getTime() - now.getTime() >= CANCEL_HOURS * 3_600_000) || b.status === "created",
  };
  if (opts.interviewer) {
    out.interviewer = publicInterviewer(opts.interviewer);
    // The joining link appears once paid
    out.meetingLink = ["confirmed", "completed"].includes(b.status) ? (opts.interviewer.meeting_link ?? null) : null;
  }
  out.viewer = opts.forInterviewer ? "interviewer" : "candidate";
  if (opts.forInterviewer) {
    out.candidate = { name: b.name ?? null, email: b.email ?? null, shareProfile: !!b.share_profile };
    out.canScore = b.status === "confirmed" && now >= start;
    out.canMarkNoShow = b.status === "confirmed" && now >= addMinutes(start, 15);
  }
  if (opts.scorecard) out.scorecard = scorecardOut(opts.scorecard);
  return out;
}

const scorecardOut = (s: any) => ({
  scores: typeof s.scores === "string" ? JSON.parse(s.scores) : s.scores,
  overall: Number(s.overall),
  strengths: s.strengths,
  improve: s.improve,
  recommendation: s.recommendation,
  shared: !!s.shared,
  createdAt: s.created_at,
});

// ---------- Candidates ----------

mockRouter.get("/mock/options", wrap(async (_req, res) => {
  res.json({
    enabled: paymentsEnabled(),
    tracks: TRACKS, levels: LEVELS(), formats: FORMATS, areas: AREAS,
    rules: { holdMinutes: HOLD_MINUTES, minNoticeHours: MIN_NOTICE_HOURS, cancelHours: CANCEL_HOURS },
  });
}));

/** Open slots for a track over the next 3 weeks, soonest first. */
mockRouter.get("/mock/slots", wrap(async (req, res) => {
  const track = trackId.parse(req.query.track ?? "flutter");
  const now = new Date();
  const rows = await query<any>(
    `SELECT s.id, s.starts_at, s.duration_min, i.* FROM interview_slots s JOIN interviewers i ON i.uid = s.interviewer_uid
     WHERE i.active = 1 AND JSON_CONTAINS(i.tracks, JSON_QUOTE(?)) AND s.starts_at >= ? AND s.starts_at <= ?
       AND (s.status = 'open' OR (s.status = 'held' AND s.held_until < ?))
     ORDER BY s.starts_at, s.id LIMIT 300`,
    [track, addMinutes(now, MIN_NOTICE_HOURS * 60), addMinutes(now, 21 * 24 * 60), now]);
  res.json({ slots: rows.map(r => ({ id: Number(r.id), startsAt: new Date(r.starts_at).toISOString(), durationMin: Number(r.duration_min), interviewer: publicInterviewer(r) })) });
}));

const bookLimit = rateLimit({ windowMs: 60 * 60 * 1000, limit: 20, standardHeaders: "draft-7", legacyHeaders: false, keyGenerator: (req: any) => req.user?.uid ?? ipKeyGenerator(req.ip ?? "") });
const bookBody = z.object({
  slotId: id,
  track: trackId,
  level: z.enum(["fresher", "mid", "senior"]),
  format: z.enum(FORMATS.map(f => f.id) as [string, ...string[]]),
  focus: z.string().trim().max(500).optional().transform(v => (v ? v : null)),
  shareProfile: z.boolean().default(true),
});

/** Holds the slot for 15 minutes and creates the Razorpay order. */
mockRouter.post("/mock/book", requireAuth, bookLimit, wrap(async (req, res) => {
  if (!paymentsEnabled()) throw new HttpError(503, "Booking opens soon. Message us on WhatsApp to book meanwhile.");
  const b = bookBody.parse(req.body);
  const u = req.user!;
  await reconcileMock(u.uid);
  const now = new Date();
  const [slot] = await query<any>("SELECT s.*, i.tracks, i.active FROM interview_slots s JOIN interviewers i ON i.uid = s.interviewer_uid WHERE s.id = ?", [b.slotId]);
  if (!slot || !slot.active) throw new HttpError(404, "This slot isn't available any more. Please pick another.");
  const tracks = typeof slot.tracks === "string" ? JSON.parse(slot.tracks) : slot.tracks;
  if (!tracks.includes(b.track)) throw new HttpError(400, `This interviewer doesn't take ${trackName(b.track)} interviews. Please pick another slot.`);
  if (new Date(slot.starts_at) < addMinutes(now, MIN_NOTICE_HOURS * 60)) throw new HttpError(409, `Bookings close ${MIN_NOTICE_HOURS} hours before the start. Please pick a later slot.`);
  if (slot.interviewer_uid === u.uid) throw new HttpError(400, "You can't book your own slot.");

  // One unpaid booking at a time: let go of any earlier hold
  for (const old of await query<{ id: number }>("SELECT id FROM mock_bookings WHERE uid = ? AND status = 'created'", [u.uid])) {
    await releaseHold(old.id);
    await exec("UPDATE mock_bookings SET status = 'cancelled' WHERE id = ? AND status = 'created'", [old.id]);
  }

  const amount = levelPrice(b.level) * 100;
  const bookingId = await tx(async c => {
    const [ins]: any = await c.execute(
      "INSERT INTO mock_bookings (uid, email, name, slot_id, interviewer_uid, starts_at, duration_min, track, level, format, focus, share_profile, amount) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
      [u.uid, u.email, u.name, slot.id, slot.interviewer_uid, slot.starts_at, slot.duration_min, b.track, b.level, b.format, b.focus, b.shareProfile ? 1 : 0, amount]);
    const [held]: any = await c.execute(
      "UPDATE interview_slots SET status = 'held', booking_id = ?, held_until = ? WHERE id = ? AND (status = 'open' OR (status = 'held' AND held_until < ?))",
      [ins.insertId, addMinutes(now, HOLD_MINUTES), slot.id, now]);
    if (held.affectedRows === 0) throw new HttpError(409, "Someone just booked this slot. Please pick another.");
    return Number(ins.insertId);
  });

  let order;
  try {
    order = await gateway().createOrder({ amount, receipt: `mock_${bookingId}`, notes: { uid: u.uid, booking: String(bookingId), type: "mock" } });
  } catch (e) {
    await releaseHold(bookingId);
    await exec("UPDATE mock_bookings SET status = 'cancelled' WHERE id = ?", [bookingId]);
    throw e;
  }
  await exec("UPDATE mock_bookings SET order_id = ? WHERE id = ?", [order.id, bookingId]);
  const profile = await loadProfile(u.uid).catch(() => null);
  res.status(201).json({
    bookingId,
    orderId: order.id,
    amount: order.amount,
    currency: order.currency || "INR",
    keyId: razorpayConfig().keyId,
    name: "Widgetry Academy",
    description: mockTitle(b),
    prefill: { name: profile?.fullName ?? u.name ?? "", email: u.email ?? "", contact: profile?.phone ?? "" },
    holdMinutes: HOLD_MINUTES,
  });
}));

const verifyBody = z.object({
  orderId: z.string().trim().regex(/^order_[A-Za-z0-9]+$/),
  paymentId: z.string().trim().regex(/^pay_[A-Za-z0-9]+$/),
  signature: z.string().trim().regex(/^[a-f0-9]{64}$/),
});

mockRouter.post("/mock/verify", requireAuth, wrap(async (req, res) => {
  const { orderId, paymentId, signature } = verifyBody.parse(req.body);
  const [b] = await query<any>("SELECT uid, amount FROM mock_bookings WHERE order_id = ?", [orderId]);
  if (!b || b.uid !== req.user!.uid) throw new HttpError(404, "We couldn't find this booking.");
  if (!validPaymentSignature(orderId, paymentId, signature)) throw new HttpError(400, "We couldn't confirm this payment. If money was taken, it will be confirmed automatically within a few minutes.");
  const pay = await gateway().fetchPayment(paymentId);
  if (pay.order_id !== orderId || pay.amount !== b.amount || !["captured", "authorized"].includes(pay.status)) {
    throw new HttpError(400, "This payment hasn't completed yet. If money was taken, it will be confirmed automatically within a few minutes.");
  }
  const r = await fulfilMock(orderId, paymentId, pay.method);
  res.json({ ok: true, status: r?.status ?? "confirmed", bookingId: r?.bookingId, paymentId });
}));

async function withDetails(rows: any[], forInterviewer = false) {
  if (!rows.length) return [];
  const ids = rows.map(r => r.id);
  const cards = await query<any>("SELECT * FROM mock_scorecards WHERE booking_id IN (?)", [ids]);
  const people = await query<any>("SELECT * FROM interviewers WHERE uid IN (?)", [[...new Set(rows.map(r => r.interviewer_uid))]]);
  return rows.map(r => bookingOut(r, { interviewer: people.find(p => p.uid === r.interviewer_uid), scorecard: cards.find(c => Number(c.booking_id) === Number(r.id)), forInterviewer }));
}

/** The candidate's bookings: upcoming first, then past. Also confirms any that were paid but not recorded. */
mockRouter.get("/mock/mine", requireAuth, wrap(async (req, res) => {
  const uid = req.user!.uid;
  await reconcileMock(uid);
  // Unpaid bookings only matter while the slot is held
  const rows = await query<any>(
    "SELECT * FROM mock_bookings WHERE uid = ? AND (status NOT IN ('created','cancelled') OR (status = 'cancelled' AND paid_at IS NOT NULL) OR (status = 'created' AND created_at > ?)) ORDER BY starts_at DESC LIMIT 50",
    [uid, addMinutes(new Date(), -HOLD_MINUTES)]);
  res.json({ bookings: await withDetails(rows) });
}));

mockRouter.get("/mock/bookings/:id", requireAuth, wrap(async (req, res) => {
  const [b] = await query<any>("SELECT * FROM mock_bookings WHERE id = ?", [id.parse(req.params.id)]);
  const uid = req.user!.uid;
  if (!b || (b.uid !== uid && b.interviewer_uid !== uid)) throw new HttpError(404, "Booking not found.");
  const [out] = await withDetails([b], b.interviewer_uid === uid);
  if (b.interviewer_uid === uid && b.share_profile) out.candidateProfile = await loadProfile(b.uid).catch(() => null);
  res.json({ booking: out });
}));

/** Cancel: unpaid bookings any time; paid ones until 24 hours before (refunded in full). */
mockRouter.post("/mock/bookings/:id/cancel", requireAuth, wrap(async (req, res) => {
  const [b] = await query<any>("SELECT * FROM mock_bookings WHERE id = ? AND uid = ?", [id.parse(req.params.id), req.user!.uid]);
  if (!b) throw new HttpError(404, "Booking not found.");
  if (b.status === "created") {
    await releaseHold(b.id);
    await exec("UPDATE mock_bookings SET status = 'cancelled' WHERE id = ?", [b.id]);
    return res.json({ ok: true, status: "cancelled", message: "Booking cancelled. No money was taken." });
  }
  if (b.status !== "confirmed") throw new HttpError(409, "This booking can't be cancelled.");
  if (new Date(b.starts_at).getTime() - Date.now() < CANCEL_HOURS * 3_600_000) {
    throw new HttpError(409, `It's less than ${CANCEL_HOURS} hours to the interview, so it can't be cancelled here. Message us on WhatsApp and we'll help.`);
  }
  await exec("UPDATE mock_bookings SET status = 'refund_due' WHERE id = ? AND status = 'confirmed'", [b.id]);
  await exec("UPDATE interview_slots SET status = 'open', booking_id = NULL, held_until = NULL WHERE id = ? AND booking_id = ?", [b.slot_id, b.id]);
  void notifyUser(b.interviewer_uid, { title: "Mock interview cancelled", body: `${b.name ?? "The candidate"} cancelled. The slot is open again.`, data: { type: "mock-interviewer", id: String(b.id) } });
  res.json({ ok: true, status: "refund_due", message: "Cancelled. Your full refund reaches your account in 5–7 working days." });
}));

/** Show (or hide) the scorecard on the candidate's Talent Network profile. */
mockRouter.put("/mock/bookings/:id/share", requireAuth, wrap(async (req, res) => {
  const { shared } = z.object({ shared: z.boolean() }).parse(req.body);
  const bid = id.parse(req.params.id);
  const [b] = await query<any>("SELECT id FROM mock_bookings WHERE id = ? AND uid = ? AND status = 'completed'", [bid, req.user!.uid]);
  if (!b) throw new HttpError(404, "Scorecard not found.");
  // One scorecard on the profile at a time
  if (shared) await exec("UPDATE mock_scorecards s JOIN mock_bookings b ON b.id = s.booking_id SET s.shared = 0 WHERE b.uid = ?", [req.user!.uid]);
  await exec("UPDATE mock_scorecards SET shared = ? WHERE booking_id = ?", [shared ? 1 : 0, bid]);
  res.json({ ok: true, shared });
}));

// ---------- Interviewers ----------

const profileBody = z.object({
  title: z.string().trim().min(2).max(120),
  company: z.string().trim().max(120).optional().transform(v => (v ? v : null)),
  years: z.coerce.number().int().min(0).max(40),
  tracks: z.array(trackId).min(1, "Choose at least one track").max(3).transform(a => [...new Set(a)]),
  bio: z.string().trim().max(500).optional().transform(v => (v ? v : null)),
  linkedinUrl: optUrl,
  meetingLink: optUrl,
});

const interviewerOut = (r: any) => ({ ...publicInterviewer(r), uid: r.uid, email: r.email, meetingLink: r.meeting_link ?? null, active: !!r.active });

/** Dashboard: own profile, open slots and bookings. interviewer is null for everyone else. */
mockRouter.get("/mock/interviewer/me", requireAuth, wrap(async (req, res) => {
  const me = await interviewerFor(req.user!.uid);
  if (!me) return res.json({ interviewer: null });
  const now = new Date();
  const slots = await query<any>("SELECT id, starts_at, duration_min, status, held_until FROM interview_slots WHERE interviewer_uid = ? AND starts_at >= ? AND status <> 'cancelled' ORDER BY starts_at LIMIT 200", [me.uid, addMinutes(now, -60)]);
  const bookings = await query<any>("SELECT * FROM mock_bookings WHERE interviewer_uid = ? AND status IN ('confirmed','completed','no_show') AND starts_at >= ? ORDER BY starts_at LIMIT 100", [me.uid, addMinutes(now, -60 * 24 * 30)]);
  res.json({
    interviewer: interviewerOut(me),
    slots: slots.map(s => ({
      id: Number(s.id), startsAt: new Date(s.starts_at).toISOString(), durationMin: Number(s.duration_min),
      status: s.status === "held" && new Date(s.held_until) < now ? "open" : s.status,
    })),
    bookings: await withDetails(bookings, true),
  });
}));

mockRouter.put("/mock/interviewer/me", requireAuth, wrap(async (req, res) => {
  const me = await interviewerFor(req.user!.uid);
  if (!me) throw new HttpError(403, "Only Widgetry interviewers can do this.");
  const p = profileBody.parse(req.body);
  await exec("UPDATE interviewers SET title = ?, company = ?, years = ?, tracks = ?, bio = ?, linkedin_url = ?, meeting_link = ? WHERE uid = ?",
    [p.title, p.company, p.years, JSON.stringify(p.tracks), p.bio, p.linkedinUrl, p.meetingLink, me.uid]);
  res.json({ interviewer: interviewerOut(await interviewerFor(me.uid)) });
}));

const slotsBody = z.object({
  starts: z.array(z.string().datetime({ offset: true })).min(1).max(20),
  durationMin: z.union([z.literal(45), z.literal(60)]).default(60),
});

/** Adds slots for an interviewer (used by the interviewer in the app and by admins). Overlaps are skipped. */
async function addSlotsFor(me: any, body: unknown) {
  if (!me.meeting_link) throw new HttpError(400, "Add a meeting link (Google Meet or Zoom) for this interviewer first.");
  const { starts, durationMin } = slotsBody.parse(body);
  const now = new Date();
  const dates = [...new Set(starts)].map(s => new Date(s));
  for (const d of dates) {
    if (d < addMinutes(now, MIN_NOTICE_HOURS * 60)) throw new HttpError(400, `Slots must start at least ${MIN_NOTICE_HOURS} hours from now.`);
    if (d > addMinutes(now, 60 * 24 * 60)) throw new HttpError(400, "Slots can be at most 60 days ahead.");
  }
  const [{ n }] = await query<{ n: number }>("SELECT COUNT(*) AS n FROM interview_slots WHERE interviewer_uid = ? AND starts_at >= ? AND status IN ('open','held')", [me.uid, now]);
  if (Number(n) + dates.length > 60) throw new HttpError(400, "Up to 60 open slots at a time.");
  const existing = await query<any>("SELECT starts_at, duration_min FROM interview_slots WHERE interviewer_uid = ? AND status <> 'cancelled' AND starts_at >= ?", [me.uid, addMinutes(now, -120)]);
  const all = [...existing.map(e => ({ s: new Date(e.starts_at).getTime(), m: Number(e.duration_min) }))];
  let added = 0;
  for (const d of dates.sort((a, b) => a.getTime() - b.getTime())) {
    const s = d.getTime();
    if (all.some(o => s < o.s + o.m * 60_000 && o.s < s + durationMin * 60_000)) continue;
    await exec("INSERT INTO interview_slots (interviewer_uid, starts_at, duration_min) VALUES (?,?,?)", [me.uid, d, durationMin]);
    all.push({ s, m: durationMin });
    added++;
  }
  return { added, skipped: dates.length - added };
}

mockRouter.post("/mock/interviewer/slots", requireAuth, wrap(async (req, res) => {
  const me = await interviewerFor(req.user!.uid);
  if (!me) throw new HttpError(403, "Only Widgetry interviewers can do this.");
  res.status(201).json({ ok: true, ...(await addSlotsFor(me, req.body)) });
}));

mockRouter.delete("/mock/interviewer/slots/:id", requireAuth, wrap(async (req, res) => {
  const me = await interviewerFor(req.user!.uid);
  if (!me) throw new HttpError(403, "Only Widgetry interviewers can do this.");
  const r = await exec("DELETE FROM interview_slots WHERE id = ? AND interviewer_uid = ? AND (status = 'open' OR (status = 'held' AND held_until < ?))", [id.parse(req.params.id), me.uid, new Date()]);
  if (r.affectedRows === 0) throw new HttpError(409, "This slot is booked or being paid for. Ask us if you need to cancel it.");
  res.json({ ok: true });
}));

const scoreBody = z.object({
  scores: z.object(Object.fromEntries(AREAS.map(a => [a.id, z.coerce.number().int().min(1).max(5)])) as Record<string, z.ZodNumber>),
  strengths: z.string().trim().min(20, "Write at least a couple of sentences on what went well").max(1500),
  improve: z.string().trim().min(20, "Write at least a couple of sentences on what to improve").max(1500),
  recommendation: z.enum(RECOMMENDATIONS),
});

mockRouter.post("/mock/interviewer/bookings/:id/scorecard", requireAuth, wrap(async (req, res) => {
  const me = await interviewerFor(req.user!.uid);
  if (!me) throw new HttpError(403, "Only Widgetry interviewers can do this.");
  const bid = id.parse(req.params.id);
  const [b] = await query<any>("SELECT * FROM mock_bookings WHERE id = ? AND interviewer_uid = ?", [bid, me.uid]);
  if (!b) throw new HttpError(404, "Booking not found.");
  if (b.status !== "confirmed") throw new HttpError(409, b.status === "completed" ? "The scorecard is already sent." : "This interview can't be scored.");
  if (new Date(b.starts_at) > new Date()) throw new HttpError(409, "You can send the scorecard once the interview has started.");
  const s = scoreBody.parse(req.body);
  const values = Object.values(s.scores) as number[];
  const overall = Math.round((values.reduce((a, v) => a + v, 0) / values.length) * 10) / 10;
  await tx(async c => {
    await c.execute("INSERT INTO mock_scorecards (booking_id, scores, overall, strengths, improve, recommendation) VALUES (?,?,?,?,?,?)",
      [bid, JSON.stringify(s.scores), overall, s.strengths, s.improve, s.recommendation]);
    await c.execute("UPDATE mock_bookings SET status = 'completed' WHERE id = ?", [bid]);
  });
  void notifyUser(b.uid, { title: "Your interview feedback is ready", body: `Overall ${overall.toFixed(1)} out of 5. See what went well and what to work on.`, data: { type: "mock", id: String(bid) } });
  res.status(201).json({ ok: true, overall });
}));

mockRouter.post("/mock/interviewer/bookings/:id/no-show", requireAuth, wrap(async (req, res) => {
  const me = await interviewerFor(req.user!.uid);
  if (!me) throw new HttpError(403, "Only Widgetry interviewers can do this.");
  const [b] = await query<any>("SELECT * FROM mock_bookings WHERE id = ? AND interviewer_uid = ? AND status = 'confirmed'", [id.parse(req.params.id), me.uid]);
  if (!b) throw new HttpError(404, "Booking not found.");
  if (new Date() < addMinutes(new Date(b.starts_at), 15)) throw new HttpError(409, "Wait at least 15 minutes after the start before marking a no-show.");
  await exec("UPDATE mock_bookings SET status = 'no_show' WHERE id = ?", [b.id]);
  void notifyUser(b.uid, { title: "We missed you at your mock interview", body: "Message us on WhatsApp if something went wrong and we'll try to help.", data: { type: "mock", id: String(b.id) } });
  res.json({ ok: true });
}));

// ---------- Admin ----------

export const mockAdminRouter = Router();

mockAdminRouter.get("/interviewers", wrap(async (_req, res) => {
  const rows = await query<any>(
    `SELECT i.*, (SELECT COUNT(*) FROM interview_slots s WHERE s.interviewer_uid = i.uid AND s.status = 'open' AND s.starts_at > ?) AS open_slots,
       (SELECT COUNT(*) FROM mock_bookings b WHERE b.interviewer_uid = i.uid AND b.status = 'completed') AS done
     FROM interviewers i ORDER BY i.active DESC, i.name`, [new Date()]);
  res.json({ items: rows.map(r => ({ ...interviewerOut(r), openSlots: Number(r.open_slots), completed: Number(r.done) })) });
}));

const addBody = profileBody.extend({
  email: z.string().trim().toLowerCase().email(),
  name: z.string().trim().min(2).max(100),
  uid: z.string().trim().min(3).max(128).optional(),
});

mockAdminRouter.post("/interviewers", wrap(async (req, res) => {
  const p = addBody.parse(req.body);
  const uid = p.uid ?? (await users().uidForEmail(p.email));
  if (!uid) throw new HttpError(404, "No Widgetry account uses this email yet. Ask them to sign in to the app or website once, then add them.");
  // One interviewer per account: the same email again updates their details instead of adding a duplicate
  const [existing] = await query<{ uid: string }>("SELECT uid FROM interviewers WHERE uid = ? OR email = ?", [uid, p.email]);
  if (existing && existing.uid !== uid) throw new HttpError(409, "This email is already used by another interviewer.");
  await exec(
    `INSERT INTO interviewers (uid, email, name, title, company, years, tracks, bio, linkedin_url, meeting_link) VALUES (?,?,?,?,?,?,?,?,?,?)
     ON DUPLICATE KEY UPDATE email = VALUES(email), name = VALUES(name), title = VALUES(title), company = VALUES(company), years = VALUES(years),
       tracks = VALUES(tracks), bio = COALESCE(VALUES(bio), bio), linkedin_url = COALESCE(VALUES(linkedin_url), linkedin_url),
       meeting_link = COALESCE(VALUES(meeting_link), meeting_link), active = 1`,
    [uid, p.email, p.name, p.title, p.company, p.years, JSON.stringify(p.tracks), p.bio, p.linkedinUrl, p.meetingLink]);
  if (!existing) void notifyUser(uid, { title: "You're a Widgetry interviewer", body: "Open the app → Mock interviews → Interviewer dashboard to see your slots and bookings.", data: { type: "mock-interviewer" } });
  res.status(existing ? 200 : 201).json({ ok: true, uid, updated: !!existing });
}));

const adminEdit = z.object({
  active: z.boolean().optional(),
  meetingLink: optUrl.optional(),
  title: z.string().trim().min(2).max(120).optional(),
  company: z.string().trim().max(120).optional(),
  years: z.coerce.number().int().min(0).max(40).optional(),
  tracks: z.array(trackId).min(1).max(3).optional(),
});

/** Pause/re-activate, or edit the meeting link and details. */
mockAdminRouter.patch("/interviewers/:uid", wrap(async (req, res) => {
  const e = adminEdit.parse(req.body);
  const [cur] = await query<any>("SELECT * FROM interviewers WHERE uid = ?", [req.params.uid]);
  if (!cur) throw new HttpError(404, "Interviewer not found.");
  await exec("UPDATE interviewers SET active = ?, meeting_link = ?, title = ?, company = ?, years = ?, tracks = ? WHERE uid = ?", [
    e.active === undefined ? cur.active : e.active ? 1 : 0,
    e.meetingLink === undefined ? cur.meeting_link : e.meetingLink,
    e.title ?? cur.title,
    e.company === undefined ? cur.company : e.company || null,
    e.years ?? cur.years,
    e.tracks ? JSON.stringify([...new Set(e.tracks)]) : (typeof cur.tracks === "string" ? cur.tracks : JSON.stringify(cur.tracks)),
    cur.uid,
  ]);
  // Taking someone off removes their open slots (booked interviews stay)
  if (e.active === false) await exec("DELETE FROM interview_slots WHERE interviewer_uid = ? AND status = 'open'", [cur.uid]);
  res.json({ ok: true });
}));

/** An interviewer's upcoming slots, for Admin. */
mockAdminRouter.get("/interviewers/:uid/slots", wrap(async (req, res) => {
  const now = new Date();
  const rows = await query<any>(
    `SELECT s.id, s.starts_at, s.duration_min, s.status, s.held_until, b.name AS booked_by FROM interview_slots s
     LEFT JOIN mock_bookings b ON b.id = s.booking_id AND s.status = 'booked'
     WHERE s.interviewer_uid = ? AND s.starts_at >= ? AND s.status <> 'cancelled' ORDER BY s.starts_at LIMIT 200`, [req.params.uid, addMinutes(now, -60)]);
  res.json({ items: rows.map(r => ({
    id: Number(r.id), startsAt: new Date(r.starts_at).toISOString(), durationMin: Number(r.duration_min),
    status: r.status === "held" && new Date(r.held_until) < now ? "open" : r.status, bookedBy: r.booked_by ?? null,
  })) });
}));

mockAdminRouter.post("/interviewers/:uid/slots", wrap(async (req, res) => {
  const [me] = await query<any>("SELECT * FROM interviewers WHERE uid = ? AND active = 1", [req.params.uid]);
  if (!me) throw new HttpError(404, "Interviewer not found or paused.");
  res.status(201).json({ ok: true, ...(await addSlotsFor(me, req.body)) });
}));

mockAdminRouter.delete("/interview-slots/:id", wrap(async (req, res) => {
  const r = await exec("DELETE FROM interview_slots WHERE id = ? AND (status = 'open' OR (status = 'held' AND held_until < ?))", [id.parse(req.params.id), new Date()]);
  if (r.affectedRows === 0) throw new HttpError(409, "This slot is booked or being paid for, so it can't be removed.");
  res.json({ ok: true });
}));

mockAdminRouter.get("/mock-bookings", wrap(async (req, res) => {
  const status = z.enum(["all", "confirmed", "completed", "refund_due", "no_show", "cancelled"]).default("all").parse(req.query.status ?? "all");
  const rows = await query<any>(
    `SELECT b.*, i.name AS interviewer_name FROM mock_bookings b LEFT JOIN interviewers i ON i.uid = b.interviewer_uid
     WHERE b.status <> 'created' ${status === "all" ? "" : "AND b.status = ?"} ORDER BY b.starts_at DESC LIMIT 200`, status === "all" ? [] : [status]);
  res.json({
    items: rows.map(b => ({
      id: Number(b.id), status: b.status, startsAt: new Date(b.starts_at).toISOString(), title: mockTitle(b),
      candidate: { name: b.name, email: b.email }, interviewer: b.interviewer_name, amount: Math.round(b.amount / 100), paymentId: b.payment_id, paidAt: b.paid_at,
    })),
  });
}));

/** After refunding in the Razorpay dashboard, or to fix a status by hand. */
mockAdminRouter.patch("/mock-bookings/:id", wrap(async (req, res) => {
  const { status } = z.object({ status: z.enum(["cancelled", "completed", "no_show", "confirmed"]) }).parse(req.body);
  const r = await exec("UPDATE mock_bookings SET status = ? WHERE id = ? AND status <> 'created'", [status, id.parse(req.params.id)]);
  if (r.affectedRows === 0) throw new HttpError(404, "Booking not found.");
  res.json({ ok: true });
}));

