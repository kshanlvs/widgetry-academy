// End-to-end API tests against a real MySQL database.
// Run: DB_PORT=3307 DB_PASSWORD=devpass ALLOW_DEV_AUTH=1 npm test
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";
import { setIndexer } from "../src/indexing.js";
import { createApp } from "../src/app.js";
import { pool } from "../src/db.js";
import { migrate } from "../src/migrate.js";
import { setSender } from "../src/notify.js";
import { createHmac } from "node:crypto";
import { setPaymentServices, type Registration } from "../src/payments.js";
import { setPlayApi, playAccountId, reportPendingExternal } from "../src/play.js";
import { setAccountServices } from "../src/routes/account.js";
import { setUserLookup, sendReminders } from "../src/mock.js";
import { setMentorStore } from "../src/routes/mentors.js";
import { setOverviewSources, istDay } from "../src/routes/overview.js";

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
  for (const t of ["mock_scorecards", "mock_bookings", "interview_slots", "interviewers"]) await pool.query(`DELETE FROM ${t}`);
  await pool.query("DELETE FROM workshop_enrollments");
  await pool.query("DELETE FROM workshops WHERE slug <> 'bloc-crash-course'");
  await pool.query("DELETE FROM chat_messages"); await pool.query("DELETE FROM chat_conversations");
  await pool.query("DELETE FROM resume_premium"); await pool.query("DELETE FROM resume_ai_usage");
  await pool.query("UPDATE workshops SET status = 'draft', starts_at = NULL, price = 99900, early_price = 79900, early_seats = 15, early_until = NULL, seats = 40, meeting_link = NULL, brochure = 'brochures/bloc-crash-course.pdf' WHERE slug = 'bloc-crash-course'");
  server = createApp().listen(0);
  await new Promise(r => server.once("listening", r));
  base = `http://127.0.0.1:${(server.address() as any).port}/api`;
});
after(async () => { server.close(); await pool.end(); await (await import("../src/resumeDoc.js")).closePdfBrowser(); });

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
  assert.equal((await call("GET", "/jobs?city=Calcutta")).body.total, 1, "a city's other name finds it");
  assert.equal((await call("GET", "/jobs?city=Pune")).body.total, 0, "other cities don't match");
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

test("resume without joining the Talent Network; joining is a separate opt-in", async () => {
  const tok = "dev:resume-only:ravi@test.dev";
  const base = { fullName: "Ravi Das", headline: "Flutter Developer", experienceYears: 1, skills: ["Flutter"] };
  const r = await call("PUT", "/talent/me", base, tok);
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(r.body.profile.talentNetwork, false); assert.match(r.body.message, /resume is saved/);
  assert.equal((await call("GET", "/admin/candidates", undefined, ADMIN)).body.items.some((c: any) => c.fullName === "Ravi Das"), false, "not offered to employers");
  assert.equal((await call("GET", "/admin/candidates?network=no", undefined, ADMIN)).body.items.length, 1);
  // Saving again without saying keeps the choice; the profile page can switch it on
  assert.equal((await call("PUT", "/talent/me", { ...base, headline: "Flutter Dev" }, tok)).body.profile.talentNetwork, false);
  assert.equal((await call("PATCH", "/talent/me", { talentNetwork: true }, tok)).body.talentNetwork, true);
  assert.equal((await call("GET", "/talent/me", undefined, tok)).body.profile.talentNetwork, true);
  assert.equal((await call("PUT", "/talent/me", { ...base, talentNetwork: false }, tok)).body.profile.talentNetwork, false);
  assert.equal((await call("DELETE", "/talent/me", undefined, tok)).status, 200);
});

