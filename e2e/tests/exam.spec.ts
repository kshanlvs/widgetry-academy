// Exam Center: take an exam as a guest, pass, sign in and claim the badge; fail one signed in; open the public badge page.
import { test, expect, signIn, sql, USERS } from "../helpers";
import { byId } from "../../jobs-api/src/exam/questions";
import type { Page } from "@playwright/test";

const shot = async (page: Page, name: string) => { if (process.env.SHOTDIR) await page.screenshot({ path: `${process.env.SHOTDIR}/${name}.png`, fullPage: false }); };

test.beforeEach(async () => {
  await sql("DELETE FROM exam_badges"); await sql("DELETE FROM exam_attempts");
});

/** Answers the question on screen correctly (or leaves it blank), then moves on. */
async function answerAll(page: Page, right: boolean) {
  const total = await page.locator("#rDots button").count();
  for (let i = 0; i < total; i++) {
    const card = page.locator("#qcard");
    await expect(card.locator("h2")).toBeVisible();
    if (right) {
      // find the question by its prompt text
      const prompt = await card.locator("h2").innerText();
      const qq = [...byId.values()].find(x => x.prompt.replace(/`/g, "") === prompt.trim())!;
      expect(qq, prompt).toBeTruthy();
      if (qq.type === "order") {
        for (let t = 0; t < qq.answer.length; t++) {
          let cur = await card.locator(".oi").evaluateAll(els => els.map(e => (e as HTMLElement).dataset.id!));
          let j = cur.indexOf(qq.answer[t]);
          while (j > t) { await card.locator(`.oi[data-id="${qq.answer[t]}"] [data-up]`).click(); j--; }
        }
      } else for (const a of qq.answer) await card.locator(`[data-o="${a}"]`).click();
    }
    if (i === 3) await shot(page, "exam-question");
    await page.click("#rNext");
  }
}

test("a guest passes the Junior exam, then signs in and claims the badge", async ({ page, errors }) => {
  await page.goto("/exam.html");
  await expect(page.locator("[data-start]")).toHaveCount(3);
  await shot(page, "exam-landing");
  await page.click('[data-start="junior"]');
  await expect(page.locator("#sheet")).toContainText("You're not signed in");
  await page.click("#stGo");
  await expect(page.locator("#rDots button")).toHaveCount(15);
  await expect(page.locator("#rTimer")).toContainText(/19:5\d|20:00/);
  await answerAll(page, true);
  await expect(page.locator("#sheet")).toContainText("All answered");
  await shot(page, "exam-submit");
  await page.click("#subGo");
  await expect(page.locator(".verdict h1")).toContainText("distinction");
  await expect(page.locator(".claim")).toContainText("Claim your badge");
  await expect(page.locator("#rvList .rv")).toHaveCount(15);
  await page.waitForTimeout(1600);
  await shot(page, "exam-result-guest");
  await page.locator("#review").scrollIntoViewIfNeeded();
  await shot(page, "exam-review");

  // Signs in and comes back: the badge is claimed
  await signIn(page, USERS.seeker);
  await page.goto("/exam.html?from=login#claim");
  await expect(page.locator("#sheet")).toContainText("Badge claimed");
  await page.waitForTimeout(1200);
  await shot(page, "exam-claimed");
  await page.click("#sheet [data-close]");
  await expect(page.locator("#mine .mb")).toHaveCount(1);
  await expect(page.locator(".lv .earned")).toHaveText(/EARNED · 100%/);
  const href = await page.locator("#mine .mb").getAttribute("href");

  // The public badge page
  await page.goto("/" + href);
  await expect(page.locator(".hero h1")).toHaveText("Priya Sharma");
  await expect(page.locator(".ver")).toContainText("Verified");
  await page.waitForTimeout(1000);
  await shot(page, "badge-page");
  expect(errors).toEqual([]);
});

test("signed in: an empty attempt fails, explains every answer and offers a retry", async ({ page, errors }) => {
  await signIn(page, USERS.employer);
  await page.goto("/exam.html");
  await page.click('[data-start="senior"]');
  await page.click("#stGo");
  await expect(page.locator("#rDots button")).toHaveCount(15);
  // flag one, jump around with the dots
  await page.click("#rFlag");
  await expect(page.locator("#rDots button.flag")).toHaveCount(1);
  await page.locator("#rDots button").nth(14).click();
  await page.click("#rNext");
  await expect(page.locator("#sheet")).toContainText("15 not answered");
  await page.click("#subGo");
  await expect(page.locator(".verdict h1")).toContainText("Not yet");
  await expect(page.locator('[data-f="no"]')).toHaveText("Wrong 15");
  await expect(page.locator("#again")).toBeVisible();
  await page.waitForTimeout(1500);
  await shot(page, "exam-result-fail");
  expect(errors).toEqual([]);
});

test("a badge link that doesn't exist says so", async ({ page }) => {
  await page.goto("/badge.html?id=nope12345");
  await expect(page.locator("h1")).toHaveText("Badge not found");
});

test("on a phone: no sideways scrolling on the landing page, a code question or the results", async ({ page, errors }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const noSideways = async () => expect(await page.evaluate(() => document.documentElement.scrollWidth - innerWidth)).toBeLessThanOrEqual(1);
  await page.goto("/exam.html");
  await expect(page.locator("[data-start]")).toHaveCount(3);
  await noSideways(); await shot(page, "phone-landing");
  await page.click('[data-start="senior"]');
  await page.click("#stGo");
  await expect(page.locator("#rDots button")).toHaveCount(15);
  for (let i = 0; i < 15 && !(await page.locator("#qcard pre.code").count()); i++) await page.click("#rNext");
  await noSideways(); await shot(page, "phone-question");
  await page.locator("#rDots button").nth(14).click();
  await page.click("#rNext"); await page.click("#subGo");
  await expect(page.locator(".verdict h1")).toBeVisible();
  await page.waitForTimeout(1500);
  await noSideways(); await shot(page, "phone-result");
  expect(errors).toEqual([]);
});
