// Talent Network: each signed-in user manages their own profile. Profiles are private (admin-only) for now.
import { Router } from "express";
import type mysql from "mysql2/promise";
import { query, tx } from "../db.js";
import { HttpError, wrap } from "../errors.js";
import { requireAuth } from "../auth.js";
import { candidateInput, publicId } from "../validate.js";

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
  return candidateOut(r, skills);
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
