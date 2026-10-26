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
writeFileSync(join(dir, "resume-parse.mjs"), readFileSync(new URL("resume-parse.js", pub), "utf8").replace("./resume-ats.js", "./resume-ats.mjs"));
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

test("an uploaded resume's text: sections, contact, bullets and keywords are found; scanned files are flagged", async () => {
  const { atsCheckText, splitSections } = await import(pathToFileURL(join(dir, "resume-ats.mjs")).href);
  const resume = `PRIYA NAIR
Flutter Developer
Bengaluru, India | priya@example.com | +91 98765 43210 | linkedin.com/in/priya | github.com/priya
PROFESSIONAL SUMMARY
Flutter developer with 3 years of experience building fintech apps.
TECHNICAL SKILLS
Flutter, Dart, Bloc, Riverpod, Firebase, REST APIs, Git, CI/CD
EXPERIENCE
Flutter Developer | PayCo | Jan 2023 – Present
• Built UPI checkout used by 200k+ users with Bloc and clean architecture
• Cut app start time by 40% by lazy-loading modules
• Responsible for code reviews
PROJECTS
QuickBite – food delivery app on Play Store
• Shipped live order tracking with Google Maps and Firebase for 10k+ downloads
EDUCATION
B.Tech, Computer Science | VIT | 2022`;
  const { sections, headings } = splitSections(resume);
  assert.deepEqual(Object.keys(sections).filter(k => k !== "_top"), ["summary", "skills", "experience", "projects", "education"]);
  assert.equal(headings.length, 5);
  const r = atsCheckText(resume, { title: "Senior Flutter Developer", text: JD }, { pages: 1, fileType: "pdf" });
  assert.ok(r.score >= 60, `score ${r.score}`);
  assert.equal(r.categories.find((c: any) => c.id === "contact").score, 10);
  assert.equal(r.categories.find((c: any) => c.id === "sections").score, 10);
  assert.ok(r.keywords.matched.includes("Riverpod") && r.keywords.matched.includes("Google Maps"));
  assert.equal(r.stats.bullets, 4);
  assert.match(r.categories.flatMap((c: any) => c.tips).join(" "), /Responsible for/);
  assert.equal(r.categories.reduce((s: number, c: any) => s + c.max, 0), 100);

  const scanned = atsCheckText("Priya Nair", null, { pages: 1, fileType: "pdf" });
  assert.equal(scanned.categories.find((c: any) => c.id === "parse").score, 0);
  assert.match(scanned.categories[0].tips[0], /can't read images/);
});

// ---------- Importing an existing resume ----------
const RES_A = `PRIYA NAIR
Flutter Developer
Bengaluru, India | priya@example.com | +91 98765 43210 | linkedin.com/in/priya | github.com/priya
PROFESSIONAL SUMMARY
Flutter developer with 3 years of experience building fintech apps.
TECHNICAL SKILLS
Flutter, Dart, Bloc, Riverpod, Firebase, REST APIs, Git, CI/CD
EXPERIENCE
Flutter Developer | PayCo | Jan 2023 – Present
• Built UPI checkout used by 200k+ users with Bloc and clean architecture
• Cut app start time by 40% by lazy-loading modules
• Responsible for code reviews
Junior Android Developer | TechSoft Solutions, Pune | Jul 2021 - Dec 2022
• Developed 12 screens in Kotlin and Jetpack Compose for a
logistics app with 50k downloads
PROJECTS
QuickBite – food delivery app on Play Store
• Shipped live order tracking with Google Maps and Firebase for 10k+ downloads
EDUCATION
B.Tech, Computer Science | VIT University | 2022 | 8.4 CGPA
Class 12 | DPS Kolkata | 2018 | 91%
CERTIFICATIONS
Flutter in 10 Days - Widgetry Academy (2024)
Associate Android Developer, Google, 2022`;

const RES_B = `Rahul Verma
rahul.verma99@gmail.com
9876501234
Kolkata

Career Objective
To work as a mobile app developer in a growing company where I can use my Flutter skills.

Skills: Flutter, Dart, Firebase, Provider, GetX, Java, Problem Solving, Communication

Internship
Mobile App Developer Intern
Sparks Infotech, Kolkata
June 2024 to Dec 2024
Built login, cart and payment screens with Razorpay for an e-commerce app used by 3,000 customers.
Fixed 25 bugs reported by the QA team and wrote widget tests for the cart flow.

Academic Projects
Expense Tracker (Flutter, Hive) - Offline expense tracker with charts. github.com/rahulv/expense-tracker
Chat App - Real-time chat with Firebase and push notifications

Education
Bachelor of Computer Applications (BCA)
Techno India University, Kolkata
2021 - 2024 | CGPA: 8.1

Hobbies
Cricket, Music`;

const RES_C = `Contact
www.linkedin.com/in/amit-shah-dev (LinkedIn)
amit.shah@outlook.com
Top Skills
Kotlin
Jetpack Compose
MVVM
Amit Shah
Senior Android Engineer at FinBank | Kotlin | Compose
Mumbai, Maharashtra, India
Summary
Android engineer with 6+ years building banking apps used by millions.
Experience
FinBank
Senior Android Engineer
March 2022 - Present (2 years 8 months)
Mumbai, Maharashtra, India
Led migration of 40 screens from XML to Jetpack Compose, cutting UI bugs by 30%.
Introduced Hilt and coroutines across 6 modules.
Zeta Payments
Android Developer
August 2018 - February 2022 (3 years 7 months)
Built the card controls feature with Retrofit and Room used by 2M users.
Education
University of Mumbai
Bachelor of Engineering - BE, Computer Engineering · (2014 - 2018)`;

test("import: a classic resume fills every part of the profile", async () => {
  const { parseResume } = await import(pathToFileURL(join(dir, "resume-parse.mjs")).href);
  const p = parseResume(RES_A);
  assert.equal(p.fullName, "Priya Nair"); assert.equal(p.headline, "Flutter Developer"); assert.equal(p.city, "Bengaluru");
  assert.equal(p.email, "priya@example.com"); assert.equal(p.phone, "+91 98765 43210");
  assert.equal(p.linkedinUrl, "https://linkedin.com/in/priya"); assert.equal(p.githubUrl, "https://github.com/priya");
  assert.equal(p.experienceYears, 3); assert.equal(p.currentCompany, "PayCo"); assert.deepEqual(p.categories, ["flutter"]);
  assert.deepEqual(p.experience.map((j: any) => [j.role, j.company, j.start, j.end]), [["Flutter Developer", "PayCo", "2023-01", ""], ["Junior Android Developer", "TechSoft Solutions", "2021-07", "2022-12"]]);
  assert.equal(p.experience[0].points.split("\n").length, 3);
  assert.match(p.experience[1].points, /for a logistics app/, "a bullet wrapped onto the next line is joined");
  assert.equal(p.apps[0].name, "QuickBite");
  assert.deepEqual(p.education[0], { degree: "B.Tech, Computer Science", institute: "VIT University", year: 2022, score: "8.4 CGPA" });
  assert.deepEqual(p.certifications[1], { name: "Associate Android Developer", issuer: "Google", year: 2022 });
  assert.deepEqual(p.skills.slice(0, 8), ["Flutter", "Dart", "Bloc", "Riverpod", "Firebase", "REST APIs", "Git", "CI/CD"]);
  assert.ok(p.skills.length <= 15);
});

test("import: a fresher's resume without bullets, and a LinkedIn PDF", async () => {
  const { parseResume, toMonth } = await import(pathToFileURL(join(dir, "resume-parse.mjs")).href);
  const b = parseResume(RES_B);
  assert.equal(b.fullName, "Rahul Verma"); assert.equal(b.phone, "9876501234");
  assert.ok(!/Skills:/.test(b.about), "a 'Skills: …' line isn't part of the summary");
  assert.ok(b.skills.includes("GetX") && b.skills.includes("Problem Solving"));
  assert.deepEqual([b.experience[0].role, b.experience[0].company, b.experience[0].start, b.experience[0].end], ["Mobile App Developer Intern", "Sparks Infotech", "2024-06", "2024-12"]);
  assert.equal(b.experience[0].points.split("\n").length, 2);
  assert.deepEqual(b.apps.map((a: any) => a.name), ["Expense Tracker", "Chat App"]);
  assert.equal(b.apps[0].url, "https://github.com/rahulv/expense-tracker"); assert.match(b.apps[0].about, /Tech: Flutter, Hive/);
  assert.equal(b.education[0].degree, "Bachelor of Computer Applications (BCA)"); assert.equal(b.education[0].year, 2024);

  const c = parseResume(RES_C);
  assert.equal(c.fullName, "Amit Shah"); assert.equal(c.city, "Mumbai"); assert.equal(c.experienceYears, 6);
  assert.deepEqual(c.experience.map((j: any) => [j.role, j.company]), [["Senior Android Engineer", "FinBank"], ["Android Developer", "Zeta Payments"]]);
  assert.equal(c.experience[0].points.split("\n").length, 2);
  assert.equal(c.education[0].degree, "Bachelor of Engineering, Computer Engineering"); assert.deepEqual(c.categories, ["android"]);

  assert.equal(toMonth("Sept 2021"), "2021-09"); assert.equal(toMonth("03/2020"), "2020-03"); assert.equal(toMonth("Jan'23"), "2023-01"); assert.equal(toMonth("2019", true), "2019-12");
  assert.deepEqual(parseResume("").experience, []);
});
