// Admin → Overview: everything new in one place (registrations, payments, mock interviews,
// mentors, jobs, profiles, app installs), with the previous period for comparison and a to-do list.
import { Router } from "express";
import { z } from "zod";
import { getFirestore } from "firebase-admin/firestore";
import { adminApp } from "../firebase.js";
import { query } from "../db.js";
import { wrap } from "../errors.js";
import { mockTitle } from "../mock.js";

export interface RegistrationRow { at: Date | null; name: string; course: string; payStatus: string; amountPaid: number }
export interface MentorRow { at: Date | null; name: string; role: string; company: string; status: string; wantsInterviews: boolean }
/** Firestore data (replaced in tests). */
export interface OverviewSources {
  registrations(): Promise<RegistrationRow[]>;
  mentorApplications(): Promise<MentorRow[]>;
}

const ts = (v: any): Date | null => (v?.toDate ? v.toDate() : v instanceof Date ? v : null);
const firestoreSources: OverviewSources = {
  async registrations() {
    const snap = await getFirestore(adminApp()).collection("registrations").select("createdAt", "name", "course", "payStatus", "amountPaid").get();
    return snap.docs.map(d => ({ at: ts(d.get("createdAt")), name: d.get("name") ?? "", course: d.get("course") ?? "", payStatus: d.get("payStatus") ?? "pending", amountPaid: Number(d.get("amountPaid") ?? 0) }));
  },
  async mentorApplications() {
    const snap = await getFirestore(adminApp()).collection("mentorApplications").select("createdAt", "name", "role", "company", "status", "wantsInterviews").get();
    return snap.docs.map(d => ({ at: ts(d.get("createdAt")), name: d.get("name") ?? "", role: d.get("role") ?? "", company: d.get("company") ?? "", status: !d.get("status") || d.get("status") === "pending" ? "new" : d.get("status"), wantsInterviews: !!d.get("wantsInterviews") }));
  },
};
let override: OverviewSources | null = null;
export function setOverviewSources(s: OverviewSources | null) { override = s; }
const sources = () => override ?? firestoreSources;

const IST = 330 * 60_000;
/** Calendar day in India, e.g. "2026-10-18". */
export const istDay = (d: Date) => new Date(d.getTime() + IST).toISOString().slice(0, 10);
const PAID = new Set(["paid", "full", "completed", "part-paid"]);

export const overviewRouter = Router();

