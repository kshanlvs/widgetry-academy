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
import { categories, assertCategories } from "../categories.js";
import { notifyTopic, notifyUser, SITE } from "../notify.js";
import { pingJob } from "../indexing.js";

/** Tell subscribers of the job's category that a new job is live. */
async function announceJobs(jobIds: number[]) {
  if (!jobIds.length) return;
  const rows = await query<any>(`SELECT j.public_id, j.title, j.category, c.name AS company FROM jobs j JOIN companies c ON c.id = j.company_id WHERE j.id IN (?) ORDER BY j.id`, [jobIds]);
  const names = new Map((await categories()).map(c => [c.slug, c.name]));
  const byCat = new Map<string, any[]>();
  for (const r of rows) (byCat.get(r.category) ?? byCat.set(r.category, []).get(r.category)!).push(r);
  for (const [cat, list] of byCat) {
    const name = names.get(cat) ?? "mobile", first = list[0];
    await notifyTopic(`jobs-${cat}`, list.length === 1
      ? { title: `New ${name} job`, body: `${first.title} at ${first.company}`, link: `${SITE}/job.html?id=${first.public_id}`, data: { type: "job", jobId: first.public_id } }
      : { title: `${list.length} new ${name} jobs`, body: `Including ${first.title} at ${first.company}`, link: `${SITE}/jobs.html?cat=${cat}`, data: { type: "jobs", category: cat } });
  }
}

export const adminRouter = Router();
adminRouter.use(requireAdmin, (_req, res, next) => { res.set("Cache-Control", "private, no-store"); next(); });

const expireOld = () => query("UPDATE jobs SET status = 'expired' WHERE status = 'approved' AND expires_at IS NOT NULL AND expires_at <= UTC_TIMESTAMP()");

async function jobByPid(pid: string) {
  const [r] = await query("SELECT id, public_id, title, status, expires_at, approved_at, posted_by_uid FROM jobs WHERE public_id = ?", [pid.slice(0, 12)]);
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
  category: z.string().trim().max(30).optional(),
  q: z.string().trim().max(100).optional(),
  page: z.coerce.number().int().min(1).default(1),
});

adminRouter.get("/jobs", wrap(async (req, res) => {
  await expireOld();
  const f = listQ.parse(req.query);
  const where: string[] = [], params: unknown[] = [];
  if (f.status !== "all") { where.push("j.status = ?"); params.push(f.status); }
  if (f.category) { where.push("j.category = ?"); params.push(f.category); }
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
    raw: { category: r.category, companyName: r.company_name, companyWebsite: r.company_website, title: r.title, jobType: r.job_type, workMode: r.work_mode,
      level: r.level, city: r.city, salaryMin: r.salary_min, salaryMax: r.salary_max, salaryPeriod: r.salary_period,
      description: r.description, applyUrl: r.apply_url, applyEmail: r.apply_email, contactName: r.contact_name, contactEmail: r.contact_email },
  })) });
}));

