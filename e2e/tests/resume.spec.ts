// The resume flow people will use most at launch: ATS check, build without an account, sign in to save,
// then preview, download PDF and Word, and change the design.
import fs from "node:fs";
import { test, expect, api, signIn, USERS, sql, givePremium } from "../helpers";

const PDF = new URL("../fixtures/two-column-resume.pdf", import.meta.url).pathname;
const DOCX = new URL("../fixtures/fresher-resume.docx", import.meta.url).pathname;

test.beforeEach(async () => {
  await api("DELETE", "/talent/me", undefined, USERS.seeker);
  await sql("DELETE FROM resume_premium WHERE uid = ?", [USERS.seeker.uid]);
});

test("ATS checker scores an uploaded resume without signing in", async ({ page, errors }) => {
  await page.goto("/ats-checker.html");
  await page.setInputFiles("#file", PDF);
  await page.click("#check");
  await expect(page.locator("#res .ring b")).toHaveText(/^\d{1,3}$/, { timeout: 20_000 });
  const score = Number(await page.locator("#res .ring b").textContent());
  expect(score).toBeGreaterThan(0);
  expect(score).toBeLessThanOrEqual(100);
  await expect(page.locator("#toBuilder")).toBeVisible();
  expect(errors).toEqual([]);
});

test("build a resume signed out by importing a file, then sign in and it is saved", async ({ page, errors }) => {
  await page.goto("/talent.html");
  await page.setInputFiles("#file", DOCX);
  await expect(page.locator("#impMsg")).not.toBeEmpty({ timeout: 20_000 });
  await expect(page.locator("#fullName")).not.toHaveValue("");
  await expect(page.locator("#headline")).not.toHaveValue("");

  // Preview with a live ATS score
  await page.click("#bPreview");
  await expect(page.locator("#pv")).toBeVisible();
  await expect(page.locator("#pvScore")).toContainText(/\d/);
  await page.click("#pvClose");

  // Saving asks to sign in, and keeps what was typed
  await page.click("#bSave");
  await expect(page.locator("#signin")).toBeVisible();
  await page.click("#siClose");
  await page.click("#bSave"); // the dialog again; this time "sign in"
  await signIn(page, USERS.seeker);
  await page.reload();
  await expect(page).toHaveURL(/resume\.html/, { timeout: 20_000 });
  const me = await api("GET", "/talent/me", undefined, USERS.seeker);
  expect(me.body.profile?.fullName, "saved to the account").toBeTruthy();
  expect(errors).toEqual([]);
});

test("signed in: free resume (PDF), then Premium: Word, Key highlights, fit to one page, Pro templates", async ({ page, errors }, info) => {
  const put = await api("PUT", "/talent/me", {
    fullName: "Priya Sharma", headline: "Flutter Developer · 2 years", experienceYears: 2, city: "Kolkata", categories: ["flutter"],
    skills: ["Flutter", "Dart", "Bloc", "Firebase", "REST APIs"], about: "Flutter developer who ships production apps with Bloc and Firebase.",
    experience: [{ company: "Bytewave Labs", role: "Flutter Developer", start: "2024-01", end: "", points: "Built offline-first ordering with Bloc\nCut crash rate by 40% with Crashlytics" }],
    education: [{ degree: "MCA", institute: "Techno India", year: 2023, score: "" }], achievements: ["Winner, college hackathon 2022"], languages: ["English", "Hindi"],
  }, USERS.seeker);
  expect(put.status, JSON.stringify(put.body)).toBe(200);
  await signIn(page, USERS.seeker);
  await page.goto("/resume.html");
  await expect(page.locator("#paper .resume")).toBeVisible();
  await expect(page.locator("#paper")).toContainText("Priya Sharma");
  await expect(page.locator("#paper")).toContainText("Achievements");
  await expect(page.locator("#pages")).toContainText(/page/);

  const hasChromium = !!process.env.CHROMIUM_PATH || process.env.CI;
  test.skip(!hasChromium, "PDF downloads need Chromium on the API (set CHROMIUM_PATH)");
  const [pdf] = await Promise.all([page.waitForEvent("download", { timeout: 45_000 }), page.click("#bPrint")]);
  const pdfPath = info.outputPath("resume.pdf");
  await pdf.saveAs(pdfPath);
  expect(fs.readFileSync(pdfPath).subarray(0, 4).toString()).toBe("%PDF");
  expect(pdf.suggestedFilename()).toMatch(/Priya-Sharma.*\.pdf$/);

  // Free: a small Widgetry line; Word, colours and "fit to one page" are Premium
  await expect(page.locator("#paper .rs-brand")).toBeVisible();
  await expect(page.locator("#bWord")).toContainText("🔒");
  await page.click("#bWord");
  await expect(page.locator("#toast")).toContainText("Premium");
  await page.click('[data-tab="design"]');
  await page.click('[data-d="tight"]');
  await expect(page.locator("#paper .resume")).not.toHaveClass(/d-tight/);

  // Premium: Word downloads, Pro features apply, the Widgetry line goes
  await givePremium(USERS.seeker);
  await page.reload();
  await expect(page.locator("#paper .resume")).toBeVisible();
  await expect(page.locator("#paper .rs-brand")).toHaveCount(0);
  await expect(page.locator("#paper")).toContainText("Key Highlights");
  const [word] = await Promise.all([page.waitForEvent("download", { timeout: 30_000 }), page.click("#bWord")]);
  const wordPath = info.outputPath("resume.docx");
  await word.saveAs(wordPath);
  expect(fs.readFileSync(wordPath).subarray(0, 2).toString()).toBe("PK");
  await page.click('[data-tab="design"]');
  await page.click('[data-d="tight"]');
  await expect(page.locator("#paper .resume")).toHaveClass(/d-tight/);
  await page.click("#tpl [data-t=impact]");
  await expect(page.locator("#paper .resume")).toHaveClass(/t-impact/);
  expect(errors).toEqual([]);
});

test("my profile page shows the saved resume", async ({ page, errors }) => {
  await api("PUT", "/talent/me", {
    fullName: "Priya Sharma", headline: "Flutter Developer", experienceYears: 1, categories: ["flutter"], skills: ["Flutter", "Dart"],
  }, USERS.seeker);
  await signIn(page, USERS.seeker);
  await page.goto("/my-profile.html");
  await expect(page.locator("#root")).toContainText("Priya Sharma");
  expect(errors).toEqual([]);
});
