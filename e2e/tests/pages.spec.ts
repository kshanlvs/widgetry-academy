// Every page on the site: opens without script errors, its own files load, internal links point to real pages,
// and (on the phone project) nothing scrolls sideways.
import fs from "node:fs";
import path from "node:path";
import { test, expect } from "../helpers";

const PUBLIC = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../../public");
const pages = (dir = PUBLIC): string[] => fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
  const p = path.join(dir, e.name);
  if (e.isDirectory()) return ["vendor", "shots", "brochures"].includes(e.name) ? [] : pages(p);
  return e.name.endsWith(".html") ? ["/" + path.relative(PUBLIC, p).split(path.sep).join("/")] : [];
});

// Pages that need Firebase sign-in or the admin's Firestore data to show anything; they must still load cleanly
const ALL = pages().sort();

/** Does an internal link point to a file that exists? (Firebase serves "/x" as "/x.html" and "/dir/" as "/dir/index.html".) */
function exists(urlPath: string) {
  const clean = decodeURIComponent(urlPath.split(/[?#]/)[0]!);
  const f = path.join(PUBLIC, clean);
  return fs.existsSync(f) && fs.statSync(f).isFile() || fs.existsSync(f + ".html") || fs.existsSync(path.join(f, "index.html"));
}

for (const url of ALL) {
  test(`page ${url}`, async ({ page, errors, baseURL }, info) => {
    const broken: string[] = [];
    page.on("response", r => {
      const u = new URL(r.url());
      // Own files only; API calls that need sign-in (401/403) are expected when signed out
      if (u.origin === new URL(baseURL!).origin && r.status() >= 400 && !u.pathname.startsWith("/api/")) broken.push(`${r.status()} ${u.pathname}`);
    });
    const res = await page.goto(url, { waitUntil: "load" });
    expect(res?.status(), "page loads").toBeLessThan(400);
    await page.waitForTimeout(400); // let module scripts run
    expect(errors, "no script errors").toEqual([]);
    expect(broken, "own files and images load").toEqual([]);
    expect((await page.title()).trim(), "has a title").not.toBe("");

    if (info.project.name === "phone") {
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      expect(overflow, "no sideways scrolling on a phone").toBeLessThanOrEqual(1);
      return;
    }
    const links = await page.$$eval("a[href]", as => as.map(a => (a as HTMLAnchorElement).href));
    const own = [...new Set(links)].map(h => new URL(h)).filter(u => u.origin === new URL(baseURL!).origin && !u.pathname.startsWith("/api/"));
    const dead = own.filter(u => !exists(u.pathname)).map(u => u.pathname);
    expect(dead, "internal links point to real pages").toEqual([]);
  });
}