// Bulk import: paste many jobs at once. Everything is checked first; if any job has a problem, nothing is added.
const bulkBody = z.object({ jobs: z.array(z.record(z.unknown())).min(1).max(50), dryRun: z.boolean().default(false) });
adminRouter.post("/jobs/import", wrap(async (req, res) => {
  const { jobs, dryRun } = bulkBody.parse(req.body);
  const report: { index: number; title: string; status: "ok" | "invalid" | "duplicate"; message?: string }[] = [];
  const valid: { index: number; job: ReturnType<typeof jobInput.parse> }[] = [];
  const seen = new Set<string>();
  const known = new Set((await categories()).map(c => c.slug));
  for (const [i, raw] of jobs.entries()) {
    const input: any = { ...raw };
    if (typeof input.skills === "string") input.skills = input.skills.split(",").map((x: string) => x.trim()).filter(Boolean);
    if (!input.contactEmail) input.contactEmail = req.user!.email;
    const title = String(input.title ?? `Job ${i + 1}`).slice(0, 140);
    const r = jobInput.safeParse(input);
    if (r.success && !known.has(r.data.category)) { report.push({ index: i, title, status: "invalid", message: `category: unknown "${r.data.category}" (use ${[...known].join(", ")})` }); continue; }
    if (!r.success) { const iss = r.error.issues[0]; report.push({ index: i, title, status: "invalid", message: `${iss.path.join(".") || "job"}: ${iss.message}` }); continue; }
    const key = (r.data.applyUrl || r.data.applyEmail || "").toLowerCase() + "|" + r.data.title.toLowerCase();
    const [dup] = await query("SELECT 1 FROM jobs j JOIN companies c ON c.id = j.company_id WHERE j.status IN ('pending','approved') AND ((j.apply_url IS NOT NULL AND j.apply_url = ?) OR (c.name = ? AND j.title = ?)) LIMIT 1",
      [r.data.applyUrl, r.data.companyName, r.data.title]);
    if (dup || seen.has(key)) { report.push({ index: i, title, status: "duplicate", message: "Already on Widgetry Jobs (same apply link or same company and title)" }); continue; }
    seen.add(key); valid.push({ index: i, job: r.data }); report.push({ index: i, title, status: "ok" });
  }
  const invalid = report.filter(r => r.status === "invalid").length;
  if (dryRun || invalid) return res.status(invalid && !dryRun ? 400 : 200).json({ created: 0, report, error: invalid && !dryRun ? `${invalid} job(s) need fixing. Nothing was added.` : undefined });
  const created: string[] = [], createdIds: number[] = [];
  for (const v of valid) { const c = await createJob(v.job, { uid: req.user!.uid, approved: true }); created.push(c.publicId); createdIds.push(c.id); }
  for (const pid of created) pingJob(pid, "URL_UPDATED");
  void announceJobs(createdIds);   // one notification per category, not one per job
  res.status(201).json({ created: created.length, ids: created, report });
}));

// Admin posts go live immediately
adminRouter.post("/jobs", wrap(async (req, res) => {
  const j = jobInput.parse({ contactEmail: req.user!.email, ...req.body });   // admin's own email unless another is given
  await assertCategories([j.category]);
  const { id, publicId } = await createJob(j, { uid: req.user!.uid, approved: true });
  void announceJobs([id]);
  pingJob(publicId, "URL_UPDATED");
  res.status(201).json({ id: publicId, status: "approved" });
}));

adminRouter.put("/jobs/:id", wrap(async (req, res) => {
  const job = await jobByPid(String(req.params.id));
  const j = jobInput.parse(req.body);
  await assertCategories([j.category]);
  await updateJob(job.id, j);
  if (job.status === "approved") pingJob(job.public_id, "URL_UPDATED");
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
  // Tell Google when the job goes live or stops being live
  const nowLive = p.status ? p.status === "approved" : (job.status === "approved" || (job.status === "expired" && !!p.extendDays));
  if (nowLive && (job.status !== "approved" || p.extendDays)) pingJob(job.public_id, "URL_UPDATED");
  else if (!nowLive && job.status === "approved") pingJob(job.public_id, "URL_DELETED");
  // Notifications: first time live goes to subscribers; the employer hears about approval or rejection
  const employer = job.posted_by_uid && job.posted_by_uid !== req.user!.uid ? job.posted_by_uid : null;
  if (p.status === "approved" && job.status !== "approved") {
    if (!job.approved_at) void announceJobs([job.id]);
    void notifyUser(employer, { title: "Your job is live 🎉", body: `${job.title} is now on Widgetry Jobs.`, link: `${SITE}/job.html?id=${job.public_id}`, data: { type: "job", jobId: job.public_id } });
  }
  if (p.status === "rejected" && job.status !== "rejected")
    void notifyUser(employer, { title: "Your job needs changes", body: p.rejectReason ? `${job.title}: ${p.rejectReason}` : `${job.title} wasn't approved. Open it to see why.`, link: `${SITE}/post-job.html`, data: { type: "myjobs" } });
  res.json({ ok: true });
}));