overviewRouter.get("/overview", wrap(async (req, res) => {
  const days = z.coerce.number().int().refine(v => [7, 30, 90].includes(v)).default(30).parse(req.query.days ?? 30);
  const now = new Date();
  // Periods end now and start at midnight India time, `days` days back (today included)
  const todayStart = new Date(Date.parse(istDay(now) + "T00:00:00Z") - IST);
  const from = new Date(todayStart.getTime() - (days - 1) * 86_400_000);
  const prevFrom = new Date(from.getTime() - days * 86_400_000);
  const inCur = (d: Date | null) => !!d && d >= from && d <= now;
  const inPrev = (d: Date | null) => !!d && d >= prevFrom && d < from;
  const kpi = <T>(rows: T[], at: (r: T) => Date | null, val: (r: T) => number = () => 1) => ({
    value: rows.filter(r => inCur(at(r))).reduce((a, r) => a + val(r), 0),
    prev: rows.filter(r => inPrev(at(r))).reduce((a, r) => a + val(r), 0),
  });

  const [regs, mentors] = await Promise.all([
    sources().registrations().catch(e => { console.warn(`[overview] registrations: ${e?.message}`); return null; }),
    sources().mentorApplications().catch(e => { console.warn(`[overview] mentors: ${e?.message}`); return null; }),
  ]);
  const D = (v: any) => (v ? new Date(v) : null);
  const [pays, mocks, jobs, cands, devices] = await Promise.all([
    query<any>("SELECT order_id, uid, email, plan, amount, channel, method, paid_at FROM payments WHERE status = 'paid' AND paid_at >= ?", [prevFrom]),
    query<any>("SELECT id, name, email, track, level, format, amount, status, starts_at, paid_at FROM mock_bookings WHERE paid_at IS NOT NULL AND paid_at >= ?", [prevFrom]),
    query<any>("SELECT j.id, j.title, j.status, j.created_at, c.name AS company FROM jobs j LEFT JOIN companies c ON c.id = j.company_id WHERE j.created_at >= ?", [prevFrom]).catch(() => [] as any[]),
    query<any>("SELECT full_name, headline, created_at FROM candidates WHERE created_at >= ?", [prevFrom]),
    query<any>("SELECT created_at FROM device_tokens WHERE created_at >= ?", [prevFrom]),
  ]);
  const [[todoJobs], [todoReports], [todoRefunds], [todoFeedback], [upcoming]] = await Promise.all([
    query<any>("SELECT COUNT(*) AS n FROM jobs WHERE status = 'pending'"),
    query<any>("SELECT COUNT(*) AS n FROM job_reports WHERE status = 'open'").catch(() => [{ n: 0 }]),
    query<any>("SELECT COUNT(*) AS n FROM mock_bookings WHERE status = 'refund_due'"),
    query<any>("SELECT COUNT(*) AS n FROM mock_bookings WHERE status = 'confirmed' AND starts_at < ?", [now]),
    query<any>("SELECT COUNT(*) AS n FROM mock_bookings WHERE status = 'confirmed' AND starts_at >= ?", [now]),
  ]);

  const rupees = (paise: number) => Math.round(Number(paise) / 100);
  const regsList = regs ?? [];
  const mentorList = mentors ?? [];

  // Daily series for the charts (India dates, oldest first)
  const daily = Array.from({ length: days }, (_, i) => ({ date: istDay(new Date(from.getTime() + i * 86_400_000 + 3_600_000)), registrations: 0, mockBookings: 0, revenue: 0 }));
  const byDay = new Map(daily.map(d => [d.date, d]));
  for (const r of regsList) if (inCur(r.at)) byDay.get(istDay(r.at!))!.registrations++;
  for (const m of mocks) { const d = D(m.paid_at); if (inCur(d)) { const b = byDay.get(istDay(d!))!; b.mockBookings++; b.revenue += rupees(m.amount); } }
  for (const p of pays) { const d = D(p.paid_at); if (inCur(d)) byDay.get(istDay(d!))!.revenue += rupees(p.amount); }

  // Latest activity across everything
  type Item = { type: string; at: string; title: string; detail: string; amount?: number };
  const feed: Item[] = [];
  for (const r of regsList) if (inCur(r.at)) feed.push({ type: "registration", at: r.at!.toISOString(), title: `${r.name || "Someone"} registered`, detail: r.course || "Course" });
  for (const p of pays) { const d = D(p.paid_at); if (inCur(d)) feed.push({ type: "payment", at: d!.toISOString(), title: `Course payment · ${p.email ?? ""}`.trim(), detail: `${p.plan} · ${p.channel === "google_play" ? "Google Play" : "Razorpay"}`, amount: rupees(p.amount) }); }
  for (const m of mocks) { const d = D(m.paid_at); if (inCur(d)) feed.push({ type: "mock", at: d!.toISOString(), title: `${m.name || m.email || "Someone"} booked a mock interview`, detail: `${mockTitle(m).replace("Mock interview · ", "")} · ${new Date(m.starts_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" })}`, amount: rupees(m.amount) }); }
  for (const m of mentorList) if (inCur(m.at)) feed.push({ type: "mentor", at: m.at!.toISOString(), title: `${m.name || "Someone"} applied as a mentor`, detail: [m.role, m.company].filter(Boolean).join(" · ") + (m.wantsInterviews ? " · wants to take interviews" : "") });
  for (const j of jobs) { const d = D(j.created_at); if (inCur(d)) feed.push({ type: "job", at: d!.toISOString(), title: `Job posted: ${j.title}`, detail: `${j.company ?? ""}${j.status === "pending" ? " · needs review" : ""}` }); }
  for (const c of cands) { const d = D(c.created_at); if (inCur(d)) feed.push({ type: "profile", at: d!.toISOString(), title: `${c.full_name} created a Talent profile`, detail: c.headline ?? "" }); }
  feed.sort((a, b) => b.at.localeCompare(a.at));

  res.set("Cache-Control", "private, no-store");
  res.json({
    range: { days, from: from.toISOString(), to: now.toISOString() },
    sourcesOk: { registrations: regs !== null, mentors: mentors !== null },
    kpis: {
      registrations: kpi(regsList, r => r.at),
      paidRegistrations: kpi(regsList.filter(r => PAID.has(r.payStatus)), r => r.at),
      courseRevenue: kpi(pays, p => D(p.paid_at), p => rupees(p.amount)),
      mockBookings: kpi(mocks, m => D(m.paid_at)),
      mockRevenue: kpi(mocks, m => D(m.paid_at), m => rupees(m.amount)),
      mentorApplications: kpi(mentorList, m => m.at),
      profiles: kpi(cands, c => D(c.created_at)),
      jobs: kpi(jobs, j => D(j.created_at)),
      appDevices: kpi(devices, d => D(d.created_at)),
    },
    totals: {
      registrations: regsList.length,
      paidRegistrations: regsList.filter(r => PAID.has(r.payStatus)).length,
      upcomingMocks: Number(upcoming?.n ?? 0),
    },
    todo: {
      jobsInReview: Number(todoJobs?.n ?? 0),
      reportedJobs: Number(todoReports?.n ?? 0),
      refundsDue: Number(todoRefunds?.n ?? 0),
      feedbackPending: Number(todoFeedback?.n ?? 0),
      newMentors: mentorList.filter(m => m.status === "new").length,
      unpaidRegistrations: regsList.filter(r => !PAID.has(r.payStatus) && !["refunded", "cancelled"].includes(r.payStatus)).length,
    },
    daily,
    feed: feed.slice(0, 40),
  });
}));
