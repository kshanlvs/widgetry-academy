// Live facts for the AI tutor: fees, dates and seats exactly as students see them right now.
//
// These change every week, so they never go into the knowledge files (which would go stale) or the model's
// memory (which is older still). They are read from the same places the website and app read, and pasted
// into the prompt on every question. A "draft" short course is listed as "dates coming soon".
import { getFirestore } from "firebase-admin/firestore";
import { adminApp, canSendPush } from "./firebase.js";
import { COURSE, plansFor } from "./payments.js";
import { publicWorkshops } from "./routes/workshops.js";
import { SITE } from "./notify.js";

const inr = (n: number | null) => "₹" + Number(n).toLocaleString("en-IN");
const ist = (iso: string) => new Date(iso).toLocaleString("en-IN", { weekday: "short", day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit", timeZone: "Asia/Kolkata" }) + " IST";

/** [p], or [fallback] if it takes longer than [ms]: a slow lookup must never hold up the tutor's answer. */
const within = <T>(p: Promise<T>, ms: number, fallback: T) =>
  Promise.race([p.catch(() => fallback), new Promise<T>(r => setTimeout(() => r(fallback), ms))]);

/** Next batch of the main course (Admin → Next batch), or null when Firestore isn't reachable. */
async function nextBatch(): Promise<Record<string, unknown> | null> {
  if (!canSendPush()) return null; // no Firebase service account (tests, local dev)
  try {
    const d = await within(getFirestore(adminApp()).collection("settings").doc("batch").get(), 2000, null);
    return d && d.exists ? d.data() ?? null : null;
  } catch { return null; }
}

let cache: { at: number; text: string } | null = null;
/** Tests reset the one-minute cache. */
export function clearFactsCache() { cache = null; }

/** Plain text, one line per fact. Cached for a minute: facts barely change between two questions. */
export async function academyFacts(): Promise<string> {
  if (cache && Date.now() - cache.at < 60_000) return cache.text;
  const [plans, batch, shorts] = await Promise.all([
    within(plansFor({ payStatus: "pending", amountPaid: 0 }).then(p => p.plans), 2500, []),
    nextBatch(),
    within(publicWorkshops(), 2500, []),
  ]);

  const lines: string[] = [`Today: ${ist(new Date().toISOString()).replace(/,? \d{1,2}:\d{2}.*$/, "")}`];
  lines.push(`${COURSE} (main course for beginners, ${SITE}/#fees):`);
  for (const p of plans) lines.push(`- ${p.title}: ${inr(p.amount)}${p.fullPrice !== p.amount ? ` now, full fee ${inr(p.fullPrice)}` : ""}. ${p.note}`);
  if (batch) {
    const b = batch as Record<string, string | number | null>;
    const parts = [b.name, b.startDate && `starts ${b.startDate}`, b.days, b.time, b.mode].filter(Boolean);
    if (parts.length) lines.push(`- Next batch: ${parts.join(", ")}`);
    if (typeof b.seatsLeft === "number") lines.push(`- Early-bird seats left: ${b.seatsLeft}`);
  } else lines.push(`- Next batch dates: shown at ${SITE}/#fees`);

  if (shorts.length) lines.push("Short courses:");
  for (const w of shorts) {
    const when = w.schedule || (w.startsAt ? `starts ${ist(w.startsAt)}` : "dates coming soon");
    const price = w.earlyPrice ? `${inr(w.earlyPrice)} early-bird${w.earlySeatsLeft != null ? ` (${w.earlySeatsLeft} early-bird seats left)` : ""}, regular ${inr(w.price)}` : inr(w.price);
    const state = w.status !== "open" ? "enrolment opens soon" : w.seatsLeft > 0 ? `enrolling now, ${w.seatsLeft} seats left` : "this batch is full";
    lines.push(`- ${w.title}: ${when}; ${state}; fee ${price}; ${SITE}/${w.slug}.html`);
  }
  cache = { at: Date.now(), text: lines.join("\n") };
  return cache.text;
}
