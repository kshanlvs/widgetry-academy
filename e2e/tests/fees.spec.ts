// Course fee on the home page: a registered student pays through an order from our server and Razorpay Checkout
// (the server and Razorpay are stood in for here; the server side is covered by the API tests).
import { test, expect, signIn, USERS } from "../helpers";

test("a registered student pays the full fee, then sees it paid", async ({ page, errors }) => {
  await signIn(page, USERS.seeker);
  await page.addInitScript(uid => localStorage.setItem("e2e_docs", JSON.stringify({ [`registrations/${uid}`]: { name: "Priya Sharma", phone: "9876543210", email: "priya@e2e.test", batch: "Batch 1" } })), USERS.seeker.uid);
  let status = "unpaid";
  const orders: any[] = [], verified: any[] = [];
  await page.route("**/api/payments/plans", r => r.fulfill({ json: {
    enabled: true, status, amountPaid: status === "paid" ? 4999 : 0,
    plans: status === "paid" ? [] : [{ id: "regular", title: "Pay in full", amount: 4999, fullPrice: 4999 }, { id: "booking", title: "Book with a part payment", amount: 2500, fullPrice: 4999 }],
  } }));
  await page.route("**/api/payments/order", r => { orders.push(r.request().postDataJSON()); r.fulfill({ status: 201, json: { orderId: "order_E2E1", amount: 499900, currency: "INR", keyId: "rzp_test_e2e", name: "Widgetry Academy", description: "Flutter in 10 Days: Pay in full", prefill: { name: "Priya Sharma" } } }); });
  await page.route("**/api/payments/verify", r => { verified.push(r.request().postDataJSON()); status = "paid"; r.fulfill({ json: { ok: true, status: "paid" } }); });
  // Razorpay Checkout: "pays" straight away
  await page.route("https://checkout.razorpay.com/v1/checkout.js", r => r.fulfill({ contentType: "text/javascript",
    body: `window.Razorpay = function (o) { this.open = () => setTimeout(() => o.handler({ razorpay_order_id: o.order_id, razorpay_payment_id: "pay_E2E1", razorpay_signature: "${"a".repeat(64)}" }), 50); };` }));

  await page.goto("/#fees");
  const full = page.locator('.paybox[data-pay="regular"] button');
  await expect(full).toHaveText("Pay ₹4,999");
  await expect(page.locator('.paybox[data-pay="booking"] button')).toHaveText("Pay ₹2,500");
  await full.click();
  await expect(page.locator('.paybox[data-pay="regular"]')).toContainText("Fee paid");
  expect(orders).toEqual([{ plan: "regular" }]);
  expect(verified[0]).toMatchObject({ orderId: "order_E2E1", paymentId: "pay_E2E1" });
  await expect(page.locator("#rgToast")).toContainText("Payment received");
  expect(errors).toEqual([]);
});

test("after the booking amount, the student pays the balance", async ({ page }) => {
  await signIn(page, USERS.seeker);
  await page.addInitScript(uid => localStorage.setItem("e2e_docs", JSON.stringify({ [`registrations/${uid}`]: { name: "Priya Sharma", phone: "9876543210" } })), USERS.seeker.uid);
  await page.route("**/api/payments/plans", r => r.fulfill({ json: { enabled: true, status: "part-paid", amountPaid: 2500, plans: [{ id: "balance", title: "Pay the balance", amount: 2499, fullPrice: 4999 }] } }));
  await page.goto("/#fees");
  await expect(page.locator('.paybox[data-pay="booking"] button')).toHaveText("Pay the balance ₹2,499");
  await expect(page.locator('.paybox[data-pay="regular"]')).toContainText("Booking paid");
});

test("signed out: register first", async ({ page }) => {
  await page.goto("/#fees");
  await expect(page.locator('.paybox[data-pay="regular"] button')).toHaveText("Register to pay");
});
