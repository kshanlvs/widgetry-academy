// Mock interviews with working engineers.
//
// Interviewers (added by an admin) publish time slots. A candidate picks a slot; we hold it for
// 15 minutes while they pay with Razorpay (one-to-one live sessions don't need Google Play Billing).
// Payment is confirmed by the app (/mock/verify), the Razorpay webhook, or recovery when the
// candidate opens their bookings, whichever comes first. After the call the interviewer fills in
// a scorecard; the candidate can show it on their Talent Network profile.
import { getAuth } from "firebase-admin/auth";
import { adminApp } from "./firebase.js";
import { query, exec } from "./db.js";
import { notifyUser } from "./notify.js";
import { gateway, paymentsEnabled } from "./payments.js";

const env = process.env;

export const TRACKS = [
  { id: "flutter", name: "Flutter" },
  { id: "android", name: "Android" },
  { id: "ios", name: "iOS" },
] as const;
export type TrackId = (typeof TRACKS)[number]["id"];

const rupees = (name: string, fallback: number) => Number(env[name] || fallback);
export const LEVELS = () => [
  { id: "fresher", name: "Fresher", note: "0–1 years", price: rupees("PRICE_MOCK_FRESHER", 499) },
  { id: "mid", name: "Mid level", note: "2–4 years", price: rupees("PRICE_MOCK_MID", 799) },
  { id: "senior", name: "Senior", note: "5+ years", price: rupees("PRICE_MOCK_SENIOR", 1199) },
];
export const FORMATS = [
  { id: "technical", name: "Technical round", note: "Core concepts, your projects, and a short live coding task." },
  { id: "coding", name: "Coding round", note: "Problem solving and clean code, the way product companies test it." },
  { id: "design", name: "App design round", note: "Architecture, state management and trade-offs. Best for mid and senior." },
];
/** What the interviewer scores, 1 to 5. */
export const AREAS = [
  { id: "knowledge", name: "Platform knowledge" },
  { id: "coding", name: "Problem solving & code" },
  { id: "architecture", name: "Architecture & state" },
  { id: "debugging", name: "Debugging & testing" },
  { id: "communication", name: "Communication" },
];
export const RECOMMENDATIONS = ["strong_hire", "hire", "lean_no", "no"] as const;

export const HOLD_MINUTES = 15;
/** Bookings close this long before the slot starts. */
export const MIN_NOTICE_HOURS = 2;
/** Candidates can cancel for a refund until this long before. */
export const CANCEL_HOURS = 24;

export const levelPrice = (level: string) => LEVELS().find(l => l.id === level)?.price ?? 0;
export const trackName = (t: string) => TRACKS.find(x => x.id === t)?.name ?? t;
export const levelName = (l: string) => LEVELS().find(x => x.id === l)?.name ?? l;
export const formatName = (f: string) => FORMATS.find(x => x.id === f)?.name ?? f;
export const mockTitle = (b: { track: string; level: string; format?: string }) => `Mock interview · ${trackName(b.track)} · ${levelName(b.level)}`;