test("talent profile: create, update, private to owner", async () => {
  assert.equal((await call("PUT", "/talent/me", profile())).status, 401);
  assert.equal((await call("PUT", "/talent/me", profile({ skills: [] }), SEEK)).status, 400);
  assert.equal((await call("GET", "/talent/me", undefined, SEEK)).body.profile, null);
  const c = await call("PUT", "/talent/me", profile(), SEEK);
  assert.equal(c.status, 200);
  assert.equal(c.body.profile.email, "riya@test.dev", "email comes from the login, not the form");
  assert.equal(c.body.profile.phone, "+919876543210");
  assert.deepEqual(c.body.profile.skills, ["Bloc", "Firebase", "Flutter"]);
  assert.equal(c.body.profile.verification, "self");
  assert.equal(c.body.profile.talentNetwork, true, "consent: true from older apps still means joining");
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

test("categories: Flutter, Android, iOS and React Native jobs and seekers", async () => {
  const meta = (await call("GET", "/meta")).body;
  assert.deepEqual(meta.categories.map((c: any) => c.slug), ["flutter", "android", "ios", "react-native"]);
  assert.ok(meta.categories[3].suggestedSkills.includes("Expo"));
  assert.ok(meta.categories[1].suggestedSkills.includes("Jetpack Compose"));
  const desc = "Build our Android app in Kotlin with Jetpack Compose, coroutines and MVVM. Work with design and backend teams and ship every sprint.";
  const android = { category: "android", companyName: "Droid Co", title: "Android Developer", jobType: "full_time", workMode: "remote", level: "mid", description: desc, skills: ["kotlin", "jetpack compose"], applyUrl: "https://droid.test/careers/android" };
  assert.equal((await call("POST", "/admin/jobs", { ...android, category: "xamarin" }, ADMIN)).status, 400, "unknown category refused");
  const rn = await call("POST", "/admin/jobs", { ...android, category: "react-native", title: "React Native Developer", skills: ["react native", "typescript"], applyUrl: "https://droid.test/careers/rn" }, ADMIN);
  assert.equal(rn.status, 201, "React Native jobs accepted");
  assert.deepEqual((await call("GET", "/jobs?category=react-native")).body.items.map((j: any) => j.title), ["React Native Developer"]);
  const a = await call("POST", "/admin/jobs", android, ADMIN);
  assert.equal(a.status, 201);
  const ios = await call("POST", "/admin/jobs", { ...android, category: "ios", title: "iOS Developer", skills: ["swift", "swiftui"], applyUrl: "https://droid.test/careers/ios" }, ADMIN);
  const fl = (await call("GET", "/jobs?category=flutter")).body.items;
  assert.ok(fl.length > 0 && fl.every((j: any) => j.category === "flutter"), "old jobs default to flutter");
  const an = (await call("GET", "/jobs?category=android")).body.items;
  assert.deepEqual(an.map((j: any) => j.title), ["Android Developer"]);
  assert.deepEqual(an[0].skills, ["Jetpack Compose", "Kotlin"]);
  assert.equal((await call("GET", "/jobs/" + ios.body.id)).body.category, "ios");
  const m2 = (await call("GET", "/meta")).body.categories;
  assert.equal(m2.find((c: any) => c.slug === "android").liveJobs, 1);
  // bulk import reports unknown categories
  const rep = await call("POST", "/admin/jobs/import", { jobs: [{ ...android, category: "kmp", title: "KMP dev", applyUrl: "https://droid.test/kmp" }], dryRun: true }, ADMIN);
  assert.equal(rep.body.report[0].status, "invalid");
  // seekers choose role types
  const tok = "dev:seekcat:cat@test.dev:Cat";
  assert.equal((await call("PUT", "/talent/me", { fullName: "Cat Roy", headline: "Android Developer", experienceYears: 2, skills: ["Kotlin"], categories: ["android", "nope"], consent: true }, tok)).status, 400);
  const s = await call("PUT", "/talent/me", { fullName: "Cat Roy", headline: "Android Developer", experienceYears: 2, skills: ["Kotlin"], categories: ["android", "flutter"], consent: true }, tok);
  assert.deepEqual(s.body.profile.categories, ["flutter", "android"]);
  const list = (await call("GET", "/admin/candidates?category=android", undefined, ADMIN)).body.items;
  assert.ok(list.some((c: any) => c.fullName === "Cat Roy"));
});

test("push: devices, new-job topic, employer and verification messages, admin announcements", async () => {
  const sent: { to: string; title: string; body: string; link?: string }[] = [];
  setSender({
    async topic(topic, p) { sent.push({ to: "topic:" + topic, title: p.title, body: p.body, link: p.link }); },
    async tokens(tokens, p) { for (const t of tokens) sent.push({ to: "token:" + t, title: p.title, body: p.body }); return tokens.filter(t => t.startsWith("dead")); },
  });
  const wait = () => new Promise(r => setTimeout(r, 150));
  const emp = "dev:pushemp:hr@push.test:Push HR", seek = "dev:pushseek:s@push.test:Seeker";
  const tokA = "a".repeat(40), tokDead = "dead" + "x".repeat(40);
  assert.equal((await call("POST", "/me/devices", { token: tokA, platform: "android" })).status, 401);
  assert.equal((await call("POST", "/me/devices", { token: "short" }, emp)).status, 400);
  assert.equal((await call("POST", "/me/devices", { token: tokA, platform: "android" }, emp)).status, 201);
  assert.equal((await call("POST", "/me/devices", { token: tokDead, platform: "ios" }, emp)).status, 201);

  // Employer job approved: category topic + employer's phones; the dead token is cleaned up
  const j = await call("POST", "/jobs", goodJob({ title: "Push Flutter Dev", applyUrl: "https://push.test/careers/1" }), emp);
  await call("PATCH", "/admin/jobs/" + j.body.id, { status: "approved" }, ADMIN); await wait();
  assert.ok(sent.some(m => m.to === "topic:jobs-flutter" && m.body === "Push Flutter Dev at Acme Apps"), JSON.stringify(sent));
  assert.ok(sent.some(m => m.to === "token:" + tokA && m.title.startsWith("Your job is live")));
  const [{ n }] = await pool.query("SELECT COUNT(*) AS n FROM device_tokens WHERE token = ?", [tokDead]).then(([r]) => r as any[]);
  assert.equal(Number(n), 0, "invalid tokens removed");
  // Re-approving doesn't announce again
  sent.length = 0;
  await call("PATCH", "/admin/jobs/" + j.body.id, { status: "pending" }, ADMIN);
  await call("PATCH", "/admin/jobs/" + j.body.id, { status: "approved" }, ADMIN); await wait();
  assert.ok(!sent.some(m => m.to.startsWith("topic:")));

  // Bulk import: one message per category
  sent.length = 0;
  const desc = "Build features in Kotlin with Jetpack Compose and coroutines for our Android app, and ship to the Play Store every sprint.";
  const base = { category: "android", companyName: "Push Droid", jobType: "full_time", workMode: "remote", level: "mid", description: desc };
  await call("POST", "/admin/jobs/import", { jobs: [{ ...base, title: "Android A", applyUrl: "https://pd.test/a" }, { ...base, title: "Android B", applyUrl: "https://pd.test/b" }] }, ADMIN); await wait();
  const topicMsgs = sent.filter(m => m.to === "topic:jobs-android");
  assert.equal(topicMsgs.length, 1); assert.equal(topicMsgs[0]!.title, "2 new Android jobs");

  // Verification change reaches the seeker
  sent.length = 0;
  await call("PUT", "/talent/me", { fullName: "Push Seeker", headline: "Flutter Developer", experienceYears: 1, skills: ["Flutter"], consent: true }, seek);
  await call("POST", "/me/devices", { token: "s".repeat(40), platform: "android" }, seek);
  const cid = (await call("GET", "/talent/me", undefined, seek)).body.profile.id;
  await call("PATCH", "/admin/candidates/" + cid, { verification: "verified" }, ADMIN); await wait();
  assert.ok(sent.some(m => m.to === "token:" + "s".repeat(40) && m.title.includes("verified")));

  // Admin announcements
  assert.equal((await call("POST", "/admin/notify", { audience: "academy", title: "Batch 2", body: "Starts Saturday" }, EMP)).status, 403);
  assert.equal((await call("POST", "/admin/notify", { audience: "nobody", title: "Hi there", body: "Test" }, ADMIN)).status, 400);
  assert.equal((await call("POST", "/admin/notify", { audience: "academy", title: "Batch 2 starts", body: "Saturday 11 AM, see you there" }, ADMIN)).status, 200);
  assert.ok(sent.some(m => m.to === "topic:academy"));
  setSender(null);
});

test("course payments: plans from the server, order, signature check, idempotent fulfil, balance, webhook", async () => {
  process.env.RAZORPAY_KEY_ID = "rzp_test_abc"; process.env.RAZORPAY_KEY_SECRET = "test_secret"; process.env.RAZORPAY_WEBHOOK_SECRET = "hook_secret";
  await pool.query("DELETE FROM payments");
  // Fakes for Razorpay and the Firestore registration
  const regs = new Map<string, Registration>();
  const payments = new Map<string, { id: string; order_id: string; amount: number; status: string }>();
  let n = 0;
  let earlyBird = true;
  setPaymentServices(
    {
      async createOrder(o) { n++; return { id: "order_T" + n, amount: o.amount, currency: "INR" }; },
      async fetchPayment(id) { const p = payments.get(id); if (!p) throw new Error("no payment"); return p; },
      async orderPayments(orderId) { return [...payments.values()].filter(p => p.order_id === orderId); },
    },
    {
      async get(uid) { return regs.get(uid) ?? null; },
      async addPayment(uid, p) {
        const r = regs.get(uid)!; const plan = p.plan === "balance" ? (r.plan || "booking") : p.plan;
        r.plan = plan; r.amountPaid = (r.amountPaid ?? 0) + p.amount; r.payStatus = r.amountPaid >= (plan === "early-bird" ? 3499 : 4999) ? "paid" : "part-paid";
        return r.payStatus;
      },
      async earlyBirdOpen() { return earlyBird; },
    });
  const STU = "dev:stu1:stu@test.dev:Stu", OTHER = "dev:stu2:other@test.dev:Other";
  const sign = (o: string, p: string) => createHmac("sha256", "test_secret").update(`${o}|${p}`).digest("hex");

  // Not registered yet: nothing to pay, and no order
  let r = await call("GET", "/payments/plans", undefined, STU);
  assert.equal(r.body.status, "unregistered"); assert.deepEqual(r.body.plans, []);
  assert.equal((await call("POST", "/payments/order", { plan: "regular" }, STU)).status, 409);
  assert.equal((await call("GET", "/payments/plans")).status, 401);

  regs.set("stu1", { name: "Stu", email: "stu@test.dev", phone: "+919876543210", payStatus: "pending", amountPaid: 0, plan: null });
  r = await call("GET", "/payments/plans", undefined, STU);
  assert.deepEqual(r.body.plans.map((p: any) => [p.id, p.amount]), [["early-bird", 3499], ["regular", 4999], ["booking", 2500]]);
  earlyBird = false;
  r = await call("GET", "/payments/plans", undefined, STU);
  assert.deepEqual(r.body.plans.map((p: any) => p.id), ["regular", "booking"], "early bird hidden when seats run out");
  assert.equal((await call("POST", "/payments/order", { plan: "early-bird" }, STU)).status, 400, "can't buy a plan that isn't offered");
  earlyBird = true;

  // Book with a part payment: the server decides the amount
  r = await call("POST", "/payments/order", { plan: "booking" }, STU);
  assert.equal(r.status, 201); assert.equal(r.body.amount, 250000); assert.equal(r.body.keyId, "rzp_test_abc");
  assert.equal(r.body.prefill.contact, "+919876543210");
  const order1 = r.body.orderId;
  payments.set("pay_A1", { id: "pay_A1", order_id: order1, amount: 250000, status: "captured" });

  // Forged or mismatched confirmations are refused
  assert.equal((await call("POST", "/payments/verify", { orderId: order1, paymentId: "pay_A1", signature: "0".repeat(64) }, STU)).status, 400);
  assert.equal((await call("POST", "/payments/verify", { orderId: order1, paymentId: "pay_A1", signature: sign(order1, "pay_A1") }, OTHER)).status, 404, "someone else's order");
  payments.set("pay_LOW", { id: "pay_LOW", order_id: order1, amount: 100, status: "captured" });
  assert.equal((await call("POST", "/payments/verify", { orderId: order1, paymentId: "pay_LOW", signature: sign(order1, "pay_LOW") }, STU)).status, 400, "amount must match");
  assert.equal(regs.get("stu1")!.amountPaid, 0);

  r = await call("POST", "/payments/verify", { orderId: order1, paymentId: "pay_A1", signature: sign(order1, "pay_A1") }, STU);
  assert.equal(r.status, 200); assert.equal(r.body.status, "part-paid");
  assert.deepEqual([regs.get("stu1")!.plan, regs.get("stu1")!.amountPaid], ["booking", 2500]);
  // Confirming twice (app retry, or the webhook too) doesn't count the money twice
  r = await call("POST", "/payments/verify", { orderId: order1, paymentId: "pay_A1", signature: sign(order1, "pay_A1") }, STU);
  assert.equal(r.status, 200); assert.equal(regs.get("stu1")!.amountPaid, 2500);

  // Now only the balance can be paid
  r = await call("GET", "/payments/plans", undefined, STU);
  assert.equal(r.body.status, "part-paid"); assert.deepEqual(r.body.plans.map((p: any) => [p.id, p.amount]), [["balance", 2499]]);
  assert.equal((await call("POST", "/payments/order", { plan: "regular" }, STU)).status, 400);
  r = await call("POST", "/payments/order", { plan: "balance" }, STU);
  const order2 = r.body.orderId; assert.equal(r.body.amount, 249900);

  // The webhook confirms it even if the app closed: bad signature first, then a real one
  const event = JSON.stringify({ event: "payment.captured", payload: { payment: { entity: { id: "pay_B2", order_id: order2, amount: 249900, status: "captured", method: "upi" } } } });
  const hook = (body: string, sig: string) => fetch(base + "/payments/webhook", { method: "POST", headers: { "content-type": "application/json", "x-razorpay-signature": sig }, body });
  assert.equal((await hook(event, "bad")).status, 400);
  assert.equal((await hook(event, createHmac("sha256", "hook_secret").update(event).digest("hex"))).status, 200);
  assert.deepEqual([regs.get("stu1")!.payStatus, regs.get("stu1")!.amountPaid], ["paid", 4999]);
  const [row] = await pool.query("SELECT status, method FROM payments WHERE order_id = ?", [order2]) as any;
  assert.deepEqual([row[0].status, row[0].method], ["paid", "upi"]);

  // Paid in full: nothing more to pay; the student sees their receipts
  r = await call("GET", "/payments/plans", undefined, STU);
  assert.equal(r.body.status, "paid"); assert.deepEqual(r.body.plans, []);
  assert.equal((await call("POST", "/payments/order", { plan: "balance" }, STU)).status, 409);
  const mine = await call("GET", "/payments/mine", undefined, STU);
  assert.equal(mine.body.items.length, 2);
  assert.deepEqual(mine.body.summary, { status: "paid", plan: "booking", amountPaid: 4999, total: 4999, due: 0, name: "Stu", email: "stu@test.dev", phone: "+919876543210" });
  assert.deepEqual(mine.body.items.map((i: any) => [i.title, i.amount]).sort(), [["Balance payment", 2499], ["Booking (part payment)", 2500]]);

  // Everything bought, in one list: the course fee, a short course and a mock interview
  await pool.query("DELETE FROM workshop_enrollments WHERE uid = 'stu1'"); await pool.query("DELETE FROM mock_bookings WHERE uid = 'stu1'");
  const [[bloc]] = await pool.query("SELECT id, title FROM workshops WHERE slug = 'bloc-crash-course'") as any;
  await pool.query("INSERT INTO workshop_enrollments (workshop_id, uid, amount, early, status, order_id, payment_id, method, paid_at) VALUES (?, 'stu1', 79900, 1, 'confirmed', 'order_W_p1', 'pay_W_p1', 'upi', NOW() + INTERVAL 1 SECOND)", [bloc.id]);
  await pool.query(`INSERT INTO mock_bookings (uid, slot_id, interviewer_uid, starts_at, duration_min, track, level, format, amount, status, order_id, payment_id, method, paid_at)
                    VALUES ('stu1', 1, 'iv1', NOW() + INTERVAL 2 DAY, 45, 'flutter', 'mid', 'technical', 99900, 'refund_due', 'order_M_p1', 'pay_M_p1', 'card', NOW() + INTERVAL 2 SECOND)`);
  const all = await call("GET", "/me/purchases", undefined, STU);
  assert.equal(all.status, 200);
  assert.deepEqual(all.body.courses.map((c: any) => [c.slug, c.status]), [["flutter-in-10-days", "enrolled"], ["bloc-crash-course", "enrolled"]]);
  assert.equal(all.body.courses[1].title, bloc.title, "short course names come from the database");
  // Newest first (the two course fees were paid in the same second, so their order is not checked)
  assert.deepEqual(all.body.orders.slice(0, 2).map((o: any) => [o.kind, o.status, o.amount]), [["mock_interview", "refund_pending", 999], ["short_course", "paid", 799]]);
  assert.deepEqual(all.body.orders.slice(2).map((o: any) => [o.kind, o.status, o.amount]).sort(), [["course_fee", "paid", 2499], ["course_fee", "paid", 2500]]);
  assert.equal(all.body.orders[1].appPath, "/short-courses/bloc-crash-course");
  assert.deepEqual((await call("GET", "/me/purchases", undefined, OTHER)).body, { courses: [], orders: [] }, "only your own purchases");
  assert.equal((await call("GET", "/me/purchases")).status, 401);
  // /payments/mine stays the main course fee summary only (older apps label every item as that course)
  assert.deepEqual((await call("GET", "/payments/mine", undefined, STU)).body.items.map((i: any) => i.amount).sort(), [2499, 2500]);
  await pool.query("DELETE FROM workshop_enrollments WHERE uid = 'stu1'"); await pool.query("DELETE FROM mock_bookings WHERE uid = 'stu1'");

  // Recovery: the app closed after paying and the webhook never came. The next visit finds the payment, so nobody pays twice.
  const STU3 = "dev:stu3:three@test.dev:Three";
  regs.set("stu3", { name: "Three", payStatus: "pending", amountPaid: 0 });
  const o3 = (await call("POST", "/payments/order", { plan: "regular" }, STU3)).body.orderId;
  payments.set("pay_C3", { id: "pay_C3", order_id: o3, amount: 499900, status: "captured" });
  r = await call("GET", "/payments/plans", undefined, STU3);
  assert.equal(r.body.status, "paid", "unconfirmed payment recovered");
  assert.equal(regs.get("stu3")!.amountPaid, 4999);
  assert.equal((await call("POST", "/payments/order", { plan: "regular" }, STU3)).status, 409, "can't pay twice");
  // A failed attempt is not counted
  const STU4 = "dev:stu4:four@test.dev:Four";
  regs.set("stu4", { name: "Four", payStatus: "pending", amountPaid: 0 });
  const o4 = (await call("POST", "/payments/order", { plan: "booking" }, STU4)).body.orderId;
  payments.set("pay_D4", { id: "pay_D4", order_id: o4, amount: 250000, status: "failed" });
  assert.equal((await call("GET", "/payments/plans", undefined, STU4)).body.status, "unpaid");

  // Without Razorpay keys the app is told payments are opening soon
  delete process.env.RAZORPAY_KEY_SECRET;
  regs.set("stu2", { name: "Other", payStatus: "pending", amountPaid: 0 });
  assert.equal((await call("POST", "/payments/order", { plan: "regular" }, OTHER)).status, 503);
  assert.equal((await call("GET", "/payments/plans", undefined, OTHER)).body.enabled, false);
  setPaymentServices(null, null);
});

test("Google Play user choice: Play purchases verified and consumed; Razorpay choices reported to Google with state", async () => {
  process.env.RAZORPAY_KEY_ID = "rzp_test_abc"; process.env.RAZORPAY_KEY_SECRET = "test_secret"; process.env.RAZORPAY_WEBHOOK_SECRET = "hook_secret";
  const regs = new Map<string, Registration>();
  const rzpPayments = new Map<string, { id: string; order_id: string; amount: number; status: string; method?: string }>();
  let n = 100;
  setPaymentServices(
    {
      async createOrder(o) { n++; return { id: "order_P" + n, amount: o.amount, currency: "INR" }; },
      async fetchPayment(id) { return rzpPayments.get(id)!; },
      async orderPayments(orderId) { return [...rzpPayments.values()].filter(p => p.order_id === orderId); },
    },
    {
      async get(uid) { return regs.get(uid) ?? null; },
      async addPayment(uid, p) {
        const r = regs.get(uid)!; const plan = p.plan === "balance" ? (r.plan || "booking") : p.plan;
        r.plan = plan; r.amountPaid = (r.amountPaid ?? 0) + p.amount; r.payStatus = r.amountPaid >= 4999 ? "paid" : "part-paid";
        return r.payStatus;
      },
      async earlyBirdOpen() { return false; },
    });
  const purchases = new Map<string, any>(), consumed: string[] = [], reported: { id: string; body: any }[] = [];
  setPlayApi({
    async getPurchase(_productId, token) { const p = purchases.get(token); if (!p) throw new Error("not found"); return p; },
    async consume(_productId, token) { consumed.push(token); },
    async reportExternal(id, body) { reported.push({ id, body }); return true; },
  });
  const P1 = "dev:play1:p1@test.dev:P1", P2 = "dev:play2:p2@test.dev:P2";
  regs.set("play1", { name: "P1", payStatus: "pending", amountPaid: 0 });

  // Plans tell the app which Play product matches each plan, and the account id to pass to Google
  let r = await call("GET", "/payments/plans", undefined, P1);
  assert.deepEqual(r.body.plans.map((p: any) => p.playProductId), ["course_fee_full", "course_fee_booking"]);
  assert.equal(r.body.android.billing, "user_choice");
  assert.equal(r.body.android.accountId, playAccountId("play1"));
  assert.ok(r.body.android.states.includes("WEST BENGAL"));

  // Paying with Google Play
  purchases.set("tok-booking-123", { purchaseState: 0, consumptionState: 0, orderId: "GPA.1234-5678-9012-34567", obfuscatedExternalAccountId: playAccountId("play1") });
  assert.equal((await call("POST", "/payments/play/verify", { productId: "course_fee_booking", purchaseToken: "tok-booking-123" }, P2)).status, 403, "someone else's purchase");
  r = await call("POST", "/payments/play/verify", { productId: "course_fee_booking", purchaseToken: "tok-booking-123" }, P1);
  assert.equal(r.status, 200); assert.equal(r.body.status, "part-paid");
  assert.deepEqual([regs.get("play1")!.plan, regs.get("play1")!.amountPaid], ["booking", 2500]);
  assert.deepEqual(consumed, ["tok-booking-123"]);
  r = await call("POST", "/payments/play/verify", { productId: "course_fee_booking", purchaseToken: "tok-booking-123" }, P1);
  assert.equal(regs.get("play1")!.amountPaid, 2500, "verifying twice doesn't count twice");
  const mine = await call("GET", "/payments/mine", undefined, P1);
  assert.equal(mine.body.items[0].method, "google_play");

  // Pending (e.g. cash at a shop) isn't counted yet
  purchases.set("tok-pending-456", { purchaseState: 2, orderId: "GPA.2", obfuscatedExternalAccountId: playAccountId("play1") });
  assert.equal((await call("POST", "/payments/play/verify", { productId: "course_fee_balance", purchaseToken: "tok-pending-456" }, P1)).status, 202);

  // A balance adjusted by hand isn't Google Play's fixed price, so it's Razorpay-only
  regs.set("play3", { name: "P3", payStatus: "part-paid", plan: "booking", amountPaid: 2000 });
  r = await call("GET", "/payments/plans", undefined, "dev:play3:p3@test.dev:P3");
  assert.deepEqual(r.body.plans.map((p: any) => [p.id, p.amount, p.playProductId ?? null]), [["balance", 2999, null]]);
  r = await call("GET", "/payments/plans", undefined, P1);
  assert.deepEqual(r.body.plans.map((p: any) => [p.id, p.amount, p.playProductId]), [["balance", 2499, "course_fee_balance"]]);

  // Paying the balance with Razorpay chosen on Google's screen: state is required and the payment is reported
  assert.equal((await call("POST", "/payments/order", { plan: "balance", externalTransactionToken: "ext-token-abcdef" }, P1)).status, 400, "state needed");
  assert.equal((await call("POST", "/payments/order", { plan: "balance", externalTransactionToken: "ext-token-abcdef", state: "WESTBENGAL" }, P1)).status, 400, "only Google's state names");
  r = await call("POST", "/payments/order", { plan: "balance", externalTransactionToken: "ext-token-abcdef", state: "WEST BENGAL" }, P1);
  assert.equal(r.status, 201);
  const oid = r.body.orderId;
  rzpPayments.set("pay_Q1", { id: "pay_Q1", order_id: oid, amount: 249900, status: "captured", method: "upi" });
  r = await call("POST", "/payments/verify", { orderId: oid, paymentId: "pay_Q1", signature: createHmac("sha256", "test_secret").update(`${oid}|pay_Q1`).digest("hex") }, P1);
  assert.equal(r.body.status, "paid");
  await new Promise(res => setTimeout(res, 50));
  assert.equal(reported.length, 1);
  assert.equal(reported[0]!.id, oid);
  assert.deepEqual(reported[0]!.body.originalPreTaxAmount, { priceMicros: "2499000000", currency: "INR" });
  assert.deepEqual(reported[0]!.body.userTaxAddress, { regionCode: "IN", administrativeArea: "WEST BENGAL" });
  assert.equal(reported[0]!.body.oneTimeTransaction.externalTransactionToken, "ext-token-abcdef");
  const [rows] = await pool.query("SELECT reported_at FROM payments WHERE order_id = ?", [oid]) as any;
  assert.ok(rows[0].reported_at, "marked as reported");

  setPlayApi(null); setPaymentServices(null, null);
});

test("delete account: removes profile, devices, jobs and sign-in; keeps paid payment records", async () => {
  const GONE = "dev:gone1:gone@test.dev:Gone";
  const calls: string[] = [];
  let paid = false;
  setAccountServices({
    async removeRegistration(uid) { calls.push("reg:" + uid); return paid; },
    async removeMentorApplications(uid) { calls.push("mentor:" + uid); },
    async deleteSignIn(uid) { calls.push("auth:" + uid); },
  });
  assert.equal((await call("DELETE", "/me")).status, 401);
  assert.equal((await call("PUT", "/talent/me", profile(), GONE)).status, 200);
  assert.equal((await call("POST", "/me/devices", { token: "tok-gone-0123456789abcdef" }, GONE)).status, 201);
  await pool.query("INSERT INTO payments (order_id, uid, plan, amount, status) VALUES ('order_gone_1','gone1','booking',250000,'created')");

  let r = await call("DELETE", "/me", undefined, GONE);
  assert.equal(r.status, 200);
  assert.equal(r.body.keptPaymentRecords, false);
  assert.deepEqual(calls, ["reg:gone1", "mentor:gone1", "auth:gone1"]);
  assert.equal((await call("GET", "/talent/me", undefined, GONE)).body.profile, null);
  const [devs] = await pool.query("SELECT COUNT(*) AS n FROM device_tokens WHERE uid = 'gone1'") as any;
  assert.equal(Number(devs[0].n), 0);
  const [pays] = await pool.query("SELECT COUNT(*) AS n FROM payments WHERE uid = 'gone1'") as any;
  assert.equal(Number(pays[0].n), 0, "unpaid attempts are removed");

  // With a paid payment, the record stays (tax law) and the person is told
  await pool.query("INSERT INTO payments (order_id, uid, plan, amount, status, paid_at) VALUES ('order_gone_2','gone1','booking',250000,'paid',NOW())");
  paid = true;
  r = await call("DELETE", "/me", undefined, GONE);
  assert.equal(r.body.keptPaymentRecords, true);
  assert.match(r.body.message, /tax law/);
  const [kept] = await pool.query("SELECT COUNT(*) AS n FROM payments WHERE uid = 'gone1'") as any;
  assert.equal(Number(kept[0].n), 1);
  setAccountServices(null);
});

test("profile links: blank or spaces means no link; a bad link says how to fix it", async () => {
  const U = "dev:links1:links@test.dev:Links";
  let r = await call("PUT", "/talent/me", profile({ githubUrl: "   ", portfolioUrl: "", apps: [{ name: "ShopEasy", url: "  ", role: "", about: "" }] }), U);
  assert.equal(r.status, 200);
  assert.equal(r.body.profile.githubUrl, null);
  r = await call("PUT", "/talent/me", profile({ githubUrl: "notalink" }), U);
  assert.equal(r.status, 400);
  assert.match(r.body.error, /githubUrl: Enter a full link/);
  r = await call("PUT", "/talent/me", profile({ apps: [{ name: "X", url: "bad link", role: "", about: "" }] }), U);
  assert.match(r.body.error, /^apps\.0\.url: /);
  await call("DELETE", "/talent/me", undefined, U);
});

test("mock interviews: interviewer slots, booking with a 15-minute hold, payment, scorecard, profile badge, cancellations", async () => {
  process.env.RAZORPAY_KEY_ID = "rzp_test_abc"; process.env.RAZORPAY_KEY_SECRET = "test_secret"; process.env.RAZORPAY_WEBHOOK_SECRET = "hook_secret";
  const rzp = new Map<string, { id: string; order_id: string; amount: number; status: string; method?: string }>();
  let n = 500;
  setPaymentServices(
    {
      async createOrder(o) { n++; return { id: "order_M" + n, amount: o.amount, currency: "INR" }; },
      async fetchPayment(id) { return rzp.get(id)!; },
      async orderPayments(orderId) { return [...rzp.values()].filter(p => p.order_id === orderId); },
    },
    { async get() { return null; }, async addPayment() { return "paid"; }, async earlyBirdOpen() { return false; } });
  const pushes: string[] = [];
  setSender({ async topic() {}, async tokens(_t, p) { pushes.push(p.title); return []; } });
  setUserLookup({ async uidForEmail(e) { return e === "arjun@eng.dev" ? "eng1" : null; } });
  const ENG = "dev:eng1:arjun@eng.dev:Arjun", C1 = "dev:cand1:c1@test.dev:Cand One", C2 = "dev:cand2:c2@test.dev:Cand Two";
  const sign = (o: string, p: string) => createHmac("sha256", "test_secret").update(`${o}|${p}`).digest("hex");
  const inDays = (d: number, h = 18) => { const t = new Date(); t.setUTCDate(t.getUTCDate() + d); t.setUTCHours(h, 0, 0, 0); return t.toISOString(); };
  await call("POST", "/me/devices", { token: "tok-cand1-0123456789abcdef" }, C1);
  await call("POST", "/me/devices", { token: "tok-eng1-0123456789abcdefg" }, ENG);

  // Admin adds an interviewer by email
  const person = { email: "arjun@eng.dev", name: "Arjun Mehta", title: "Senior Flutter Engineer", company: "Swiggy", years: 7, tracks: ["flutter", "android"], bio: "Built apps used by millions." };
  assert.equal((await call("POST", "/admin/interviewers", person, C1)).status, 403);
  assert.equal((await call("POST", "/admin/interviewers", { ...person, email: "nobody@x.dev" }, ADMIN)).status, 404, "must have signed in once");
  assert.equal((await call("POST", "/admin/interviewers", person, ADMIN)).status, 201);
  let again = await call("POST", "/admin/interviewers", { ...person, title: "Staff Engineer" }, ADMIN);
  assert.deepEqual([again.status, again.body.updated], [200, true], "same email updates, never duplicates");
  assert.equal((await call("GET", "/admin/interviewers", undefined, ADMIN)).body.items.length, 1);
  assert.equal((await call("GET", "/mock/interviewer/me", undefined, C1)).body.interviewer, null);

  // Slots need a meeting link; too soon and overlapping ones are refused/skipped
  assert.equal((await call("POST", "/mock/interviewer/slots", { starts: [inDays(3)] }, ENG)).status, 400);
  assert.equal((await call("PUT", "/mock/interviewer/me", { title: "Senior Flutter Engineer", company: "Swiggy", years: 7, tracks: ["flutter", "android"], meetingLink: "https://meet.google.com/abc-defg-hij" }, ENG)).status, 200);
  again = await call("POST", "/admin/interviewers", person, ADMIN);
  assert.equal((await call("GET", "/admin/interviewers", undefined, ADMIN)).body.items[0].meetingLink, "https://meet.google.com/abc-defg-hij", "re-adding keeps the saved link");
  assert.equal((await call("POST", "/mock/interviewer/slots", { starts: [new Date(Date.now() + 30 * 60_000).toISOString()] }, ENG)).status, 400);
  let r = await call("POST", "/mock/interviewer/slots", { starts: [inDays(3), inDays(3, 18).replace("18:00:00", "18:30:00"), inDays(4), inDays(5), inDays(6)], durationMin: 60 }, ENG);
  assert.equal(r.status, 201);
  assert.deepEqual([r.body.added, r.body.skipped], [4, 1], "18:30 overlaps 18:00");
  assert.equal((await call("POST", "/mock/interviewer/slots", { starts: [inDays(3)] }, C1)).status, 403);

  // Candidates see open slots for their track
  const opts = await call("GET", "/mock/options");
  assert.deepEqual(opts.body.levels.map((l: any) => l.price), [499, 799, 1199]);
  assert.equal((await call("GET", "/mock/slots?track=ios")).body.slots.length, 0);
  let slots = (await call("GET", "/mock/slots?track=flutter")).body.slots;
  assert.equal(slots.length, 4);
  assert.equal(slots[0].interviewer.name, "Arjun Mehta");
  assert.equal(slots[0].interviewer.meetingLink, undefined, "link is never public");

  // Book: slot is held, price by level, others can't take it
  const book = { slotId: slots[0].id, track: "flutter", level: "mid", format: "technical", focus: "Bloc and testing" };
  assert.equal((await call("POST", "/mock/book", { ...book, track: "ios" }, C1)).status, 400);
  r = await call("POST", "/mock/book", book, C1);
  assert.equal(r.status, 201);
  assert.equal(r.body.amount, 79900);
  const o1 = r.body.orderId, b1 = r.body.bookingId;
  assert.equal((await call("POST", "/mock/book", book, C2)).status, 409, "held for C1");
  assert.equal((await call("GET", "/mock/slots?track=flutter")).body.slots.length, 3);
  let mine = (await call("GET", "/mock/mine", undefined, C1)).body.bookings;
  assert.equal(mine[0].status, "created");
  assert.equal(mine[0].meetingLink, null, "no link before paying");

  // Pay
  rzp.set("pay_M1", { id: "pay_M1", order_id: o1, amount: 79900, status: "captured", method: "upi" });
  assert.equal((await call("POST", "/mock/verify", { orderId: o1, paymentId: "pay_M1", signature: sign(o1, "pay_M1") }, C2)).status, 404, "not C2's booking");
  r = await call("POST", "/mock/verify", { orderId: o1, paymentId: "pay_M1", signature: sign(o1, "pay_M1") }, C1);
  assert.equal(r.body.status, "confirmed");
  mine = (await call("GET", "/mock/mine", undefined, C1)).body.bookings;
  assert.equal(mine[0].meetingLink, "https://meet.google.com/abc-defg-hij");
  assert.equal(mine[0].interviewer.company, "Swiggy");
  assert.ok(pushes.includes("Mock interview booked") && pushes.includes("New mock interview booked"));

  // Interviewer sees it, with the candidate's profile when shared
  await call("PUT", "/talent/me", profile({ fullName: "Cand One" }), C1);
  let dash = (await call("GET", "/mock/interviewer/me", undefined, ENG)).body;
  assert.equal(dash.bookings.length, 1);
  assert.equal(dash.bookings[0].candidate.name, "Cand One");
  assert.equal(dash.bookings[0].canScore, false);
  assert.equal((await call("GET", `/mock/bookings/${b1}`, undefined, ENG)).body.booking.candidateProfile.fullName, "Cand One");
  assert.equal((await call("GET", `/mock/bookings/${b1}`, undefined, C2)).status, 404);
  assert.equal((await call("DELETE", `/mock/interviewer/slots/${slots[0].id}`, undefined, ENG)).status, 409, "booked slots can't be deleted");

  // Reminder about an hour before
  const start1 = new Date(mine[0].startsAt);
  assert.equal(await sendReminders(new Date(start1.getTime() - 50 * 60_000)), 1);
  assert.equal(await sendReminders(new Date(start1.getTime() - 45 * 60_000)), 0, "only once");

  // Scorecard after the interview
  const card = { scores: { knowledge: 4, coding: 3, architecture: 4, debugging: 3, communication: 5 }, strengths: "Clear explanation of Bloc and solid widget tests.", improve: "Practise breaking problems down before coding.", recommendation: "hire" };
  assert.equal((await call("POST", `/mock/interviewer/bookings/${b1}/scorecard`, card, ENG)).status, 409, "not started yet");
  await pool.query("UPDATE mock_bookings SET starts_at = ? WHERE id = ?", [new Date(Date.now() - 70 * 60_000), b1]);
  assert.equal((await call("POST", `/mock/interviewer/bookings/${b1}/scorecard`, { ...card, strengths: "ok" }, ENG)).status, 400);
  r = await call("POST", `/mock/interviewer/bookings/${b1}/scorecard`, card, ENG);
  assert.equal(r.status, 201);
  assert.equal(r.body.overall, 3.8);
  mine = (await call("GET", "/mock/mine", undefined, C1)).body.bookings;
  assert.equal(mine[0].status, "completed");
  assert.equal(mine[0].scorecard.recommendation, "hire");
  assert.equal((await call("GET", "/talent/me", undefined, C1)).body.profile.mockInterview, null, "private until shared");
  assert.equal((await call("PUT", `/mock/bookings/${b1}/share`, { shared: true }, C1)).status, 200);
  assert.deepEqual((await call("GET", "/talent/me", undefined, C1)).body.profile.mockInterview.overall, 3.8);

  // Cancel an unpaid booking: slot opens again
  slots = (await call("GET", "/mock/slots?track=flutter")).body.slots;
  r = await call("POST", "/mock/book", { ...book, slotId: slots[0].id }, C2);
  assert.equal((await call("POST", `/mock/bookings/${r.body.bookingId}/cancel`, undefined, C2)).body.status, "cancelled");
  assert.equal((await call("GET", "/mock/slots?track=flutter")).body.slots.length, 3);

  // Paid and more than 24 hours away: cancel → refund due, slot open again
  r = await call("POST", "/mock/book", { ...book, slotId: slots[0].id, level: "fresher" }, C2);
  assert.equal(r.body.amount, 49900);
  rzp.set("pay_M2", { id: "pay_M2", order_id: r.body.orderId, amount: 49900, status: "captured", method: "card" });
  await call("POST", "/mock/verify", { orderId: r.body.orderId, paymentId: "pay_M2", signature: sign(r.body.orderId, "pay_M2") }, C2);
  const c = await call("POST", `/mock/bookings/${r.body.bookingId}/cancel`, undefined, C2);
  assert.equal(c.body.status, "refund_due");
  assert.equal((await call("GET", "/mock/slots?track=flutter")).body.slots.length, 3);

  // Hold expired and someone else took the slot; the late payment becomes a refund, never a double booking
  slots = (await call("GET", "/mock/slots?track=flutter")).body.slots;
  const late = await call("POST", "/mock/book", { ...book, slotId: slots[1].id }, C1);
  await pool.query("UPDATE interview_slots SET held_until = ? WHERE id = ?", [new Date(Date.now() - 60_000), slots[1].id]);
  const other = await call("POST", "/mock/book", { ...book, slotId: slots[1].id }, C2);
  assert.equal(other.status, 201);
  rzp.set("pay_M3", { id: "pay_M3", order_id: late.body.orderId, amount: 79900, status: "captured" });
  mine = (await call("GET", "/mock/mine", undefined, C1)).body.bookings;   // recovered here
  assert.equal(mine.find((b: any) => b.id === late.body.bookingId).status, "refund_due");

  // Admin sees bookings that need a refund
  const due = await call("GET", "/admin/mock-bookings?status=refund_due", undefined, ADMIN);
  assert.equal(due.body.items.length, 2);
  assert.equal((await call("PATCH", `/admin/mock-bookings/${c.body ? r.body.bookingId : 0}`, { status: "cancelled" }, ADMIN)).status, 200);
  const list = await call("GET", "/admin/interviewers", undefined, ADMIN);
  assert.equal(list.body.items[0].completed, 1);

  // Admin can manage another interviewer's link and slots without the app
  setUserLookup({ async uidForEmail(e) { return e === "neha@eng.dev" ? "eng2" : null; } });
  await call("POST", "/admin/interviewers", { ...person, email: "neha@eng.dev", name: "Neha", tracks: ["ios"] }, ADMIN);
  assert.equal((await call("POST", "/admin/interviewers/eng2/slots", { starts: [inDays(8)] }, ADMIN)).status, 400, "needs a meeting link");
  assert.equal((await call("PATCH", "/admin/interviewers/eng2", { meetingLink: "meet.google.com/x" }, ADMIN)).status, 400, "full link only");
  assert.equal((await call("PATCH", "/admin/interviewers/eng2", { meetingLink: "https://zoom.us/j/123" }, ADMIN)).status, 200);
  r = await call("POST", "/admin/interviewers/eng2/slots", { starts: [inDays(8), inDays(9)], durationMin: 45 }, ADMIN);
  assert.equal(r.body.added, 2);
  assert.equal((await call("POST", "/admin/interviewers/eng2/slots", { starts: [inDays(8)] }, C1)).status, 403);
  const adminSlots = (await call("GET", "/admin/interviewers/eng2/slots", undefined, ADMIN)).body.items;
  assert.equal(adminSlots.length, 2);
  assert.equal((await call("GET", "/mock/slots?track=ios")).body.slots.length, 2);
  assert.equal((await call("DELETE", `/admin/interview-slots/${adminSlots[0].id}`, undefined, ADMIN)).status, 200);
  assert.equal((await call("GET", "/mock/slots?track=ios")).body.slots.length, 1);

  // Taking an interviewer off removes their open slots
  await call("PATCH", "/admin/interviewers/eng1", { active: false }, ADMIN);
  assert.equal((await call("GET", "/mock/slots?track=flutter")).body.slots.length, 0);

  setUserLookup(null); setSender(null); setPaymentServices(null, null);
  await call("DELETE", "/talent/me", undefined, C1);
});

test("mentors: apply or edit their own profile, opt in to mock interviews, public card and interviewer kept in step", async () => {
  const docs = new Map<string, Record<string, any>>(), cards = new Map<string, Record<string, any>>();
  let n = 0;
  setMentorStore({
    async findMine(uid, email) {
      const hit = [...docs.entries()].find(([, d]) => d.uid === uid) ?? [...docs.entries()].find(([, d]) => d.email === email);
      return hit ? { id: hit[0], data: hit[1] } : null;
    },
    async create(d) { const id = "m" + ++n; docs.set(id, { ...d }); return id; },
    async update(id, d) { docs.set(id, { ...docs.get(id), ...d }); },
    async setPublic(id, c) { cards.set(id, c); },
  });
  const M = "dev:men1:meena@eng.dev:Meena";
  const form = { name: "Meena Iyer", phone: "98765 43210", company: "Zoho", role: "Senior Flutter Engineer", experience: 6, linkedin: "linkedin.com/in/meena",
    skills: ["Flutter", "Dart"], course: "State management", bio: "I build large Flutter apps and enjoy teaching.", availability: "Weekends" };

  assert.equal((await call("GET", "/mentor/me")).status, 401);
  assert.equal((await call("GET", "/mentor/me", undefined, M)).body.application, null);
  assert.equal((await call("PUT", "/mentor/me", { ...form, wantsInterviews: true }, M)).status, 400, "tracks needed when opting in");
  let r = await call("PUT", "/mentor/me", { ...form, wantsInterviews: true, interviewTracks: ["flutter", "android"] }, M);
  assert.equal(r.status, 201);
  assert.equal(r.body.application.phone, "+919876543210");
  assert.equal(r.body.application.linkedin, "https://linkedin.com/in/meena");
  assert.equal(r.body.application.status, "new");
  assert.equal(docs.get("m1")!.email, "meena@eng.dev", "email comes from the sign-in");

  // Editing keeps the admin's status; approved mentors' public card updates
  docs.get("m1")!.status = "approved";
  r = await call("PUT", "/mentor/me", { ...form, company: "Razorpay", wantsInterviews: true, interviewTracks: ["flutter"] }, M);
  assert.equal(r.status, 200);
  assert.equal(r.body.application.status, "approved");
  assert.equal(cards.get("m1")!.company, "Razorpay");
  assert.equal(docs.size, 1, "no second application");

  // Once an interviewer, edits flow to the interviewer details
  setUserLookup({ async uidForEmail() { return "men1"; } });
  await call("POST", "/admin/interviewers", { email: "meena@eng.dev", name: "Meena Iyer", title: "Senior Flutter Engineer", company: "Razorpay", years: 6, tracks: ["flutter"] }, ADMIN);
  assert.equal((await call("GET", "/mentor/me", undefined, M)).body.interviewer, "active");
  await call("PUT", "/mentor/me", { ...form, role: "Staff Engineer", company: "Razorpay", wantsInterviews: true, interviewTracks: ["flutter", "ios"] }, M);
  const iv = (await call("GET", "/admin/interviewers", undefined, ADMIN)).body.items.find((i: any) => i.uid === "men1");
  assert.equal(iv.title, "Staff Engineer");
  assert.deepEqual(iv.tracks, ["flutter", "ios"]);

  setMentorStore(null); setUserLookup(null);
});

test("admin overview: counts this period vs the previous one, daily series, to-do list and activity feed", async () => {
  const now = Date.now(), day = 86_400_000;
  setOverviewSources({
    async registrations() {
      return [
        { at: new Date(now - 60_000), name: "Asha", course: "Flutter in 10 Days", payStatus: "paid", amountPaid: 4999 },
        { at: new Date(now - 2 * day), name: "Ravi", course: "Flutter in 10 Days", payStatus: "pending", amountPaid: 0 },
        { at: new Date(now - 10 * day), name: "Old", course: "Flutter in 10 Days", payStatus: "pending", amountPaid: 0 },
      ];
    },
    async mentorApplications() { return [{ at: new Date(now - day), name: "Meena", role: "SDE", company: "Zoho", status: "new", wantsInterviews: true }]; },
  });
  assert.equal((await call("GET", "/admin/overview?days=7", undefined, SEEK)).status, 403);
  assert.equal((await call("GET", "/admin/overview?days=5", undefined, ADMIN)).status, 400);
  const r = await call("GET", "/admin/overview?days=7", undefined, ADMIN);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.kpis.registrations, { value: 2, prev: 1 });
  assert.equal(r.body.kpis.paidRegistrations.value, 1);
  assert.equal(r.body.kpis.mentorApplications.value, 1);
  assert.equal(r.body.daily.length, 7);
  assert.equal(r.body.daily.at(-1).date, istDay(new Date()));
  assert.equal(r.body.daily.at(-1).registrations, 1);
  assert.equal(r.body.todo.newMentors, 1);
  assert.equal(r.body.todo.unpaidRegistrations, 2);
  assert.ok(r.body.feed.some((f: any) => f.type === "registration" && f.title === "Asha registered"));
  assert.ok(r.body.feed.some((f: any) => f.type === "mentor" && f.detail.includes("wants to take interviews")));
  // Mock interviews paid earlier in the test run show up with revenue
  assert.ok(r.body.kpis.mockBookings.value >= 1);
  assert.ok(r.body.kpis.mockRevenue.value >= 499);
  assert.equal(r.body.daily.reduce((a: number, d: any) => a + d.revenue, 0), r.body.kpis.mockRevenue.value + r.body.kpis.courseRevenue.value);
  setOverviewSources(null);
});

test("Google: live jobs sitemap, and Google is told when a job goes live or closes", async () => {
  const pings: string[] = [];
  setIndexer({ async notify(url, type) { pings.push(`${type} ${url.split("id=")[1]}`); } });
  try {
    const a = await call("POST", "/admin/jobs", goodJob({ title: "Senior Flutter Engineer", applyUrl: "https://acme.test/careers/seo-1" }), ADMIN);
    const id = a.body.id;
    assert.ok(pings.includes(`URL_UPDATED ${id}`), "admin post pings Google");
    const sm = await fetch(`${base}/sitemap-jobs.xml`);
    assert.equal(sm.status, 200);
    assert.match(sm.headers.get("content-type") ?? "", /xml/);
    const xml = await sm.text();
    assert.match(xml, new RegExp(`job\\.html\\?id=${id}</loc>`));
    // featured-only change: no ping
    pings.length = 0;
    await call("PATCH", `/admin/jobs/${id}`, { featured: true }, ADMIN);
    assert.deepEqual(pings, []);
    // taken down: Google is told and it leaves the sitemap
    await call("PATCH", `/admin/jobs/${id}`, { status: "rejected", rejectReason: "Duplicate" }, ADMIN);
    assert.deepEqual(pings, [`URL_DELETED ${id}`]);
    assert.doesNotMatch(await (await fetch(`${base}/sitemap-jobs.xml`)).text(), new RegExp(id));
    // live again, then deleted
    pings.length = 0;
    await call("PATCH", `/admin/jobs/${id}`, { status: "approved" }, ADMIN);
    await call("DELETE", `/admin/jobs/${id}`, undefined, ADMIN);
    assert.deepEqual(pings, [`URL_UPDATED ${id}`, `URL_DELETED ${id}`]);
  } finally { setIndexer(null); }
});

test("short courses: Bloc crash course enrolment, early-bird price, seats, Razorpay confirm, joining link, admin", async () => {
  process.env.RAZORPAY_KEY_ID = "rzp_test_abc"; process.env.RAZORPAY_KEY_SECRET = "test_secret"; process.env.RAZORPAY_WEBHOOK_SECRET = "hook_secret";
  const rzp = new Map<string, { id: string; order_id: string; amount: number; status: string; method?: string }>();
  let n = 900;
  setPaymentServices({
    async createOrder(o) { n++; return { id: "order_W" + n, amount: o.amount, currency: "INR" }; },
    async fetchPayment(id) { return rzp.get(id)!; },
    async orderPayments(orderId) { return [...rzp.values()].filter(p => p.order_id === orderId); },
  }, { async get() { return null; }, async addPayment() { return "paid"; }, async earlyBirdOpen() { return false; } });
  const sign = (o: string, p: string) => createHmac("sha256", "test_secret").update(`${o}|${p}`).digest("hex");
  const S1 = "dev:stu1:s1@test.dev:Stu One", S2 = "dev:stu2:s2@test.dev:Stu Two", S3 = "dev:stu3:s3@test.dev:Stu Three";
  try {
    // Seeded as a draft: visible, not open
    let g = await call("GET", "/workshops/bloc-crash-course");
    assert.equal(g.status, 200);
    assert.deepEqual([g.body.workshop.status, g.body.workshop.price, g.body.workshop.earlyPrice], ["draft", 999, 799]);
    assert.equal(g.body.workshop.brochureUrl, "https://widgetryacademy.in/brochures/bloc-crash-course.pdf");
    assert.equal((await call("POST", "/workshops/bloc-crash-course/enroll", { name: "Stu One", phone: "9876543210" }, S1)).status, 409);
    assert.equal((await call("GET", "/workshops/nope")).status, 404);

    const list = await call("GET", "/admin/workshops", undefined, ADMIN);
    const id = list.body.items.find((w: any) => w.slug === "bloc-crash-course").id;
    assert.equal((await call("GET", "/admin/workshops", undefined, S1)).status, 403);
    const start = new Date(Date.now() + 7 * 86_400_000).toISOString();
    const edit = { title: "Bloc State Management Crash Course", startsAt: start, schedule: "Sat & Sun · 11 AM–1:30 PM IST", durationMin: 300, price: 999, earlyPrice: 799, earlySeats: 1, seats: 2, meetingLink: "https://meet.google.com/abc-defg-hij", status: "open" };
    assert.equal((await call("PUT", `/admin/workshops/${id}`, { ...edit, startsAt: null }, ADMIN)).status, 400, "needs a date to open");
    assert.equal((await call("PUT", `/admin/workshops/${id}`, { ...edit, earlyPrice: 1200 }, ADMIN)).status, 400, "early price must be lower");
    assert.equal((await call("PUT", `/admin/workshops/${id}`, { ...edit, brochure: "notes.docx" }, ADMIN)).status, 400, "brochure must be a PDF");
    assert.equal((await call("PUT", `/admin/workshops/${id}`, edit, ADMIN)).status, 200);
    assert.equal((await call("GET", "/admin/workshops", undefined, ADMIN)).body.items.find((w: any) => w.id === id).brochure, "brochures/bloc-crash-course.pdf", "kept when not sent");

    // Sign-in and a valid phone are needed
    assert.equal((await call("POST", "/workshops/bloc-crash-course/enroll", { name: "Stu One", phone: "9876543210" })).status, 401);
    assert.equal((await call("POST", "/workshops/bloc-crash-course/enroll", { name: "Stu One", phone: "123" }, S1)).status, 400);

    // First student gets the early-bird price and pays through the app flow
    let e1 = await call("POST", "/workshops/bloc-crash-course/enroll", { name: "Stu One", phone: "98765 43210" }, S1);
    assert.equal(e1.status, 201);
    assert.equal(e1.body.amount, 79900);
    assert.equal(e1.body.prefill.contact, "+919876543210");
    rzp.set("pay_W1", { id: "pay_W1", order_id: e1.body.orderId, amount: 79900, status: "captured", method: "upi" });
    assert.equal((await call("POST", "/workshops/verify", { orderId: e1.body.orderId, paymentId: "pay_W1", signature: "0".repeat(64) }, S1)).status, 400, "bad signature");
    assert.equal((await call("POST", "/workshops/verify", { orderId: e1.body.orderId, paymentId: "pay_W1", signature: sign(e1.body.orderId, "pay_W1") }, S2)).status, 404, "someone else's order");
    let v = await call("POST", "/workshops/verify", { orderId: e1.body.orderId, paymentId: "pay_W1", signature: sign(e1.body.orderId, "pay_W1") }, S1);
    assert.deepEqual([v.status, v.body.status], [200, "confirmed"]);
    g = await call("GET", "/workshops/bloc-crash-course", undefined, S1);
    assert.equal(g.body.mine.status, "confirmed");
    assert.equal(g.body.mine.meetingLink, "https://meet.google.com/abc-defg-hij", "joining link only for paid students");
    assert.equal((await call("GET", "/workshops/bloc-crash-course", undefined, S2)).body.mine, null);
    assert.equal((await call("POST", "/workshops/bloc-crash-course/enroll", { name: "Stu One", phone: "9876543210" }, S1)).status, 409, "already enrolled");

    // Early-bird seats used up: full price now. Second student pays, confirmed by the webhook only.
    g = await call("GET", "/workshops/bloc-crash-course");
    assert.deepEqual([g.body.workshop.earlyPrice, g.body.workshop.seatsLeft], [null, 1]);
    const e2 = await call("POST", "/workshops/bloc-crash-course/enroll", { name: "Stu Two", phone: "9123456789" }, S2);
    assert.equal(e2.body.amount, 99900);
    // While S2's seat is held, the course is full for others
    assert.equal((await call("POST", "/workshops/bloc-crash-course/enroll", { name: "Stu Three", phone: "9000000001" }, S3)).status, 409);
    const raw = JSON.stringify({ event: "payment.captured", payload: { payment: { entity: { id: "pay_W2", order_id: e2.body.orderId, amount: 99900, status: "captured", method: "card" } } } });
    const hook = await fetch(base + "/payments/webhook", { method: "POST", headers: { "content-type": "application/json", "x-razorpay-signature": createHmac("sha256", "hook_secret").update(raw).digest("hex") }, body: raw });
    assert.equal(hook.status, 200);
    assert.equal((await call("GET", "/workshops/bloc-crash-course", undefined, S2)).body.mine.status, "confirmed");

    // Admin sees both, revenue adds up, and can mark a refund
    const adm = (await call("GET", "/admin/workshops", undefined, ADMIN)).body.items.find((w: any) => w.id === id);
    assert.deepEqual([adm.enrolled, adm.revenue], [2, 1798]);
    const people = (await call("GET", `/admin/workshops/${id}/enrollments`, undefined, ADMIN)).body.items;
    assert.equal(people.length, 2);
    assert.equal(people.find((p: any) => p.name === "Stu One").early, true);
    assert.equal((await call("PATCH", `/admin/workshop-enrollments/${people[0].id}`, { status: "refunded" }, ADMIN)).status, 200);
    assert.equal((await call("PATCH", `/admin/workshop-enrollments/${people[0].id}`, { status: "refunded" }, ADMIN)).status, 404, "only once");

    // A new course can be added from admin
    const c = await call("POST", "/admin/workshops", { slug: "riverpod-crash-course", title: "Riverpod Crash Course", price: 999, seats: 30 }, ADMIN);
    assert.equal(c.status, 201);
    assert.equal((await call("POST", "/admin/workshops", { slug: "riverpod-crash-course", title: "Riverpod Crash Course", price: 999, seats: 30 }, ADMIN)).status, 409);
  } finally { setPaymentServices(null, null); }
});

test("short courses in the Android app: Google Play purchase, Razorpay from Google's choice screen reported to Google", async () => {
  process.env.RAZORPAY_KEY_ID = "rzp_test_abc"; process.env.RAZORPAY_KEY_SECRET = "test_secret"; process.env.RAZORPAY_WEBHOOK_SECRET = "hook_secret";
  const rzp = new Map<string, { id: string; order_id: string; amount: number; status: string; method?: string }>();
  let n = 950;
  setPaymentServices({
    async createOrder(o) { n++; return { id: "order_A" + n, amount: o.amount, currency: "INR" }; },
    async fetchPayment(id) { return rzp.get(id)!; },
    async orderPayments(orderId) { return [...rzp.values()].filter(p => p.order_id === orderId); },
  }, { async get() { return null; }, async addPayment() { return "paid"; }, async earlyBirdOpen() { return false; } });
  const purchases = new Map<string, any>(); const consumed: string[] = []; const reported: any[] = [];
  setPlayApi({
    async getPurchase(_p, token) { return purchases.get(token); },
    async consume(_p, token) { consumed.push(token); },
    async reportExternal(id, body) { reported.push({ id, body }); return true; },
  });
  const sign = (o: string, p: string) => createHmac("sha256", "test_secret").update(`${o}|${p}`).digest("hex");
  const A1 = "dev:app1:a1@test.dev:App One", A2 = "dev:app2:a2@test.dev:App Two";
  try {
    await pool.query("DELETE FROM workshop_enrollments");
    const id = (await call("GET", "/admin/workshops", undefined, ADMIN)).body.items.find((w: any) => w.slug === "bloc-crash-course").id;
    const start = new Date(Date.now() + 7 * 86_400_000).toISOString();
    await call("PUT", `/admin/workshops/${id}`, { title: "Bloc State Management Crash Course", startsAt: start, schedule: "Sat & Sun", durationMin: 300, price: 999, earlyPrice: 799, earlySeats: 1, seats: 10, meetingLink: "https://meet.google.com/x", status: "open" }, ADMIN);

    // The app's list and detail (with Google Play details for signed-in users)
    const list = await call("GET", "/workshops");
    assert.equal(list.body.items[0].slug, "bloc-crash-course");
    let d = await call("GET", "/workshops/bloc-crash-course", undefined, A1);
    assert.equal(d.body.android.playProductId, "short_course_799");
    assert.equal(d.body.android.billing, "user_choice");
    assert.equal((await call("GET", "/workshops/bloc-crash-course")).body.android, null);

    // Google Play: hold the seat, buy, verify
    const hold = await call("POST", "/workshops/bloc-crash-course/enroll", { name: "App One", phone: "9876543210", mode: "play" }, A1);
    assert.deepEqual([hold.status, hold.body.productId, hold.body.amount], [201, "short_course_799", 79900]);
    purchases.set("tok-someone-else", { purchaseState: 0, orderId: "GPA.1111", obfuscatedExternalAccountId: "not-me" });
    assert.equal((await call("POST", "/workshops/play/verify", { productId: "short_course_799", purchaseToken: "tok-someone-else" }, A1)).status, 403);
    purchases.set("tok-pending-1234", { purchaseState: 2 });
    assert.equal((await call("POST", "/workshops/play/verify", { productId: "short_course_799", purchaseToken: "tok-pending-1234" }, A1)).status, 202);
    purchases.set("tok-a1-purchase", { purchaseState: 0, consumptionState: 0, orderId: "GPA.2222", obfuscatedExternalAccountId: playAccountId("app1") });
    let v = await call("POST", "/workshops/play/verify", { productId: "short_course_799", purchaseToken: "tok-a1-purchase" }, A1);
    assert.deepEqual([v.status, v.body.status], [200, "confirmed"]);
    assert.ok(consumed.includes("tok-a1-purchase"));
    v = await call("POST", "/workshops/play/verify", { productId: "short_course_799", purchaseToken: "tok-a1-purchase" }, A1);
    assert.equal(v.status, 200, "repeat is safe");
    d = await call("GET", "/workshops/bloc-crash-course", undefined, A1);
    assert.deepEqual([d.body.mine.status, d.body.mine.meetingLink], ["confirmed", "https://meet.google.com/x"]);
    // A second purchase with no seat to match is left for Google to refund (not consumed)
    purchases.set("tok-a1-again-00", { purchaseState: 0, consumptionState: 0, orderId: "GPA.3333", obfuscatedExternalAccountId: playAccountId("app1") });
    assert.equal((await call("POST", "/workshops/play/verify", { productId: "short_course_999", purchaseToken: "tok-a1-again-00" }, A1)).status, 409);
    assert.ok(!consumed.includes("tok-a1-again-00"));

    // Razorpay chosen on Google's screen: needs a state; reported to Google once paid
    assert.equal((await call("POST", "/workshops/bloc-crash-course/enroll", { name: "App Two", phone: "9123456789", externalTransactionToken: "ext-token-abcdefgh" }, A2)).status, 400);
    const o = await call("POST", "/workshops/bloc-crash-course/enroll", { name: "App Two", phone: "9123456789", externalTransactionToken: "ext-token-abcdefgh", state: "WEST BENGAL" }, A2);
    assert.equal(o.body.amount, 99900, "early-bird seat already taken");
    rzp.set("pay_A2", { id: "pay_A2", order_id: o.body.orderId, amount: 99900, status: "captured", method: "upi" });
    v = await call("POST", "/workshops/verify", { orderId: o.body.orderId, paymentId: "pay_A2", signature: sign(o.body.orderId, "pay_A2") }, A2);
    assert.equal(v.body.status, "confirmed");
    await new Promise(r => setTimeout(r, 50));
    await reportPendingExternal();
    const rep = reported.find(r => r.body.oneTimeTransaction.externalTransactionToken === "ext-token-abcdefgh");
    assert.ok(rep, "reported to Google");
    assert.equal(rep.body.originalPreTaxAmount.priceMicros, "999000000");
    assert.equal(reported.filter(r => r.body.oneTimeTransaction.externalTransactionToken === "ext-token-abcdefgh").length, 1, "reported once");

    // Releasing a hold frees the seat
    const h2 = await call("POST", "/workshops/bloc-crash-course/enroll", { name: "App Two", phone: "9123456789", mode: "play" }, "dev:app3:a3@test.dev:Three");
    assert.equal(h2.status, 201);
    const before = (await call("GET", "/workshops/bloc-crash-course")).body.workshop.seatsLeft;
    await call("POST", "/workshops/bloc-crash-course/release", {}, "dev:app3:a3@test.dev:Three");
    assert.equal((await call("GET", "/workshops/bloc-crash-course")).body.workshop.seatsLeft, before + 1);
    const people = (await call("GET", `/admin/workshops/${id}/enrollments`, undefined, ADMIN)).body.items;
    assert.deepEqual(people.map((p: any) => p.channel).sort(), ["google_play", "razorpay"]);
  } finally { setPaymentServices(null, null); setPlayApi(null); }
});

test("city names: other names and Delhi NCR", async () => {
  const { cityNames } = await import("../src/routes/jobs.js");
  assert.deepEqual(cityNames("bangalore"), ["Bengaluru", "Bangalore"]);
  assert.deepEqual(cityNames("Delhi NCR"), ["Delhi", "Noida", "Gurugram", "Gurgaon", "Ghaziabad", "Faridabad"]);
  assert.deepEqual(cityNames("Noida"), ["Noida"]);
});

test("AI tutor chat: history is resent, usage is returned, other users can't read it", async () => {
  const { setChatModel } = await import("../src/chat.js");
  const seen: number[] = [];
  setChatModel(async (_system, messages) => { seen.push(messages.length); return { text: `answer ${messages.length}`, stopReason: "end_turn", inputTokens: 100 + messages.length, outputTokens: 20 }; });
  try {
    const me = "dev:chat1:chat@test.dev:Chat", other = "dev:chat2:other@test.dev:Other";
    assert.equal((await call("POST", "/chat", { message: "hi" })).status, 401, "sign-in needed");
    assert.equal((await call("POST", "/chat", { message: "  " }, me)).status, 400, "empty question");

    const a = await call("POST", "/chat", { message: "What is a widget?" }, me);
    assert.equal(a.status, 200);
    assert.equal(a.body.reply, "answer 1");
    assert.equal(a.body.usage.contextMessages, 0, "first question: nothing earlier to resend");
    assert.equal(a.body.usage.inputTokens, 101);

    const b = await call("POST", "/chat", { conversationId: a.body.conversationId, message: "And a StatefulWidget?" }, me);
    assert.equal(b.body.usage.contextMessages, 2, "the earlier question and answer are resent");
    assert.deepEqual(seen, [1, 3]);
    assert.equal(b.body.usage.questionsLeftToday, a.body.usage.questionsLeftToday - 1, "one question fewer left");

    const list = await call("GET", "/chat/conversations", undefined, me);
    assert.equal(list.body.conversations.length, 1);
    const msgs = await call("GET", `/chat/conversations/${a.body.conversationId}/messages`, undefined, me);
    assert.deepEqual(msgs.body.messages.map((m: any) => m.role), ["user", "assistant", "user", "assistant"]);
    assert.equal(msgs.body.messages[3].inputTokens, 103);

    assert.equal((await call("GET", `/chat/conversations/${a.body.conversationId}/messages`, undefined, other)).status, 404, "someone else's chat");
    assert.equal((await call("POST", "/chat", { conversationId: a.body.conversationId, message: "x" }, other)).status, 404);
  } finally { setChatModel(null); }
});

test("AI tutor RAG: Widgetry passages and live fees go into the prompt, sources come back and are saved", async () => {
  const { setChatModel } = await import("../src/chat.js");
  const { clearFactsCache } = await import("../src/facts.js");
  clearFactsCache();
  const systems: string[] = [];
  setChatModel(async (system, messages) => { systems.push(system); return { text: `answer ${messages.length}`, stopReason: "end_turn", inputTokens: 500, outputTokens: 40 }; });
  try {
    const me = "dev:rag1:rag@test.dev:Rag";
    const a = await call("POST", "/chat", { message: "What is the difference between Cubit and Bloc?" }, me);
    assert.equal(a.status, 200);
    assert.ok(a.body.sources.some((s: any) => s.url.endsWith("/blog/flutter-bloc-tutorial.html")), "the Bloc tutorial is a source");
    assert.match(systems[0], /<reference id="1"/);
    assert.match(systems[0], /Cubit vs Bloc/, "the matching section is pasted into the prompt");
    assert.match(systems[0], /<academy_facts>[\s\S]*Flutter in 10 Days[\s\S]*₹[\d,]+[\s\S]*<\/academy_facts>/, "live fees are in the prompt");
    assert.ok(a.body.usage.retrieved.length > 0 && a.body.usage.retrieved.length <= 4);

    // A follow-up with no topic words still finds the topic from the previous question
    const b = await call("POST", "/chat", { conversationId: a.body.conversationId, message: "Show me a short example please" }, me);
    assert.ok(b.body.sources.some((s: any) => s.url.includes("flutter-bloc-tutorial")));

    // Nothing relevant in our material: no passages, no sources (Claude answers from its own knowledge, or declines)
    const c = await call("POST", "/chat", { message: "How do I bake a pizza?" }, me);
    assert.deepEqual(c.body.sources, []);
    assert.doesNotMatch(systems[2], /<reference id=/);

    // Sources are saved with the answer, so a reopened chat still shows them
    const msgs = await call("GET", `/chat/conversations/${a.body.conversationId}/messages`, undefined, me);
    assert.deepEqual(msgs.body.messages[1].sources, a.body.sources);
    assert.deepEqual(msgs.body.messages[0].sources, [], "questions have no sources");
  } finally { setChatModel(null); }
});

test("RAG retrieval: chunks keep code whole, BM25 ranks the right section, unrelated questions find nothing", async () => {
  const { KnowledgeIndex, chunkDocument, tokens } = await import("../src/rag.js");
  const doc = `---\ntitle: "State guide"\nurl: "https://x.test/state"\n---\nIntro text.\n\n## Cubit vs Bloc\n\nCubit uses methods. Bloc uses events.\n\n## Testing\n\n${"Long paragraph about tests. ".repeat(40)}\n\n\`\`\`dart\nvoid main() {\n\n  print('a');\n}\n\`\`\`\n`;
  const chunks = chunkDocument(doc, "x");
  assert.equal(chunks[0].section, null, "the intro is its own chunk");
  assert.ok(chunks.some(c => c.section === "Cubit vs Bloc"));
  assert.ok(chunks.some(c => /```dart[\s\S]*print\('a'\);\n}\n```/.test(c.text)), "a code block is never split");
  assert.deepEqual(tokens("Testing the States of a Bloc"), ["test", "state", "bloc"]);

  const other = `---\ntitle: "Jobs"\nurl: "https://x.test/jobs"\n---\n## Salaries\n\nFlutter developers in India earn well.`;
  const kb = new KnowledgeIndex([{ name: "a", raw: doc }, { name: "b", raw: other }]);
  assert.equal(kb.search("cubit or bloc which one", 4, 0.5)[0].chunk.section, "Cubit vs Bloc");
  assert.equal(kb.search("salary of flutter developer", 4, 0.5)[0].chunk.url, "https://x.test/jobs");
  assert.deepEqual(kb.search("pizza recipe", 4, 0.5), []);
});

test("Resume Premium: ₹299 for 30 days via Razorpay, AI help only with Premium, daily cap, suggestions saved, pro templates, orders list", async () => {
  process.env.RAZORPAY_KEY_ID = "rzp_test_abc"; process.env.RAZORPAY_KEY_SECRET = "test_secret"; process.env.RAZORPAY_WEBHOOK_SECRET = "hook_secret";
  process.env.RESUME_AI_DAILY = "3";
  const rzp = new Map<string, { id: string; order_id: string; amount: number; status: string; method?: string }>();
  let n = 500;
  setPaymentServices({
    async createOrder(o) { n++; return { id: "order_R" + n, amount: o.amount, currency: "INR" }; },
    async fetchPayment(id) { return rzp.get(id)!; },
    async orderPayments(orderId) { return [...rzp.values()].filter(p => p.order_id === orderId); },
  }, { async get() { return null; }, async addPayment() { return "paid"; }, async earlyBirdOpen() { return false; } });
  const sign = (o: string, p: string) => createHmac("sha256", "test_secret").update(`${o}|${p}`).digest("hex");
  const { setChatModel } = await import("../src/chat.js");
  const prompts: string[] = [];
  setChatModel(async (_s, messages) => {
    const ask = messages[0].content; prompts.push(ask);
    const text = ask.includes("cover letter") ? JSON.stringify({ letter: "Dear [Hiring Manager],\n\nI am applying..." })
      : ask.includes("Tailor this resume") ? "```json\n" + JSON.stringify({ summary: "Flutter developer aimed at fintech.", jobs: [{ index: 0, points: ["Built payments with Riverpod"] }, { index: 7, points: ["bad index"] }], addSkills: ["Riverpod"], gaps: ["GraphQL"], tips: ["Lead with payments"] }) + "\n```"
      : ask.includes("achievement points") ? "Here you go: " + JSON.stringify({ points: ["Built checkout used by [N]k+ users", "Cut crashes by [X]%"], note: "Fill in the numbers." })
      : JSON.stringify({ summary: "Flutter developer with 3 years shipping apps." });
    return { text, stopReason: "end_turn", inputTokens: 900, outputTokens: 200 };
  });
  const ME = "dev:rp1:rp@test.dev:Resume Person", OTHER = "dev:rp2:rp2@test.dev:Other";
  const JOB = "We are hiring a Flutter developer with Riverpod, REST APIs and payments experience for our fintech app in Bengaluru. 2+ years.";
  try {
    assert.equal((await call("PUT", "/talent/me", profile({ experience: [{ company: "Acme Apps", role: "Flutter Developer", start: "2023-01", end: "", points: "Worked on payments\nHelped with tests" }] }), ME)).status, 200);

    // Price is public; status needs sign-in
    let g = await call("GET", "/resume/premium");
    assert.deepEqual([g.body.price, g.body.days, g.body.active], [299, 30, false]);
    g = await call("GET", "/resume/premium", undefined, ME);
    assert.deepEqual([g.body.active, g.body.aiLeftToday], [false, 3]);

    // No Premium: AI and pro templates are refused
    assert.equal((await call("POST", "/resume/ai", { action: "summary" }, ME)).status, 402);
    assert.equal((await call("PUT", "/talent/me/resume-settings", { template: "executive" }, ME)).status, 402);
    assert.equal((await call("PUT", "/talent/me/resume-settings", { template: "classic" }, ME)).status, 200, "free templates still work");

    // Buy: order, then verify (bad signature, someone else, then the real one)
    assert.equal((await call("POST", "/resume/premium/order", {})).status, 401);
    const o = await call("POST", "/resume/premium/order", {}, ME);
    assert.deepEqual([o.status, o.body.amount, o.body.description], [201, 29900, "Resume Premium · 30 days"]);
    rzp.set("pay_R1", { id: "pay_R1", order_id: o.body.orderId, amount: 29900, status: "captured", method: "upi" });
    assert.equal((await call("POST", "/resume/premium/verify", { orderId: o.body.orderId, paymentId: "pay_R1", signature: "0".repeat(64) }, ME)).status, 400);
    assert.equal((await call("POST", "/resume/premium/verify", { orderId: o.body.orderId, paymentId: "pay_R1", signature: sign(o.body.orderId, "pay_R1") }, OTHER)).status, 404);
    const v = await call("POST", "/resume/premium/verify", { orderId: o.body.orderId, paymentId: "pay_R1", signature: sign(o.body.orderId, "pay_R1") }, ME);
    assert.equal(v.status, 200);
    assert.equal(v.body.active, true);
    const days = (new Date(v.body.expiresAt).getTime() - Date.now()) / 86_400_000;
    assert.ok(days > 29.9 && days < 30.01, `about 30 days, got ${days}`);
    assert.equal((await call("POST", "/resume/premium/verify", { orderId: o.body.orderId, paymentId: "pay_R1", signature: sign(o.body.orderId, "pay_R1") }, ME)).body.expiresAt, v.body.expiresAt, "verifying twice changes nothing");

    // Buying again while active adds 30 days on top, confirmed by the webhook alone
    const o2 = await call("POST", "/resume/premium/order", {}, ME);
    const raw = JSON.stringify({ event: "payment.captured", payload: { payment: { entity: { id: "pay_R2", order_id: o2.body.orderId, amount: 29900, status: "captured", method: "card" } } } });
    assert.equal((await fetch(base + "/payments/webhook", { method: "POST", headers: { "content-type": "application/json", "x-razorpay-signature": createHmac("sha256", "hook_secret").update(raw).digest("hex") }, body: raw })).status, 200);
    g = await call("GET", "/resume/premium", undefined, ME);
    assert.ok(Math.abs((new Date(g.body.expiresAt).getTime() - new Date(v.body.expiresAt).getTime()) / 86_400_000 - 30) < 0.01, "extended by 30 days");

    // Pro template now allowed
    assert.equal((await call("PUT", "/talent/me/resume-settings", { template: "executive" }, ME)).status, 200);

    // AI: bullets need a real job index; the reply is cleaned; contact details never reach the model
    assert.equal((await call("POST", "/resume/ai", { action: "bullets", experienceIndex: 5 }, ME)).status, 400);
    let a = await call("POST", "/resume/ai", { action: "bullets", experienceIndex: 0, jobText: JOB }, ME);
    assert.equal(a.status, 200);
    assert.deepEqual(a.body.result.points, ["Built checkout used by [N]k+ users", "Cut crashes by [X]%"]);
    assert.equal(a.body.aiLeftToday, 2);
    assert.match(prompts[0], /Worked on payments/);
    assert.doesNotMatch(prompts[0], /98765|rp@test\.dev/, "no phone or email sent to the AI");
    assert.equal((await call("POST", "/resume/ai", { action: "tailor" }, ME)).status, 400, "tailoring needs a job");
    a = await call("POST", "/resume/ai", { action: "tailor", jobText: JOB, jobTitle: "Flutter Developer", company: "PayCo" }, ME);
    assert.deepEqual(a.body.result.jobs, [{ index: 0, points: ["Built payments with Riverpod"] }], "out-of-range jobs dropped");
    assert.deepEqual([a.body.result.addSkills, a.body.result.gaps], [["Riverpod"], ["GraphQL"]]);
    a = await call("POST", "/resume/ai", { action: "cover", jobText: JOB, company: "PayCo" }, ME);
    assert.match(a.body.result.letter, /Hiring Manager/);
    assert.equal((await call("POST", "/resume/ai", { action: "summary" }, ME)).status, 429, "daily cap of 3");

    // Saving suggestions: summary, one job's points and new skills; nothing else changes
    assert.equal((await call("PATCH", "/talent/me/resume-content", {}, ME)).status, 400);
    assert.equal((await call("PATCH", "/talent/me/resume-content", { points: [{ index: 4, points: "x" }] }, ME)).status, 400);
    const s = await call("PATCH", "/talent/me/resume-content", { about: "Flutter developer aimed at fintech.", points: [{ index: 0, points: "Built payments with Riverpod" }], addSkills: ["Riverpod", "bloc"] }, ME);
    assert.equal(s.status, 200);
    assert.equal(s.body.profile.about, "Flutter developer aimed at fintech.");
    assert.equal(s.body.profile.experience[0].points, "Built payments with Riverpod");
    assert.equal(s.body.profile.experience[0].company, "Acme Apps");
    assert.ok(s.body.profile.skills.includes("Riverpod"));
    assert.equal(s.body.profile.skills.filter((k: string) => k.toLowerCase() === "bloc").length, 1, "no duplicate skills");

    // Both payments show in Orders & receipts
    const mine = await call("GET", "/me/purchases", undefined, ME);
    const rp = mine.body.orders.filter((x: any) => x.kind === "resume_premium");
    assert.equal(rp.length, 2);
    assert.match(rp[0].item, /^30 days · until /);
    assert.equal(rp[0].amount, 299);
  } finally { setChatModel(null); delete process.env.RESUME_AI_DAILY; await pool.query("DELETE FROM candidates WHERE uid = 'rp1'"); }
});

test("Resume v2: achievements and languages, PDF and Word downloads, ATS for the app, import, saved copies, Play purchase, reminder", async () => {
  const { readFileSync } = await import("node:fs");
  const { setChatModel } = await import("../src/chat.js");
  const ME = "dev:rv1:rv@test.dev:Rohan", OTHER = "dev:rv2:rv2@test.dev:Other";
  const hasChromium = (() => { try { readFileSync(process.env.CHROMIUM_PATH || "/usr/bin/chromium"); return true; } catch { return false; } })();
  const raw = async (path: string, bytes: Buffer, type: string, token?: string) => {
    const r = await fetch(base + path, { method: "POST", headers: { "content-type": type, "x-forwarded-for": "10.9.9.9", ...(token ? { authorization: "Bearer " + token } : {}) }, body: bytes });
    return { status: r.status, body: await r.json() };
  };
  const bin = async (path: string, body: unknown, token: string) => {
    const r = await fetch(base + path, { method: "POST", headers: { "content-type": "application/json", authorization: "Bearer " + token }, body: JSON.stringify(body) });
    return { status: r.status, bytes: Buffer.from(await r.arrayBuffer()), headers: r.headers };
  };
  try {
    // New sections are saved and come back
    const put = await call("PUT", "/talent/me", profile({ achievements: ["Winner, Smart India Hackathon 2023", ""], languages: ["English", "Hindi", "English"],
      experience: [{ company: "PayNow", role: "Android Developer", start: "2022-03", end: "", points: "Led migration to Compose\nAdded Hilt" }] }), ME);
    assert.equal(put.status, 200, JSON.stringify(put.body));
    assert.deepEqual([put.body.profile.achievements, put.body.profile.languages], [["Winner, Smart India Hackathon 2023"], ["English", "Hindi"]]);
    const kept = await call("PUT", "/talent/me", profile({ headline: "Android Developer" }), ME);
    assert.deepEqual(kept.body.profile.achievements, ["Winner, Smart India Hackathon 2023"], "older apps that don't send the new sections don't wipe them");
    assert.equal((await call("PUT", "/talent/me/resume-settings", { template: "modern", density: "tight", hide: ["languages"] }, ME)).status, 200);

    // Word download is Pro; PDF stays free
    assert.equal((await bin("/resume/docx", {}, ME)).status, 402);
    await pool.query("INSERT INTO resume_premium (uid, email, amount, days, status, order_id, paid_at, starts_at, expires_at) VALUES ('rv1','rv@test.dev',29900,30,'paid','order_word_test',NOW(),NOW(),NOW() + INTERVAL 5 DAY)");
    const d = await bin("/resume/docx", { accent: "maroon" }, ME);
    assert.equal(d.status, 200);
    assert.equal(d.bytes.subarray(0, 2).toString(), "PK");
    assert.match(d.headers.get("content-disposition") || "", /Riya-Sen-Resume\.docx/);
    await pool.query("DELETE FROM resume_premium WHERE order_id = 'order_word_test'");
    // Free resumes: fixed colour, no photo, normal spacing, no Key highlights, a small Widgetry line. Pro: all of it.
    const { resumeHtml } = await import("../src/resumeDoc.js");
    const who = { fullName: "Riya Sen", headline: "Flutter Developer", skills: ["Flutter"], photo: "data:image/png;base64,AAAA",
      experience: [{ company: "A", role: "Dev", start: "2023-01", points: "Grew daily users by 40% with a new onboarding\nCut app start time by 2x on low-end phones" }] };
    const body = (h: string) => h.slice(h.indexOf("<body>"));
    const free = body(resumeHtml(who, { template: "modern", accent: "maroon", density: "tight", showPhoto: true }, false, false));
    assert.ok(free.includes("Made with Widgetry") && !free.includes("d-tight") && !free.includes("Key Highlights") && !free.includes('class="photo"') && !free.includes("--rs-accent:#7a1f2b"));
    const paid = body(resumeHtml(who, { template: "modern", accent: "maroon", density: "tight", showPhoto: true }, false, true));
    assert.ok(!paid.includes("Made with Widgetry") && paid.includes("d-tight") && paid.includes("Key Highlights") && paid.includes('class="photo"') && paid.includes("--rs-accent:#7a1f2b"));
    assert.ok(resumeHtml(who, { template: "impact" }, true, false).includes("Key Highlights"), "a Pro template's preview shows what Pro gives");
    // PDF: made by Chromium; Premium templates come with the watermark
    if (hasChromium) {
      const pdf = await bin("/resume/pdf", {}, ME);
      assert.equal(pdf.status, 200);
      assert.equal(pdf.bytes.subarray(0, 5).toString(), "%PDF-");
      assert.deepEqual([pdf.headers.get("x-resume-pages"), pdf.headers.get("x-resume-watermark")], ["1", "0"]);
      const pro = await bin("/resume/pdf", { template: "elegant" }, ME);
      assert.equal(pro.headers.get("x-resume-watermark"), "1", "Premium template without Premium");
    }
    assert.equal((await bin("/resume/pdf", { template: "nope" }, ME)).status, 400);
    assert.equal((await bin("/resume/pdf", {}, OTHER)).status, 404, "no resume yet");

    // ATS check for the app: the role's keywords, or a pasted job
    let a = await call("POST", "/resume/ats", {}, ME);
    assert.equal(a.status, 200);
    assert.ok(a.body.result.score > 0 && a.body.result.categories.length >= 6);
    assert.equal((await call("POST", "/resume/ats", { jobText: "too short" }, ME)).status, 400);
    a = await call("POST", "/resume/ats", { jobText: "Android developer with Kotlin, Jetpack Compose, Hilt, Room and Coroutines for our payments app. 3+ years. GraphQL is a plus." }, ME);
    assert.equal(a.body.result.mode, "job");
    assert.ok(a.body.result.keywords.missing.includes("GraphQL"));

    // Import: a two-column PDF and a Word file, read on the server (for the app)
    let im = await raw("/resume/import", readFileSync(new URL("./fixtures/two-column-resume.pdf", import.meta.url)), "application/pdf");
    assert.equal(im.status, 200, JSON.stringify(im.body));
    assert.equal(im.body.profile.fullName, "Rohan Mehta");
    assert.deepEqual(im.body.profile.languages, ["English", "Hindi", "Marathi"], "sidebar read on its own");
    assert.deepEqual(im.body.profile.experience.map((j: any) => j.company), ["PayNow", "ShopKart"]);
    assert.equal(im.body.profile.achievements.length, 2);
    im = await raw("/resume/import", readFileSync(new URL("./fixtures/fresher-resume.docx", import.meta.url)), "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    assert.equal(im.body.profile.fullName, "Rahul Verma");
    assert.equal((await raw("/resume/import", Buffer.from("hello, not a resume"), "application/octet-stream")).status, 400);
    // With AI: the model's reading wins, made-up shapes are cleaned, the parser fills gaps
    setChatModel(async () => ({ text: JSON.stringify({ fullName: "Rohan Mehta", headline: "Senior Android Developer", experienceYears: 6, skills: ["Kotlin", "Compose"],
      experience: [{ company: "PayNow", role: "Senior Android Developer", start: "2022-03", end: "present?", points: ["Led migration", ""] }], apps: [{ name: "", url: "x" }], languages: [] }),
      stopReason: "end_turn", inputTokens: 1200, outputTokens: 400 }));
    im = await call("POST", "/resume/import", { text: "ROHAN MEHTA\nSenior Android Developer\nrohan@x.dev\nLANGUAGES\nEnglish, Hindi\nEXPERIENCE\nSenior Android Developer | PayNow | Mar 2022 - Present\n• Led migration", ai: true });
    assert.equal(im.status, 200, JSON.stringify(im.body));
    assert.equal(im.body.ai, true);
    assert.deepEqual([im.body.profile.experience[0].end, im.body.profile.experience[0].points], ["", "Led migration"]);
    assert.deepEqual(im.body.profile.apps, []);
    assert.deepEqual(im.body.profile.languages, ["English", "Hindi"], "parser fills what the AI left empty");
    for (let i = 0; i < 2; i++) await call("POST", "/resume/import", { text: "ROHAN MEHTA\nSenior Android Developer\nrohan@x.dev\nEXPERIENCE\nAndroid | X | 2020 - 2021", ai: true });
    assert.equal((await call("POST", "/resume/import", { text: "ROHAN MEHTA\nSenior Android Developer\nrohan@x.dev\nmore text here to read", ai: true })).status, 429, "3 AI imports a day");

    // Saved copies need Premium
    assert.equal((await call("POST", "/resume/versions", { name: "For PayCo", data: { about: "Aimed at PayCo." } }, ME)).status, 402);

    // Premium bought in the app with Google Play
    process.env.ANDROID_BILLING = "user_choice";
    const g = await call("GET", "/resume/premium");
    assert.equal(g.body.playProductId, "resume_premium_299");
    const o = await call("POST", "/resume/premium/order", { mode: "play" }, ME);
    assert.deepEqual([o.status, o.body.productId], [201, "resume_premium_299"]);
    let consumed = 0;
    setPlayApi({
      async getPurchase(_p, token) { return token === "tok_other_acct_123" ? { purchaseState: 0, orderId: "GPA.9", obfuscatedExternalAccountId: playAccountId("someone") } : { purchaseState: 0, consumptionState: 0, orderId: "GPA.3333-1", obfuscatedExternalAccountId: playAccountId("rv1") }; },
      async consume() { consumed++; }, async reportExternal() { return true; },
    });
    assert.equal((await call("POST", "/resume/premium/play/verify", { productId: "resume_premium_299", purchaseToken: "tok_other_acct_123" }, ME)).status, 403);
    let v = await call("POST", "/resume/premium/play/verify", { productId: "resume_premium_299", purchaseToken: "tok_good_purchase_1" }, ME);
    assert.deepEqual([v.status, v.body.active, consumed], [200, true, 1]);
    v = await call("POST", "/resume/premium/play/verify", { productId: "resume_premium_299", purchaseToken: "tok_good_purchase_1" }, ME);
    assert.deepEqual([v.status, v.body.status], [200, "paid"], "verifying twice is fine");

    // Saved copies: create, use for PDF/ATS, edit, limit, delete
    const c = await call("POST", "/resume/versions", { name: "For PayCo", jobTitle: "Senior Android Developer", company: "PayCo",
      data: { title: "Senior Android Engineer", about: "Android engineer aimed at payments.", skills: ["Kotlin", "GraphQL"], points: [{ index: 0, points: "Built UPI payments" }] }, settings: { template: "classic" } }, ME);
    assert.equal(c.status, 201, JSON.stringify(c.body));
    const vid = c.body.version.id;
    a = await call("POST", "/resume/ats", { versionId: vid, jobText: "Android developer with Kotlin, Jetpack Compose, Hilt, Room and Coroutines for our payments app. 3+ years. GraphQL is a plus." }, ME);
    assert.ok(!a.body.result.keywords.missing.includes("GraphQL"), "the copy's skills are used");
    if (hasChromium) assert.equal((await bin("/resume/pdf", { versionId: vid }, ME)).status, 200);
    assert.equal((await call("POST", "/resume/ats", { versionId: vid }, OTHER)).status, 404, "not someone else's copy");
    const p2 = await call("PATCH", `/resume/versions/${vid}`, { name: "PayCo (final)", data: { about: "Updated." } }, ME);
    assert.deepEqual([p2.body.version.name, p2.body.version.data.about, p2.body.version.data.skills], ["PayCo (final)", "Updated.", ["Kotlin", "GraphQL"]]);
    process.env.RESUME_MAX_VERSIONS = "1";
    assert.equal((await call("POST", "/resume/versions", { name: "Second" }, ME)).status, 409);
    delete process.env.RESUME_MAX_VERSIONS;
    assert.equal((await call("GET", "/resume/versions", undefined, ME)).body.items.length, 1);
    assert.equal((await call("DELETE", `/resume/versions/${vid}`, undefined, ME)).status, 200);
    assert.equal((await call("GET", "/resume/versions", undefined, ME)).body.items.length, 0);

    // Reminder 3 days before it ends, once
    const pushes: string[] = [];
    setSender({ async topic() {}, async tokens(_t, p) { pushes.push(p.title); return []; } });
    await pool.query("INSERT INTO device_tokens (uid, token, platform) VALUES ('rv1', 'devtok-rv1', 'android') ON DUPLICATE KEY UPDATE uid = uid");
    await pool.query("UPDATE resume_premium SET expires_at = UTC_TIMESTAMP() + INTERVAL 2 DAY WHERE uid = 'rv1' AND status = 'paid'");
    const { remindPremiumEnding } = await import("../src/resume.js");
    assert.equal(await remindPremiumEnding(), 1);
    assert.equal(await remindPremiumEnding(), 0, "only once");
    await new Promise(r => setTimeout(r, 50));
    assert.match(pushes.join("|"), /Resume Premium ends in 2 days/);
  } finally {
    setChatModel(null); setPlayApi(null); setSender(null); delete process.env.ANDROID_BILLING;
    await pool.query("DELETE FROM candidates WHERE uid IN ('rv1','rv2')"); await pool.query("DELETE FROM resume_premium WHERE uid = 'rv1'");
    await pool.query("DELETE FROM resume_ai_usage WHERE action = 'import'");
  }
});

test("the API's copy of the resume engine matches the website's", async () => {
  const { SHARED, copyOf } = await import("../scripts/sync-shared.mjs");
  const { readFileSync } = await import("node:fs");
  for (const f of SHARED) assert.equal(readFileSync(new URL(`../src/shared/${f}`, import.meta.url), "utf8"), copyOf(f), `src/shared/${f} is out of date: run npm run sync-shared`);
});

test("Guests (the app before signing in) can preview a resume and see its ATS score; nothing is saved", async () => {
  const { readFileSync } = await import("node:fs");
  const hasChromium = (() => { try { readFileSync(process.env.CHROMIUM_PATH || "/usr/bin/chromium"); return true; } catch { return false; } })();
  const draft = profile({ fullName: "Guest Person", headline: "Flutter Developer", skills: ["Flutter", "Dart", "Bloc"] });
  const before = ((await pool.query("SELECT COUNT(*) AS n FROM candidates")) as any)[0][0].n;
  const ats = await call("POST", "/resume/guest/ats", { profile: draft, jobText: "Flutter Developer\nWe need Flutter, Dart, Bloc, Firebase and CI/CD experience for our fintech app. ".repeat(2) }, undefined, "10.7.7.7");
  assert.equal(ats.status, 200, JSON.stringify(ats.body));
  assert.equal(ats.body.result.mode, "job");
  assert.ok(ats.body.result.keywords.missing.includes("firebase") || ats.body.result.keywords.missing.some((k: string) => /firebase/i.test(k)));
  const bad = await call("POST", "/resume/guest/ats", { profile: { ...draft, fullName: "" } }, undefined, "10.7.7.7");
  assert.equal(bad.status, 400, "the same checks as saving a profile");
  if (hasChromium) {
    const r = await fetch(base + "/resume/guest/pdf", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "10.7.7.7" },
      body: JSON.stringify({ profile: draft, look: { template: "elegant" } }) });
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("x-resume-watermark"), "1", "Premium templates are watermarked for guests");
    assert.equal(Buffer.from(await r.arrayBuffer()).subarray(0, 4).toString(), "%PDF");
  }
  assert.equal(((await pool.query("SELECT COUNT(*) AS n FROM candidates")) as any)[0][0].n, before);
});

