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

test("CORS: academy website allowed, other sites refused", async () => {
  const ok = await fetch(base + "/jobs", { method: "OPTIONS", headers: { origin: "https://widgetryacademy.in", "access-control-request-method": "POST", "access-control-request-headers": "authorization, content-type" } });
  assert.equal(ok.status, 204);
  assert.equal(ok.headers.get("access-control-allow-origin"), "https://widgetryacademy.in");
  const get = await fetch(base + "/meta", { headers: { origin: "https://widgetry-academy.web.app" } });
  assert.equal(get.headers.get("access-control-allow-origin"), "https://widgetry-academy.web.app");
  const bad = await fetch(base + "/jobs", { method: "OPTIONS", headers: { origin: "https://evil.test", "access-control-request-method": "POST" } });
  assert.equal(bad.status, 403);
  assert.equal(bad.headers.get("access-control-allow-origin"), null);
});

test("resume: work history and education are saved and validated", async () => {
  const tok = "dev:seek7:asha@test.dev:Asha";
  const base = { fullName: "Asha Roy", headline: "Flutter Developer", experienceYears: 2, skills: ["Flutter"], consent: true };
  const bad = await call("PUT", "/talent/me", { ...base, experience: [{ company: "X", role: "Dev", start: "2024-05", end: "2023-01" }] }, tok);
  assert.equal(bad.status, 400);
  const r = await call("PUT", "/talent/me", { ...base,
    experience: [{ company: "Nimbus Labs", role: "Flutter Developer", start: "2023-06", end: "", points: "Built the delivery app\nCut crashes by 40%" }],
    education: [{ degree: "MCA", institute: "Techno India", year: 2022, score: "8.1 CGPA" }],
    certifications: [{ name: "Flutter in 10 Days", issuer: "Widgetry Academy", year: 2026 }],
    apps: [{ name: "QuickBite", url: "https://play.google.com/store/apps/details?id=q", role: "Lead", about: "Food delivery app with live tracking" }] }, tok);
  assert.equal(r.status, 200);
  assert.equal(r.body.profile.experience[0].end, null);
  assert.equal(r.body.profile.experience[0].points, "Built the delivery app\nCut crashes by 40%");
  assert.equal(r.body.profile.education[0].year, 2022);
  assert.equal(r.body.profile.certifications[0].issuer, "Widgetry Academy");
  assert.equal(r.body.profile.apps[0].about, "Food delivery app with live tracking");
});

test("employers can edit, mark filled and delete only their own jobs", async () => {
  const own = "dev:emp7:hr@own.test:Own", other = "dev:emp8:hr@other.test:Other";
  const p = await call("POST", "/jobs", goodJob({ title: "Flutter Engineer (Maps)" }), own);
  assert.equal(p.status, 201);
  const id = p.body.id;
  await call("PATCH", "/admin/jobs/" + id, { status: "approved" }, ADMIN);
  assert.equal((await call("GET", "/my/jobs/" + id, undefined, other)).status, 404);
  assert.equal((await call("PUT", "/my/jobs/" + id, goodJob(), other)).status, 404);
  assert.equal((await call("DELETE", "/my/jobs/" + id, undefined, other)).status, 404);
  const g = await call("GET", "/my/jobs/" + id, undefined, own);
  assert.equal(g.body.form.title, "Flutter Engineer (Maps)");
  const e = await call("PUT", "/my/jobs/" + id, { ...g.body.form, title: "Senior Flutter Engineer (Maps)", agree: true }, own);
  assert.equal(e.status, 200);
  assert.equal(e.body.status, "pending", "edits go back to review");
  assert.equal((await call("GET", "/jobs/" + id)).status, 404, "not public while in review");
  await call("PATCH", "/admin/jobs/" + id, { status: "approved" }, ADMIN);
  assert.equal((await call("PATCH", "/my/jobs/" + id, { status: "approved" }, own)).status, 400, "employer can't self-approve");
  assert.equal((await call("PATCH", "/my/jobs/" + id, { status: "filled" }, own)).body.status, "filled");
  assert.equal((await call("GET", "/jobs/" + id)).body.status, "filled");
  assert.equal((await call("PUT", "/my/jobs/" + id, { ...g.body.form, agree: true }, own)).status, 409);
  assert.equal((await call("DELETE", "/my/jobs/" + id, undefined, own)).status, 200);
  assert.equal((await call("GET", "/my/jobs/" + id, undefined, own)).status, 404);
});

