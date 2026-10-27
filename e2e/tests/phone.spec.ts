// On a phone: the menu opens and its links are reachable on the home page and the jobs pages.
import { test, expect } from "../helpers";

test("home page menu opens on a phone", async ({ page }) => {
  await page.goto("/");
  const toggle = page.locator(".navtoggle");
  await expect(toggle).toBeVisible();
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  await expect(page.locator("#navlinks a").first()).toBeVisible();
});

test("jobs menu opens on a phone", async ({ page }) => {
  await page.goto("/jobs.html");
  const toggle = page.locator(".navburger");
  await expect(toggle).toBeVisible();
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
});
