// GENERATED from public/resume-ats.js by `npm run sync-shared`. Edit the website file, not this one.
// Widgetry ATS check: how a resume reads to screening software, and how well it matches a job.
//
// Runs in the browser (free, instant, nothing leaves the page). Without a job description it checks the
// resume against what recruiters expect for the person's role (Flutter, Android, iOS or React Native).
// With one, it compares the resume's keywords with the job's, the way most ATS rank candidates.
//
// It is a guide, not a promise: every ATS (Workday, Greenhouse, Lever, Naukri RMS…) scores differently.

import { autoSummary } from "./resume-render.js";

// ---------- Vocabulary ----------
// [canonical name, ...other ways people write it]. Very short aliases ("js", "di") are left out on purpose:
// they match too many unrelated words.
export const SKILLS = [
  ["Flutter"], ["Dart"], ["Kotlin"], ["Swift"], ["Java"], ["Objective-C", "objective c", "objc"],
  ["JavaScript", "javascript", "es6"], ["TypeScript"], ["React Native", "react-native"], ["React", "react.js", "reactjs"],
  ["Jetpack Compose", "compose ui"], ["Jetpack", "android jetpack", "architecture components"], ["SwiftUI"], ["UIKit"], ["XML Layouts", "xml layout"],
  ["Bloc", "flutter_bloc", "cubit"], ["Provider"], ["Riverpod"], ["GetX"], ["MobX"], ["Redux"],
  ["Coroutines", "kotlin coroutines"], ["Kotlin Flow", "stateflow", "sharedflow"], ["Combine"], ["RxJava"], ["RxSwift"], ["async/await", "async await"],
  ["Firebase"], ["Firestore", "cloud firestore"], ["Firebase Auth", "firebase authentication"], ["Crashlytics"], ["Remote Config"],
  ["REST APIs", "rest api", "restful", "rest apis", "web services"], ["GraphQL"], ["WebSockets", "websocket", "socket.io"],
  ["Retrofit"], ["OkHttp"], ["Dio"], ["Alamofire"], ["JSON"],
  ["Room"], ["Core Data"], ["SQLite"], ["Hive"], ["Realm"], ["Isar"], ["SharedPreferences", "shared preferences"],
  ["Google Maps", "maps sdk", "mapbox"], ["Push Notifications", "push notification", "fcm", "apns", "firebase cloud messaging"],
  ["Supabase"], ["Node.js", "nodejs", "node js"], ["Expo"],
  ["Clean Architecture"], ["MVVM"], ["MVI"], ["MVC"], ["VIPER"], ["SOLID Principles", "solid principles", "solid design principles"], ["Design Patterns", "design pattern"],
  ["Dependency Injection", "dependency injection"], ["Hilt"], ["Dagger"], ["get_it", "getit"], ["injectable"], ["Koin"],
  ["Unit Testing", "unit test", "unit tests", "unit testing"], ["Widget Testing", "widget test", "widget tests"],
  ["Integration Testing", "integration test", "integration tests"], ["UI Testing", "ui test", "ui tests"], ["TDD", "test driven"],
  ["bloc_test"], ["Mockito"], ["mocktail"], ["Espresso"], ["XCTest"], ["Jest"], ["Detox"],
  ["CI/CD", "ci cd", "ci/cd", "continuous integration", "continuous delivery"], ["GitHub Actions"], ["Fastlane"], ["Codemagic"], ["Bitrise"],
  ["Gradle"], ["Xcode"], ["Android Studio"], ["Git"], ["GitHub"], ["Jira"], ["Agile", "scrum", "sprint"],
  ["Play Store", "google play", "play console"], ["App Store", "app store connect", "testflight"],
  ["Animations", "animation", "lottie"], ["Material Design"], ["Figma"], ["Responsive UI", "responsive design", "responsive layouts"],
  ["Performance Optimization", "performance optimisation", "performance tuning", "app performance"], ["Memory Management", "memory leaks"],
  ["Offline-first", "offline first", "offline support", "offline mode"], ["Bluetooth", "ble", "bluetooth low energy", "corebluetooth"],
  ["In-App Purchases", "in-app purchase", "in app purchase", "storekit", "play billing"], ["Payment Gateway", "payment gateway", "razorpay", "stripe", "upi"],
  ["Analytics", "firebase analytics", "mixpanel", "amplitude"], ["Accessibility", "a11y"], ["Localization", "localisation", "l10n", "i18n"],
  ["Kotlin Multiplatform", "kmm", "kmp"], ["Platform Channels", "platform channel", "method channel", "methodchannel"],
  ["App Security", "ssl pinning", "certificate pinning", "obfuscation", "keychain", "keystore"],
  ["Deep Links", "deep link", "deeplink", "universal links", "app links"], ["Background Tasks", "workmanager", "background services", "background processing"],
  ["Camera", "camerax"], ["AWS"], ["Docker"], ["Python"], ["Machine Learning", "ml kit", "mlkit", "tensorflow lite", "tflite"],
  ["Generative AI", "llm", "openai", "gemini", "claude", "ai integration"], ["Data Structures", "data structures", "dsa", "algorithms"],
  ["Code Review", "code reviews"], ["Mentoring", "mentor", "mentored"], ["Flame"], ["Unity"],
];
const CANON = new Map(SKILLS.map(([c]) => [c.toLowerCase(), c]));