test("profile photo, resume settings and open-to-work toggle", async () => {
  const tok = "dev:seek9:meera@test.dev:Meera";
  const PNG = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
  assert.equal((await call("PUT", "/talent/me/photo", { dataUrl: PNG }, tok)).status, 404, "needs a profile first");
  await call("PUT", "/talent/me", { fullName: "Meera Iyer", headline: "Flutter Developer", experienceYears: 1, skills: ["Flutter"], consent: true }, tok);
  const fake = "data:image/png;base64," + Buffer.from("<script>alert(1)</script>").toString("base64");
  assert.equal((await call("PUT", "/talent/me/photo", { dataUrl: fake }, tok)).status, 400, "content must really be an image");
  assert.equal((await call("PUT", "/talent/me/photo", { dataUrl: "data:image/svg+xml;base64,PHN2Zz4=" }, tok)).status, 400, "no SVG");
  const big = "data:image/jpeg;base64," + Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(260 * 1024)]).toString("base64");
  assert.equal((await call("PUT", "/talent/me/photo", { dataUrl: big }, tok)).status, 400, "too large");
  const ok = await call("PUT", "/talent/me/photo", { dataUrl: PNG }, tok);
  assert.equal(ok.status, 200);
  assert.equal((await call("GET", "/talent/me", undefined, tok)).body.profile.photo, PNG);

  assert.equal((await call("PUT", "/talent/me/resume-settings", { template: "fancy" }, tok)).status, 400);
  const rs = await call("PUT", "/talent/me/resume-settings", { template: "classic", accent: "navy", title: "Senior Flutter Engineer", showPhoto: true, hide: ["phone"] }, tok);
  assert.equal(rs.status, 200);
  const me = (await call("GET", "/talent/me", undefined, tok)).body.profile;
  assert.equal(me.resumeSettings.template, "classic");
  assert.deepEqual(me.resumeSettings.hide, ["phone"]);

  assert.equal((await call("PATCH", "/talent/me", { openToWork: false }, tok)).body.openToWork, false);
  assert.equal((await call("GET", "/talent/me", undefined, tok)).body.profile.openToWork, false);

  // A full profile save keeps the photo and settings
  await call("PUT", "/talent/me", { fullName: "Meera Iyer", headline: "Flutter Developer · 1 year", experienceYears: 1, skills: ["Flutter"], consent: true }, tok);
  const after = (await call("GET", "/talent/me", undefined, tok)).body.profile;
  assert.equal(after.photo, PNG); assert.equal(after.resumeSettings.accent, "navy");

  assert.equal((await call("DELETE", "/talent/me/photo", undefined, tok)).status, 200);
  assert.equal((await call("GET", "/talent/me", undefined, tok)).body.profile.photo, null);
  await call("PUT", "/talent/me/photo", { dataUrl: PNG }, tok);
  await call("DELETE", "/talent/me", undefined, tok);
  const [{ n }] = await pool.query("SELECT COUNT(*) AS n FROM candidate_photos").then(([r]) => r as any[]);
  assert.equal(Number(n), 0, "deleting the profile deletes the photo");
});

test("admin bulk import: checks everything first, skips duplicates, posts live", async () => {
  const desc = "Build consumer features in Flutter with Bloc and REST APIs, improve architecture, fix performance issues and mentor juniors.";
  const a = { companyName: "Bulk Co", title: "Flutter Engineer", jobType: "full_time", workMode: "onsite", level: "mid", city: "Pune", description: desc, skills: "Flutter, Dart, bloc", applyUrl: "https://bulk.test/careers/flutter" };
  const b = { ...a, title: "Flutter Intern", jobType: "internship", level: "fresher", applyUrl: "https://bulk.test/careers/intern" };
  const bad = { ...a, title: "Broken", applyUrl: "javascript:alert(1)" };
  assert.equal((await call("POST", "/admin/jobs/import", { jobs: [a] }, EMP)).status, 403);
  const check = await call("POST", "/admin/jobs/import", { jobs: [a, b, bad], dryRun: true }, ADMIN);
  assert.equal(check.status, 200);
  assert.deepEqual(check.body.report.map((r: any) => r.status), ["ok", "ok", "invalid"]);
  const refused = await call("POST", "/admin/jobs/import", { jobs: [a, b, bad] }, ADMIN);
  assert.equal(refused.status, 400); assert.equal(refused.body.created, 0);
  const ok = await call("POST", "/admin/jobs/import", { jobs: [a, b, a] }, ADMIN);
  assert.equal(ok.status, 201); assert.equal(ok.body.created, 2);
  assert.equal(ok.body.report[2].status, "duplicate");
  const job = (await call("GET", "/jobs/" + ok.body.ids[0])).body;
  assert.equal(job.status, "open"); assert.deepEqual(job.skills, ["Bloc", "Dart", "Flutter"]);
  const again = await call("POST", "/admin/jobs/import", { jobs: [a] }, ADMIN);
  assert.equal(again.body.created, 0); assert.equal(again.body.report[0].status, "duplicate");
});
