// Widgetry resume renderer: one ATS-friendly structure, two free looks and six Pro ones.
// ATS rules followed: single column, real text (no images/icons/tables), standard section names,
// plain contact line, consistent "Mon YYYY – Mon YYYY" dates, bullet points as real lists.

export const TEMPLATES = {
  classic: "Classic",     // Free: serif, centered, black: accepted everywhere (banks, MNCs, service companies)
  modern: "Modern",       // Free: clean sans with a green accent: product companies and startups
  impact: "Impact",       // Pro: colour header band and a "Key highlights" strip of your best numbers
  timeline: "Timeline",   // Pro: experience on an accent timeline, dates up front: shows a career path at a glance
  executive: "Executive", // Pro: strong serif name, ruled sections, for senior and lead roles
  elegant: "Elegant",     // Pro: serif headings over a sans body, accent rule beside each heading
  minimal: "Minimal",     // Pro: airy, light rules, quiet accent: design-led startups
  compact: "Compact",     // Pro: tighter spacing: fits 4+ years of experience on one page
};
/** Templates that need Resume Premium. Same ATS-safe structure as the free ones (one column, real text, standard headings). */
export const PRO_TEMPLATES = new Set(["impact", "timeline", "executive", "elegant", "minimal", "compact"]);
/**
 * What Pro adds on every template. Free resumes (Classic, Modern) keep a fixed colour, no photo,
 * normal spacing, no Key highlights, PDF only, and a small "Made with Widgetry" line at the bottom.
 */
export const PRO_FEATURES = [
  ["templates", "6 Pro templates", "Impact, Timeline, Executive, Elegant, Minimal and Compact"],
  ["highlights", "Key highlights", "your 3 strongest numbers pulled to the top, where recruiters look first"],
  ["colours", "6 accent colours", "match the company's style or your own"],
  ["fit", "Fit to one page", "the same resume, tightened to one or two pages"],
  ["photo", "Photo", "for roles and countries that expect one"],
  ["word", "Word download", "a .docx for recruiters and job portals that ask for it"],
  ["brand", "No Widgetry branding", "free resumes carry a small \"Made with Widgetry\" line"],
];