// What recruiters expect to see for each kind of mobile role when there is no job description
const ROLE_KEYWORDS = {
  flutter: ["Flutter", "Dart", "Bloc", "Provider", "Riverpod", "REST APIs", "Firebase", "Clean Architecture", "Unit Testing", "Git", "Play Store", "App Store", "CI/CD", "Animations", "Platform Channels"],
  android: ["Kotlin", "Java", "Jetpack", "Jetpack Compose", "MVVM", "Coroutines", "Kotlin Flow", "Retrofit", "Room", "Hilt", "REST APIs", "Unit Testing", "Git", "Play Store", "Gradle"],
  ios: ["Swift", "SwiftUI", "UIKit", "Combine", "async/await", "MVVM", "Core Data", "REST APIs", "XCTest", "Xcode", "Git", "App Store", "Push Notifications", "Memory Management", "CI/CD"],
  "react-native": ["React Native", "JavaScript", "TypeScript", "React", "Redux", "REST APIs", "Expo", "Jest", "Firebase", "Git", "Play Store", "App Store", "Push Notifications", "Performance Optimization", "CI/CD"],
};

const ACTION_VERBS = new Set(("built,developed,designed,led,launched,shipped,created,implemented,improved,reduced,increased,cut,optimized,optimised,migrated," +
  "refactored,automated,integrated,architected,owned,delivered,scaled,mentored,introduced,rebuilt,redesigned,added,wrote,set,setup,established,drove," +
  "managed,coordinated,collaborated,partnered,enabled,streamlined,accelerated,boosted,raised,lowered,fixed,resolved,debugged,tested,published,released," +
  "deployed,maintained,converted,modernized,modernised,replaced,spearheaded,initiated,engineered,prototyped,researched,analysed,analyzed,documented,trained," +
  "onboarded,supported,contributed,secured,achieved,won,grew,saved,handled,ported,localized,localised,configured,crafted,conducted,translated").split(","));
const WEAK_STARTS = /^(responsible for|worked on|working on|involved in|helped|assisted|part of|tasked with|duties included|handling)\b/i;
const CLICHES = ["hardworking", "hard working", "hard-working", "team player", "go-getter", "self-motivated", "results-driven", "results oriented",
  "detail-oriented", "think outside the box", "dynamic", "synergy", "passionate about everything", "quick learner", "fast learner", "best of my knowledge", "perfectionist"];

