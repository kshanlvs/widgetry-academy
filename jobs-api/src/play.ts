// Google Play side of in-app payments (India "user choice billing").
//
// In the Android app the student sees Google's choice screen:
//  - Google Play: the app sends the purchase token to POST /payments/play/verify. We check it with the
//    Android Publisher API, record it like any payment, then consume it (so the product can be bought again later).
//  - Razorpay: the app gets an external transaction token from Google, sends it with the Razorpay order,
//    and after the payment we must report it to Google within 24 hours (reportExternal below).
import { createHash } from "node:crypto";
import { GoogleAuth } from "google-auth-library";
import { exec, query } from "./db.js";

const env = process.env;
export const playConfig = () => ({
  packageName: env.PLAY_PACKAGE_NAME || "in.widgetryacademy.app",
  /** Service account JSON with access in Play Console (Users & permissions). Defaults to the Firebase one. */
  serviceAccount: env.PLAY_SERVICE_ACCOUNT || env.FIREBASE_SERVICE_ACCOUNT || "",
  /** "user_choice" (default, required on Google Play) or "razorpay" (only for internal testing before enrolment). */
  androidBilling: env.ANDROID_BILLING === "razorpay" ? "razorpay" : "user_choice",
  /** GST included in prices, in percent (0 if not GST-registered). Used to split reported amounts. */
  gstPercent: Number(env.GST_PERCENT || 0),
});

/** One Play Console product per plan. Create these as one-time products with the same prices. */
export const PLAY_PRODUCTS: Record<string, string> = {
  "early-bird": "course_fee_early_bird",
  regular: "course_fee_full",
  booking: "course_fee_booking",
  balance: "course_fee_balance",
};
export const planForProduct = (productId: string) => Object.entries(PLAY_PRODUCTS).find(([, p]) => p === productId)?.[0] ?? null;

/** Opaque per-user id given to Google Play (obfuscatedAccountId), so a purchase can be tied to the right student. */
export const playAccountId = (uid: string) => createHash("sha256").update("widgetry|" + uid).digest("hex");

/** India states and UTs exactly as the Play Developer API expects them (userTaxAddress.administrativeArea). */
export const INDIA_STATES = [
  "ANDAMAN AND NICOBAR ISLANDS", "ANDHRA PRADESH", "ARUNACHAL PRADESH", "ASSAM", "BIHAR", "CHANDIGARH", "CHHATTISGARH",
  "DADRA AND NAGAR HAVELI AND DAMAN AND DIU", "DELHI", "GOA", "GUJARAT", "HARYANA", "HIMACHAL PRADESH", "JAMMU AND KASHMIR",
  "JHARKHAND", "KARNATAKA", "KERALA", "LADAKH", "LAKSHADWEEP", "MADHYA PRADESH", "MAHARASHTRA", "MANIPUR", "MEGHALAYA",
  "MIZORAM", "NAGALAND", "ODISHA", "PUDUCHERRY", "PUNJAB", "RAJASTHAN", "SIKKIM", "TAMIL NADU", "TELANGANA", "TRIPURA",
  "UTTAR PRADESH", "UTTARAKHAND", "WEST BENGAL",
] as const;

export interface ProductPurchase {
  purchaseState?: number;          // 0 purchased, 1 cancelled, 2 pending
  consumptionState?: number;       // 0 not consumed, 1 consumed
  orderId?: string;
  obfuscatedExternalAccountId?: string;
  purchaseTimeMillis?: string;
}
export interface PlayApi {
  getPurchase(productId: string, token: string): Promise<ProductPurchase>;
  consume(productId: string, token: string): Promise<void>;
  /** Returns false if Google says it was already reported. */
  reportExternal(externalTransactionId: string, body: unknown): Promise<boolean>;
}

