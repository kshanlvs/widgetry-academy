// Fresh data before every run: clear the test database, then add jobs the way an admin would.
import mysql from "mysql2/promise";
import { DB } from "./playwright.config";
import { api, USERS } from "./helpers";

export const JOBS = [
  { companyName: "Bytewave Labs", title: "Flutter Developer", jobType: "full_time", workMode: "hybrid", level: "junior", city: "Kolkata", skills: ["Flutter", "Dart", "Bloc", "Firebase"], featured: true },
  { companyName: "Nimbus Apps", title: "Flutter Intern", jobType: "internship", workMode: "remote", level: "fresher", city: "", skills: ["Flutter", "Provider"] },
  { companyName: "Kite Mobile", title: "Android Developer", jobType: "full_time", workMode: "onsite", level: "mid", city: "Bengaluru", skills: ["Kotlin", "Jetpack Compose"], category: "android" },
];

export default async function setup() {
  const db = await mysql.createConnection(DB);
  for (const t of ["job_reports", "job_skills", "jobs", "companies", "candidate_skills", "candidate_photos", "candidates", "resume_versions", "resume_premium", "resume_ai_usage"]) {
    await db.query(`DELETE FROM ${t}`).catch(() => {});
  }
  await db.end();
  for (const j of JOBS) {
    const { featured, category, ...job } = j as any;
    const r = await api("POST", "/admin/jobs", {
      ...job, ...(category ? { category } : {}),
      companyWebsite: "https://example.com", salaryMin: 30000, salaryMax: 60000, salaryPeriod: "month",
      description: `${job.title} at ${job.companyName}. Build and ship mobile apps for Android and iOS, work with REST APIs and Firebase, write clean tested code and review pull requests every sprint.`,
      applyUrl: "https://example.com/careers", contactName: "HR", contactEmail: "hr@example.com", agree: true,
    }, USERS.admin);
    if (r.status !== 201) throw new Error(`Seeding job "${job.title}" failed: ${r.status} ${JSON.stringify(r.body)}`);
    if (featured) await api("PATCH", `/admin/jobs/${r.body.id}`, { featured: true }, USERS.admin);
  }
}