// ---------- Text helpers ----------
const lines = t => String(t || "").split(/\n+/).map(s => s.replace(/^\s*[-•*·]\s*/, "").trim()).filter(Boolean);
const words = t => (String(t || "").match(/[A-Za-z0-9+#.'/-]+/g) || []);
/** Lower case with punctuation turned into spaces (keeping + # / . _ - inside words), padded so " term " matches whole words. */
export const norm = t => " " + String(t || "").toLowerCase().replace(/[^a-z0-9+#/._\- ]+/g, " ").replace(/(\s)[._\-/]+|[._\-/]+(\s)/g, "$1$2").replace(/\s+/g, " ").trim() + " ";
const has = (n, term) => n.includes(" " + norm(term).trim() + " ");

// Skills that are also everyday English ("combine design and code", "room to grow", "service provider"):
// in a job description they only count when written with a capital letter, as a tool name would be.
const EVERYDAY = { Combine: /\bCombine\b/g, Room: /\bRoom\b/g, Provider: /\bProvider\b/g };

/** Canonical skills mentioned in a text, with how often. strict: apply the EVERYDAY rule (for job descriptions). */
export function findSkills(text, strict = false) {
  const n = norm(text), found = new Map();
  for (const [canon, ...aliases] of SKILLS) {
    if (strict && EVERYDAY[canon]) {
      const c = (String(text).match(EVERYDAY[canon]) || []).length;
      if (c) found.set(canon, c);
      continue;
    }
    let count = 0;
    for (const a of [canon, ...aliases]) {
      const t = " " + norm(a).trim() + " ";
      if (t.trim().length < 2) continue;
      let i = n.indexOf(t);
      while (i !== -1) { count++; i = n.indexOf(t, i + 1); }
    }
    if (count) found.set(canon, count);
  }
  // "GitHub Actions" also contains "GitHub", "React Native" contains "React": drop the shorter one when every mention was part of the longer
  for (const [k, c] of [...found]) {
    const longer = [...found].filter(([o]) => o !== k && o.toLowerCase().startsWith(k.toLowerCase() + " ")).reduce((s, [, oc]) => s + oc, 0);
    if (longer >= c) found.delete(k);
  }
  return found;
}

/** The resume's whole text, as ATS software extracts it from the PDF. */
export function resumeText(p, opts = {}) {
  const parts = [p.fullName, opts.title || p.headline, (p.about || "").trim() || autoSummary(p), (p.skills || []).join(", ")];
  for (const w of p.experience || []) parts.push(`${w.role} ${w.company}`, ...lines(w.points));
  for (const a of p.apps || []) parts.push(`${a.name} ${a.role || ""}`, a.about || "");
  for (const e of p.education || []) parts.push(`${e.degree} ${e.institute}`);
  for (const c of p.certifications || []) parts.push(c.name);
  for (const a of p.achievements || []) parts.push(a);
  return parts.filter(Boolean).join("\n");
}

/** Years of experience a job asks for ("3+ years", "2-4 years", "minimum 5 yrs"), or null. */
export function jobYears(jd) {
  const m = /(\d{1,2})\s*(?:\+|plus)?\s*(?:(?:-|–|to)\s*(\d{1,2}))?\s*\+?\s*(?:years?|yrs?)/i.exec(String(jd || ""));
  return m ? { min: Number(m[1]), max: m[2] ? Number(m[2]) : null } : null;
}

/** The role a job is for, from its title or text. */
export function jobRole(text) {
  const n = norm(text);
  if (has(n, "react native")) return "react-native";
  if (has(n, "flutter")) return "flutter";
  if (has(n, "ios") || has(n, "swift") || has(n, "swiftui")) return "ios";
  if (has(n, "android") || has(n, "kotlin")) return "android";
  return null;
}

const rate = (r, max) => Math.round(Math.max(0, Math.min(1, r)) * max);
const status = (got, max) => (got >= max * 0.8 ? "good" : got >= max * 0.5 ? "ok" : "bad");

/**
 * Scores a profile out of 100.
 * job: optional { text, title } (a pasted job description or a Widgetry job). opts: the resume settings (title, hide, showPhoto).
 * Returns { score, grade, mode, categories: [{ id, label, score, max, status, detail, tips }], keywords: { matched, missing, key }, stats }.
 */
export function atsCheck(p, job = null, opts = {}) {
  const hide = new Set(opts.hide || []);
  const jd = job && String(job.text || "").trim().length >= 80 ? job : null;
  const text = resumeText(p, opts);
  const n = norm(text);
  const have = findSkills(text);
  const bullets = (p.experience || []).flatMap(w => lines(w.points)).concat((p.apps || []).map(a => a.about).filter(Boolean));
  const cats = [];
  const add = (id, label, got, max, detail, tips = []) => cats.push({ id, label, score: got, max, status: status(got, max), detail, tips });

  // 1. Keywords: the job's (or the role's) skills found in the resume
  let wanted, key = [];
  if (jd) {
    const inJob = findSkills(`${jd.title || ""}\n${jd.text}`, true);
    wanted = [...inJob.keys()];
    key = wanted.filter(k => inJob.get(k) >= 2 || norm(jd.title || "").includes(" " + norm(k).trim() + " "));
  } else {
    const role = (p.categories || []).find(c => ROLE_KEYWORDS[c]) || jobRole(`${opts.title || ""} ${p.headline} ${(p.skills || []).join(" ")}`) || "flutter";
    wanted = ROLE_KEYWORDS[role];
  }
  const matched = wanted.filter(k => have.has(k)), missing = wanted.filter(k => !have.has(k));
  // Key skills (asked for twice, or in the job title) count double
  const weight = k => (key.includes(k) ? 2 : 1);
  const total = wanted.reduce((s, k) => s + weight(k), 0) || 1;
  const kwRatio = matched.reduce((s, k) => s + weight(k), 0) / total;
  const kwMax = jd ? 35 : 25;
  add("keywords", jd ? "Job keyword match" : "Role keywords", rate(kwRatio / 0.85, kwMax), kwMax,
    wanted.length ? `${matched.length} of ${wanted.length} ${jd ? "skills from the job" : "skills recruiters look for"} are on your resume` : "No technical skills found in this job description",
    missing.length ? [`Add the skills you really have: ${missing.slice(0, 8).join(", ")}. Mention them in your skills and in a bullet that shows how you used them.`] : []);

  // 2. Title and experience fit (job only)
  if (jd) {
    const role = jobRole(`${jd.title || ""} ${jd.text.slice(0, 400)}`);
    const titleN = norm(`${opts.title || ""} ${p.headline}`);
    const titleOk = !role || has(titleN, role === "react-native" ? "react native" : role) || has(titleN, "mobile");
    const yrs = jobYears(jd.text), mine = Number(p.experienceYears) || 0;
    const yrsOk = !yrs || mine >= yrs.min || (yrs.min - mine <= 1);
    add("fit", "Title and experience fit", (titleOk ? 5 : 0) + (yrsOk ? 5 : yrs && mine >= yrs.min - 2 ? 2 : 0), 10,
      [titleOk ? "Your title matches the role" : "Your title doesn't name the role", yrs ? `job asks for ${yrs.min}${yrs.max ? "–" + yrs.max : "+"} years, you have ${mine}` : ""].filter(Boolean).join(" · "),
      [!titleOk && `Set your target job title to match the role, e.g. "${role === "react-native" ? "React Native" : role === "ios" ? "iOS" : role ? role[0].toUpperCase() + role.slice(1) : "Mobile"} Developer".`,
       !yrsOk && "You have less experience than asked. Lead with projects and measurable results, and apply anyway if the rest fits."].filter(Boolean));
  }

  // 3. Contact details recruiters and ATS parse
  const contact = [[!!p.fullName, "your full name"], [!!p.email && !hide.has("email"), "an email address"], [!!p.phone && !hide.has("phone"), "a phone number"],
    [!!p.city && !hide.has("city"), "your city"], [!!(p.linkedinUrl || p.githubUrl), "a LinkedIn or GitHub link"]];
  const cOk = contact.filter(c => c[0]).length;
  add("contact", "Contact details", rate(cOk / contact.length, 10), 10, `${cOk} of ${contact.length} present`,
    contact.filter(c => !c[0]).length ? [`Add ${contact.filter(c => !c[0]).map(c => c[1]).join(", ")}.`] : []);

  // 4. Standard sections ATS look for
  const work = p.experience || [];
  const secs = [[!hide.has("summary"), "Professional Summary"], [(p.skills || []).length >= 6, "Technical Skills (6 or more)"],
    [work.length > 0 || (p.apps || []).length > 0, "Experience or Projects"], [(p.education || []).length > 0 && !hide.has("education"), "Education"]];
  const sOk = secs.filter(s => s[0]).length;
  add("sections", "Standard sections", rate(sOk / secs.length, 10), 10, `${sOk} of ${secs.length} sections`,
    secs.filter(s => !s[0]).map(s => `Add a ${s[1]} section.`));

  // 5. Impact: numbers and strong verbs
  const quant = bullets.filter(b => /\d/.test(b)).length;
  const strong = bullets.filter(b => ACTION_VERBS.has((b.match(/^[A-Za-z]+/) || [""])[0].toLowerCase())).length;
  const weak = bullets.filter(b => WEAK_STARTS.test(b));
  const qR = bullets.length ? quant / bullets.length : 0, vR = bullets.length ? strong / bullets.length : 0;
  const impactMax = jd ? 15 : 20;
  add("impact", "Impact and results", bullets.length ? rate((Math.min(qR / 0.5, 1) * 0.6) + (Math.min(vR / 0.7, 1) * 0.4), impactMax) : 0, impactMax,
    bullets.length ? `${quant} of ${bullets.length} points have numbers · ${strong} start with a strong action verb` : "No achievement points yet",
    [!bullets.length && "Add 2–4 achievement points under each job or project.",
     bullets.length && qR < 0.5 && "Add numbers to more points: users, downloads, % faster, crash rate, screens built, time saved.",
     bullets.length && vR < 0.7 && "Start each point with an action verb: Built, Led, Cut, Shipped, Migrated, Improved.",
     weak.length && `Rewrite points that start with "${(weak[0].match(WEAK_STARTS) || [""])[0]}": say what you did and the result.`].filter(Boolean));

  // 6. Clarity: bullet length, first person, clichés
  const tooLong = bullets.filter(b => words(b).length > 35).length, tooShort = bullets.filter(b => words(b).length < 6).length;
  const firstPerson = /(^|\s)(i|my|me)\s/i.test(" " + bullets.join(" ") + " ");
  const cliches = CLICHES.filter(c => n.includes(" " + c + " ") || n.includes(" " + c.replace(/-/g, " ") + " "));
  let clarity = 10 - Math.min(4, tooLong * 2) - Math.min(2, tooShort) - (firstPerson ? 2 : 0) - Math.min(3, cliches.length);
  if (!bullets.length) clarity = 4;
  add("clarity", "Clear, scannable writing", Math.max(0, clarity), 10,
    [tooLong && `${tooLong} point${tooLong > 1 ? "s are" : " is"} too long`, tooShort && `${tooShort} too short`, firstPerson && "uses \"I\"/\"my\"", cliches.length && `clichés: ${cliches.slice(0, 3).join(", ")}`].filter(Boolean).join(" · ") || "Points are short and direct",
    [tooLong && "Keep each point to one or two lines (under 30 words).", firstPerson && "Drop \"I\" and \"my\" from points: start with the verb.",
     cliches.length && `Replace "${cliches[0]}" with evidence: a result, a project, a number.`].filter(Boolean));

  // 7. Length: about one page for under 5 years, two for more
  const wc = words(text).length, yrs = Number(p.experienceYears) || 0, hi = yrs >= 5 ? 1100 : 750;
  const lenOk = wc >= 250 && wc <= hi;
  add("length", "Length", lenOk ? 5 : wc < 150 || wc > hi + 400 ? 1 : 3, 5, `About ${wc} words`,
    [wc < 250 && "Your resume is thin. Add projects, achievements and skills you've used.", wc > hi && `Trim to about ${hi} words: keep the last 5–7 years and your strongest points.`].filter(Boolean));

  // 8. Format: our templates are built for ATS; a photo is the one thing some parsers trip on
  const photo = opts.showPhoto && !hide.has("photo") && !!p.photo;
  add("format", "ATS-safe format", photo ? 2 : 5, 5, photo ? "Photo shown" : "One column, real text, standard headings",
    photo ? ["Turn the photo off: many ATS and most Indian IT companies don't want one."] : []);

  const max = cats.reduce((s, c) => s + c.max, 0), got = cats.reduce((s, c) => s + c.score, 0);
  const score = Math.round((got / max) * 100);
  const grade = score >= 85 ? "Excellent" : score >= 70 ? "Strong" : score >= 50 ? "Fair" : "Needs work";
  return {
    score, grade, mode: jd ? "job" : "role", categories: cats,
    keywords: { matched, missing, key },
    stats: { words: wc, bullets: bullets.length, quantified: quant, actionStarts: strong },
  };
}

// ---------- Checking an uploaded resume (PDF, Word or pasted text) ----------

// Headings ATS look for, and the other names people give them
const SECTION_NAMES = {
  summary: /^(professional\s+|career\s+|profile\s+)?(summary|profile|objective|career objective|about me|about|overview)$/i,
  skills: /^(technical\s+|key\s+|core\s+|professional\s+)?(skills|skill set|skillset|technologies|tech stack|competencies|expertise|tools)(\s*(&|and)\s*(tools|technologies|expertise|languages|frameworks))?$/i,
  experience: /^(professional\s+|work\s+|relevant\s+|industry\s+)?(experience|employment|work history|internships?|employment history|career history)(\s*(&|and)\s*internships?)?$/i,
  projects: /^(personal\s+|academic\s+|key\s+|notable\s+|side\s+|selected\s+|major\s+)?(projects|portfolio|apps|apps built|applications)$/i,
  education: /^(education|academic background|academics|academic details|qualifications?|educational qualifications?|education\s*(&|and)\s*training)$/i,
  certifications: /^(certifications?|certificates|courses|training|licenses|licenses\s*(&|and)\s*certifications|certifications?\s*(&|and)\s*(courses|training))$/i,
  // Headings that end a section but aren't scored
  achievements: /^(key\s+)?(achievements?|accomplishments|awards?|honou?rs|awards\s*(&|and)\s*(achievements|honou?rs)|achievements\s*(&|and)\s*awards|hackathons?|positions? of responsibility|extra[- ]curricular( activities)?|leadership)$/i,
  languages: /^languages( known| spoken)?$/i,
  other: /^(hobbies|interests|hobbies\s*(&|and)\s*interests|personal details|personal information|personal profile|declaration|references|strengths|activities|volunteering|publications|contact|contact details|top skills)$/i,
};
const CITY = /\b(bengaluru|bangalore|mumbai|pune|hyderabad|chennai|kolkata|delhi|new delhi|noida|gurugram|gurgaon|ahmedabad|jaipur|indore|kochi|coimbatore|chandigarh|lucknow|bhubaneswar|nagpur|surat|vadodara|india)\b/i;

/** Splits plain resume text into sections by their headings. */
export function splitSections(text) {
  const out = { _top: [] }; let cur = "_top";
  const found = [];
  for (const raw of String(text).split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const clean = line.replace(/[:|•·\-–—_=*#]+$/g, "").replace(/^[\s•·\-*#]+/, "").trim();
    const key = clean.length <= 40 && Object.keys(SECTION_NAMES).find(k => SECTION_NAMES[k].test(clean));
    if (key) { cur = key; out[cur] ||= []; found.push(clean); continue; }
    (out[cur] ||= []).push(line);
  }
  return { sections: out, headings: found };
}

/** Years of experience from "3+ years" in the text, else from the earliest year in the experience section. */
function resumeYears(text, expLines) {
  const m = /(\d{1,2})\+?\s*(?:years?|yrs?)\s+(?:of\s+)?(?:experience|exp)/i.exec(text);
  if (m) return Number(m[1]);
  const years = (expLines.join(" ").match(/\b(19[89]\d|20[0-4]\d)\b/g) || []).map(Number);
  return years.length ? Math.max(0, new Date().getFullYear() - Math.min(...years)) : null;
}

/**
 * Scores an uploaded resume's text out of 100, the same way as atsCheck.
 * info: { pages, fileType: "pdf"|"docx"|"text" } from the file reader.
 */
export function atsCheckText(rawText, job = null, info = {}) {
  const text = String(rawText || "").replace(/\u00a0/g, " ");
  const jd = job && String(job.text || "").trim().length >= 80 ? job : null;
  const { sections, headings } = splitSections(text);
  const n = norm(text);
  const have = findSkills(text);
  const wc = words(text).length;
  const cats = [];
  const add = (id, label, got, max, detail, tips = []) => cats.push({ id, label, score: got, max, status: status(got, max), detail, tips });

  // 1. Can ATS read it at all?
  const pages = info.pages || Math.max(1, Math.round(wc / 450));
  const perPage = wc / pages;
  const spaced = /(?:\b[A-Z] ){4,}[A-Z]\b/.test(text);                       // "S K I L L S"
  const junk = (text.match(/[\uFFFD\uE000-\uF8FF]/g) || []).length;          // unreadable characters (icon fonts, broken encodings)
  const readable = perPage >= 60 && junk < 8 && !spaced;
  add("parse", "ATS can read it", readable ? 10 : perPage < 40 ? 0 : 5, 10,
    perPage < 40 ? "Almost no text could be read: it's probably a scanned image or a design export" : readable ? `Text extracted cleanly${info.fileType && info.fileType !== "text" ? ` from your ${info.fileType === "pdf" ? "PDF" : "Word file"}` : ""}` : "Some text couldn't be read cleanly",
    [perPage < 40 && "ATS can't read images. Export your resume as a text PDF from Word or Google Docs, or build one with Widgetry.",
     spaced && "Letter-spaced headings (S K I L L S) are read as single letters. Use normal spacing.",
     junk >= 8 && "Icons or special fonts came out as unreadable symbols. Replace icons with plain text (Email:, Phone:).",
     readable && pages > 2 && "Keep it to 1–2 pages."].filter(Boolean));

  // 2. Keywords
  let wanted, key = [];
  if (jd) {
    const inJob = findSkills(`${jd.title || ""}\n${jd.text}`, true);
    wanted = [...inJob.keys()];
    key = wanted.filter(k => inJob.get(k) >= 2 || norm(jd.title || "").includes(" " + norm(k).trim() + " "));
  } else {
    const role = jobRole((sections._top || []).slice(0, 6).join(" ") + " " + text.slice(0, 1500)) || "flutter";
    wanted = ROLE_KEYWORDS[role];
  }
  const matched = wanted.filter(k => have.has(k)), missing = wanted.filter(k => !have.has(k));
  const weight = k => (key.includes(k) ? 2 : 1);
  const total = wanted.reduce((s, k) => s + weight(k), 0) || 1;
  const kwMax = jd ? 30 : 25;
  add("keywords", jd ? "Job keyword match" : "Role keywords", rate((matched.reduce((s, k) => s + weight(k), 0) / total) / 0.85, kwMax), kwMax,
    wanted.length ? `${matched.length} of ${wanted.length} ${jd ? "skills from the job" : "skills recruiters look for"} are on your resume` : "No technical skills found in this job description",
    missing.length ? [`Add the skills you really have: ${missing.slice(0, 8).join(", ")}. Put them in your skills section and in a point that shows how you used them.`] : []);

  // 3. Fit (job only)
  if (jd) {
    const role = jobRole(`${jd.title || ""} ${jd.text.slice(0, 400)}`);
    const top = norm((sections._top || []).slice(0, 5).join(" "));
    const titleOk = !role || has(top, role === "react-native" ? "react native" : role) || has(top, "mobile");
    const yrs = jobYears(jd.text), mine = resumeYears(text, sections.experience || []);
    const yrsOk = !yrs || mine == null || mine >= yrs.min - 1;
    add("fit", "Title and experience fit", (titleOk ? 5 : 0) + (yrsOk ? 5 : 2), 10,
      [titleOk ? "Your headline matches the role" : "Your headline doesn't name the role", yrs ? `job asks for ${yrs.min}${yrs.max ? "–" + yrs.max : "+"} years${mine != null ? `, your resume shows about ${mine}` : ""}` : ""].filter(Boolean).join(" · "),
      [!titleOk && "Put the role's title under your name, e.g. \"Flutter Developer\" or \"Android Developer\".",
       !yrsOk && "You have less experience than asked: lead with projects and measurable results."].filter(Boolean));
  }

  // 4. Contact details
  const contact = [
    [/[\w.+-]+@[\w-]+\.[\w.-]+/.test(text), "an email address"],
    [/(\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b/.test(text) || /\+\d[\d\s-]{8,}\d/.test(text), "a phone number"],
    [CITY.test(text.slice(0, 600)), "your city"],
    [/linkedin\.com\//i.test(text), "your LinkedIn"],
    [/github\.com\/|portfolio|play\.google\.com|apps\.apple\.com/i.test(text), "GitHub, a portfolio or an app link"],
  ];
  const cOk = contact.filter(c => c[0]).length;
  add("contact", "Contact details", rate(cOk / contact.length, 10), 10, `${cOk} of ${contact.length} found`,
    contact.filter(c => !c[0]).length ? [`Add ${contact.filter(c => !c[0]).map(c => c[1]).join(", ")} as plain text near the top (not in a header, footer or icon).`] : []);

  // 5. Standard sections
  const need = [["summary", "Professional Summary"], ["skills", "Skills"], ["experience", "Experience"], ["projects", "Projects"], ["education", "Education"]];
  const hasSec = k => (sections[k] || []).length > 0 || (k === "projects" && (sections.experience || []).length > 0);
  const sOk = need.filter(([k]) => hasSec(k)).length;
  add("sections", "Standard section headings", rate(sOk / need.length, 10), 10,
    headings.length ? `Found: ${[...new Set(headings)].slice(0, 6).join(", ")}` : "No standard headings found",
    need.filter(([k]) => !hasSec(k)).map(([, l]) => `Add a section called "${l}" (ATS look for these exact names).`));

  // 6. Impact: points with numbers and strong verbs
  const body = [...(sections.experience || []), ...(sections.projects || [])];
  // Marked bullet points; if the file lost its bullet symbols, sentence-like lines that aren't job/date headers
  const BUL = /^[•·\-*▪●◦‣–➢►✓]\s*/;
  const marked = body.filter(l => BUL.test(l));
  const bullets = (marked.length >= 2 ? marked : body.filter(l => words(l).length >= 7 && !/\||\b(19|20)\d\d\b/.test(l)))
    .map(l => l.replace(BUL, "").trim()).filter(l => words(l).length >= 4);
  const quant = bullets.filter(b => /\d/.test(b)).length;
  const strong = bullets.filter(b => ACTION_VERBS.has((b.match(/^[A-Za-z]+/) || [""])[0].toLowerCase())).length;
  const weak = bullets.filter(b => WEAK_STARTS.test(b));
  const qR = bullets.length ? quant / bullets.length : 0, vR = bullets.length ? strong / bullets.length : 0;
  const impactMax = jd ? 15 : 20;
  add("impact", "Impact and results", bullets.length ? rate((Math.min(qR / 0.5, 1) * 0.6) + (Math.min(vR / 0.7, 1) * 0.4), impactMax) : 0, impactMax,
    bullets.length ? `${quant} of ${bullets.length} points have numbers · ${strong} start with an action verb` : "No achievement points found under Experience or Projects",
    [!bullets.length && "Under each job and project, add 2–4 bullet points that start with a verb and show a result.",
     bullets.length && qR < 0.5 && "Add numbers: users, downloads, % faster, crash rate, screens built, time saved.",
     bullets.length && vR < 0.7 && "Start each point with an action verb: Built, Led, Cut, Shipped, Migrated, Improved.",
     weak.length && `Rewrite points that start with "${(weak[0].match(WEAK_STARTS) || [""])[0]}": say what you did and the result.`].filter(Boolean));

  // 7. Clarity
  const tooLong = bullets.filter(b => words(b).length > 35).length;
  const firstPerson = (text.match(/(^|[\s(])(I|my|me)\s/g) || []).length >= 3;
  const cliches = CLICHES.filter(c => n.includes(" " + c + " ") || n.includes(" " + c.replace(/-/g, " ") + " "));
  let clarity = 10 - Math.min(4, tooLong * 2) - (firstPerson ? 2 : 0) - Math.min(3, cliches.length);
  add("clarity", "Clear, scannable writing", Math.max(0, clarity), 10,
    [tooLong && `${tooLong} point${tooLong > 1 ? "s are" : " is"} too long`, firstPerson && "uses \"I\"/\"my\" a lot", cliches.length && `clichés: ${cliches.slice(0, 3).join(", ")}`].filter(Boolean).join(" · ") || "Points are short and direct",
    [tooLong && "Keep each point to one or two lines (under 30 words).", firstPerson && "Drop \"I\" and \"my\": start points with the verb.",
     cliches.length && `Replace "${cliches[0]}" with evidence: a result, a project, a number.`].filter(Boolean));

  // 8. Length
  const lenOk = wc >= 250 && wc <= 1100 && pages <= 2;
  add("length", "Length", lenOk ? 5 : wc < 150 || pages > 3 ? 1 : 3, 5, `About ${wc} words${info.pages ? ` on ${info.pages} page${info.pages > 1 ? "s" : ""}` : ""}`,
    [wc < 250 && "Your resume is thin: add projects, achievements and skills.", (wc > 1100 || pages > 2) && "Trim to 1–2 pages: keep the last 5–7 years and your strongest points."].filter(Boolean));

  const max = cats.reduce((s, c) => s + c.max, 0), got = cats.reduce((s, c) => s + c.score, 0);
  const score = Math.round((got / max) * 100);
  return {
    score, grade: score >= 85 ? "Excellent" : score >= 70 ? "Strong" : score >= 50 ? "Fair" : "Needs work", mode: jd ? "job" : "role",
    categories: cats, keywords: { matched, missing, key }, stats: { words: wc, bullets: bullets.length, quantified: quant, actionStarts: strong, pages },
  };
}
