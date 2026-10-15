import { z } from "zod";
import { randomBytes, createHash } from "node:crypto";
import { config } from "./config.js";

export const JOB_TYPES = ["full_time", "internship", "freelance", "contract", "part_time"] as const;
export const WORK_MODES = ["remote", "onsite", "hybrid"] as const;
export const LEVELS = ["fresher", "junior", "mid", "senior", "lead"] as const;
export const SALARY_PERIODS = ["month", "year", "project"] as const;
export const NOTICE = ["immediate", "15_days", "30_days", "60_days", "90_days"] as const;
export const REPORT_REASONS = ["scam", "asks_fees", "fake", "expired", "wrong_info", "other"] as const;
export const VERIFICATION = ["self", "portfolio", "verified"] as const;

// Suggested skills (free text is also allowed, normalised below)
export const COMMON_SKILLS = ["Flutter", "Dart", "Firebase", "Bloc", "Provider", "Riverpod", "GetX", "REST APIs", "GraphQL",
  "Clean Architecture", "Testing", "CI/CD", "Google Maps", "Push Notifications", "Animations", "Flame", "Android", "iOS", "Flutter Web", "Git"];

const trim = (max: number) => z.string().trim().max(max);
const optText = (max: number) => trim(max).optional().transform(v => (v ? v : null));
// Only http(s) links; stops javascript:/data: URLs being stored and shown
const url = z.string().trim().max(400).url().refine(u => /^https?:\/\//i.test(u), "must start with https://");
const optUrl = z.union([url, z.literal("")]).optional().transform(v => (v ? v : null));
const email = z.string().trim().toLowerCase().email().max(200);

export const skillList = z.array(trim(40).min(1)).max(15).default([])
  .transform(list => {
    const seen = new Map<string, string>();
    for (const s of list) {
      const canon = COMMON_SKILLS.find(c => c.toLowerCase() === s.toLowerCase()) ?? s.replace(/\s+/g, " ");
      seen.set(canon.toLowerCase(), canon);
    }
    return [...seen.values()];
  });

export const jobInput = z.object({
  companyName: trim(120).min(2, "Company name is required"),
  companyWebsite: optUrl,
  title: trim(140).min(4, "Job title is required"),
  jobType: z.enum(JOB_TYPES),
  workMode: z.enum(WORK_MODES),
  level: z.enum(LEVELS),
  city: optText(80),
  salaryMin: z.coerce.number().int().min(0).max(100_000_000).optional().nullable(),
  salaryMax: z.coerce.number().int().min(0).max(100_000_000).optional().nullable(),
  salaryPeriod: z.enum(SALARY_PERIODS).optional().nullable(),
  description: trim(8000).min(80, "Please describe the role in at least 80 characters"),
  skills: skillList,
  applyUrl: optUrl,
  applyEmail: z.union([email, z.literal("")]).optional().transform(v => (v ? v : null)),
  contactName: optText(100),
  contactEmail: email,
  agree: z.literal(true, { errorMap: () => ({ message: "Please accept the posting rules" }) }).optional(),
}).superRefine((j, ctx) => {
  if (!j.applyUrl && !j.applyEmail) ctx.addIssue({ code: "custom", path: ["applyUrl"], message: "Add an application link or email" });
  if (j.salaryMin != null && j.salaryMax != null && j.salaryMin > j.salaryMax) ctx.addIssue({ code: "custom", path: ["salaryMax"], message: "Max salary must be at least the min salary" });
  if ((j.salaryMin != null || j.salaryMax != null) && !j.salaryPeriod) ctx.addIssue({ code: "custom", path: ["salaryPeriod"], message: "Choose per month, per year or per project" });
  if (j.workMode !== "remote" && !j.city) ctx.addIssue({ code: "custom", path: ["city"], message: "City is required for on-site and hybrid roles" });
  // Jobs that charge candidates are not allowed on Widgetry Jobs
  if (/\b(registration|security|training|joining)\s+(fee|deposit|charges?)\b|\bpay\s+(?:₹|rs\.?|inr)\s*\d/i.test(j.description))
    ctx.addIssue({ code: "custom", path: ["description"], message: "Jobs that ask candidates to pay any fee are not allowed" });
});
export type JobInput = z.infer<typeof jobInput>;

export const jobSearch = z.object({
  q: trim(100).optional(),
  type: z.enum(JOB_TYPES).optional(),
  mode: z.enum(WORK_MODES).optional(),
  level: z.enum(LEVELS).optional(),
  city: trim(80).optional(),
  skill: trim(40).optional(),
  page: z.coerce.number().int().min(1).max(200).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

export const reportInput = z.object({
  reason: z.enum(REPORT_REASONS),
  details: optText(500),
});

const appItem = z.object({ name: trim(80).min(1), url: optUrl, role: optText(80) });

export const candidateInput = z.object({
  fullName: trim(100).min(2, "Your name is required"),
  phone: z.string().trim().regex(/^\+?\d[\d\s-]{7,16}$/, "Enter a valid phone number").optional().or(z.literal("")).transform(v => (v ? v.replace(/[\s-]/g, "") : null)),
  headline: trim(140).min(4, "Add a short headline, e.g. Flutter Developer · 3 years"),
  currentCompany: optText(120),
  experienceYears: z.coerce.number().min(0).max(40).multipleOf(0.5),
  city: optText(80),
  workModes: z.array(z.enum(WORK_MODES)).max(3).default([]),
  jobTypes: z.array(z.enum(JOB_TYPES)).max(5).default([]),
  noticePeriod: z.enum(NOTICE).optional().nullable(),
  expectedSalaryLpa: z.coerce.number().min(0).max(500).optional().nullable(),
  githubUrl: optUrl, linkedinUrl: optUrl, portfolioUrl: optUrl,
  apps: z.array(appItem).max(8).default([]),
  about: optText(2000),
  skills: skillList.refine(s => s.length > 0, "Add at least one skill"),
  openToWork: z.boolean().default(true),
  hiddenCompanies: optText(400),
  consent: z.literal(true, { errorMap: () => ({ message: "Please agree to how we use your profile" }) }),
});
export type CandidateInput = z.infer<typeof candidateInput>;

export const adminJobPatch = z.object({
  status: z.enum(["pending", "approved", "rejected", "filled", "expired"]).optional(),
  rejectReason: optText(300),
  featured: z.boolean().optional(),
  extendDays: z.coerce.number().int().min(1).max(90).optional(),
});

export const adminCandidatePatch = z.object({
  verification: z.enum(VERIFICATION).optional(),
  verifiedNote: optText(300),
  status: z.enum(["active", "hidden"]).optional(),
});

const ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz";
export function publicId(len = 12) {
  const b = randomBytes(len);
  return Array.from(b, x => ALPHABET[x % ALPHABET.length]).join("");
}
export const hashIp = (ip: string) => createHash("sha256").update(config.hashSalt + "|" + ip).digest("hex");

/** Turn free text into a safe MySQL boolean full-text query: +word* for each word of 3+ chars. */
export function ftQuery(q: string) {
  const words = q.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, " ").split(/\s+/).filter(w => w.length >= 3).slice(0, 8);
  return words.length ? words.map(w => `+${w}*`).join(" ") : null;
}