let auth: GoogleAuth | null = null;
async function google<T>(method: string, path: string, body?: unknown): Promise<{ status: number; data: T }> {
  const cfg = playConfig();
  if (!cfg.serviceAccount) throw new Error("PLAY_SERVICE_ACCOUNT / FIREBASE_SERVICE_ACCOUNT is not set");
  auth ??= new GoogleAuth({ credentials: JSON.parse(cfg.serviceAccount), scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  const client = await auth.getClient();
  const r = await client.request<T>({
    url: `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(cfg.packageName)}${path}`,
    method: method as any, data: body, validateStatus: () => true, timeout: 15000,
  });
  return { status: r.status, data: r.data };
}

const googlePlayApi: PlayApi = {
  async getPurchase(productId, token) {
    const r = await google<ProductPurchase>("GET", `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`);
    if (r.status >= 400) throw new Error(`Play purchase check failed (${r.status})`);
    return r.data;
  },
  async consume(productId, token) {
    const r = await google("POST", `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}:consume`);
    if (r.status >= 400 && r.status !== 409) throw new Error(`Play consume failed (${r.status})`);
  },
  async reportExternal(id, body) {
    const r = await google("POST", `/externalTransactions?externalTransactionId=${encodeURIComponent(id)}`, body);
    if (r.status === 409) return false;
    if (r.status >= 400) throw new Error(`Play external transaction report failed (${r.status}): ${JSON.stringify(r.data).slice(0, 300)}`);
    return true;
  },
};

let override: PlayApi | null = null;
/** Tests replace the Play Developer API with a fake. */
export function setPlayApi(p: PlayApi | null) { override = p; }
export const playApi = () => override ?? googlePlayApi;

const micros = (paise: number) => String(Math.round(paise) * 10000);

/** Reports one paid Razorpay order that came through Google's choice screen. Safe to call repeatedly. */
export async function reportExternal(orderId: string): Promise<boolean> {
  const [r] = await query<{ amount: number; ext_token: string | null; tax_state: string | null; paid_at: Date | null; reported_at: Date | null; status: string }>(
    "SELECT amount, ext_token, tax_state, paid_at, reported_at, status FROM payments WHERE order_id = ?", [orderId]);
  if (!r || !r.ext_token || r.reported_at || r.status !== "paid") return false;
  const gst = playConfig().gstPercent;
  const preTax = gst > 0 ? Math.round(r.amount / (1 + gst / 100)) : r.amount;
  const body = {
    originalPreTaxAmount: { priceMicros: micros(preTax), currency: "INR" },
    originalTaxAmount: { priceMicros: micros(r.amount - preTax), currency: "INR" },
    transactionTime: (r.paid_at ?? new Date()).toISOString(),
    oneTimeTransaction: { externalTransactionToken: r.ext_token },
    userTaxAddress: { regionCode: "IN", administrativeArea: r.tax_state || "WEST BENGAL" },
  };
  await playApi().reportExternal(orderId.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 63), body);
  await exec("UPDATE payments SET reported_at = CURRENT_TIMESTAMP WHERE order_id = ?", [orderId]);
  return true;
}

/** Same as reportExternal, for a short course (workshop) paid with Razorpay from Google's choice screen. */
export async function reportExternalWorkshop(orderId: string): Promise<boolean> {
  const [r] = await query<{ amount: number; ext_token: string | null; tax_state: string | null; paid_at: Date | null; reported_at: Date | null; status: string }>(
    "SELECT amount, ext_token, tax_state, paid_at, reported_at, status FROM workshop_enrollments WHERE order_id = ?", [orderId]);
  if (!r || !r.ext_token || r.reported_at || !["confirmed", "refunded"].includes(r.status) || !r.paid_at) return false;
  const gst = playConfig().gstPercent;
  const preTax = gst > 0 ? Math.round(r.amount / (1 + gst / 100)) : r.amount;
  await playApi().reportExternal(orderId.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 63), {
    originalPreTaxAmount: { priceMicros: micros(preTax), currency: "INR" },
    originalTaxAmount: { priceMicros: micros(r.amount - preTax), currency: "INR" },
    transactionTime: r.paid_at.toISOString(),
    oneTimeTransaction: { externalTransactionToken: r.ext_token },
    userTaxAddress: { regionCode: "IN", administrativeArea: r.tax_state || "WEST BENGAL" },
  });
  await exec("UPDATE workshop_enrollments SET reported_at = CURRENT_TIMESTAMP WHERE order_id = ?", [orderId]);
  return true;
}

/** Retries any reports that failed (runs every few minutes on the server). Google needs them within 24 hours. */
export async function reportPendingExternal(): Promise<number> {
  let n = 0;
  const rows = await query<{ order_id: string }>("SELECT order_id FROM payments WHERE status = 'paid' AND ext_token IS NOT NULL AND reported_at IS NULL ORDER BY paid_at LIMIT 50");
  for (const r of rows) {
    try { if (await reportExternal(r.order_id)) n++; }
    catch (e: any) { console.warn(`[play] report ${r.order_id} failed: ${e?.message}`); }
  }
  const ws = await query<{ order_id: string }>("SELECT order_id FROM workshop_enrollments WHERE paid_at IS NOT NULL AND ext_token IS NOT NULL AND reported_at IS NULL AND order_id IS NOT NULL ORDER BY paid_at LIMIT 50");
  for (const r of ws) {
    try { if (await reportExternalWorkshop(r.order_id)) n++; }
    catch (e: any) { console.warn(`[play] report ${r.order_id} failed: ${e?.message}`); }
  }
  return n;
}

/**
 * Short courses on Google Play: one one-time product per price, named short_course_<rupees>
 * (short_course_799, short_course_999…). Only the prices listed in WORKSHOP_PLAY_PRICES are offered
 * through Google Play; any other price is paid with Razorpay (still from Google's choice screen).
 */
export const workshopPlayPrices = () => (env.WORKSHOP_PLAY_PRICES ?? "799,999").split(",").map(s => Number(s.trim())).filter(n => n > 0);
export const workshopPlayProduct = (rupees: number) => (workshopPlayPrices().includes(rupees) ? `short_course_${rupees}` : null);
export const workshopProductPrice = (productId: string) => { const m = /^short_course_(\d+)$/.exec(productId); return m ? Number(m[1]) : null; };
