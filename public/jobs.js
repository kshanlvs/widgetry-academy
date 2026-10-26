// Widgetry Jobs: shared helpers (auth, API calls, formatting). Loaded as an ES module.
import { initializeApp, getApps } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js";
import { getAuth, onAuthStateChanged, GoogleAuthProvider, signInWithPopup, signInWithRedirect, getRedirectResult, signOut } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";
import { firebaseConfig } from "./firebase-config.js";
import { JOBS_API } from "./jobs-api-url.js";

const app = getApps()[0] || initializeApp(firebaseConfig);
export const auth = getAuth(app);
auth.languageCode = "en";
getRedirectResult(auth).catch(() => {});

export const $ = id => document.getElementById(id);
export const esc = t => { const d = document.createElement("div"); d.textContent = t == null ? "" : String(t); return d.innerHTML; };
export const safeUrl = u => (/^https?:\/\//i.test(u || "") ? u : "");

export const LABEL = {
  type: { full_time: "Full-time", internship: "Internship", freelance: "Freelance", contract: "Contract", part_time: "Part-time" },
  mode: { remote: "Remote", onsite: "On-site", hybrid: "Hybrid" },
  level: { fresher: "Fresher", junior: "Junior (0–2 yrs)", mid: "Mid (2–5 yrs)", senior: "Senior (5+ yrs)", lead: "Lead" },
  period: { month: "/ month", year: "/ year", project: "/ project" },
  notice: { immediate: "Immediate", "15_days": "15 days", "30_days": "30 days", "60_days": "60 days", "90_days": "90 days" },
  report: { scam: "Looks like a scam", asks_fees: "Asks candidates to pay", fake: "Fake company or job", expired: "Job is no longer open", wrong_info: "Wrong information", other: "Something else" },
  verification: { self: "Self-declared", portfolio: "✓ Portfolio checked", verified: "★ Widgetry verified" },
};

/**
 * Job categories come from the server (job_categories table), so a new one appears everywhere without code changes.
 * The fallback is only used if the server can't be reached.
 */
const FALLBACK_CATS = [{ slug: "flutter", name: "Flutter", liveJobs: 0, suggestedSkills: [] }, { slug: "android", name: "Android", liveJobs: 0, suggestedSkills: [] }, { slug: "ios", name: "iOS", liveJobs: 0, suggestedSkills: [] }, { slug: "react-native", name: "React Native", liveJobs: 0, suggestedSkills: [] }];
let metaP = null;
export function getMeta() { return (metaP ??= api("/meta").catch(e => { metaP = null; throw e; })); }
export async function getCategories() { try { return (await getMeta()).categories || FALLBACK_CATS; } catch { return FALLBACK_CATS; } }
export const catName = (cats, slug) => cats.find(c => c.slug === slug)?.name || (slug ? slug[0].toUpperCase() + slug.slice(1) : "Flutter");

const inr = n => "₹" + Number(n).toLocaleString("en-IN");
const short = n => (n >= 100000 ? (n / 100000).toFixed(n % 100000 ? 1 : 0) + "L" : n >= 1000 ? Math.round(n / 1000) + "k" : String(n));
export function salaryText(s, compact = false) {
  if (!s) return "";
  const f = compact ? n => "₹" + short(n) : inr;
  const range = s.min != null && s.max != null ? (s.min === s.max ? f(s.min) : `${f(s.min)}–${compact ? short(s.max) : inr(s.max).slice(1)}`) : s.min != null ? `${f(s.min)}+` : `up to ${f(s.max)}`;
  return range + " " + (LABEL.period[s.period] || "");
}
export function timeAgo(d) {
  const s = (Date.now() - new Date(d).getTime()) / 1000;
  if (s < 3600) return "just now";
  if (s < 86400) return Math.floor(s / 3600) + "h ago";
  const days = Math.floor(s / 86400);
  return days === 1 ? "yesterday" : days < 30 ? days + " days ago" : new Date(d).toLocaleDateString("en-IN", { day: "numeric", month: "short" });
}
const COLORS = ["#0f6b56", "#2f6fd6", "#c0571b", "#7b4fd6", "#b8860b", "#0277bd", "#c2185b", "#2e7d32"];
export function logo(name) {
  const n = String(name || "?").trim(), i = [...n].reduce((a, c) => a + c.charCodeAt(0), 0) % COLORS.length;
  return `<span class="logo" style="background:${COLORS[i]}" aria-hidden="true">${esc(n[0]?.toUpperCase() || "?")}</span>`;
}

/** Call the jobs API. Sends the signed-in user's token when available. */
export async function api(path, { method = "GET", body, auth: needAuth = false } = {}) {
  const headers = { "content-type": "application/json" };
  const u = auth.currentUser;
  if (u) headers.authorization = "Bearer " + (await u.getIdToken());
  else if (needAuth) throw Object.assign(new Error("Please sign in first."), { status: 401 });
  let r;
  try { r = await fetch(JOBS_API + path, { method, headers, body: body ? JSON.stringify(body) : undefined }); }
  catch { throw Object.assign(new Error("Network problem. Check your connection and try again."), { status: 0 }); }
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw Object.assign(new Error(data.error || "Something went wrong. Please try again."), { status: r.status, issues: data.issues });
  return data;
}

/** Resolves once Firebase knows whether someone is signed in; calls cb on every change. */
export function onUser(cb) { onAuthStateChanged(auth, u => cb(u)); }

export async function googleSignIn() {
  try { await signInWithPopup(auth, new GoogleAuthProvider()); }
  catch (e) {
    if (["auth/popup-blocked", "auth/operation-not-supported-in-this-environment"].includes(e?.code)) return signInWithRedirect(auth, new GoogleAuthProvider());
    if (["auth/popup-closed-by-user", "auth/cancelled-popup-request"].includes(e?.code)) return;
    throw e;
  }
}
export const logOut = () => signOut(auth);
export const loginLink = () => "pages/login.html?next=" + encodeURIComponent(location.pathname + location.search);

export const GOOGLE_SVG = '<svg viewBox="0 0 48 48" width="20" height="20" aria-hidden="true"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"/></svg>';

/** Small "signed in as … · Sign out" area in the nav */
export function mountWho(el) {
  onUser(u => {
    el.innerHTML = u ? `<a href="pages/dashboard.html" style="font-weight:700">My courses</a> ${location.pathname.endsWith("my-profile.html") ? "" : `<a href="my-profile.html" class="hide-m" style="font-weight:700">My profile</a>`} <span class="hide-m">${esc(u.email || "")}</span> <button class="linkbtn" type="button">Sign out</button>` : "";
    const b = el.querySelector("button"); if (b) b.onclick = () => logOut();
  });
}

export function toast(msg) {
  let t = document.querySelector(".toast");
  if (!t) { t = document.createElement("div"); t.className = "toast"; t.setAttribute("role", "status"); document.body.appendChild(t); }
  t.textContent = msg; t.hidden = false; clearTimeout(toast.t); toast.t = setTimeout(() => (t.hidden = true), 3500);
}

/** Show field-level problems returned by the API next to the form */
export function showIssues(errEl, e) {
  errEl.textContent = e.message; errEl.hidden = false;
  errEl.scrollIntoView({ behavior: "smooth", block: "center" });
}

// Phones and tablets: a ☰ button opens the nav links as a menu (the CSS shows it below 980px)
(function navMenu() {
  const nav = document.querySelector(".jnav .wrap"), links = nav && nav.querySelector(".jlinks");
  if (!links || nav.querySelector(".navburger")) return;
  links.id ||= "jlinks";
  const b = document.createElement("button");
  b.type = "button"; b.className = "navburger"; b.setAttribute("aria-controls", links.id); b.setAttribute("aria-expanded", "false"); b.setAttribute("aria-label", "Open menu");
  b.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16"/></svg>';
  const set = open => { links.classList.toggle("open", open); b.setAttribute("aria-expanded", String(open)); b.setAttribute("aria-label", open ? "Close menu" : "Open menu"); };
  b.onclick = e => { e.stopPropagation(); set(!links.classList.contains("open")); };
  links.addEventListener("click", e => { if (e.target.closest("a")) set(false); });
  document.addEventListener("click", e => { if (!nav.contains(e.target)) set(false); });
  document.addEventListener("keydown", e => { if (e.key === "Escape") set(false); });
  nav.insertBefore(b, links);
})();
