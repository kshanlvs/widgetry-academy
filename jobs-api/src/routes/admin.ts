// Admin-only: moderate jobs, handle reports, verify candidates
import { Router } from "express";
import { z } from "zod";
import { query } from "../db.js";
import { config } from "../config.js";
import { HttpError, wrap } from "../errors.js";
import { requireAdmin } from "../auth.js";
import { jobInput, adminJobPatch, adminCandidatePatch, VERIFICATION } from "../validate.js";
import { jobOut, skillsFor, createJob, updateJob } from "./jobs.js";
import { candidateOut } from "./talent.js";

export const adminRouter = Router();
adminRouter.use(requireAdmin, (_req, res, next) => { res.set("Cache-Control", "private, no-store"); next(); });

const expireOld = () => query("UPDATE jobs SET status = 'expired' WHERE status = 'approved' AND expires_at IS NOT NULL AND expires_at <= UTC_TIMESTAMP()");

async function jobByPid(pid: string) {
  const [r] = await query("SELECT id, status, expires_at FROM jobs WHERE public_id = ?", [pid.slice(0, 12)]);
  if (!r) throw new HttpError(404, "Job not found.");
  return r;
}

adminRouter.get("/stats", wrap(async (_req, res) => {
  await expireOld();
  const jobs = await query<{ status: string; n: number }>("SELECT status, COUNT(*) AS n FROM jobs GROUP BY status");
  const [rep] = await query<{ n: number }>("SELECT COUNT(*) AS n FROM job_reports WHERE status = 'open'");
  const cands = await query<{ verification: string; n: number }>("SELECT verification, COUNT(*) AS n FROM candidates GROUP BY verification");
  res.json({
    jobs: Object.fromEntries(jobs.map(j => [j.status, Number(j.n)])),
    openReports: Number(rep?.n ?? 0),
    candidates: Object.fromEntries(cands.map(c => [c.verification, Number(c.n)])),
  });
}));

const listQ = z.object({
  status: z.enum(["pending", "approved", "rejected", "filled", "expired", "all"]).default("pending"),
  q: z.string().trim().max(100).optional(),
  page: z.coerce.number().int().min(1).default(1),
});

adminRouter.get("/jobs", wrap(async (req, res) => {
  await expireOld();
  const f = listQ.parse(req.query);
  const where: string[] = [], params: unknown[] = [];
  if (f.status !== "all") { where.push("j.status = ?"); params.push(f.status); }
  if (f.q) { where.push("(j.title LIKE ? OR c.name LIKE ? OR j.contact_email LIKE ?)"); const l = `%${f.q.replace(/[\\%_]/g, m => "\\" + m)}%`; params.push(l, l, l); }
  const rows = await query(`SELECT j.*, c.name AS company_name, c.website AS company_website, c.verified AS company_verified,
      (SELECT COUNT(*) FROM job_reports r WHERE r.job_id = j.id AND r.status = 'open') AS open_reports
    FROM jobs j JOIN companies c ON c.id = j.company_id ${where.length ? "WHERE " + where.join(" AND ") : ""}
    ORDER BY j.created_at DESC LIMIT 50 OFFSET ?`, [...params, (f.page - 1) * 50]);
  const sk = await skillsFor(rows.map(r => r.id));
  res.json({ items: rows.map(r => ({
    ...jobOut(r, sk.get(r.id), true),
    contact: { name: r.contact_name, email: r.contact_email }, postedByUid: r.posted_by_uid,
    rejectReason: r.reject_reason, createdAt: r.created_at, openReports: Number(r.open_reports),
    raw: { companyName: r.company_name, companyWebsite: r.company_website, title: r.title, jobType: r.job_type, workMode: r.work_mode,
      level: r.level, city: r.city, salaryMin: r.salary_min, salaryMax: r.salary_max, salaryPeriod: r.salary_period,
      description: r.description, applyUrl: r.apply_url, applyEmail: r.apply_email, contactName: r.contact_name, contactEmail: r.contact_email },
  })) });
}));

// Admin posts go live immediately
adminRouter.post("/jobs", wrap(async (req, res) => {
  const j = jobInput.parse(req.body);
  const { publicId } = await createJob(j, { uid: req.user!.uid, approved: true });
  res.status(201).json({ id: publicId, status: "approved" });
}));

adminRouter.put("/jobs/:id", wrap(async (req, res) => {
  const job = await jobByPid(String(req.params.id));
  await updateJob(job.id, jobInput.parse(req.body));
  res.json({ ok: true });
}));

