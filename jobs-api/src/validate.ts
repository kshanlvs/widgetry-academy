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
// Canonical spelling for common skills (free text is also allowed, normalised below). Per-category suggestions live in job_categories.
export const COMMON_SKILLS = ["Flutter", "Dart", "Firebase", "Bloc", "Provider", "Riverpod", "GetX", "REST APIs", "GraphQL",
  "Kotlin", "Java", "Jetpack Compose", "Android SDK", "Coroutines", "MVVM", "Room", "Hilt", "Retrofit", "Espresso", "Gradle",
  "Swift", "SwiftUI", "UIKit", "Combine", "Objective-C", "Core Data", "Xcode", "XCTest",
  "Clean Architecture", "Testing", "CI/CD", "Google Maps", "Push Notifications", "Animations", "Flame", "Android", "iOS", "Flutter Web", "Git"];

const trim = (max: number) => z.string().trim().max(max);
const optText = (max: number) => trim(max).optional().transform(v => (v ? v : null));
// Only http(s) links; stops javascript:/data: URLs being stored and shown
const url = z.string().trim().max(400, "Link is too long").url("Enter a full link, e.g. https://github.com/you").refine(u => /^https?:\/\//i.test(u), "Enter a full link starting with https://");
// Empty or spaces only means "no link"
const optUrl = z.preprocess(v => (typeof v === "string" ? v.trim() : v), z.union([url, z.literal("")]).optional().nullable()).transform(v => (v ? v : null));
const email = z.string().trim().toLowerCase().email().max(200);

/**
 * Job boards and aggregators. A job's apply link must go to the hiring company itself (its careers site or its
 * own applicant-tracking page on Greenhouse, Lever, Workday and so on), never to another job board.
 */
const JOB_BOARDS = ["jobfound.org", "cutshort.io", "builtin.com", "wellfound.com", "angel.co", "internshala.com", "weekday.works",
  "efinancialcareers.com", "naukri.com", "indeed.com", "linkedin.com", "foundit.in", "monsterindia.com", "monster.com", "glassdoor.com",
  "glassdoor.co.in", "instahyre.com", "hirist.tech", "hirist.com", "iimjobs.com", "shine.com", "apna.co", "workindia.in", "timesjobs.com",
  "freshersworld.com", "jobsora.com", "semesteria.com", "theindiajobs.com", "jobrise.io", "remotive.com", "weworkremotely.com",
  "remoteok.com", "jobgether.com", "jooble.org", "simplyhired.com", "simplyhired.co.in", "ziprecruiter.com", "dice.com", "themuse.com",
  "peerlist.io", "jointaro.com", "career.io", "bayt.com", "jobera.com", "employbl.com", "teamlease.com", "unstop.com", "hirect.in"];
export function jobBoardHost(link: string | null | undefined): string | null {
  if (!link) return null;
  let host: string;
  try { host = new URL(link).hostname.toLowerCase().replace(/^www\./, ""); } catch { return null; }
  if (/^builtin[a-z]*\.(com|in|org|uk|ie)$/.test(host)) return host;          // builtinbengaluru.in, builtinnyc.com, …
  if (/(^|\.)(indeed|glassdoor|monster|foundit|naukri|linkedin)\.[a-z.]+$/.test(host)) return host;  // country domains, e.g. in.indeed.com, glassdoor.co.uk
  return JOB_BOARDS.some(d => host === d || host.endsWith("." + d)) ? host : null;
}

export const skillList = z.array(trim(40).min(1)).max(15).default([])
  .transform(list => {
    const seen = new Map<string, string>();
    for (const s of list) {
      const canon = COMMON_SKILLS.find(c => c.toLowerCase() === s.toLowerCase()) ?? s.replace(/\s+/g, " ");
      seen.set(canon.toLowerCase(), canon);
    }
    return [...seen.values()];
  });

// Category slug (checked against job_categories by the routes)
export const categorySlug = z.string().trim().toLowerCase().regex(/^[a-z0-9-]{2,30}$/, "Choose a category");

export const jobInput = z.object({
  category: categorySlug.default("flutter"),
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
  const board = jobBoardHost(j.applyUrl);
  if (board) ctx.addIssue({ code: "custom", path: ["applyUrl"], message: `Link to the company's own careers page, not a job board (${board})` });
  if (j.salaryMin != null && j.salaryMax != null && j.salaryMin > j.salaryMax) ctx.addIssue({ code: "custom", path: ["salaryMax"], message: "Max salary must be at least the min salary" });
  if ((j.salaryMin != null || j.salaryMax != null) && !j.salaryPeriod) ctx.addIssue({ code: "custom", path: ["salaryPeriod"], message: "Choose per month, per year or per project" });
  if (j.workMode !== "remote" && !j.city) ctx.addIssue({ code: "custom", path: ["city"], message: "City is required for on-site and hybrid roles" });
  // Jobs that charge candidates are not allowed on Widgetry Jobs
  if (/\b(registration|security|training|joining)\s+(fee|deposit|charges?)\b|\bpay\s+(?:₹|rs\.?|inr)\s*\d/i.test(j.description))
    ctx.addIssue({ code: "custom", path: ["description"], message: "Jobs that ask candidates to pay any fee are not allowed" });
});
export type JobInput = z.infer<typeof jobInput>;

export const jobSearch = z.object({
  category: categorySlug.optional(),
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

const appItem = z.object({ name: trim(80).min(1), url: optUrl, role: optText(80), about: optText(400) });   // about: what it does, tech used

const month = z.string().trim().regex(/^\d{4}-(0[1-9]|1[0-2])$/, "Use month and year");
const workItem = z.object({
  company: trim(120).min(1, "Add the company name"), role: trim(100).min(1, "Add your role"),
  start: month, end: z.union([month, z.literal("")]).optional().transform(v => (v ? v : null)),   // empty = present
  points: trim(1500).optional().transform(v => (v ? v : null)),                                   // one achievement per line
}).refine(w => !w.end || w.end >= w.start, { message: "End date must be after the start date", path: ["end"] });
const eduItem = z.object({
  degree: trim(120).min(1, "Add the degree or course"), institute: trim(150).min(1, "Add the college or school"),
  year: z.coerce.number().int().min(1970).max(2040).optional().nullable(), score: optText(40),
});

export const candidateInput = z.object({
  categories: z.array(categorySlug).min(1, "Choose at least one role type").max(10).default(["flutter"]).transform(a => [...new Set(a)]),
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
  experience: z.array(workItem).max(10).default([]),
  education: z.array(eduItem).max(6).default([]),
  certifications: z.array(z.object({ name: trim(120).min(1, "Add the certificate name"), issuer: optText(120),
    year: z.coerce.number().int().min(1970).max(2040).optional().nullable() })).max(8).default([]),
  about: optText(2000),
  // One line each: awards, hackathons, positions of responsibility. Blank lines are dropped.
  // Left out (older app versions): kept as they are
  achievements: z.array(z.string().trim().max(200, "Keep each achievement under 200 characters")).max(10).optional().transform(a => a?.filter(Boolean)),
  languages: z.array(z.string().trim().max(40)).max(8).optional().transform(a => (a ? [...new Set(a.filter(Boolean))] : undefined)),
  skills: skillList.refine(s => s.length > 0, "Add at least one skill"),
  openToWork: z.boolean().default(true),
  hiddenCompanies: optText(400),
  // Join the Talent Network (employers can be introduced to you, with your approval). Separate from building a resume.
  talentNetwork: z.boolean().optional(),
  consent: z.boolean().optional(),   // older app versions: consent: true meant joining the network
}).transform(({ consent, ...p }) => ({ ...p, talentNetwork: p.talentNetwork ?? (consent === true ? true : undefined) }));
export type CandidateInput = z.infer<typeof candidateInput>;

// Resume look, saved per seeker
export const ACCENTS = ["green", "navy", "black", "maroon", "teal", "purple"] as const;
export const HIDEABLE = ["photo", "phone", "email", "city", "summary", "highlights", "projects", "achievements", "education", "certifications", "languages"] as const;
export const DENSITIES = ["normal", "compact", "tight"] as const;
export const resumeSettingsInput = z.object({
  template: z.enum(["classic", "modern", "impact", "timeline", "executive", "elegant", "minimal", "compact"]).default("modern"),   // all but Classic and Modern are Resume Premium
  accent: z.enum(ACCENTS).default("green"),
  title: optText(140),                                  // target role shown instead of the headline
  showPhoto: z.boolean().default(false),
  hide: z.array(z.enum(HIDEABLE)).max(HIDEABLE.length).default([]),
  density: z.enum(DENSITIES).default("normal"),   // "Fit to one page"
});

// Profile photo: the browser resizes to a small JPEG/PNG/WebP first
export const photoInput = z.object({ dataUrl: z.string().max(400_000).regex(/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/, "Upload a JPG, PNG or WebP image") });

export const openToWorkInput = z.object({ openToWork: z.boolean().optional(), talentNetwork: z.boolean().optional() })
  .refine(b => b.openToWork !== undefined || b.talentNetwork !== undefined, { message: "Nothing to change" });

export const employerJobPatch = z.object({ status: z.enum(["filled"]) });

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
