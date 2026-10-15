// Talent Network: each signed-in user manages their own profile. Profiles are private (admin-only) for now.
import { Router } from "express";
import type mysql from "mysql2/promise";
import { query, tx } from "../db.js";
import { HttpError, wrap } from "../errors.js";
import { requireAuth } from "../auth.js";
import { candidateInput, publicId, resumeSettingsInput, photoInput, openToWorkInput } from "../validate.js";

export const talentRouter = Router();

const csv = (v: string | null) => (v ? v.split(",").filter(Boolean) : []);
const json = (v: any) => (typeof v === "string" ? JSON.parse(v) : (v ?? []));

export function candidateOut(r: any, skills: string[], forAdmin = false) {
  const out: any = {
    id: r.public_id,
    fullName: r.full_name, email: r.email, phone: r.phone ?? null,
    headline: r.headline, currentCompany: r.current_company ?? null,
    experienceYears: Number(r.experience_years), city: r.city ?? null,
    workModes: csv(r.work_modes), jobTypes: csv(r.job_types),
    noticePeriod: r.notice_period ?? null,
    expectedSalaryLpa: r.expected_salary_lpa != null ? Number(r.expected_salary_lpa) : null,
    githubUrl: r.github_url ?? null, linkedinUrl: r.linkedin_url ?? null, portfolioUrl: r.portfolio_url ?? null,
    apps: json(r.apps), experience: json(r.experience), education: json(r.education), certifications: json(r.certifications),
    about: r.about ?? null, skills,
    resumeSettings: r.resume_settings ? (typeof r.resume_settings === "string" ? JSON.parse(r.resume_settings) : r.resume_settings) : null,
    openToWork: !!r.open_to_work, hiddenCompanies: r.hidden_companies ?? null,
    verification: r.verification, status: r.status,
    createdAt: r.created_at, updatedAt: r.updated_at,
  };
  if (forAdmin) { out.verifiedNote = r.verified_note ?? null; out.uid = r.uid; }
  return out;
}

async function load(uid: string) {
  const [r] = await query("SELECT * FROM candidates WHERE uid = ?", [uid]);
  if (!r) return null;
  const skills = (await query<{ skill: string }>("SELECT skill FROM candidate_skills WHERE candidate_id = ? ORDER BY skill", [r.id])).map(s => s.skill);
  const out = candidateOut(r, skills);
  const [ph] = await query<{ mime: string; data: Buffer }>("SELECT mime, data FROM candidate_photos WHERE candidate_id = ?", [r.id]);
  out.photo = ph ? `data:${ph.mime};base64,${Buffer.from(ph.data).toString("base64")}` : null;
  return out;
}

talentRouter.use((_req, res, next) => { res.set("Cache-Control", "private, no-store"); next(); });

talentRouter.get("/talent/me", requireAuth, wrap(async (req, res) => {
  res.json({ profile: await load(req.user!.uid) });
}));

talentRouter.put("/talent/me", requireAuth, wrap(async (req, res) => {
  const u = req.user!;
  if (!u.email) throw new HttpError(400, "Your account has no email address. Please sign in with Google or email.");
  const p = candidateInput.parse(req.body);
  await tx(async c => {
    const vals = [p.fullName, u.email, p.phone, p.headline, p.currentCompany, p.experienceYears, p.city,
      p.workModes.join(",") || null, p.jobTypes.join(",") || null, p.noticePeriod ?? null, p.expectedSalaryLpa ?? null,
      p.githubUrl, p.linkedinUrl, p.portfolioUrl, JSON.stringify(p.apps), JSON.stringify(p.experience), JSON.stringify(p.education), JSON.stringify(p.certifications), p.about, p.openToWork ? 1 : 0, p.hiddenCompanies];
    const [existing] = await c.query("SELECT id FROM candidates WHERE uid = ? FOR UPDATE", [u.uid]);
    let id: number;
    if ((existing as any[]).length) {
      id = (existing as any[])[0].id;
      await c.query(`UPDATE candidates SET full_name=?, email=?, phone=?, headline=?, current_company=?, experience_years=?, city=?,
        work_modes=?, job_types=?, notice_period=?, expected_salary_lpa=?, github_url=?, linkedin_url=?, portfolio_url=?, apps=?, experience=?, education=?, certifications=?, about=?,
        open_to_work=?, hidden_companies=? WHERE id=?`, [...vals, id]);
      await c.query("DELETE FROM candidate_skills WHERE candidate_id = ?", [id]);
    } else {
      const [ins] = await c.query(`INSERT INTO candidates (public_id, uid, full_name, email, phone, headline, current_company, experience_years, city,
        work_modes, job_types, notice_period, expected_salary_lpa, github_url, linkedin_url, portfolio_url, apps, experience, education, certifications, about,
        open_to_work, hidden_companies, consent_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,UTC_TIMESTAMP())`,
        [publicId(), u.uid, ...vals]);
      id = (ins as mysql.ResultSetHeader).insertId;
    }
    await c.query("INSERT INTO candidate_skills (candidate_id, skill) VALUES ?", [p.skills.map(s => [id, s])]);
  });
  res.json({ profile: await load(u.uid), message: "Your Talent Network profile is saved." });
}));

