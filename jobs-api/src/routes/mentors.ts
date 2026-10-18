// Mentors manage their own application/profile (stored in Firestore "mentorApplications"),
// including "I want to take mock interviews". Done on the server so Firestore rules stay admin-only for edits.
import { Router } from "express";
import { z } from "zod";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { adminApp } from "../firebase.js";
import { exec, query } from "../db.js";
import { wrap, HttpError } from "../errors.js";
import { requireAuth } from "../auth.js";
import { TRACKS } from "../mock.js";

export interface MentorDoc { id: string; data: Record<string, any> }
export interface MentorStore {
  /** The signed-in person's application: linked by uid, or an older one sent with the same email. */
  findMine(uid: string, email: string | null): Promise<MentorDoc | null>;
  create(data: Record<string, any>): Promise<string>;
  update(id: string, data: Record<string, any>): Promise<void>;
  /** Updates the public mentor card (only for approved mentors). */
  setPublic(id: string, card: Record<string, any>): Promise<void>;
}

const firestoreMentors: MentorStore = {
  async findMine(uid, email) {
    const db = getFirestore(adminApp());
    const byUid = await db.collection("mentorApplications").where("uid", "==", uid).get();
    let docs = byUid.docs;
    if (!docs.length && email) docs = (await db.collection("mentorApplications").where("email", "==", email.toLowerCase()).get()).docs;
    if (!docs.length) return null;
    // Newest first
    docs.sort((a, b) => (b.get("createdAt")?.toMillis?.() ?? 0) - (a.get("createdAt")?.toMillis?.() ?? 0));
    return { id: docs[0]!.id, data: docs[0]!.data() };
  },
  async create(data) {
    const ref = await getFirestore(adminApp()).collection("mentorApplications").add({ ...data, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    return ref.id;
  },
  async update(id, data) {
    await getFirestore(adminApp()).collection("mentorApplications").doc(id).update({ ...data, updatedAt: FieldValue.serverTimestamp() });
  },
  async setPublic(id, card) {
    await getFirestore(adminApp()).collection("mentorProfiles").doc(id).set({ ...card, updatedAt: FieldValue.serverTimestamp() });
  },
};

let override: MentorStore | null = null;
export function setMentorStore(s: MentorStore | null) { override = s; }
const store = () => override ?? firestoreMentors;

const STATUS = (s: unknown) => (!s || s === "pending" ? "new" : String(s));
const trackId = z.enum(TRACKS.map(t => t.id) as [string, ...string[]]);

const mentorBody = z.object({
  name: z.string().trim().min(2, "Please enter your full name").max(99),
  phone: z.string().trim().transform(v => v.replace(/[\s()-]/g, "")).transform(v => (/^[6-9]\d{9}$/.test(v) ? "+91" + v : /^91[6-9]\d{9}$/.test(v) ? "+" + v : v))
    .refine(v => /^\+[1-9]\d{9,14}$/.test(v), "Enter your WhatsApp number with country code, e.g. +91 98765 43210"),
  company: z.string().trim().min(1, "Add your company").max(100),
  role: z.string().trim().min(1, "Add your role").max(100),
  experience: z.coerce.number().int().refine(v => [2, 4, 6, 10, 15].includes(v), "Choose your experience"),
  linkedin: z.string().trim().max(200).optional().default("").transform(v => (!v ? "" : /^https?:\/\//i.test(v) ? v : "https://" + v))
    .refine(v => !v || /^https:\/\/([a-z]+\.)?linkedin\.com\//i.test(v), "Enter your LinkedIn profile link"),
  skills: z.array(z.string().trim().min(1).max(30)).min(1, "Choose at least one skill").max(10),
  course: z.string().trim().min(3, "Tell us what you'd like to teach").max(200),
  bio: z.string().trim().min(20, "Write at least 20 characters about yourself").max(500),
  availability: z.enum(["Weekends", "Weekdays", "Flexible"]),
  wantsInterviews: z.boolean().default(false),
  interviewTracks: z.array(trackId).max(3).default([]).transform(a => [...new Set(a)]),
}).refine(b => !b.wantsInterviews || b.interviewTracks.length > 0, { path: ["interviewTracks"], message: "Choose which interviews you can take" });

const out = (m: MentorDoc | null) => m && ({
  id: m.id,
  status: STATUS(m.data.status),
  name: m.data.name ?? "", email: m.data.email ?? "", phone: m.data.phone ?? "",
  company: m.data.company ?? "", role: m.data.role ?? "",
  experience: typeof m.data.experience === "number" ? m.data.experience : null,
  linkedin: m.data.linkedin ?? "",
  skills: Array.isArray(m.data.skills) ? m.data.skills : [],
  course: m.data.course ?? "", bio: m.data.bio ?? m.data.pitch ?? "",
  availability: typeof m.data.availability === "string" ? m.data.availability : "",
  wantsInterviews: !!m.data.wantsInterviews,
  interviewTracks: Array.isArray(m.data.interviewTracks) ? m.data.interviewTracks : [],
});

export const mentorsRouter = Router();
mentorsRouter.use("/mentor", (_req, res, next) => { res.set("Cache-Control", "private, no-store"); next(); });

mentorsRouter.get("/mentor/me", requireAuth, wrap(async (req, res) => {
  const u = req.user!;
  const m = await store().findMine(u.uid, u.email);
  const [iv] = await query<{ active: number }>("SELECT active FROM interviewers WHERE uid = ?", [u.uid]);
  res.json({ application: out(m), interviewer: iv ? (iv.active ? "active" : "paused") : null });
}));

/** Apply, or edit your existing application. Status stays as the admin set it. */
mentorsRouter.put("/mentor/me", requireAuth, wrap(async (req, res) => {
  const u = req.user!;
  if (!u.email) throw new HttpError(400, "Your account has no email. Sign in with Google or an email account.");
  const b = mentorBody.parse(req.body);
  const fields = {
    name: b.name, phone: b.phone, company: b.company, role: b.role, experience: b.experience, linkedin: b.linkedin,
    skills: b.skills, course: b.course, bio: b.bio, availability: b.availability,
    wantsInterviews: b.wantsInterviews, interviewTracks: b.wantsInterviews ? b.interviewTracks : [],
  };
  const s = store();
  const mine = await s.findMine(u.uid, u.email);
  let id: string;
  let created = false;
  if (!mine) {
    id = await s.create({ ...fields, uid: u.uid, email: u.email.toLowerCase(), status: "new" });
    created = true;
  } else {
    id = mine.id;
    // Link an older application (sent before signing in) to this account
    await s.update(id, { ...fields, ...(mine.data.uid ? {} : { uid: u.uid }) });
    // Approved mentors: keep the public card in step
    if (STATUS(mine.data.status) === "approved") {
      await s.setPublic(id, {
        name: b.name, role: b.role, company: b.company, experience: b.experience,
        skills: b.skills.slice(0, 10), course: b.course, linkedin: b.linkedin,
      });
    }
  }
  // Already an interviewer: keep their interviewer details in step too
  const [iv] = await query<any>("SELECT uid FROM interviewers WHERE uid = ?", [u.uid]);
  if (iv) {
    await exec("UPDATE interviewers SET name = ?, title = ?, company = ?, years = ?, linkedin_url = COALESCE(?, linkedin_url), bio = ?" + (b.interviewTracks.length ? ", tracks = ?" : "") + " WHERE uid = ?",
      [b.name, b.role, b.company, b.experience, b.linkedin || null, b.bio, ...(b.interviewTracks.length ? [JSON.stringify(b.interviewTracks)] : []), u.uid]);
  }
  const now = await s.findMine(u.uid, u.email);
  res.status(created ? 201 : 200).json({ ok: true, created, application: out(now ?? { id, data: { ...fields, status: "new" } }) });
}));