test("AI cost cap: over the daily budget every AI feature pauses; admins can see the spend", async () => {
  const { setChatModel, resetAiSpend } = await import("../src/chat.js");
  setChatModel(async () => ({ text: "ok", stopReason: "end_turn", inputTokens: 1000, outputTokens: 200 }));
  const me = "dev:cap1:cap@test.dev:Cap";
  try {
    process.env.AI_DAILY_BUDGET_USD = "0.5"; resetAiSpend();
    assert.equal((await call("POST", "/chat", { message: "What is Bloc?" }, me, "10.8.8.1")).status, 200, "under budget");
    // Someone used a lot of AI today: $1 at Haiku prices
    await pool.query("INSERT INTO resume_ai_usage (uid, action, input_tokens, output_tokens) VALUES ('cap-x', 'tailor', 5000000, 1000000)");
    resetAiSpend();
    const r = await call("POST", "/chat", { message: "And Riverpod?" }, me, "10.8.8.1");
    assert.equal(r.status, 503); assert.match(r.body.error, /resting/);
    const u = await call("GET", "/admin/ai-usage", undefined, ADMIN);
    assert.equal(u.status, 200);
    assert.ok(u.body.last24h.usd >= 1 && u.body.dailyBudgetUsd === 0.5 && u.body.last30d.calls >= u.body.last24h.calls);
    assert.equal((await call("GET", "/admin/ai-usage", undefined, me)).status, 403);
  } finally {
    delete process.env.AI_DAILY_BUDGET_USD; setChatModel(null); resetAiSpend();
    await pool.query("DELETE FROM resume_ai_usage WHERE uid = 'cap-x'");
  }
});
