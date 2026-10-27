// Shared test helpers: test users, a fake Firebase (the pages load it from Google's CDN) and API calls.
import { test as base, expect, type Page, type BrowserContext } from "@playwright/test";
import mysql from "mysql2/promise";
import { DB } from "./playwright.config";

/** Runs SQL on the test database (e.g. to give a test user Resume Premium). */
export async function sql(q: string, params: unknown[] = []) {
  const db = await mysql.createConnection(DB);
  try { return (await db.query(q, params))[0]; } finally { await db.end(); }
}
export const givePremium = (u: User, days = 10) => sql(
  "INSERT INTO resume_premium (uid, email, amount, days, status, order_id, paid_at, starts_at, expires_at) VALUES (?,?,29900,30,'paid',?,NOW(),NOW(),NOW() + INTERVAL ? DAY)",
  [u.uid, u.email, `order_e2e_${u.uid}_${Date.now()}`, days]);

export const USERS = {
  admin: { uid: "E4edbAvcdwTdkTdNwcdWneVWe572", email: "admin@widgetry.test", name: "Admin" },
  seeker: { uid: "e2eseek", email: "priya@e2e.test", name: "Priya Sharma" },
  employer: { uid: "e2eemp", email: "hr@e2e.test", name: "Asha HR" },
} as const;
export type User = (typeof USERS)[keyof typeof USERS];
export const token = (u: User) => `dev:${u.uid}:${u.email}:${u.name}`;

const API = () => `${process.env.E2E_BASE || "http://127.0.0.1:" + (process.env.E2E_PORT || 8090)}/api`;
export async function api(method: string, path: string, body?: unknown, as?: User) {
  const r = await fetch(API() + path, {
    method,
    headers: { "content-type": "application/json", ...(as ? { authorization: "Bearer " + token(as) } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  let json: any = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = text; }
  return { status: r.status, body: json };
}

// The signed-in user is kept in localStorage ("e2e_user"), so a test signs in before the page loads.
const AUTH = `
const read = () => { try { const u = JSON.parse(localStorage.getItem("e2e_user") || "null"); return u && { ...u, getIdToken: async () => u.token, getIdTokenResult: async () => ({ claims: {} }) }; } catch { return null; } };
let user = read(); const cbs = new Set();
const auth = { get currentUser() { return user; }, onAuthStateChanged: (cb) => onAuthStateChanged(auth, cb) };
const set = (u) => { user = u; for (const cb of cbs) cb(user); return { user }; };
export const getAuth = () => auth;
export const onAuthStateChanged = (_a, cb) => { cbs.add(cb); setTimeout(() => cb(user), 0); return () => cbs.delete(cb); };
export class GoogleAuthProvider { setCustomParameters() {} addScope() {} }
export const browserLocalPersistence = {};
export const setPersistence = async () => {};
export const signInWithPopup = async () => { throw Object.assign(new Error("popup blocked in tests"), { code: "auth/popup-blocked" }); };
export const signInWithRedirect = async () => {};
export const getRedirectResult = async () => null;
export const signOut = async () => { localStorage.removeItem("e2e_user"); set(null); };
export const signInWithEmailAndPassword = async () => set(read());
export const createUserWithEmailAndPassword = async () => set(read());
export const sendPasswordResetEmail = async () => {};
export const updateProfile = async () => {};
`;
const APP = `export const initializeApp = () => ({}); export const getApps = () => []; export const getApp = () => ({});`;
// Firestore (academy registrations, admin): empty and never failing
const FIRESTORE = `
const snap = { exists: () => false, data: () => undefined, id: "x" };
const qs = { docs: [], empty: true, size: 0, forEach() {} };
export const getFirestore = () => ({});
export const collection = () => ({}); export const doc = () => ({ id: "x" }); export const query = () => ({});
export const where = () => ({}); export const orderBy = () => ({}); export const limit = () => ({});
export const getDoc = async () => snap; export const getDocs = async () => qs;
export const setDoc = async () => {}; export const addDoc = async () => ({ id: "x" }); export const updateDoc = async () => {}; export const deleteDoc = async () => {};
export const onSnapshot = (_r, cb) => { setTimeout(() => cb(qs), 0); return () => {}; };
export const serverTimestamp = () => new Date(); export const deleteField = () => null; export const increment = (n) => n;
export const Timestamp = { now: () => ({ toDate: () => new Date() }), fromDate: (d) => ({ toDate: () => d }) };
`;
const STORAGE = `export const getStorage = () => ({}); export const ref = () => ({}); export const uploadBytes = async () => ({}); export const getDownloadURL = async () => "";`;

export async function fakeOutsideServices(ctx: BrowserContext) {
  await ctx.route(/https:\/\/www\.gstatic\.com\/firebasejs\/.*\/firebase-(app|auth|firestore|storage)\.js/, r => {
    const kind = /firebase-(\w+)\.js/.exec(r.request().url())![1];
    r.fulfill({ contentType: "text/javascript", body: ({ app: APP, auth: AUTH, firestore: FIRESTORE, storage: STORAGE } as Record<string, string>)[kind] });
  });
  // Analytics, payments, fonts and other third parties are not part of these tests
  await ctx.route(/googletagmanager|google-analytics|checkout\.razorpay|fonts\.(googleapis|gstatic)|youtube|instagram|facebook|linkedin\.com\/embed/, r => r.abort());
}

export async function signIn(page: Page, u: User) {
  await page.addInitScript(([key, value]) => localStorage.setItem(key, value), ["e2e_user", JSON.stringify({ uid: u.uid, email: u.email, displayName: u.name, emailVerified: true, token: token(u), providerData: [] })]);
}

/** Page errors (uncaught exceptions) collected per test; tests assert there were none. */
export const test = base.extend<{ errors: string[] }>({
  context: async ({ context }, use) => {
    await fakeOutsideServices(context);
    await use(context);
  },
  errors: async ({ page }, use) => {
    const errors: string[] = [];
    page.on("pageerror", e => errors.push(e.message));
    await use(errors);
  },
});
export { expect };
