// Turns the text of an existing resume (from a PDF, Word file or LinkedIn "Save to PDF") into a Widgetry profile,
// so people can import instead of typing. Runs in the browser; nothing is uploaded.
//
// Resumes come in every layout, so this is careful rather than clever: it fills what it can read with
// confidence and leaves the rest empty for the person to check. The form highlights anything still missing.

import { splitSections, findSkills, jobRole, SKILLS } from "./resume-ats.js";

const BUL = /^[•·\-*▪●◦‣–➢►✓✔❖■□○]\s*/;
const MONTHS = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12 };
const MON = "(?:jan|feb|mar|apr|may|jun|jul|aug|sept?|oct|nov|dec)[a-z]*\\.?";
const DATE = `(?:${MON}[\\s,'’-]*(?:\\d{4}|'?\\d{2})|\\d{1,2}[\\/.-]\\d{4}|\\d{4}[\\/.-]\\d{1,2}|(?:19|20)\\d{2})`;
const NOW = "(?:present|current(?:ly)?|now|till date|to date|today|ongoing|date)";
const RANGE = new RegExp(`(${DATE})\\s*(?:-|–|—|to|till|until)\\s*(${DATE}|${NOW})`, "i");
const ROLE_WORDS = /\b(developer|engineer|intern|internship|lead|architect|designer|analyst|consultant|manager|programmer|sde|trainee|freelancer?|founder|co-founder|specialist|head|cto|associate|executive|member of technical staff|mts)\b/i;
const DEGREE = /\b(b\.?\s?tech|m\.?\s?tech|b\.?\s?e\b|m\.?\s?e\b|b\.?\s?sc|m\.?\s?sc|bca|mca|mba|bba|b\.?\s?com|m\.?\s?com|ph\.?\s?d|diploma|bachelor'?s?|master'?s?|b\.?\s?s\b|m\.?\s?s\b|class\s*(x|xii|10|12)(th)?|(10|12)th|hsc|ssc|higher secondary|secondary|intermediate|matriculation|cbse|icse|pgdm|b\.?\s?a\b|m\.?\s?a\b)/i;
const INSTITUTE = /\b(universit(y|é)|college|institute|school|academy|vidyalaya|iit|nit|iiit|bits|polytechnic|vit|srm|manipal|amity|kiit|lpu)\b/i;
const CITIES = ["Bengaluru", "Bangalore", "Mumbai", "Pune", "Hyderabad", "Chennai", "Kolkata", "New Delhi", "Delhi", "Noida", "Gurugram", "Gurgaon", "Ahmedabad",
  "Jaipur", "Indore", "Kochi", "Coimbatore", "Chandigarh", "Lucknow", "Bhubaneswar", "Nagpur", "Surat", "Vadodara", "Thane", "Navi Mumbai", "Mysuru", "Mysore",
  "Visakhapatnam", "Vizag", "Bhopal", "Patna", "Ranchi", "Guwahati", "Thiruvananthapuram", "Trivandrum", "Mangaluru", "Mangalore", "Dehradun", "Mohali", "Goa"];
const CITY_RE = new RegExp(`\\b(${CITIES.map(c => c.replace(/ /g, "\\s+")).join("|")})\\b`, "i");
const STATES = "andhra pradesh|arunachal pradesh|assam|bihar|chhattisgarh|goa|gujarat|haryana|himachal pradesh|jharkhand|karnataka|kerala|madhya pradesh|maharashtra|manipur|meghalaya|mizoram|nagaland|odisha|punjab|rajasthan|sikkim|tamil nadu|telangana|tripura|uttar pradesh|uttarakhand|west bengal|delhi ncr|ncr";
const LOCATIONISH = new RegExp(`^((${CITIES.join("|")}|${STATES}|india|remote|hybrid|on-?site|work from home|wfh)[,\\s]*)+$|,\\s*india$`, "i");
const DURATION = /\(?\s*\d+\s*(?:years?|yrs?|months?|mos?)(?:\s*,?\s*\d+\s*(?:months?|mos?))?\s*\)?/gi;