adminRouter.delete("/jobs/:id", wrap(async (req, res) => {
  const job = await jobByPid(String(req.params.id));
  await query("DELETE FROM jobs WHERE id = ?", [job.id]);
  if (job.status === "approved") pingJob(job.public_id, "URL_DELETED");
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

const candQ = z.object({ network: z.enum(["yes", "no", "all"]).default("yes"), verification: z.enum(VERIFICATION).optional(), category: z.string().trim().max(30).optional(), q: z.string().trim().max(100).optional(), page: z.coerce.number().int().min(1).default(1) });

adminRouter.get("/candidates", wrap(async (req, res) => {
  const f = candQ.parse(req.query);
  const where: string[] = [], params: unknown[] = [];
  // Only people who joined the Talent Network can be introduced to employers; others just built a resume
  if (f.network !== "all") where.push(f.network === "yes" ? "talent_network = 1" : "talent_network = 0");
  if (f.verification) { where.push("verification = ?"); params.push(f.verification); }
  if (f.category) { where.push("EXISTS (SELECT 1 FROM candidate_categories cc WHERE cc.candidate_id = candidates.id AND cc.category = ?)"); params.push(f.category); }
  if (f.q) { const l = `%${f.q.replace(/[\\%_]/g, m => "\\" + m)}%`; where.push("(full_name LIKE ? OR email LIKE ? OR headline LIKE ? OR current_company LIKE ?)"); params.push(l, l, l, l); }
  const rows = await query(`SELECT * FROM candidates ${where.length ? "WHERE " + where.join(" AND ") : ""} ORDER BY updated_at DESC LIMIT 50 OFFSET ?`, [...params, (f.page - 1) * 50]);
  const ids = rows.map(r => r.id);
  const skills = new Map<number, string[]>();
  if (ids.length) for (const s of await query<{ candidate_id: number; skill: string }>("SELECT candidate_id, skill FROM candidate_skills WHERE candidate_id IN (?) ORDER BY skill", [ids]))
    (skills.get(s.candidate_id) ?? skills.set(s.candidate_id, []).get(s.candidate_id)!).push(s.skill);
  const cats = new Map<number, string[]>();
  if (ids.length) for (const c of await query<{ candidate_id: number; category: string }>("SELECT candidate_id, category FROM candidate_categories WHERE candidate_id IN (?)", [ids]))
    (cats.get(c.candidate_id) ?? cats.set(c.candidate_id, []).get(c.candidate_id)!).push(c.category);
  res.json({ items: rows.map(r => candidateOut(r, skills.get(r.id) ?? [], true, cats.get(r.id) ?? ["flutter"])) });
}));

adminRouter.patch("/candidates/:id", wrap(async (req, res) => {
  const p = adminCandidatePatch.parse(req.body);
  const sets: string[] = [], params: unknown[] = [];
  if (p.verification) { sets.push("verification = ?"); params.push(p.verification); }
  if (p.verifiedNote !== undefined) { sets.push("verified_note = ?"); params.push(p.verifiedNote); }
  if (p.status) { sets.push("status = ?"); params.push(p.status); }
  if (!sets.length) throw new HttpError(400, "Nothing to change.");
  const [before] = await query<any>("SELECT uid, verification FROM candidates WHERE public_id = ?", [String(req.params.id).slice(0, 12)]);
  if (!before) throw new HttpError(404, "Profile not found.");
  await query<any>(`UPDATE candidates SET ${sets.join(", ")} WHERE public_id = ?`, [...params, String(req.params.id).slice(0, 12)]);
  if (p.verification && p.verification !== before.verification && p.verification !== "self")
    void notifyUser(before.uid, p.verification === "verified"
      ? { title: "You're Widgetry verified ★", body: "Your profile now carries the Widgetry verified badge. Employers trust it most.", link: `${SITE}/my-profile.html`, data: { type: "profile" } }
      : { title: "Portfolio checked ✓", body: "A Widgetry engineer reviewed your apps and GitHub. Your badge is updated.", link: `${SITE}/my-profile.html`, data: { type: "profile" } });
  res.json({ ok: true });
}));

// Send a push notification to app users: everyone, academy subscribers, or one job category
const notifyBody = z.object({
  audience: z.string().trim().regex(/^(all|academy|jobs-[a-z0-9-]{2,30})$/, "Audience must be all, academy or jobs-<category>"),
  title: z.string().trim().min(3).max(100), body: z.string().trim().min(3).max(240),
  link: z.string().trim().url().refine(u => u.startsWith(SITE) || u.startsWith("https://"), "Use an https link").optional(),
});
adminRouter.post("/notify", wrap(async (req, res) => {
  const n = notifyBody.parse(req.body);
  await notifyTopic(n.audience, { title: n.title, body: n.body, link: n.link, data: { type: "announcement" } });
  res.json({ ok: true, message: `Sent to ${n.audience}.` });
}));
