// Public jobs board + employer submissions + reports
import { Router } from "express";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import type mysql from "mysql2/promise";
import { query, tx } from "../db.js";
import { config } from "../config.js";
import { HttpError, wrap } from "../errors.js";
import { requireAuth } from "../auth.js";
import { jobInput, jobSearch, reportInput, publicId, hashIp, ftQuery, COMMON_SKILLS, type JobInput } from "../validate.js";

export const jobsRouter = Router();

const LIVE = "j.status = 'approved' AND (j.expires_at IS NULL OR j.expires_at > UTC_TIMESTAMP())";
const likeEsc = (s: string) => s.replace(/[\\%_]/g, m => "\\" + m);

export function jobOut(r: any, skills: string[] = [], detail = false) {
  const out: any = {
    id: r.public_id,
    title: r.title,
    company: { name: r.company_name, website: r.company_website ?? null, verified: !!r.company_verified },
    type: r.job_type, mode: r.work_mode, level: r.level, city: r.city ?? null,
    salary: r.salary_min != null || r.salary_max != null ? { min: r.salary_min, max: r.salary_max, period: r.salary_period } : null,
    skills, featured: !!r.featured,
    postedAt: r.approved_at ?? r.created_at, expiresAt: r.expires_at ?? null,
    status: r.status,
  };
  if (detail) {
    out.description = r.description;
    out.apply = { url: r.apply_url ?? null, email: r.apply_email ?? null };
  }
  return out;
}

export async function skillsFor(ids: number[]) {
  const map = new Map<number, string[]>();
  if (!ids.length) return map;
  const rows = await query<{ job_id: number; skill: string }>("SELECT job_id, skill FROM job_skills WHERE job_id IN (?) ORDER BY skill", [ids]);
  for (const r of rows) (map.get(r.job_id) ?? map.set(r.job_id, []).get(r.job_id)!).push(r.skill);
  return map;
}

const SELECT_JOB = `SELECT j.*, c.name AS company_name, c.website AS company_website, c.verified AS company_verified
  FROM jobs j JOIN companies c ON c.id = j.company_id`;

/** Insert or update a company by name and return its id. */
async function companyId(c: mysql.PoolConnection, name: string, website: string | null) {
  const [res] = await c.query(
    "INSERT INTO companies (name, website) VALUES (?, ?) ON DUPLICATE KEY UPDATE website = COALESCE(website, VALUES(website)), id = LAST_INSERT_ID(id)",
    [name, website]);
  return (res as mysql.ResultSetHeader).insertId;
}

