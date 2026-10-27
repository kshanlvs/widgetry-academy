// Job seekers: browse, search and filter jobs, open one and see how to apply. Employers: post a job; it goes live after review.
import { test, expect, api, signIn, USERS } from "../helpers";

test("jobs list shows live jobs, featured first", async ({ page, errors }) => {
  await page.goto("/jobs.html?cat=all");
  const cards = page.locator("#results .jcard");
  await expect(cards).toHaveCount(3);
  await expect(cards.first()).toContainText("Flutter Developer");
  await expect(cards.first()).toContainText("Featured");
  expect(errors).toEqual([]);
});

test("search and filters narrow the list", async ({ page }) => {
  await page.goto("/jobs.html?cat=all");
  await page.fill("#q", "intern");
  await page.press("#q", "Enter");
  await expect(page.locator("#results .jcard")).toHaveCount(1);
  await expect(page.locator("#results .jcard")).toContainText("Nimbus Apps");
  await page.fill("#q", "");
  await page.press("#q", "Enter");
  await page.selectOption("#fMode", "remote");
  await expect(page.locator("#results .jcard")).toHaveCount(1);
  await page.goto("/jobs.html?cat=android");
  await expect(page.locator("#results .jcard")).toHaveCount(1);
  await expect(page.locator("#results .jcard")).toContainText("Kite Mobile");
});

test("a job page shows the details and how to apply", async ({ page, errors }) => {
  await page.goto("/jobs.html?cat=all");
  await page.locator("#results .jcard", { hasText: "Flutter Developer" }).click();
  await expect(page).toHaveURL(/job\.html\?id=/);
  await expect(page.locator("h1")).toContainText("Flutter Developer");
  await expect(page.getByRole("link", { name: /Apply on company site/ })).toHaveAttribute("href", "https://example.com/careers");
  // Google for Jobs reads this
  const ld = await page.locator('script[type="application/ld+json"]').allTextContents();
  expect(ld.map(t => JSON.parse(t)).some(j => j["@type"] === "JobPosting")).toBe(true);
  expect(errors).toEqual([]);
});

test("city and role landing pages list matching jobs", async ({ page }) => {
  await page.goto("/mobile-developer-jobs-bengaluru.html");
  await expect(page.locator("body")).toContainText("Kite Mobile");
  await page.goto("/flutter-internships.html");
  await expect(page.locator("body")).toContainText("Nimbus Apps");
});

test("an employer posts a job; it is reviewed, then goes live", async ({ page, errors }) => {
  await signIn(page, USERS.employer);
  await page.goto("/post-job.html");
  await page.fill("#companyName", "E2E Studio");
  await page.fill("#companyWebsite", "https://e2e-studio.example.com");
  await page.fill("#title", "Senior Flutter Engineer");
  await page.selectOption("#jobType", "full_time");
  await page.selectOption("#workMode", "remote");
  await page.selectOption("#level", "senior");
  await page.fill("#salaryMin", "120000");
  await page.fill("#salaryMax", "180000");
  await page.fill("#description", "Lead our Flutter team building a fintech app used by a million people. Own architecture with Bloc and clean architecture, mentor juniors, review code and ship weekly releases to both stores.");
  await page.fill("#applyUrl", "https://e2e-studio.example.com/jobs/1");
  await page.fill("#contactName", "Asha");
  await page.fill("#contactEmail", "asha@e2e-studio.example.com");
  // At least one skill
  await page.fill("#skillOther", "Flutter");
  await page.click("#bAddSkill");
  await page.check("#agree");
  await page.click("#bSubmit");
  await expect(page.locator("#ok")).toBeVisible();
  expect(errors).toEqual([]);

  // Not public until reviewed
  const pending = await api("GET", "/admin/jobs?status=pending", undefined, USERS.admin);
  const job = (pending.body.items as any[]).find(j => j.title === "Senior Flutter Engineer");
  expect(job, "the job waits for review").toBeTruthy();
  await page.goto("/jobs.html?cat=all&q=E2E");
  await expect(page.locator("#results .jcard")).toHaveCount(0);

  expect((await api("PATCH", `/admin/jobs/${job.id}`, { status: "approved" }, USERS.admin)).status).toBe(200);
  await page.goto("/jobs.html?cat=all&q=E2E");
  await expect(page.locator("#results .jcard")).toHaveCount(1);
});
