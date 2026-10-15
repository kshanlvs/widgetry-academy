// End-to-end API tests against a real MySQL database.
// Run: DB_PORT=3307 DB_PASSWORD=devpass ALLOW_DEV_AUTH=1 npm test
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";
import { createApp } from "../src/app.js";
import { pool } from "../src/db.js";
import { migrate } from "../src/migrate.js";

const ADMIN = "dev:E4edbAvcdwTdkTdNwcdWneVWe572:admin@widgetry.test:Admin";
const EMP = "dev:emp1:hr@acme.test:Acme HR";
const EMP2 = "dev:emp2:hr@beta.test:Beta HR";
const SEEK = "dev:seek1:riya@test.dev:Riya";
let server: Server, base = "";

async function call(method: string, path: string, body?: unknown, token?: string, ip = "10.0.0.1") {
  const r = await fetch(base + path, { method, headers: { "content-type": "application/json", "x-forwarded-for": ip, ...(token ? { authorization: "Bearer " + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  return { status: r.status, body: text ? JSON.parse(text) : null, headers: r.headers };
}

const goodJob = (over: Record<string, unknown> = {}) => ({
  companyName: "Acme Apps", companyWebsite: "https://acme.test", title: "Junior Flutter Developer",
  jobType: "full_time", workMode: "hybrid", level: "junior", city: "Kolkata",
  salaryMin: 25000, salaryMax: 40000, salaryPeriod: "month",
  description: "Build and maintain our Flutter apps for Android and iOS. You will work with Firebase, REST APIs and Bloc, write clean tested code and ship features every sprint.",
  skills: ["flutter", "Dart", "firebase", "Bloc"], applyUrl: "https://acme.test/careers/flutter", contactName: "Asha", contactEmail: "asha@acme.test", agree: true, ...over,
});

before(async () => {
  await migrate(() => {});
  for (const t of ["job_reports", "job_skills", "jobs", "companies", "candidate_skills", "candidates"]) await pool.query(`DELETE FROM ${t}`);
  server = createApp().listen(0);
  await new Promise(r => server.once("listening", r));
  base = `http://127.0.0.1:${(server.address() as any).port}/api`;
});
after(async () => { server.close(); await pool.end(); });

test("health check reaches the database", async () => {
  const r = await call("GET", "/health");
  assert.equal(r.status, 200); assert.equal(r.body.ok, true);
});

test("posting a job needs sign-in", async () => {
  const r = await call("POST", "/jobs", goodJob());
  assert.equal(r.status, 401);
});

test("job validation: apply method, fee wording, salary, city, description, unsafe links", async () => {
  const cases: [Record<string, unknown>, string][] = [
    [{ applyUrl: "", applyEmail: "" }, "applyUrl"],
    [{ description: goodJob().description + " Candidates must pay a registration fee of Rs 500." }, "description"],
    [{ salaryMin: 50000, salaryMax: 20000 }, "salaryMax"],
    [{ workMode: "onsite", city: "" }, "city"],
    [{ description: "too short" }, "description"],
    [{ applyUrl: "javascript:alert(1)" }, "applyUrl"],
    [{ jobType: "permanent" }, "jobType"],
  ];
  for (const [over, field] of cases) {
    const r = await call("POST", "/jobs", goodJob(over), EMP);
    assert.equal(r.status, 400, JSON.stringify(over));
    assert.ok(r.body.issues.some((i: any) => i.field === field), `expected issue on ${field}: ${JSON.stringify(r.body)}`);
  }
});

let pendingId = "";
test("employer job goes to review, not live", async () => {
  const r = await call("POST", "/jobs", goodJob(), EMP);
  assert.equal(r.status, 201); assert.equal(r.body.status, "pending");
  pendingId = r.body.id; assert.match(pendingId, /^[a-z0-9]{12}$/);
  assert.equal((await call("GET", "/jobs")).body.total, 0);
  assert.equal((await call("GET", `/jobs/${pendingId}`)).status, 404);
  const mine = await call("GET", "/my/jobs", undefined, EMP);
  assert.equal(mine.body.items.length, 1); assert.equal(mine.body.items[0].status, "pending");
  assert.equal((await call("GET", "/my/jobs", undefined, EMP2)).body.items.length, 0, "employers only see their own jobs");
});

test("admin routes are admins only", async () => {
  assert.equal((await call("GET", "/admin/jobs")).status, 401);
  assert.equal((await call("GET", "/admin/jobs", undefined, EMP)).status, 403);
  assert.equal((await call("GET", "/admin/jobs", undefined, "garbage")).status, 401);
});

test("admin approves; job becomes public with skills normalised and private fields hidden", async () => {
  const list = await call("GET", "/admin/jobs?status=pending", undefined, ADMIN);
  assert.equal(list.status, 200); assert.equal(list.body.items[0].contact.email, "asha@acme.test");
  assert.equal((await call("PATCH", `/admin/jobs/${pendingId}`, { status: "approved" }, ADMIN)).status, 200);
  const pub = await call("GET", "/jobs");
  assert.equal(pub.body.total, 1);
  const j = pub.body.items[0];
  assert.deepEqual(j.skills, ["Bloc", "Dart", "Firebase", "Flutter"]);
  assert.ok(j.expiresAt, "approval sets an expiry");
  const d = await call("GET", `/jobs/${pendingId}`);
  assert.equal(d.status, 200); assert.equal(d.body.status, "open"); assert.equal(d.body.apply.url, "https://acme.test/careers/flutter");
  const raw = JSON.stringify(pub.body) + JSON.stringify(d.body);
  for (const secret of ["asha@acme.test", "Asha", "emp1", "contact"]) assert.ok(!raw.includes(secret), `public output leaks ${secret}`);
});

test("admin posts go live immediately; featured jobs sort first; search and filters work", async () => {
  const a = await call("POST", "/admin/jobs", goodJob({ companyName: "Bytewave", title: "Flutter Intern", jobType: "internship", workMode: "remote", level: "fresher", city: "", salaryMin: 10000, salaryMax: 15000, skills: ["Flutter", "Provider"], applyUrl: "", applyEmail: "jobs@bytewave.test" }), ADMIN);
  assert.equal(a.status, 201);
  await call("PATCH", `/admin/jobs/${a.body.id}`, { featured: true }, ADMIN);
  const all = await call("GET", "/jobs");
  assert.equal(all.body.total, 2); assert.equal(all.body.items[0].id, a.body.id, "featured first");
  assert.equal((await call("GET", "/jobs?type=internship")).body.total, 1);
  assert.equal((await call("GET", "/jobs?mode=remote")).body.total, 1);
  assert.equal((await call("GET", "/jobs?level=junior")).body.total, 1);
  assert.equal((await call("GET", "/jobs?city=kolkata")).body.total, 1, "city match is case-insensitive");
  assert.equal((await call("GET", "/jobs?skill=Provider")).body.total, 1);
  assert.equal((await call("GET", "/jobs?q=intern")).body.total, 1, "full-text prefix search");
  assert.equal((await call("GET", "/jobs?q=bytewave")).body.total, 1, "company name search");
  assert.equal((await call("GET", "/jobs?q=provider")).body.total, 1, "skill search");
  assert.equal((await call("GET", "/jobs?q=bloc")).body.total, 2, "matches descriptions too");
  assert.equal((await call("GET", "/jobs?q=%25")).status, 200, "wildcards are escaped");
  assert.equal((await call("GET", "/jobs?q=ui")).status, 200, "short words fall back to LIKE");
  assert.equal((await call("GET", "/jobs?type=bogus")).status, 400);
  const meta = await call("GET", "/meta");
  assert.equal(meta.body.liveJobs, 2); assert.deepEqual(meta.body.cities, ["Kolkata"]);
});

test("rejection reason is shown to the employer", async () => {
  const r = await call("POST", "/jobs", goodJob({ title: "Senior Flutter Engineer", level: "senior" }), EMP);
  await call("PATCH", `/admin/jobs/${r.body.id}`, { status: "rejected", rejectReason: "Please add a salary range" }, ADMIN);
  const mine = await call("GET", "/my/jobs", undefined, EMP);
  const job = mine.body.items.find((x: any) => x.id === r.body.id);
  assert.equal(job.status, "rejected"); assert.equal(job.rejectReason, "Please add a salary range");
});

test("reports: one per person, three different people send the job back to review", async () => {
  const id = pendingId;
  assert.equal((await call("POST", `/jobs/${id}/report`, { reason: "asks_fees" }, undefined, "1.1.1.1")).status, 201);
  await call("POST", `/jobs/${id}/report`, { reason: "asks_fees" }, undefined, "1.1.1.1");   // duplicate ignored
  assert.equal((await call("GET", `/jobs/${id}`)).body.status, "open");
  await call("POST", `/jobs/${id}/report`, { reason: "scam", details: "asked for money" }, undefined, "2.2.2.2");
  await call("POST", `/jobs/${id}/report`, { reason: "fake" }, undefined, "3.3.3.3");
  assert.equal((await call("GET", `/jobs/${id}`)).status, 404, "hidden after 3 reports");
  const reps = await call("GET", "/admin/reports", undefined, ADMIN);
  assert.equal(reps.body.items.length, 3);
  await call("PATCH", `/admin/jobs/${id}`, { status: "approved" }, ADMIN);
  assert.equal((await call("GET", "/admin/reports", undefined, ADMIN)).body.items.length, 0, "re-approving closes reports");
  assert.equal((await call("POST", `/jobs/${id}/report`, { reason: "nonsense" })).status, 400);
});

test("expired jobs close automatically and hide the apply link", async () => {
  await pool.query("UPDATE jobs SET expires_at = UTC_TIMESTAMP() - INTERVAL 1 DAY WHERE public_id = ?", [pendingId]);
  assert.equal((await call("GET", "/jobs")).body.total, 1);
  const d = await call("GET", `/jobs/${pendingId}`);
  assert.equal(d.body.status, "closed"); assert.equal(d.body.apply.url, null);
  const stats = await call("GET", "/admin/stats", undefined, ADMIN);
  assert.equal(stats.body.jobs.expired, 1);
  await call("PATCH", `/admin/jobs/${pendingId}`, { extendDays: 15 }, ADMIN);
  assert.equal((await call("GET", `/jobs/${pendingId}`)).body.status, "open", "extending reopens it");
});

test("admin can edit a job fully", async () => {
  const r = await call("PUT", `/admin/jobs/${pendingId}`, goodJob({ title: "Flutter Developer (Bloc)", skills: ["Flutter", "Riverpod"] }), ADMIN);
  assert.equal(r.status, 200);
  const d = await call("GET", `/jobs/${pendingId}`);
  assert.equal(d.body.title, "Flutter Developer (Bloc)"); assert.deepEqual(d.body.skills, ["Flutter", "Riverpod"]);
});

const profile = (over: Record<string, unknown> = {}) => ({
  fullName: "Riya Sen", phone: "+91 98765 43210", headline: "Flutter Developer · 3 years", currentCompany: "Acme Apps",
  experienceYears: 3, city: "Kolkata", workModes: ["remote", "hybrid"], jobTypes: ["full_time"], noticePeriod: "30_days",
  expectedSalaryLpa: 9.5, githubUrl: "https://github.com/riya", linkedinUrl: "", portfolioUrl: "",
  apps: [{ name: "ShopEasy", url: "https://play.google.com/store/apps/details?id=x", role: "Lead dev" }],
  about: "I build Flutter apps.", skills: ["flutter", "Bloc", "Firebase"], openToWork: true, hiddenCompanies: "Acme Apps", consent: true, ...over,
});

test("talent profile: consent required, create, update, private to owner", async () => {
  assert.equal((await call("PUT", "/talent/me", profile())).status, 401);
  assert.equal((await call("PUT", "/talent/me", profile({ consent: false }), SEEK)).status, 400);
  assert.equal((await call("PUT", "/talent/me", profile({ skills: [] }), SEEK)).status, 400);
  assert.equal((await call("GET", "/talent/me", undefined, SEEK)).body.profile, null);
  const c = await call("PUT", "/talent/me", profile(), SEEK);
  assert.equal(c.status, 200);
  assert.equal(c.body.profile.email, "riya@test.dev", "email comes from the login, not the form");
  assert.equal(c.body.profile.phone, "+919876543210");
  assert.deepEqual(c.body.profile.skills, ["Bloc", "Firebase", "Flutter"]);
  assert.equal(c.body.profile.verification, "self");
  const u = await call("PUT", "/talent/me", profile({ headline: "Senior Flutter Developer", openToWork: false }), SEEK);
  assert.equal(u.body.profile.headline, "Senior Flutter Developer"); assert.equal(u.body.profile.openToWork, false);
  assert.equal(u.body.profile.id, c.body.profile.id, "same profile updated");
  assert.equal((await call("GET", "/talent/me", undefined, EMP)).body.profile, null, "others can't see it");
  assert.equal((await call("GET", "/admin/candidates", undefined, EMP)).status, 403);
});

test("admin verifies a candidate; candidate can delete everything", async () => {
  const list = await call("GET", "/admin/candidates", undefined, ADMIN);
  assert.equal(list.body.items.length, 1);
  const id = list.body.items[0].id;
  assert.equal((await call("PATCH", `/admin/candidates/${id}`, { verification: "verified", verifiedNote: "30-min call, strong Bloc" }, ADMIN)).status, 200);
  assert.equal((await call("GET", "/talent/me", undefined, SEEK)).body.profile.verification, "verified");
  assert.equal((await call("GET", "/admin/candidates?verification=verified", undefined, ADMIN)).body.items.length, 1);
  assert.equal((await call("DELETE", "/talent/me", undefined, SEEK)).status, 200);
  assert.equal((await call("GET", "/talent/me", undefined, SEEK)).body.profile, null);
  const [rows] = await pool.query("SELECT COUNT(*) AS n FROM candidate_skills");
  assert.equal((rows as any)[0].n, 0, "skills deleted too");
});

test("employers are rate limited", async () => {
  const tok = "dev:spammer:s@spam.test:S";
  let last = 0;
  for (let i = 0; i < 6; i++) last = (await call("POST", "/jobs", goodJob({ title: "Flutter Dev " + i }), tok)).status;
  assert.equal(last, 429);
});

test("unknown routes and bad JSON return clean errors", async () => {
  assert.equal((await call("GET", "/nope")).status, 404);
  const r = await fetch(base + "/jobs", { method: "POST", headers: { "content-type": "application/json", authorization: "Bearer " + EMP2 }, body: "{bad" });
  assert.equal(r.status, 400);
});