/** Create a job (used by employers: pending, and by the admin: approved). */
export async function createJob(j: JobInput, opts: { uid: string | null; approved: boolean }) {
  return tx(async c => {
    const cid = await companyId(c, j.companyName, j.companyWebsite);
    const pid = publicId();
    const [res] = await c.query(
      `INSERT INTO jobs (public_id, company_id, title, job_type, work_mode, level, city, salary_min, salary_max, salary_period,
        description, apply_url, apply_email, contact_name, contact_email, posted_by_uid, status, approved_at, expires_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [pid, cid, j.title, j.jobType, j.workMode, j.level, j.city, j.salaryMin ?? null, j.salaryMax ?? null,
        j.salaryMin != null || j.salaryMax != null ? j.salaryPeriod ?? null : null,
        j.description, j.applyUrl, j.applyEmail, j.contactName, j.contactEmail, opts.uid,
        opts.approved ? "approved" : "pending",
        opts.approved ? new Date() : null,
        opts.approved ? new Date(Date.now() + config.jobLifetimeDays * 864e5) : null]);
    const id = (res as mysql.ResultSetHeader).insertId;
    if (j.skills.length) await c.query("INSERT INTO job_skills (job_id, skill) VALUES ?", [j.skills.map(s => [id, s])]);
    return { id, publicId: pid };
  });
}

/** Replace all editable fields of a job (admin edit). */
export async function updateJob(jobId: number, j: JobInput) {
  return tx(async c => {
    const cid = await companyId(c, j.companyName, j.companyWebsite);
    await c.query(
      `UPDATE jobs SET company_id=?, title=?, job_type=?, work_mode=?, level=?, city=?, salary_min=?, salary_max=?, salary_period=?,
        description=?, apply_url=?, apply_email=?, contact_name=?, contact_email=? WHERE id=?`,
      [cid, j.title, j.jobType, j.workMode, j.level, j.city, j.salaryMin ?? null, j.salaryMax ?? null,
        j.salaryMin != null || j.salaryMax != null ? j.salaryPeriod ?? null : null,
        j.description, j.applyUrl, j.applyEmail, j.contactName, j.contactEmail, jobId]);
    await c.query("DELETE FROM job_skills WHERE job_id = ?", [jobId]);
    if (j.skills.length) await c.query("INSERT INTO job_skills (job_id, skill) VALUES ?", [j.skills.map(s => [jobId, s])]);
  });
}

// ---------- Public ----------

jobsRouter.get("/meta", wrap(async (_req, res) => {
  const [count] = await query<{ n: number }>(`SELECT COUNT(*) AS n FROM jobs j WHERE ${LIVE}`);
  const cities = await query<{ city: string }>(`SELECT DISTINCT j.city FROM jobs j WHERE ${LIVE} AND j.city IS NOT NULL ORDER BY j.city LIMIT 50`);
  const top = await query<{ skill: string }>(
    `SELECT s.skill FROM job_skills s JOIN jobs j ON j.id = s.job_id WHERE ${LIVE} GROUP BY s.skill ORDER BY COUNT(*) DESC, s.skill LIMIT 20`);
  res.set("Cache-Control", "public, max-age=60");
  res.json({ liveJobs: Number(count?.n ?? 0), cities: cities.map(c => c.city), skills: top.length ? top.map(t => t.skill) : COMMON_SKILLS.slice(0, 12), suggestedSkills: COMMON_SKILLS });
}));

jobsRouter.get("/jobs", wrap(async (req, res) => {
  const f = jobSearch.parse(req.query);
  const where = [LIVE];
  const params: unknown[] = [];
  if (f.type) { where.push("j.job_type = ?"); params.push(f.type); }
  if (f.mode) { where.push("j.work_mode = ?"); params.push(f.mode); }
  if (f.level) { where.push("j.level = ?"); params.push(f.level); }
  if (f.city) { where.push("j.city = ?"); params.push(f.city); }
  if (f.skill) { where.push("EXISTS (SELECT 1 FROM job_skills s WHERE s.job_id = j.id AND s.skill = ?)"); params.push(f.skill); }
  if (f.q) {
    const ft = ftQuery(f.q), like = "%" + likeEsc(f.q) + "%";
    if (ft) { where.push("(MATCH(j.title, j.description) AGAINST (? IN BOOLEAN MODE) OR c.name LIKE ? OR EXISTS (SELECT 1 FROM job_skills s2 WHERE s2.job_id = j.id AND s2.skill LIKE ?))"); params.push(ft, like, like); }
    else { where.push("(j.title LIKE ? OR c.name LIKE ?)"); params.push(like, like); }
  }
  const w = where.join(" AND ");
  const [count] = await query<{ n: number }>(`SELECT COUNT(*) AS n FROM jobs j JOIN companies c ON c.id = j.company_id WHERE ${w}`, params);
  const rows = await query(`${SELECT_JOB} WHERE ${w} ORDER BY j.featured DESC, j.approved_at DESC, j.id DESC LIMIT ? OFFSET ?`,
    [...params, f.pageSize, (f.page - 1) * f.pageSize]);
  const sk = await skillsFor(rows.map(r => r.id));
  res.set("Cache-Control", "public, max-age=30");
  res.json({ total: Number(count?.n ?? 0), page: f.page, pageSize: f.pageSize, items: rows.map(r => jobOut(r, sk.get(r.id))) });
}));

jobsRouter.get("/jobs/:id", wrap(async (req, res) => {
  const [r] = await query(`${SELECT_JOB} WHERE j.public_id = ? AND j.status IN ('approved','filled','expired')`, [String(req.params.id).slice(0, 12)]);
  if (!r) throw new HttpError(404, "This job doesn't exist or is no longer listed.");
  const live = r.status === "approved" && (!r.expires_at || new Date(r.expires_at) > new Date());
  const sk = await skillsFor([r.id]);
  const out = jobOut(r, sk.get(r.id), true);
  out.status = live ? "open" : (r.status === "filled" ? "filled" : "closed");
  if (!live) out.apply = { url: null, email: null };   // don't send people to closed listings
  res.set("Cache-Control", "public, max-age=60");
  res.json(out);
}));

// ---------- Employers ----------

const postLimiter = rateLimit({ windowMs: 60 * 60 * 1000, limit: 5, standardHeaders: "draft-7", legacyHeaders: false, skipFailedRequests: true,
  keyGenerator: req => (req as any).user?.uid ?? ipKeyGenerator(req.ip ?? "0.0.0.0"),
  handler: (_req, res) => res.status(429).json({ error: "You've posted several jobs in the last hour. Please try again later." }) });

jobsRouter.post("/jobs", requireAuth, postLimiter, wrap(async (req, res) => {
  const j = jobInput.parse(req.body);
  const [{ n }] = await query<{ n: number }>("SELECT COUNT(*) AS n FROM jobs WHERE posted_by_uid = ? AND status = 'pending'", [req.user!.uid]);
  if (Number(n) >= 10) throw new HttpError(429, "You already have 10 jobs waiting for review. Please wait for them to be reviewed.");
  const { publicId: id } = await createJob(j, { uid: req.user!.uid, approved: false });
  res.status(201).json({ id, status: "pending", message: "Thanks! Your job will go live after a quick review, usually within 24 hours." });
}));

jobsRouter.get("/my/jobs", requireAuth, wrap(async (req, res) => {
  const rows = await query(`${SELECT_JOB} WHERE j.posted_by_uid = ? ORDER BY j.created_at DESC LIMIT 100`, [req.user!.uid]);
  const sk = await skillsFor(rows.map(r => r.id));
  res.set("Cache-Control", "private, no-store");
  res.json({ items: rows.map(r => ({ ...jobOut(r, sk.get(r.id)), rejectReason: r.status === "rejected" ? r.reject_reason : null })) });
}));

// ---------- Reports ----------

const reportLimiter = rateLimit({ windowMs: 60 * 60 * 1000, limit: 10, standardHeaders: "draft-7", legacyHeaders: false,
  handler: (_req, res) => res.status(429).json({ error: "Too many reports. Please try again later." }) });
const AUTO_HIDE_AFTER = 3;   // distinct reports that send a job back to review

jobsRouter.post("/jobs/:id/report", reportLimiter, wrap(async (req, res) => {
  const body = reportInput.parse(req.body);
  const [job] = await query<{ id: number }>("SELECT id FROM jobs WHERE public_id = ? AND status = 'approved'", [String(req.params.id).slice(0, 12)]);
  if (!job) throw new HttpError(404, "Job not found.");
  await query("INSERT IGNORE INTO job_reports (job_id, reason, details, reporter_uid, reporter_hash) VALUES (?,?,?,?,?)",
    [job.id, body.reason, body.details, (req as any).user?.uid ?? null, hashIp(req.ip ?? "unknown")]);
  const [{ n }] = await query<{ n: number }>("SELECT COUNT(*) AS n FROM job_reports WHERE job_id = ? AND status = 'open'", [job.id]);
  if (Number(n) >= AUTO_HIDE_AFTER) await query("UPDATE jobs SET status = 'pending' WHERE id = ? AND status = 'approved'", [job.id]);
  res.status(201).json({ ok: true, message: "Thanks for letting us know. We'll review this job." });
}));
