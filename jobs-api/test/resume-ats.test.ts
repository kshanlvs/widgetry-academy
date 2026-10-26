// The free ATS check (public/resume-ats.js) runs in the browser; these tests run the same file in Node.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// The website's files are plain browser modules (.js outside any "type": "module" package), so load copies as .mjs
const dir = mkdtempSync(join(tmpdir(), "ats-"));
const pub = new URL("../../public/", import.meta.url);
writeFileSync(join(dir, "resume-render.mjs"), readFileSync(new URL("resume-render.js", pub), "utf8"));
writeFileSync(join(dir, "resume-ats.mjs"), readFileSync(new URL("resume-ats.js", pub), "utf8").replace("./resume-render.js", "./resume-render.mjs"));
const { atsCheck, findSkills, jobYears, jobRole, norm } = await import(pathToFileURL(join(dir, "resume-ats.mjs")).href);
const { SAMPLE } = await import(pathToFileURL(join(dir, "resume-render.mjs")).href);

const JD = `Senior Flutter Developer (Bengaluru)
We're looking for 3+ years of Flutter and Dart. You'll use Bloc and Riverpod, integrate REST APIs and Firebase, write unit tests and widget tests,
and ship to the Play Store and App Store with CI/CD (GitHub Actions). Experience with Google Maps and push notifications is a plus.
Our team values clean architecture and code reviews. There's room to grow, and we combine design and engineering.`;

test("skills are found by any common spelling, whole words only", () => {
  const s = findSkills("Built apps with flutter_bloc, Kotlin coroutines, FCM and a RESTful backend; git and github");
  for (const k of ["Bloc", "Coroutines", "Push Notifications", "REST APIs", "Git", "GitHub"]) assert.ok(s.has(k), k);
  assert.ok(!findSkills("digital marketing").has("Git"), "no matches inside other words");
  assert.equal(norm("CI/CD, Node.js!"), " ci/cd node.js ");
});

test("everyday words in a job description aren't mistaken for skills", () => {
  const s = findSkills(JD, true);
  assert.ok(!s.has("Room") && !s.has("Combine"), "\"room to grow\" and \"we combine\" are not Room or Combine");
  assert.ok(findSkills("Used Room and Combine", true).has("Room"));
});

test("years and role are read from a job description", () => {
  assert.deepEqual(jobYears("Need 3+ years of Flutter"), { min: 3, max: null });
  assert.deepEqual(jobYears("2-4 yrs experience"), { min: 2, max: 4 });
  assert.equal(jobYears("No experience needed"), null);
  assert.equal(jobRole("Senior iOS Engineer (Swift)"), "ios");
  assert.equal(jobRole("React Native Developer"), "react-native");
});

test("a strong resume scores well against a matching job, and the gaps are named", () => {
  const r = atsCheck({ ...SAMPLE, categories: ["flutter"] }, { title: "Senior Flutter Developer", text: JD });
  assert.equal(r.mode, "job");
  assert.ok(r.score >= 70, `score ${r.score}`);
  assert.ok(r.keywords.matched.includes("Bloc") && r.keywords.matched.includes("Firebase"));
  assert.ok(r.keywords.missing.includes("Riverpod") && r.keywords.missing.includes("GitHub Actions"));
  assert.ok(r.keywords.key.includes("Flutter"), "the job title's skills are key");
  assert.equal(r.categories.reduce((s: number, c: any) => s + c.max, 0), 100);
});

test("a thin resume scores low with concrete tips; without a job it checks the role's keywords", () => {
  const thin = { fullName: "Ravi", headline: "Developer", skills: ["Flutter"], experience: [{ role: "Intern", company: "X", start: "2025-01", points: "Responsible for working on screens\nI helped the team" }], categories: ["flutter"] };
  const r = atsCheck(thin);
  assert.equal(r.mode, "role");
  assert.ok(r.score < 50, `score ${r.score}`);
  const tips = r.categories.flatMap((c: any) => c.tips).join(" ");
  assert.match(tips, /Responsible for/);
  assert.match(tips, /numbers/);
  assert.match(tips, /"I"/);
  assert.ok(r.keywords.missing.includes("Dart"));
  // Photos cost a little: some ATS can't parse them
  const withPhoto = atsCheck({ ...SAMPLE, photo: "data:image/png;base64,AA==" }, null, { showPhoto: true });
  assert.equal(withPhoto.categories.find((c: any) => c.id === "format").score, 2);
});