adminRouter.patch("/jobs/:id", wrap(async (req, res) => {
  const job = await jobByPid(String(req.params.id));
  const p = adminJobPatch.parse(req.body);
  const sets: string[] = [], params: unknown[] = [];
  if (p.status) {
    sets.push("status = ?"); params.push(p.status);
    if (p.status === "approved") {
      sets.push("approved_at = COALESCE(approved_at, UTC_TIMESTAMP())");
      // (Re)approving gives the job a fresh lifetime if it has none or it already ran out
      sets.push(`expires_at = IF(expires_at IS NULL OR expires_at <= UTC_TIMESTAMP(), UTC_TIMESTAMP() + INTERVAL ${Number(config.jobLifetimeDays)} DAY, expires_at)`);
      sets.push("reject_reason = NULL");
      await query("UPDATE job_reports SET status = 'closed' WHERE job_id = ? AND status = 'open'", [job.id]);
    }
    if (p.status === "rejected") { sets.push("reject_reason = ?"); params.push(p.rejectReason ?? null); }
  }
  if (p.featured !== undefined) { sets.push("featured = ?"); params.push(p.featured ? 1 : 0); }
  if (p.extendDays) {
    sets.push("expires_at = GREATEST(COALESCE(expires_at, UTC_TIMESTAMP()), UTC_TIMESTAMP()) + INTERVAL ? DAY"); params.push(p.extendDays);
    if (!p.status && job.status === "expired") sets.push("status = 'approved'");
  }
  if (!sets.length) throw new HttpError(400, "Nothing to change.");
  await query(`UPDATE jobs SET ${sets.join(", ")} WHERE id = ?`, [...params, job.id]);
  res.json({ ok: true });
}));

adminRouter.delete("/jobs/:id", wrap(async (req, res) => {
  const job = await jobByPid(String(req.params.id));
  await query("DELETE FROM jobs WHERE id = ?", [job.id]);
  res.json({ ok: true });
}));

adminRouter.get("/reports", wrap(async (req, res) => {
  const status = req.query.status === "closed" ? "closed" : "open";
  const rows = await query(`SELECT r.id, r.reason, r.details, r.status, r.created_at, j.public_id, j.title, j.status AS job_status, c.name AS company_name
    FROM job_reports r JOIN jobs j ON j.id = r.job_id JOIN companies c ON c.id = j.company_id
    WHERE r.status = ? ORDER BY r.created_at DESC LIMIT 100`, [status]);
  res.json({ items: rows.map(r => ({ id: r.id, reason: r.reason, details: r.details, status: r.status, createdAt: r.created_at,
    job: { id: r.public_id, title: r.title, company: r.company_name, status: r.job_status } })) });
}));

adminRouter.patch("/reports/:id", wrap(async (req, res) => {
  const status = z.object({ status: z.enum(["open", "closed"]) }).parse(req.body).status;
  await query("UPDATE job_reports SET status = ? WHERE id = ?", [status, Number(req.params.id) || 0]);
  res.json({ ok: true });
}));

const candQ = z.object({ verification: z.enum(VERIFICATION).optional(), q: z.string().trim().max(100).optional(), page: z.coerce.number().int().min(1).default(1) });

adminRouter.get("/candidates", wrap(async (req, res) => {
  const f = candQ.parse(req.query);
  const where: string[] = [], params: unknown[] = [];
  if (f.verification) { where.push("verification = ?"); params.push(f.verification); }
  if (f.q) { const l = `%${f.q.replace(/[\\%_]/g, m => "\\" + m)}%`; where.push("(full_name LIKE ? OR email LIKE ? OR headline LIKE ? OR current_company LIKE ?)"); params.push(l, l, l, l); }
  const rows = await query(`SELECT * FROM candidates ${where.length ? "WHERE " + where.join(" AND ") : ""} ORDER BY updated_at DESC LIMIT 50 OFFSET ?`, [...params, (f.page - 1) * 50]);
  const ids = rows.map(r => r.id);
  const skills = new Map<number, string[]>();
  if (ids.length) for (const s of await query<{ candidate_id: number; skill: string }>("SELECT candidate_id, skill FROM candidate_skills WHERE candidate_id IN (?) ORDER BY skill", [ids]))
    (skills.get(s.candidate_id) ?? skills.set(s.candidate_id, []).get(s.candidate_id)!).push(s.skill);
  res.json({ items: rows.map(r => candidateOut(r, skills.get(r.id) ?? [], true)) });
}));

adminRouter.patch("/candidates/:id", wrap(async (req, res) => {
  const p = adminCandidatePatch.parse(req.body);
  const sets: string[] = [], params: unknown[] = [];
  if (p.verification) { sets.push("verification = ?"); params.push(p.verification); }
  if (p.verifiedNote !== undefined) { sets.push("verified_note = ?"); params.push(p.verifiedNote); }
  if (p.status) { sets.push("status = ?"); params.push(p.status); }
  if (!sets.length) throw new HttpError(400, "Nothing to change.");
  const r = await query<any>(`UPDATE candidates SET ${sets.join(", ")} WHERE public_id = ?`, [...params, String(req.params.id).slice(0, 12)]);
  if (!(r as any).affectedRows) throw new HttpError(404, "Profile not found.");
  res.json({ ok: true });
}));
