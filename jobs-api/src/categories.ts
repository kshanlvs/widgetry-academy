// Job categories live in the job_categories table, so adding one (e.g. React Native) needs no code change.
import { query } from "./db.js";
import { HttpError } from "./errors.js";

export interface Category { slug: string; name: string; sortOrder: number; suggestedSkills: string[] }

let cache: { at: number; list: Category[] } | null = null;
const TTL = 60_000;

export async function categories(): Promise<Category[]> {
  if (cache && Date.now() - cache.at < TTL) return cache.list;
  const rows = await query<any>("SELECT slug, name, sort_order, suggested_skills FROM job_categories WHERE active = 1 ORDER BY sort_order, name");
  const list = rows.map(r => ({
    slug: r.slug, name: r.name, sortOrder: Number(r.sort_order),
    suggestedSkills: typeof r.suggested_skills === "string" ? JSON.parse(r.suggested_skills) : (r.suggested_skills ?? []),
  }));
  cache = { at: Date.now(), list };
  return list;
}

export function clearCategoryCache() { cache = null; }

/** Throws a friendly 400 if any slug isn't an active category. */
export async function assertCategories(slugs: string[]) {
  const known = new Set((await categories()).map(c => c.slug));
  const bad = slugs.find(s => !known.has(s));
  if (bad) throw new HttpError(400, `Unknown category "${bad}". Choose one of: ${[...known].join(", ")}.`);
}