const esc = t => String(t ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const ym = v => { if (!v) return "Present"; const [y, m] = String(v).split("-"); return `${MONTHS[Number(m) - 1] || ""} ${y}`.trim(); };
const safe = u => (/^https?:\/\//i.test(u || "") ? u : "");
const short = u => u.replace(/^https?:\/\/(www\.)?/i, "").replace(/\/$/, "");
const lines = t => String(t || "").split(/\n+/).map(s => s.replace(/^\s*[-•*·]\s*/, "").trim()).filter(Boolean);

// Wide letter-spacing makes PDF text come out as "S K I L L S", which some ATS can't read: keep spacing small.
const phone = v => { const d = String(v || "").replace(/\D/g, ""); return /^91\d{10}$/.test(d) ? `+91 ${d.slice(2, 7)} ${d.slice(7)}` : /^\d{10}$/.test(d) ? `+91 ${d.slice(0, 5)} ${d.slice(5)}` : String(v || ""); };

// Group skills the way recruiters scan them
const GROUPS = [
  ["Languages & Frameworks", ["Flutter", "Dart", "Kotlin", "Swift", "Java", "Objective-C", "JavaScript", "TypeScript", "Flutter Web", "Flame"]],
  ["UI", ["Jetpack Compose", "SwiftUI", "UIKit", "XML Layouts", "Material Design", "Animations"]],
  ["State & Concurrency", ["Bloc", "Provider", "Riverpod", "GetX", "MobX", "Redux", "Coroutines", "Flow", "Combine", "RxJava", "RxSwift"]],
  ["Data & Integrations", ["Firebase", "REST APIs", "GraphQL", "Retrofit", "Room", "Core Data", "SQLite", "Hive", "Google Maps", "Push Notifications", "Supabase", "Node.js"]],
  ["Architecture & Practices", ["Clean Architecture", "MVVM", "MVI", "Dependency Injection", "Hilt", "Dagger", "Testing", "Espresso", "XCTest", "CI/CD", "Gradle", "Xcode", "Git"]],
  ["Platforms", ["Android", "Android SDK", "iOS"]],
];
export function groupSkills(skills = []) {
  const left = [...skills], out = [];
  for (const [label, list] of GROUPS) {
    const got = list.filter(s => left.some(x => x.toLowerCase() === s.toLowerCase()));
    if (got.length) { out.push([label, got]); for (const g of got) left.splice(left.findIndex(x => x.toLowerCase() === g.toLowerCase()), 1); }
  }
  if (left.length) out.push([out.length ? "Other" : "Skills", left]);
  return out;
}

/** Written for people who leave "About" empty, so every resume has a summary. */
export function autoSummary(p) {
  const yrs = Number(p.experienceYears) || 0;
  const top = (p.skills || []).filter(s => !/^(flutter|dart|kotlin|swift)$/i.test(s)).slice(0, 4);
  // Role comes from what they work with: Flutter, Android or iOS (several = "Mobile")
  const ROLE = { flutter: ["Flutter developer", "cross-platform Android and iOS apps"], android: ["Android developer", "native Android apps"], ios: ["iOS developer", "native iOS apps"], "react-native": ["React Native developer", "cross-platform Android and iOS apps"] };
  const cats = (p.categories || ["flutter"]).filter(c => ROLE[c]);
  const [role, what] = cats.length === 1 ? ROLE[cats[0]] : cats.length > 1 ? ["Mobile developer", `apps with ${cats.map(c => ROLE[c][0].split(" ")[0]).join(" and ")}`] : ROLE.flutter;
  const names = (p.apps || []).map(a => a.name).filter(Boolean).slice(0, 2);
  const who = yrs >= 1 ? `${role} with ${yrs} year${yrs === 1 ? "" : "s"} of experience building ${what}` : `${role} building ${what}`;
  const builds = names.length ? `, including ${names.join(" and ")}` : "";
  const stack = top.length ? ` Skilled in ${top.slice(0, -1).join(", ")}${top.length > 1 ? " and " : ""}${top[top.length - 1]}.` : "";
  return `${who}${builds}.${stack} Focused on clean, maintainable code and smooth user experiences.`;
}

/**
 * Key highlights (Pro): the strongest achievements with numbers, from jobs, projects and achievements.
 * Picked, not written: the text is the person's own, so nothing is invented. The number is wrapped in <b>.
 */
const NUM = /(\d[\d,.]*\s?(?:%|\+|k\+?|K\+?|x|X|L\+?|lakh|crore|million|M\+?)?)/;
export function keyHighlights(p, n = 3) {
  const all = [
    ...(p.experience || []).flatMap(w => lines(w.points)),
    ...(p.apps || []).map(a => (a.about || "").split("·")[0].trim()),
    ...(p.achievements || []).map(a => String(a || "").trim()),
  ].filter(l => l.length >= 18 && l.length <= 170 && /\d/.test(l) && !/^\d{4}\s*[-–]/.test(l));
  const score = l => (/\d\s?%/.test(l) ? 4 : 0) + (/\d\s?(k|K|L|lakh|crore|million|M)\b|\d\+/.test(l) ? 4 : 0) + (/\b(users|downloads|customers|installs|rating|revenue|faster|reduced|cut|increased|grew|improved|saved)\b/i.test(l) ? 2 : 0) + (/^(winner|won|rank|top|first)\b/i.test(l) ? 2 : 0);
  const seen = new Set();
  return all.map((l, i) => ({ l, s: score(l), i })).filter(x => x.s > 0).sort((a, b) => b.s - a.s || a.i - b.i)
    .filter(x => { const k = x.l.toLowerCase().slice(0, 40); if (seen.has(k)) return false; seen.add(k); return true; })
    .slice(0, n).map(x => x.l);
}

/** "Fit to one page": the same resume, slightly smaller. Still real text, so ATS read it the same way. */
export const DENSITY = { compact: "d-compact", tight: "d-tight" };
export const DENSITY_LABELS = { normal: "Normal", compact: "Snug", tight: "Fit more" };

export const ACCENTS = { green: "#0f6b56", navy: "#1d3557", black: "#111111", maroon: "#7a1f2b", teal: "#0e6d7a", purple: "#53389e" };

// Premium templates seen without Premium carry a watermark, on screen and in print. It's a background image,
// so there's no extra text for ATS software or copy-paste to pick up.
const WM_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="330" height="210"><text x="165" y="112" text-anchor="middle" transform="rotate(-30 165 105)" font-family="Arial,Helvetica,sans-serif" font-size="19" font-weight="700" letter-spacing="2" fill="#0f6b56" fill-opacity="0.17">WIDGETRY PREMIUM · PREVIEW</text></svg>`;
const WM_URL = "data:image/svg+xml," + encodeURIComponent(WM_SVG);

/**
 * opts (all optional, saved per seeker): { accent, title, showPhoto, density: "normal"|"compact"|"tight",
 *   hide: ["photo","phone","email","city","summary","highlights","projects","achievements","education","certifications","languages"] }
 * Not saved: watermark (true for a Pro template viewed without Premium); pro (the person has Resume Premium).
 * Pro features (colour, photo, density, Key highlights, no branding) apply with Premium, or on a Pro template's preview.
 */
export function renderResume(p, template = "modern", opts = {}) {
  const t = TEMPLATES[template] ? template : "modern";
  const full = !!opts.pro || PRO_TEMPLATES.has(t);
  const hide = new Set(opts.hide || []), show = k => !hide.has(k);
  const accent = full ? ACCENTS[opts.accent] || null : null;
  const style = accent && t !== "classic" ? ` style="--rs-accent:${accent};--rs-rule:${accent}40"` : accent && t === "classic" ? ` style="--rs-head-rule:${accent}"` : "";
  const photo = full && opts.showPhoto && show("photo") && /^data:image\/(jpeg|png|webp);base64,/.test(p.photo || "") ? `<img class="photo" src="${p.photo}" alt="">` : "";
  const contact = [
    show("city") && p.city && `${esc(p.city)}, India`, show("phone") && p.phone && esc(phone(p.phone)), show("email") && p.email && esc(p.email),
    ...[p.linkedinUrl, p.githubUrl, p.portfolioUrl].filter(safe).map(u => `<a href="${esc(u)}">${esc(short(u))}</a>`),
  ].filter(Boolean).join(`<span class="sep"> | </span>`);

  const summary = (p.about || "").trim() || autoSummary(p);
  const skills = groupSkills(p.skills).map(([label, list]) => `<li><b>${esc(label)}:</b> ${list.map(esc).join(", ")}</li>`).join("");

  const work = (p.experience || []).map(w => `<div class="item"><div class="row"><span class="what"><b>${esc(w.role)}</b><span class="sep"> | </span>${esc(w.company)}</span><span class="when">${ym(w.start)} – ${ym(w.end)}</span></div>
    ${lines(w.points).length ? `<ul>${lines(w.points).map(l => `<li>${esc(l)}</li>`).join("")}</ul>` : ""}</div>`).join("")
    || (p.currentCompany ? `<div class="item"><div class="row"><span class="what"><b>${esc(p.headline)}</b><span class="sep"> | </span>${esc(p.currentCompany)}</span><span class="when">Present</span></div></div>` : "");

  const projects = (p.apps || []).map(a => `<div class="item"><div class="row"><span class="what"><b>${esc(a.name)}</b>${a.role ? `<span class="sep"> | </span>${esc(a.role)}` : ""}</span>${safe(a.url) ? `<span class="when"><a href="${esc(a.url)}">${esc(short(a.url).slice(0, 60))}</a></span>` : ""}</div>
    ${a.about ? `<ul><li>${esc(a.about)}</li></ul>` : ""}</div>`).join("");

  const edu = (p.education || []).map(e => `<div class="item"><div class="row"><span class="what"><b>${esc(e.degree)}</b><span class="sep"> | </span>${esc(e.institute)}${e.score ? `<span class="sep"> | </span>${esc(e.score)}` : ""}</span>${e.year ? `<span class="when">${esc(e.year)}</span>` : ""}</div></div>`).join("");

  const certList = [...(p.certifications || [])];
  if (p.verification === "verified") certList.unshift({ name: "Widgetry Verified Flutter Developer (technical interview)", issuer: "Widgetry Academy" });
  const certs = certList.map(c => `<li><b>${esc(c.name)}</b>${c.issuer ? ` – ${esc(c.issuer)}` : ""}${c.year ? ` (${esc(c.year)})` : ""}</li>`).join("");

  const sec = (title, body, cls = "") => (body ? `<section${cls ? ` class="${cls}"` : ""}><h2>${title}</h2>${body}</section>` : "");
  const hl = full && show("highlights") ? keyHighlights(p) : [];
  const highlights = hl.length >= 2 ? `<ul class="hl">${hl.map(l => `<li data-n="${esc((NUM.exec(l) || [""])[0].trim())}">${esc(l).replace(NUM, "<b>$1</b>")}</li>`).join("")}</ul>` : "";
  const achievements = (p.achievements || []).map(a => String(a || "").trim()).filter(Boolean).map(a => `<li>${esc(a)}</li>`).join("");
  const langs = (p.languages || []).map(l => String(l || "").trim()).filter(Boolean).map(esc).join(", ");
  const density = full && DENSITY[opts.density] ? ` ${DENSITY[opts.density]}` : "";
  return `<article class="resume t-${t}${photo ? " has-photo" : ""}${opts.watermark ? " wm" : ""}${density}"${style}>
    <header>${photo}<div class="hd"><h1>${esc(p.fullName)}</h1><p class="title">${esc((opts.title || "").trim() || p.headline)}</p><p class="contact">${contact}</p></div></header>
    ${show("summary") ? sec("Professional Summary", `<p>${esc(summary)}</p>`) : ""}
    ${sec("Key Highlights", highlights, "s-hl")}
    ${sec("Technical Skills", skills && `<ul class="skills">${skills}</ul>`)}
    ${sec("Professional Experience", work, "s-exp")}
    ${show("projects") ? sec("Projects", projects) : ""}
    ${show("achievements") ? sec("Achievements", achievements && `<ul>${achievements}</ul>`) : ""}
    ${show("education") ? sec("Education", edu) : ""}
    ${show("certifications") ? sec("Certifications", certs && `<ul>${certs}</ul>`) : ""}
    ${show("languages") ? sec("Languages", langs && `<p>${langs}</p>`) : ""}
    ${full ? "" : '<p class="rs-brand">Made with Widgetry · widgetryacademy.in</p>'}
    ${opts.watermark ? '<div class="rs-wm" aria-hidden="true"></div>' : ""}
  </article>`;
}

/**
 * A saved copy of the resume (Resume Premium) keeps only what differs from the main one:
 * { title, about, skills, points: [{ index, points }] }. This returns the profile with those applied.
 */
export function applyVersion(p, data) {
  if (!data) return p;
  const q = { ...p, experience: (p.experience || []).map(w => ({ ...w })) };
  if (data.about) q.about = data.about;
  if (data.skills && data.skills.length) q.skills = data.skills;
  for (const x of data.points || []) if (q.experience[x.index]) q.experience[x.index].points = x.points || null;
  return q;
}

/** Resume strength: what's missing that recruiters and ATS look for. */
export function strength(p) {
  const work = p.experience || [];
  const pts = work.flatMap(w => lines(w.points));
  const checks = [
    [!!(p.about && p.about.length >= 120), 12, "Write your own summary (2–3 lines on what you build and your strengths)"],
    [(p.skills || []).length >= 6, 12, "Add at least 6 skills (state management, Firebase, testing…)"],
    [work.length > 0 || Number(p.experienceYears) === 0, 14, "Add your work experience or internships"],
    [work.length === 0 || work.every(w => lines(w.points).length >= 2), 12, "Give each job at least 2–3 bullet points"],
    [pts.some(l => /\d/.test(l)), 12, "Add numbers to your points (e.g. \"cut load time by 40%\", \"10k+ downloads\")"],
    [(p.apps || []).some(a => safe(a.url)), 14, "Add an app or project with a Play Store or GitHub link"],
    [(p.apps || []).length === 0 || (p.apps || []).every(a => a.about), 6, "Describe each project in one line"],
    [(p.education || []).length > 0, 8, "Add your education"],
    [!!(p.linkedinUrl || p.githubUrl), 6, "Add your LinkedIn or GitHub"],
    [!!p.phone, 4, "Add a phone number so recruiters can call you"],
  ];
  const score = checks.reduce((s, [ok, w]) => s + (ok ? w : 0), 0);
  return { score, tips: checks.filter(c => !c[0]).map(c => c[2]) };
}

// Styles shared by the resume page and the builder preview. Sizes in pt so print matches screen.
export const RESUME_CSS = `
.resume.wm{position:relative}
.resume .rs-wm{position:absolute;inset:-8mm;z-index:3;pointer-events:none;user-select:none;background:url("${WM_URL}") repeat;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.resume{--rs-ink:#111;--rs-muted:#444;--rs-accent:#111;--rs-rule:#111;color:var(--rs-ink);background:#fff;font-size:10.5pt;line-height:1.42}
.resume a{color:inherit;text-decoration:none}
.resume header{margin-bottom:6pt}
.resume h1,.resume h2{font-family:inherit;color:var(--rs-ink);text-wrap:wrap}
.resume h1{margin:0;font-size:22pt;line-height:1.1;font-weight:700;letter-spacing:.01em}
.resume .title{margin:3pt 0 0;font-size:11.5pt;font-weight:600}
.resume header .title{color:var(--rs-accent)}
.resume .contact{margin:5pt 0 0;font-size:9.5pt;color:var(--rs-muted)}
.resume section{margin-top:10pt}
.resume h2{margin:0 0 5pt;line-height:1.3;font-size:10.5pt;font-weight:700;text-transform:uppercase;letter-spacing:.03em;color:var(--rs-accent);border-bottom:1px solid var(--rs-rule);padding-bottom:2pt}
.resume p,.resume li{color:var(--rs-ink)}
.resume p{margin:0}
.resume .contact,.resume .title{color:var(--rs-muted)}
.resume ul{margin:2pt 0 0;padding-left:14pt}
.resume li{margin:1.5pt 0}
.resume ul.skills{list-style:none;padding:0}
.resume .item{margin-bottom:7pt;break-inside:avoid}
.resume .row{display:flex;justify-content:space-between;align-items:baseline;gap:10pt}
.resume .what{min-width:0}
.resume .when{flex:none;font-size:9.5pt;color:var(--rs-muted);white-space:nowrap}
.resume .sep{color:var(--rs-muted)}
.resume .photo{width:62pt;height:62pt;border-radius:50%;object-fit:cover;flex:none}
.resume.has-photo header{display:flex;gap:14pt;align-items:center}
.resume.has-photo .hd{min-width:0}
/* Classic: serif, centered header, black */
.resume.t-classic{font-family:"Source Serif 4",Georgia,"Times New Roman",serif;font-size:10.8pt}
.resume.t-classic header{text-align:center;border-bottom:1.5px solid var(--rs-head-rule,#111);padding-bottom:7pt}
.resume.t-classic.has-photo header{text-align:left}
.resume.t-classic h1{font-size:23pt;letter-spacing:.03em;text-transform:uppercase;font-weight:600}
.resume.t-classic .title{color:#222;font-weight:500;font-style:italic}
.resume.t-classic h2{border-bottom:.75px solid #111;letter-spacing:.03em;font-size:10.5pt}
/* Modern: sans, green accent */
.resume.t-modern{font-family:"DM Sans",Arial,Helvetica,sans-serif;--rs-accent:#0f6b56;--rs-rule:#b9d3c8}
.resume.t-modern header{border-bottom:2.5px solid #0f6b56;padding-bottom:8pt}
.resume.t-modern h1{font-size:24pt;letter-spacing:-.01em}
.resume.t-modern h2{border-bottom:none;padding-bottom:0;font-size:10pt;letter-spacing:.03em}
/* Compact: tighter, smaller, navy */
.resume.t-compact{font-family:"DM Sans",Arial,Helvetica,sans-serif;font-size:9.8pt;line-height:1.35;--rs-accent:#1d3557;--rs-rule:#c9d3e0}
.resume.t-compact h1{font-size:19pt}
.resume.t-compact section{margin-top:7pt}
.resume.t-compact .item{margin-bottom:5pt}
.resume.t-compact h2{font-size:9.5pt;margin-bottom:3pt}
/* Executive (Premium): serif name, double rule under the header, ruled small-caps-style sections */
.resume.t-executive{font-family:"DM Sans",Arial,Helvetica,sans-serif;font-size:10.4pt;--rs-accent:#1d3557;--rs-rule:#1d3557}
.resume.t-executive h1{font-family:"Source Serif 4",Georgia,serif;font-size:26pt;font-weight:600;letter-spacing:0}
.resume.t-executive header{border-bottom:3px double var(--rs-accent);padding-bottom:8pt}
.resume.t-executive header .title{color:var(--rs-accent);font-weight:700;font-size:11pt;text-transform:uppercase;letter-spacing:.04em}
.resume.t-executive h2{font-family:"Source Serif 4",Georgia,serif;text-transform:none;font-size:12pt;letter-spacing:0;color:var(--rs-ink);border-bottom:1px solid var(--rs-rule);padding-bottom:2pt}
.resume.t-executive .what b{color:var(--rs-accent)}
/* Minimal (Premium): light name, lots of air, hairline rules, quiet accent */
.resume.t-minimal{font-family:"DM Sans",Arial,Helvetica,sans-serif;font-size:10.2pt;line-height:1.5;--rs-accent:#0f6b56;--rs-rule:#e3e7e5}
.resume.t-minimal h1{font-size:27pt;font-weight:400;letter-spacing:-.01em}
.resume.t-minimal header{padding-bottom:10pt;border-bottom:1px solid var(--rs-rule)}
.resume.t-minimal section{margin-top:13pt}
.resume.t-minimal h2{border:none;text-transform:none;letter-spacing:0;font-size:11pt;font-weight:600;color:var(--rs-accent);margin-bottom:6pt}
.resume.t-minimal .item{margin-bottom:9pt}
/* Elegant (Premium): serif headings, sans body, accent bar beside each heading */
.resume.t-elegant{font-family:"DM Sans",Arial,Helvetica,sans-serif;font-size:10.3pt;--rs-accent:#7a1f2b;--rs-rule:#7a1f2b}
.resume.t-elegant header{text-align:center;padding-bottom:6pt}
.resume.t-elegant.has-photo header{text-align:left}
.resume.t-elegant h1{font-family:"Source Serif 4",Georgia,serif;font-size:25pt;font-weight:600;font-style:italic;letter-spacing:0}
.resume.t-elegant header .title{color:var(--rs-accent);font-weight:600}
.resume.t-elegant h2{font-family:"Source Serif 4",Georgia,serif;text-transform:none;letter-spacing:0;font-size:12pt;color:var(--rs-ink);border:none;border-left:3px solid var(--rs-accent);padding:0 0 0 7pt;margin-bottom:6pt}
/* Key highlights (Pro): the default look, every Pro template */
.resume ul.hl{list-style:none;padding:0;margin:0}
.resume ul.hl li{position:relative;padding-left:12pt;margin:2pt 0}
.resume ul.hl li::before{content:"";position:absolute;left:0;top:.5em;width:5pt;height:5pt;border-radius:1pt;background:var(--rs-accent)}
.resume ul.hl b{color:var(--rs-accent)}
/* Free resumes: a small line at the bottom */
.resume .rs-brand{margin-top:14pt;text-align:center;font-size:7.5pt;color:#9aa5a0;letter-spacing:.02em}
/* Impact (Pro): colour header band, highlights as three cards */
.resume.t-impact{font-family:"DM Sans",Arial,Helvetica,sans-serif;font-size:10.3pt;--rs-accent:#0f6b56;--rs-rule:#0f6b5640}
.resume.t-impact header{background:var(--rs-accent);border-radius:6pt;padding:13pt 15pt;margin-bottom:9pt;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.resume.t-impact header h1{color:#fff;font-size:25pt;letter-spacing:-.01em}
.resume.t-impact header .title{color:#fff;opacity:.92;font-weight:600}
.resume.t-impact header .contact,.resume.t-impact header .contact .sep{color:#fff;opacity:.85}
.resume.t-impact .photo{border:2pt solid #fff}
.resume.t-impact h2{border-bottom:1.5px solid var(--rs-rule);font-size:10pt;letter-spacing:.05em}
.resume.t-impact .s-hl h2{display:none}
.resume.t-impact ul.hl{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6pt}
.resume.t-impact ul.hl li{margin:0;padding:7pt 8pt;border-radius:5pt;background:#f4f7f6;border-top:2.5pt solid var(--rs-accent);font-size:9.4pt;line-height:1.35;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.resume.t-impact ul.hl li::before{content:attr(data-n);position:static;display:block;width:auto;height:auto;background:none;color:var(--rs-accent);font-size:16pt;font-weight:800;line-height:1.1;margin-bottom:3pt}
.resume.t-impact .what b{color:var(--rs-ink)}
/* Timeline (Pro): experience on an accent line, dates first */
.resume.t-timeline{font-family:"DM Sans",Arial,Helvetica,sans-serif;font-size:10.3pt;--rs-accent:#1d3557;--rs-rule:#1d355733}
.resume.t-timeline header{border-left:5pt solid var(--rs-accent);padding:2pt 0 4pt 11pt}
.resume.t-timeline h1{font-size:25pt;letter-spacing:-.01em}
.resume.t-timeline header .title{color:var(--rs-accent);font-weight:700}
.resume.t-timeline h2{text-transform:none;letter-spacing:0;font-size:12pt;border-bottom:1px solid var(--rs-rule);color:var(--rs-accent)}
.resume.t-timeline .s-exp .item{position:relative;margin-left:4pt;padding:0 0 2pt 13pt;border-left:1.5pt solid var(--rs-rule)}
.resume.t-timeline .s-exp .item::before{content:"";position:absolute;left:-4.6pt;top:3.5pt;width:7.5pt;height:7.5pt;border-radius:50%;background:var(--rs-accent);-webkit-print-color-adjust:exact;print-color-adjust:exact}
.resume.t-timeline .s-exp .row{flex-direction:row-reverse;justify-content:flex-end}
.resume.t-timeline .s-exp .when{color:var(--rs-accent);font-weight:700;min-width:84pt}
/* Fit to one page */
.resume.d-compact{zoom:.94}
.resume.d-tight{zoom:.88}
.resume.d-tight section{margin-top:7pt}
.resume.d-tight .item{margin-bottom:5pt}
@media (max-width:600px){.resume .row,.resume.t-timeline .s-exp .row{flex-direction:column;gap:0}.resume .when{white-space:normal}.resume.t-impact ul.hl{grid-template-columns:1fr}}
`;

/** Fonts used by the templates (loaded once by the page). */
export const RESUME_FONTS = "https://fonts.googleapis.com/css2?family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,500;0,8..60,600;0,8..60,700;1,8..60,400;1,8..60,500&display=swap";

/** Sample profile for the public builder page. */
export const SAMPLE = {
  fullName: "Ananya Sen", headline: "Flutter Developer", city: "Kolkata", phone: "+91 90000 00000", email: "ananya.sen@example.com",
  linkedinUrl: "https://linkedin.com/in/ananya-sen", githubUrl: "https://github.com/ananyasen", experienceYears: 3,
  about: "Flutter developer with 3 years of experience shipping consumer apps used by 50,000+ people. I build clean, tested features end to end, from pixel-perfect UI to Firebase back ends, and I care about fast, crash-free apps.",
  skills: ["Flutter", "Dart", "Bloc", "Provider", "Firebase", "REST APIs", "Google Maps", "Push Notifications", "Clean Architecture", "Testing", "CI/CD", "Git"],
  experience: [
    { company: "Nimbus Labs", role: "Flutter Developer", start: "2023-07", end: "", points: "Built real-time order tracking with Google Maps and Firebase for a food delivery app with 50k+ downloads\nCut crash rate from 2.1% to 0.3% by adding error handling, logging and widget tests\nMoved the app to Bloc and clean architecture, reducing new feature time by about 30%" },
    { company: "Pixel Apps", role: "Flutter Intern", start: "2022-12", end: "2023-06", points: "Built 15+ screens from Figma designs and connected them to REST APIs\nSet up push notifications with Firebase Cloud Messaging" },
  ],
  apps: [{ name: "QuickBite", role: "Lead Flutter developer", url: "https://play.google.com/store/apps/details?id=example.quickbite", about: "Food delivery app with live rider tracking, payments and order history · Flutter, Firebase, Google Maps" }],
  education: [{ degree: "MCA", institute: "Techno India University", year: 2022, score: "8.4 CGPA" }],
  certifications: [{ name: "Flutter in 10 Days", issuer: "Widgetry Academy", year: 2026 }],
  verification: "self",
};

/** Profile score (0–100): how complete and convincing the whole profile is. */
export function profileScore(p) {
  const work = p.experience || [], pts = work.flatMap(w => lines(w.points));
  const checks = [
    [!!p.photo, 8, "Add a profile photo", "photo"],
    [!!(p.about && p.about.length >= 120), 10, "Write a 2–3 line summary about what you build", "edit"],
    [(p.skills || []).length >= 6, 10, "Add at least 6 skills", "edit"],
    [work.length > 0 || Number(p.experienceYears) === 0, 12, "Add your work experience or internships", "edit"],
    [pts.some(l => /\d/.test(l)), 10, "Use numbers in your achievements (downloads, % faster, users)", "edit"],
    [(p.apps || []).some(a => safe(a.url)), 14, "Add an app or project with a Play Store or GitHub link", "edit"],
    [(p.education || []).length > 0, 8, "Add your education", "edit"],
    [!!(p.githubUrl && p.linkedinUrl), 8, "Add both GitHub and LinkedIn", "edit"],
    [!!p.phone, 5, "Add your phone number", "edit"],
    [(p.jobTypes || []).length > 0 && (p.workModes || []).length > 0, 5, "Tell us the job type and work mode you want", "edit"],
    [p.verification !== "self", 10, "Get your portfolio checked by a Widgetry engineer", "verify"],
  ];
  const score = checks.reduce((s, [ok, w]) => s + (ok ? w : 0), 0);
  return { score, done: checks.filter(c => c[0]).length, total: checks.length, tips: checks.filter(c => !c[0]).map(c => ({ text: c[2], action: c[3] })) };
}
