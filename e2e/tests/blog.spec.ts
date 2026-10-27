// Blog: the index lists every post, posts render with valid structured data for Google.
import fs from "node:fs";
import { test, expect } from "../helpers";

const POSTS = fs.readdirSync(new URL("../../blog-src/posts/", import.meta.url)).filter(f => f.endsWith(".md")).map(f => f.replace(/\.md$/, ""));

test("the blog index lists every post", async ({ page }) => {
  await page.goto("/blog/");
  for (const slug of POSTS) await expect(page.locator(`a[href$="${slug}.html"]`).first()).toBeAttached();
});

for (const slug of POSTS) {
  test(`post ${slug} renders with valid structured data`, async ({ page, errors }) => {
    await page.goto(`/blog/${slug}.html`);
    await expect(page.locator("h1")).toBeVisible();
    const ld = await page.locator('script[type="application/ld+json"]').allTextContents();
    expect(ld.length).toBeGreaterThan(0);
    for (const t of ld) expect(() => JSON.parse(t)).not.toThrow();
    expect(await page.locator('link[rel="canonical"]').getAttribute("href")).toBe(`https://widgetryacademy.in/blog/${slug}.html`);
    expect(errors).toEqual([]);
  });
}

test("the app's blog feed is valid and lists every post", async ({ request }) => {
  const feed = await (await request.get("/blog/feed.json")).json();
  const urls = JSON.stringify(feed);
  for (const slug of POSTS) expect(urls).toContain(`${slug}.html`);
});
