// Mock interview booking on the website (Flutter only): choose level, round and time, pay, see it under "My mock interviews".
// Payments and interviewer slots are stood in for; the server side is covered by the API tests.
import { test, expect, signIn, USERS } from "../helpers";

const SLOT_AT = new Date(Date.now() + 3 * 86_400_000).toISOString();
const interviewer = { name: "Arjun Mehta", title: "Senior Flutter Engineer", company: "Acme", years: 7, tracks: ["flutter"], bio: null, linkedinUrl: null };

async function standIns(page: import("@playwright/test").Page) {
  const state = { booked: false, book: null as any };
  // Real options from the API, with payments switched on
  await page.route("**/api/mock/options", async r => { const res = await r.fetch(); const j = await res.json(); r.fulfill({ json: { ...j, enabled: true } }); });
  await page.route("**/api/mock/slots*", r => r.fulfill({ json: { slots: state.booked ? [] : [{ id: 41, startsAt: SLOT_AT, durationMin: 60, interviewer }] } }));
  await page.route("**/api/mock/book", r => { state.book = r.request().postDataJSON(); r.fulfill({ status: 201, json: { bookingId: 7, orderId: "order_M1", amount: 79900, currency: "INR", keyId: "rzp_test_e2e", name: "Widgetry Academy", description: "Mock interview · Flutter · Mid level", prefill: {}, holdMinutes: 15 } }); });
  await page.route("**/api/mock/verify", r => { state.booked = true; r.fulfill({ json: { ok: true, status: "confirmed", bookingId: 7 } }); });
  await page.route("**/api/mock/mine", r => r.fulfill({ json: { bookings: state.booked ? [{
    id: 7, status: "confirmed", startsAt: SLOT_AT, durationMin: 60, track: "flutter", level: "mid", format: "technical", title: "Mock interview · Flutter · Mid level",
    amount: 799, canCancel: true, interviewer, meetingLink: "https://meet.google.com/abc-defg-hij", viewer: "candidate" }] : [] } }));
  await page.route("https://checkout.razorpay.com/v1/checkout.js", r => r.fulfill({ contentType: "text/javascript",
    body: `window.Razorpay = function (o) { this.on = () => {}; this.open = () => setTimeout(() => o.handler({ razorpay_order_id: o.order_id, razorpay_payment_id: "pay_M1", razorpay_signature: "${"b".repeat(64)}" }), 50); };` }));
  return state;
}

test("only Flutter, levels with prices; signed out asks to sign in and keeps the choices", async ({ page, errors }) => {
  await standIns(page);
  await page.goto("/mock-interview.html");
  await expect(page.locator("[data-level]")).toHaveCount(3);
  await expect(page.locator("#book")).not.toContainText("Android");
  await page.click('[data-level="mid"]');
  await page.click('[data-slot="41"]');
  await expect(page.locator(".who")).toContainText("Arjun Mehta");
  await expect(page.locator("#bSignin")).toHaveText("Sign in to book");
  await page.click("#bSignin");
  await page.goBack();
  await expect(page.locator('[data-level="mid"]')).toHaveAttribute("aria-pressed", "true");
  expect(errors).toEqual([]);
});

test("signed in: book a mid-level technical round, pay, and see it with the joining link", async ({ page, errors }) => {
  const state = await standIns(page);
  await signIn(page, USERS.seeker);
  await page.goto("/mock-interview.html");
  await page.click('[data-level="mid"]');
  await page.click('[data-format="technical"]');
  await expect(page.locator("#bPay")).toBeDisabled();
  await page.click('[data-slot="41"]');
  await page.fill("#focus", "Bloc and clean architecture");
  await expect(page.locator("#bPay")).toHaveText("Pay ₹799 & book");
  await page.click("#bPay");
  await expect(page.locator("#book")).toContainText("You're booked");
  expect(state.book).toMatchObject({ slotId: 41, track: "flutter", level: "mid", format: "technical", focus: "Bloc and clean architecture", shareProfile: true });
  await expect(page.locator("#mine")).toContainText("Mock interview · Flutter · Mid level");
  await expect(page.locator("#mine a", { hasText: "Join the call" })).toHaveAttribute("href", "https://meet.google.com/abc-defg-hij");
  await expect(page.locator("#mine [data-cancel]")).toBeVisible();
  expect(errors).toEqual([]);
});