// Delete everything we hold for this profile (right to erasure)
talentRouter.delete("/talent/me", requireAuth, wrap(async (req, res) => {
  await query("DELETE FROM candidates WHERE uid = ?", [req.user!.uid]);
  res.json({ ok: true, message: "Your profile has been deleted." });
}));

async function myId(uid: string) {
  const [r] = await query<{ id: number }>("SELECT id FROM candidates WHERE uid = ?", [uid]);
  if (!r) throw new HttpError(404, "Create your profile first.");
  return r.id;
}

// Check the real file type from its first bytes, not just what the browser says
function sniff(b: Buffer) {
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "image/jpeg";
  if (b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "image/png";
  if (b.subarray(0, 4).toString("ascii") === "RIFF" && b.subarray(8, 12).toString("ascii") === "WEBP") return "image/webp";
  return null;
}
const MAX_PHOTO = 250 * 1024;

talentRouter.put("/talent/me/photo", requireAuth, wrap(async (req, res) => {
  const id = await myId(req.user!.uid);
  const { dataUrl } = photoInput.parse(req.body);
  const buf = Buffer.from(dataUrl.slice(dataUrl.indexOf(",") + 1), "base64");
  const mime = sniff(buf);
  if (!mime) throw new HttpError(400, "That file isn't a valid JPG, PNG or WebP image.");
  if (buf.length > MAX_PHOTO) throw new HttpError(400, "The photo is too large. Please use a smaller image.");
  await query("INSERT INTO candidate_photos (candidate_id, mime, data) VALUES (?,?,?) ON DUPLICATE KEY UPDATE mime = VALUES(mime), data = VALUES(data)", [id, mime, buf]);
  res.json({ ok: true, photo: `data:${mime};base64,${buf.toString("base64")}`, message: "Profile photo updated." });
}));

talentRouter.delete("/talent/me/photo", requireAuth, wrap(async (req, res) => {
  const id = await myId(req.user!.uid);
  await query("DELETE FROM candidate_photos WHERE candidate_id = ?", [id]);
  res.json({ ok: true, message: "Profile photo removed." });
}));

talentRouter.put("/talent/me/resume-settings", requireAuth, wrap(async (req, res) => {
  const id = await myId(req.user!.uid);
  const s = resumeSettingsInput.parse(req.body);
  await query("UPDATE candidates SET resume_settings = ? WHERE id = ?", [JSON.stringify(s), id]);
  res.json({ ok: true, resumeSettings: s });
}));

talentRouter.patch("/talent/me", requireAuth, wrap(async (req, res) => {
  const id = await myId(req.user!.uid);
  const { openToWork } = openToWorkInput.parse(req.body);
  await query("UPDATE candidates SET open_to_work = ? WHERE id = ?", [openToWork ? 1 : 0, id]);
  res.json({ ok: true, openToWork, message: openToWork ? "You're open to work." : "Your profile is paused." });
}));
