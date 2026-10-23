// Everything a person has bought, in one place: the courses they're enrolled in and every paid order.
// Built from the database each time, so a new short course (Admin → Short courses) shows up here
// on its own, with no change to the website or the app.
import { query } from "./db.js";
import { COURSE, PLAN_TITLE, reconcile, store, type Registration } from "./payments.js";
import { reconcileWorkshops } from "./routes/workshops.js";
import { reconcileMock, trackName, levelName } from "./mock.js";
import { SITE } from "./notify.js";

const rupees = (paise: number | null | undefined) => Math.round(Number(paise ?? 0) / 100);
const iso = (d: Date | string | null | undefined) => (d ? new Date(d).toISOString() : null);
const brochureUrl = (b: string | null | undefined) => (!b ? null : /^https:\/\//i.test(b) ? b : `${SITE}/${b.replace(/^\/+/, "")}`);

export type OrderKind = "course_fee" | "short_course" | "mock_interview";

export interface Order {
  /** Unique across kinds, e.g. "short_course-12" */
  id: string;
  kind: OrderKind;
  /** What was bought: the course name, or "Mock interview" */
  title: string;
  /** Course fee plan (early-bird, regular, booking, balance); null for other kinds */
  plan: string | null;
  /** The line on the receipt, e.g. "Early bird (full fee)" or "Flutter · Mid level" */
  item: string;
  /** Rupees */
  amount: number;
  currency: string;
  /** paid, refunded, or refund_pending (a cancelled mock interview whose refund is on its way) */
  status: string;
  orderId: string | null;
  paymentId: string | null;
  /** upi, card, netbanking, wallet, google_play... */
  method: string | null;
  paidAt: string | null;
  /** Where the thing bought lives, on the website and in the app */
  webPath: string | null;
  appPath: string | null;
}

export interface EnrolledCourse {
  kind: "flagship" | "short_course";
  /** "flutter-in-10-days", or the short course's slug */
  slug: string;
  title: string;
  /** enrolled (fully paid), booked (part paid), registered (not paid yet), refunded */
  status: string;
  amountPaid: number;
  startsAt: string | null;
  schedule: string | null;
  /** Only once paid */
  meetingLink: string | null;
  brochureUrl: string | null;
  webPath: string;
  appPath: string;
}

const flagshipStatus = (r: Registration) => {
  const s = (r.payStatus ?? "").toLowerCase();
  if (s === "refunded" || s === "cancelled") return s;
  if (s === "paid" || s === "full" || s === "completed") return "enrolled";
  if (s === "part-paid" || Number(r.amountPaid ?? 0) > 0) return "booked";
  return "registered";
};

/** Courses and orders for one person, newest first. Recent unconfirmed payments are checked first, so nothing paid is missing. */
export async function purchasesFor(uid: string): Promise<{ courses: EnrolledCourse[]; orders: Order[] }> {
  await Promise.all([reconcile(uid), reconcileWorkshops(uid), reconcileMock(uid)].map(p => p.catch(() => 0)));

  const [reg, fees, shorts, mocks] = await Promise.all([
    store().get(uid).catch(() => null),
    query<any>("SELECT order_id, plan, amount, currency, payment_id, method, paid_at FROM payments WHERE uid = ? AND status = 'paid' ORDER BY paid_at DESC LIMIT 100", [uid]),
    query<any>(`SELECT e.id, e.amount, e.early, e.status, e.order_id, e.payment_id, e.method, e.paid_at,
                       w.slug, w.title, w.starts_at, w.schedule, w.meeting_link, w.brochure
                  FROM workshop_enrollments e JOIN workshops w ON w.id = e.workshop_id
                 WHERE e.uid = ? AND e.paid_at IS NOT NULL AND e.status IN ('confirmed','refunded')
                 ORDER BY e.paid_at DESC LIMIT 100`, [uid]),
    query<any>(`SELECT id, track, level, duration_min, starts_at, amount, status, order_id, payment_id, method, paid_at
                  FROM mock_bookings WHERE uid = ? AND paid_at IS NOT NULL ORDER BY paid_at DESC LIMIT 100`, [uid]),
  ]);

  const courses: EnrolledCourse[] = [];
  if (reg) {
    const status = flagshipStatus(reg);
    if (status !== "cancelled") courses.push({
      kind: "flagship", slug: "flutter-in-10-days", title: COURSE, status, amountPaid: Number(reg.amountPaid ?? 0),
      startsAt: null, schedule: reg.batch ?? null, meetingLink: null,
      brochureUrl: `${SITE}/Widgetry-Academy-Flutter-Brochure.pdf`, webPath: "/#fees", appPath: "/courses",
    });
  }
  // One entry per short course, even if someone (rarely) paid twice
  const seen = new Set<string>();
  for (const s of shorts) {
    if (seen.has(s.slug)) continue;
    seen.add(s.slug);
    const paid = s.status === "confirmed";
    courses.push({
      kind: "short_course", slug: s.slug, title: s.title, status: paid ? "enrolled" : "refunded", amountPaid: paid ? rupees(s.amount) : 0,
      startsAt: iso(s.starts_at), schedule: s.schedule ?? null, meetingLink: paid ? s.meeting_link ?? null : null,
      brochureUrl: brochureUrl(s.brochure), webPath: `/${s.slug}.html`, appPath: `/short-courses/${s.slug}`,
    });
  }

  const orders: Order[] = [
    ...fees.map((f): Order => ({
      id: `course_fee-${f.order_id}`, kind: "course_fee", plan: f.plan, title: COURSE, item: PLAN_TITLE[f.plan] ?? "Course fee",
      amount: rupees(f.amount), currency: f.currency ?? "INR", status: "paid",
      orderId: f.order_id, paymentId: f.payment_id, method: f.method, paidAt: iso(f.paid_at), webPath: "/#fees", appPath: "/courses",
    })),
    ...shorts.map((s): Order => ({
      id: `short_course-${s.id}`, kind: "short_course", plan: null, title: s.title, item: s.early ? "Course fee (early bird)" : "Course fee",
      amount: rupees(s.amount), currency: "INR", status: s.status === "confirmed" ? "paid" : "refunded",
      orderId: s.order_id, paymentId: s.payment_id, method: s.method, paidAt: iso(s.paid_at),
      webPath: `/${s.slug}.html`, appPath: `/short-courses/${s.slug}`,
    })),
    ...mocks.map((m): Order => ({
      id: `mock_interview-${m.id}`, kind: "mock_interview", plan: null, title: "Mock interview",
      item: `${trackName(m.track)} · ${levelName(m.level)} · ${m.duration_min} min`,
      amount: rupees(m.amount), currency: "INR",
      status: m.status === "refund_due" ? "refund_pending" : m.status === "cancelled" ? "refunded" : "paid",
      orderId: m.order_id, paymentId: m.payment_id, method: m.method, paidAt: iso(m.paid_at),
      webPath: null, appPath: `/interviews/${m.id}`,
    })),
  ].sort((a, b) => (b.paidAt ?? "").localeCompare(a.paidAt ?? ""));

  return { courses, orders };
}