const addMinutes = (d: Date, m: number) => new Date(d.getTime() + m * 60_000);
const when = (d: Date) =>
  new Intl.DateTimeFormat("en-IN", { timeZone: "Asia/Kolkata", weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" }).format(d);

// ---------- Finding a user by email (admins add interviewers by email) ----------
export interface UserLookup { uidForEmail(email: string): Promise<string | null> }
const firebaseLookup: UserLookup = {
  async uidForEmail(email) {
    try { return (await getAuth(adminApp()).getUserByEmail(email)).uid; } catch { return null; }
  },
};
let lookup: UserLookup | null = null;
export function setUserLookup(l: UserLookup | null) { lookup = l; }
export const users = () => lookup ?? firebaseLookup;

export async function interviewerFor(uid: string) {
  const [r] = await query<any>("SELECT * FROM interviewers WHERE uid = ? AND active = 1", [uid]);
  return r ?? null;
}

export const publicInterviewer = (r: any) => ({
  name: r.name, title: r.title, company: r.company ?? null, years: Number(r.years ?? 0),
  tracks: typeof r.tracks === "string" ? JSON.parse(r.tracks) : r.tracks ?? [], bio: r.bio ?? null, linkedinUrl: r.linkedin_url ?? null,
});

// ---------- Confirming a payment (idempotent) ----------
export async function fulfilMock(orderId: string, paymentId: string, method?: string): Promise<{ status: string; bookingId: number; first: boolean } | null> {
  const [b] = await query<any>("SELECT * FROM mock_bookings WHERE order_id = ?", [orderId]);
  if (!b) return null;
  const res = await exec("UPDATE mock_bookings SET status = 'confirmed', payment_id = ?, method = ?, paid_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'created'", [paymentId, method ?? null, b.id]);
  if (res.affectedRows === 0) {
    const [now] = await query<{ status: string }>("SELECT status FROM mock_bookings WHERE id = ?", [b.id]);
    return { status: now?.status ?? b.status, bookingId: b.id, first: false };
  }
  // The slot is still ours unless the hold expired and someone else took it
  const slot = await exec("UPDATE interview_slots SET status = 'booked', held_until = NULL WHERE id = ? AND booking_id = ? AND status IN ('held','open')", [b.slot_id, b.id]);
  if (slot.affectedRows === 0) {
    await exec("UPDATE mock_bookings SET status = 'refund_due' WHERE id = ?", [b.id]);
    void notifyUser(b.uid, {
      title: "That slot was just taken",
      body: "Your payment came through after the slot was booked by someone else. We'll refund you in full within 3 working days, or message us to pick another time.",
      data: { type: "mock", id: String(b.id) },
    });
    return { status: "refund_due", bookingId: b.id, first: true };
  }
  const start = new Date(b.starts_at);
  void notifyUser(b.uid, {
    title: "Mock interview booked",
    body: `${trackName(b.track)} · ${when(start)}. The joining link is in the app.`,
    data: { type: "mock", id: String(b.id) },
  });
  void notifyUser(b.interviewer_uid, {
    title: "New mock interview booked",
    body: `${b.name ?? "A candidate"} · ${trackName(b.track)} ${levelName(b.level)} · ${when(start)}`,
    data: { type: "mock-interviewer", id: String(b.id) },
  });
  return { status: "confirmed", bookingId: b.id, first: true };
}

/** Confirms this candidate's recent unconfirmed bookings that were actually paid (app closed, slow webhook). */
export async function reconcileMock(uid: string): Promise<number> {
  if (!paymentsEnabled()) return 0;
  let fixed = 0;
  try {
    const rows = await query<{ order_id: string; amount: number }>(
      "SELECT order_id, amount FROM mock_bookings WHERE uid = ? AND status = 'created' AND order_id IS NOT NULL AND created_at > ? ORDER BY created_at DESC LIMIT 3",
      [uid, addMinutes(new Date(), -24 * 60)]);
    for (const r of rows) {
      const items = await gateway().orderPayments(r.order_id);
      const paid = items.find(p => p.status === "captured" && p.amount === r.amount);
      if (paid) { const res = await fulfilMock(r.order_id, paid.id, paid.method); if (res?.first) fixed++; }
    }
  } catch (e: any) {
    console.warn(`[mock] reconcile ${uid} failed: ${e?.message}`);
  }
  return fixed;
}

/** Releases a slot held by an unpaid booking, so others can book it. */
export async function releaseHold(bookingId: number) {
  await exec("UPDATE interview_slots SET status = 'open', booking_id = NULL, held_until = NULL WHERE booking_id = ? AND status = 'held'", [bookingId]);
}

/** Push reminders about an hour before each confirmed interview. Runs every few minutes. */
export async function sendReminders(now = new Date()) {
  const rows = await query<any>(
    "SELECT * FROM mock_bookings WHERE status = 'confirmed' AND reminded_at IS NULL AND starts_at > ? AND starts_at <= ?",
    [now, addMinutes(now, 65)]);
  for (const b of rows) {
    const r = await exec("UPDATE mock_bookings SET reminded_at = CURRENT_TIMESTAMP WHERE id = ? AND reminded_at IS NULL", [b.id]);
    if (r.affectedRows === 0) continue;
    const mins = Math.max(1, Math.round((new Date(b.starts_at).getTime() - now.getTime()) / 60_000));
    void notifyUser(b.uid, { title: `Your mock interview starts in ${mins} minutes`, body: "Open the app to join. Keep your laptop, a quiet room and a working mic ready.", data: { type: "mock", id: String(b.id) } });
    void notifyUser(b.interviewer_uid, { title: `Mock interview in ${mins} minutes`, body: `${b.name ?? "Candidate"} · ${trackName(b.track)} ${levelName(b.level)}`, data: { type: "mock-interviewer", id: String(b.id) } });
  }
  return rows.length;
}