const clip = (s, n) => String(s || "").replace(/\s+/g, " ").trim().slice(0, n).trim();
const wc = s => (String(s).match(/\S+/g) || []).length;
const titleCase = s => (s === s.toUpperCase() ? s.toLowerCase().replace(/\b[a-z]/g, c => c.toUpperCase()) : s);
const nowYm = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`; };

/** "Jan 2023", "01/2023", "2023-01", "Jan'23" or "2023" as "2023-01". end: a bare year means its last month (or this month, for this year). */
export function toMonth(tok, end = false) {
  const t = String(tok || "").trim().toLowerCase();
  let m = /^([a-z]+)\.?[\s,'’-]*('?\d{2}|\d{4})$/.exec(t);
  if (m && MONTHS[m[1].slice(0, m[1].startsWith("sept") ? 4 : 3)]) {
    let y = Number(m[2].replace("'", "")); if (y < 100) y += 2000;
    return `${y}-${String(MONTHS[m[1].slice(0, m[1].startsWith("sept") ? 4 : 3)]).padStart(2, "0")}`;
  }
  if ((m = /^(\d{1,2})[\/.-](\d{4})$/.exec(t)) && +m[1] >= 1 && +m[1] <= 12) return `${m[2]}-${m[1].padStart(2, "0")}`;
  if ((m = /^(\d{4})[\/.-](\d{1,2})$/.exec(t)) && +m[2] >= 1 && +m[2] <= 12) return `${m[1]}-${m[2].padStart(2, "0")}`;
  if ((m = /^((?:19|20)\d{2})$/.exec(t))) {
    if (!end) return `${m[1]}-01`;
    return Number(m[1]) >= new Date().getFullYear() ? nowYm() : `${m[1]}-12`;
  }
  return "";
}
/** The first date range in a line: { start, end ("" = present), rest: the line without it }. */
export function dateRange(line) {
  const m = RANGE.exec(line);
  if (!m) return null;
  const start = toMonth(m[1]);
  const end = new RegExp(`^${NOW}$`, "i").test(m[2].trim()) ? "" : toMonth(m[2], true);
  if (!start) return null;
  const rest = (line.slice(0, m.index) + " " + line.slice(m.index + m[0].length)).replace(DURATION, " ").replace(/[(\[]\s*[)\]]/g, "").replace(/\s*[|•·,–—-]\s*$/, "").replace(/^\s*[|•·,–—-]\s*/, "").trim();
  return { start, end: end && end < start ? "" : end, rest };
}

/** Splits "Flutter Developer | PayCo, Bengaluru" into its pieces, dropping locations. */
function pieces(s, commas = true) {
  const re = commas ? /\s*[|•·]\s*|\s+[–—-]\s+|\s+at\s+|\s+@\s+|\s*,\s*/i : /\s*[|•·]\s*|\s+[–—-]\s+|\s+at\s+|\s+@\s+/i;
  return s.split(re).map(x => x.replace(/^[(\[](?=[^)\]]*$)/, "").replace(/^([^(\[]*)[)\]]$/, "$1").trim()).filter(x => x && !LOCATIONISH.test(x) && !/^[\W\d]+$/.test(x));
}

/**
 * Groups a section's lines into entries: header lines (role, company, dates) followed by their points.
 * Long lines without bullets count as points when the section has no bullets at all.
 */
function entries(lines, projects = false) {
  const anyBullets = lines.some(l => BUL.test(l));
  const out = []; let cur = null, prevPoint = false;
  for (const raw of lines) {
    const bullet = BUL.test(raw), l = raw.replace(BUL, "").trim();
    if (!l) continue;
    const range = RANGE.test(l);
    // A wrapped bullet continues on the next line in many PDFs
    if (!bullet && prevPoint && cur?.points.length && !range && (/^[a-z0-9(%&]/.test(l) || /[,&]$|\b(and|with|to|of|for|the|in|using|by)$/i.test(cur.points.at(-1)))) {
      cur.points[cur.points.length - 1] += " " + l; continue;
    }
    // "Expense Tracker (Flutter, Hive) - Offline expense tracker…": in a projects list, a short title then a dash starts a new project
    const titled = projects && !bullet && /^[A-Z0-9][\w&'+.]*(?: [\w&'+.]+){0,4}\s*(\([^)]{1,60}\))?\s*(?:[–—:|]|\s-)\s+\S/.test(l);
    if (titled) { out.push((cur = { head: [l], points: [] })); prevPoint = false; continue; }
    const roleish = ROLE_WORDS.test(l) && wc(l) <= 12 && !/[.;]$/.test(l);
    const point = bullet || (!anyBullets && !range && !roleish && (wc(l) >= 9 || (/[.!]$/.test(l) && wc(l) >= 5)));
    if (point) {
      if (!cur) out.push((cur = { head: [], points: [] }));
      cur.points.push(l); prevPoint = true;
    } else {
      if (!cur || cur.points.length || (range && cur.dated)) out.push((cur = { head: [], points: [] }));
      cur.head.push(l); if (range) cur.dated = true; prevPoint = false;
    }
  }
  return out;
}

function parseJob(e) {
  let start = "", end = "", text = [];
  for (const h of e.head) {
    const r = dateRange(h);
    if (r && !start) { start = r.start; end = r.end; if (r.rest) text.push(r.rest); } else text.push(h);
  }
  const parts = text.flatMap(t => pieces(t));
  let role = parts.find(p => ROLE_WORDS.test(p)) || "";
  let company = parts.find(p => p !== role && !ROLE_WORDS.test(p)) || "";
  if (!role && parts.length > 1) { role = parts[1]; company = parts[0]; }
  if (!company && !role && parts[0]) company = parts[0];
  return { company: clip(company, 120), role: clip(role, 100), start, end, points: e.points.map(p => clip(p, 400)).join("\n").slice(0, 1500) };
}

const URL_RE = /\b((?:https?:\/\/)?(?:www\.)?(?:[a-z0-9-]+\.)+(?:com|in|io|dev|me|app|co|org|net|tech|xyz|page|site)(?:\/[^\s,|)]*)?)/gi;
const withHttps = u => (/^https?:\/\//i.test(u) ? u : "https://" + u).replace(/[.,;]+$/, "");

function parseProject(e) {
  const all = [...e.head, ...e.points].join(" ");
  const url = (all.match(URL_RE) || []).find(u => !/@/.test(u) && /play\.google|apps\.apple|github\.com\/[^/\s]+\/|\.(app|dev|io|com|in)/i.test(u));
  const head = (e.head[0] || e.points.shift() || "").replace(URL_RE, "").trim();
  const range = dateRange(head);
  const h = range ? range.rest : head;
  const br = /\(([^)]{1,60})\)/.exec(h);
  const [name, ...rest] = h.replace(/\([^)]{1,60}\)/, " ").split(/\s+[–—-]\s+|\s*[|:]\s*/);
  if (br && !/\b(19|20)\d\d\b/.test(br[1])) rest.push(`Tech: ${br[1]}`);
  const tech = e.head.slice(1).filter(l => /^(tech|stack|technologies|tools|built with)\b/i.test(l)).map(l => l.replace(/^[^:]*:\s*/, "Tech: "));
  const about = [...rest, ...e.points, ...tech].map(s => s.trim().replace(/[.;,]+$/, "")).filter(Boolean).map(s => s[0].toUpperCase() + s.slice(1)).join(". ");
  const roleM = /\b(solo developer|lead developer|team lead|developer|contributor|maintainer)\b/i.exec(e.head.join(" "));
  return { name: clip(name.replace(URL_RE, "").replace(/[.:,;]+$/, ""), 80), url: url ? withHttps(url) : "", role: roleM ? titleCase(roleM[1]) : "", about: clip(about, 400) };
}

function parseEducation(lines) {
  const out = []; let cur = null;
  for (const raw of lines) {
    const l = raw.replace(BUL, "").trim(); if (!l) continue;
    if (DEGREE.test(l) && (!cur || cur.degree)) out.push((cur = { lines: [], degree: "" }));
    if (!cur) out.push((cur = { lines: [], degree: "" }));
    cur.lines.push(l); if (DEGREE.test(l)) cur.degree = l;
  }
  return out.map(c => {
    const all = c.lines.join(" | ");
    const years = (all.match(/\b(19[7-9]\d|20[0-4]\d)\b/g) || []).map(Number);
    const sc = /(\d{1,2}(?:\.\d{1,2})?)\s*\/?\s*(?:10\s*)?(cgpa|gpa|sgpa|cpi)|(cgpa|gpa|sgpa|cpi)\s*[:\-]?\s*(\d{1,2}(?:\.\d{1,2})?)|(\d{2}(?:\.\d{1,2})?)\s*%/i.exec(all);
    const score = sc ? (sc[1] ? `${sc[1]} ${sc[2].toUpperCase()}` : sc[4] ? `${sc[4]} ${sc[3].toUpperCase()}` : `${sc[5]}%`) : "";
    const strip = s => s.replace(RANGE, "").replace(/\b(19[7-9]\d|20[0-4]\d)\b/g, "").replace(sc?.[0] || "\u0000", "").replace(/\b(cgpa|gpa|percentage|score)\s*[:\-]?\s*$/i, "").replace(/\(\s*[-–—]?\s*\)/g, " ").replace(/\s*[|,–—·-]\s*$/, "").replace(/\s+/g, " ").trim();
    const parts = c.lines.flatMap(l => pieces(strip(l), false)).map(strip).filter(Boolean);
    let degree = parts.find(p => DEGREE.test(p)) || "";
    let institute = parts.find(p => p !== degree && INSTITUTE.test(p)) || "";
    // "B.Tech in CSE, VIT University" on one line
    if (!institute && degree.includes(",")) { const [d, ...i] = degree.split(/\s*,\s*/); const inst = i.find(x => INSTITUTE.test(x)); if (inst) { institute = inst; degree = [d, ...i.filter(x => x !== inst)].join(", "); } }
    if (!institute) institute = parts.find(p => p !== degree && !LOCATIONISH.test(p) && !DEGREE.test(p)) || "";
    // LinkedIn: "Bachelor of Engineering - BE, Computer Engineering": add the field, not the abbreviation again
    const field = parts.find(p => p !== degree && p !== institute && DEGREE.test(p) && wc(p) <= 8);
    if (field) { const f = field.replace(DEGREE, "").replace(/^[\s,.-]+/, "").trim(); if (f && !degree.includes(f)) degree += `, ${f}`; }
    return { degree: clip(degree, 120), institute: clip(institute, 150), year: years.length ? Math.max(...years) : null, score: clip(score, 40) };
  }).filter(e => e.degree || e.institute).slice(0, 6);
}

function parseCerts(lines) {
  return lines.map(l => l.replace(BUL, "").trim()).filter(l => l && wc(l) <= 20).map(l => {
    const years = l.match(/\b(19[7-9]\d|20[0-4]\d)\b/g);
    const s = l.replace(RANGE, "").replace(/\b(19[7-9]\d|20[0-4]\d)\b/g, "").replace(/[()]/g, " ").trim();
    const [name, issuer = ""] = s.split(/\s+[–—-]\s+|\s*[|]\s*|\s+by\s+|\s+from\s+|\s*,\s*(?=[A-Z])/);
    const tidy = x => clip(x, 120).replace(/[,;:.\s-]+$/, "");
    return { name: tidy(name), issuer: tidy(issuer), year: years ? Number(years.at(-1)) : null };
  }).filter(c => c.name.length >= 3).slice(0, 8);
}

const CANON = new Map(SKILLS.flatMap(([c, ...a]) => [c, ...a].map(x => [x.toLowerCase(), c])));
function parseSkills(skillLines, wholeText) {
  const tokens = [];
  for (const raw of skillLines) {
    const l = raw.replace(BUL, "").replace(/^[^:]{1,30}:\s*/, "");   // "Languages: Dart, Kotlin"
    for (const t of l.split(/\s*[,|•·;]\s*|\s{2,}|\t|\s+[–—-]\s+/)) {
      const s = t.replace(/^(and|&)\s+/i, "").replace(/[.()]+$/, "").trim();
      if (s && s.length <= 40 && wc(s) <= 4 && /[a-z]/i.test(s)) tokens.push(s);
    }
  }
  const out = [], seen = new Set();
  const add = s => { const k = s.toLowerCase(); if (!seen.has(k) && out.length < 15) { seen.add(k); out.push(s); } };
  for (const t of tokens) {
    const k = CANON.get(t.toLowerCase());
    if (k) { add(k); continue; }
    const f = [...findSkills(t).keys()];
    add(f.length === 1 && wc(t) <= 2 ? f[0] : t);
  }
  // Known skills mentioned elsewhere (in points and projects), most-mentioned first
  for (const [k] of [...findSkills(wholeText)].sort((a, b) => b[1] - a[1])) add(k);
  return out;
}

/** Years of experience: what the resume says ("3+ years"), else the span of the jobs. */
function yearsOf(text, jobs) {
  const m = /(\d{1,2}(?:\.\d)?)\s*\+?\s*(?:years?|yrs?)\b(?!\s*\d*\s*months?)/i.exec(text);
  if (m) return Math.min(40, Math.round(Number(m[1]) * 2) / 2);
  let months = 0;
  for (const j of jobs) if (j.start) {
    const [sy, sm] = j.start.split("-").map(Number), [ey, em] = (j.end || nowYm()).split("-").map(Number);
    months += Math.max(0, (ey - sy) * 12 + (em - sm) + 1);
  }
  return Math.min(40, Math.round((months / 12) * 2) / 2);
}

/**
 * Reads resume text into profile fields: { fullName, email, phone, city, headline, experienceYears, currentCompany, about,
 * skills, experience, apps, education, certifications, githubUrl, linkedinUrl, portfolioUrl, categories } plus
 * found: a short list of what was filled in, for the "We filled in…" message.
 */
export function parseResume(rawText) {
  const text = String(rawText || "").replace(/\u00a0/g, " ").replace(/[\uFFFD\uE000-\uF8FF]/g, " ").replace(/[ \t]+/g, " ");
  // "Skills: Flutter, Dart…" on one line: read it as skills and keep it out of the section it sits in
  const SKILL_LINE = /^\s*(technical\s+|key\s+|core\s+)?skills\s*[:\-–]\s*\S/i;
  const inlineSkills = text.split("\n").filter(l => SKILL_LINE.test(l)).map(l => l.replace(/^[^:\-–]*[:\-–]\s*/, ""));
  const { sections } = splitSections(text.split("\n").filter(l => !SKILL_LINE.test(l)).join("\n"));
  const top = (sections._top || []).map(l => l.trim()).filter(Boolean);
  // LinkedIn's "Save to PDF" puts contact details and top skills first, then the name: look there too
  const front = [...top, ...(sections.other || []).slice(0, 14)];
  const isContact = l => /@|\d{5}|linkedin|github|https?:|www\./i.test(l);
  const isSkill = l => CANON.has(l.toLowerCase());
  const nameAt = front.findIndex(l => !isContact(l) && !isSkill(l) && wc(l) >= 2 && wc(l) <= 5 && /^[A-Za-z][A-Za-z .'-]+$/.test(l) && !ROLE_WORDS.test(l) && !/^top skills$|^languages$|^certifications$|^honors|^summary$/i.test(l));
  const nameLine = nameAt >= 0 ? front[nameAt] : "";
  const head = (nameAt >= 0 ? front.slice(Math.max(0, nameAt - 6), nameAt + 6) : top.slice(0, 12)).join("\n");
  const p = {};

  // Contact details
  p.email = (text.match(/[\w.+-]+@[\w-]+(?:\.[\w-]+)+/) || [""])[0];
  const ph = /(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b|\+\d{1,3}[\s-]?\d[\d\s-]{7,13}\d/.exec(head) || /(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b/.exec(text);
  p.phone = ph ? ph[0].replace(/\s+/g, " ").trim() : "";
  const li = /(?:https?:\/\/)?(?:[a-z]{2,3}\.)?linkedin\.com\/in\/[\w%-]+/i.exec(text);
  p.linkedinUrl = li ? withHttps(li[0]) : "";
  // The profile link (github.com/name), not a repository (github.com/name/repo)
  const ghs = [...text.matchAll(/(?:https?:\/\/)?(?:www\.)?github\.com\/([\w-]+)(\/[\w.-]+)?/gi)];
  const gh = ghs.find(m => !m[2]) || ghs[0];
  p.githubUrl = gh ? `https://github.com/${gh[1]}` : "";
  const emailDomain = p.email.split("@")[1] || "~";
  const site = (head.match(URL_RE) || []).find(u => !/linkedin|github|play\.google|apps\.apple|gmail|yahoo|outlook|hotmail/i.test(u) && !u.includes(emailDomain) && !p.email.includes(u));
  p.portfolioUrl = site ? withHttps(site) : "";
  const city = CITY_RE.exec(head);
  p.city = city ? CITIES.find(c => c.toLowerCase() === city[1].toLowerCase().replace(/\s+/g, " ")) || titleCase(city[1]) : "";

  // Name, and a headline near it that names a role
  p.fullName = clip(titleCase(nameLine.replace(/\s{2,}/g, " ")), 100);
  const hl = (nameAt >= 0 ? front.slice(nameAt + 1, nameAt + 5) : top).filter(l => l !== nameLine).map(l => l.split(/\s*[|]\s*/).filter(x => ROLE_WORDS.test(x) && !isContact(x)).join(" · ")).find(l => l && wc(l) <= 16);
  p.headline = clip(hl || "", 140);

  // Sections
  p.about = clip((sections.summary || []).join(" "), 2000) || clip(top.find(l => wc(l) >= 18 && !isContact(l)) || "", 2000);
  p.experience = entries(sections.experience || []).map(parseJob).filter(j => j.company || j.role).slice(0, 10);
  p.apps = entries(sections.projects || [], true).map(parseProject).filter(a => a.name).slice(0, 8);
  p.education = parseEducation(sections.education || []);
  p.certifications = parseCerts(sections.certifications || []);
  p.skills = parseSkills([...(sections.skills || []), ...inlineSkills], text);

  p.currentCompany = (p.experience.find(j => j.company && !j.end) || {}).company || "";
  p.experienceYears = yearsOf([p.about, p.headline].join(" "), p.experience);
  if (!p.headline && p.experience[0]?.role) p.headline = clip(`${p.experience[0].role}${p.experienceYears >= 1 ? ` · ${p.experienceYears} years` : ""}`, 140);
  const role = jobRole(`${p.headline} ${p.experience.map(j => j.role).join(" ")} ${p.skills.slice(0, 6).join(" ")}`);
  p.categories = role ? [role] : [];

  p.found = [
    p.fullName && "your name", (p.email || p.phone) && "contact details", p.headline && "headline", p.about && "summary",
    p.skills.length && `${p.skills.length} skills`, p.experience.length && `${p.experience.length} job${p.experience.length > 1 ? "s" : ""}`,
    p.apps.length && `${p.apps.length} project${p.apps.length > 1 ? "s" : ""}`, p.education.length && "education",
    p.certifications.length && `${p.certifications.length} certificate${p.certifications.length > 1 ? "s" : ""}`,
  ].filter(Boolean);
  return p;
}
