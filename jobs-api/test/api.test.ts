// End-to-end API tests against a real MySQL database.
// Run: DB_PORT=3307 DB_PASSWORD=devpass ALLOW_DEV_AUTH=1 npm test
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import type { Server } from "node:http";
import { createApp } from "../src/app.js";
import { pool } from "../src/db.js";
import { migrate } from "../src/migrate.js";
import { setSender } from "../src/notify.js";
import { createHmac } from "node:crypto";
import { setPaymentServices, type Registration } from "../src/payments.js";
import { setPlayApi, playAccountId } from "../src/play.js";
import { setAccountServices } from "../src/routes/account.js";

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

test("categories: Flutter, Android and iOS jobs and seekers", async () => {
  const meta = (await call("GET", "/meta")).body;
  assert.deepEqual(meta.categories.map((c: any) => c.slug), ["flutter", "android", "ios"]);
  assert.ok(meta.categories[1].suggestedSkills.includes("Jetpack Compose"));
  const desc = "Build our Android app in Kotlin with Jetpack Compose, coroutines and MVVM. Work with design and backend teams and ship every sprint.";
  const android = { category: "android", companyName: "Droid Co", title: "Android Developer", jobType: "full_time", workMode: "remote", level: "mid", description: desc, skills: ["kotlin", "jetpack compose"], applyUrl: "https://droid.test/careers/android" };
  assert.equal((await call("POST", "/admin/jobs", { ...android, category: "react-native" }, ADMIN)).status, 400, "unknown category refused");
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
