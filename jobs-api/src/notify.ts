// Push notifications through Firebase Cloud Messaging.
// Topics (the app subscribes): "all", "academy", "jobs-<category>" (e.g. jobs-flutter, jobs-android).
// Personal messages go to the phones a user signed in on (device_tokens table).
// Never throws: a failed push must not fail the request that triggered it.
import { getMessaging } from "firebase-admin/messaging";
import { adminApp, canSendPush } from "./firebase.js";
import { query } from "./db.js";

export const SITE = process.env.SITE_URL || "https://widgetryacademy.in";

export interface Push { title: string; body: string; link?: string; data?: Record<string, string> }
export interface Sender {
  topic(topic: string, p: Push): Promise<void>;
  /** Returns the tokens that are no longer valid, so they can be removed. */
  tokens(tokens: string[], p: Push): Promise<string[]>;
}

const message = (p: Push) => ({
  notification: { title: p.title.slice(0, 100), body: p.body.slice(0, 240) },
  data: { ...(p.data ?? {}), ...(p.link ? { link: p.link } : {}) },
  android: { priority: "high" as const },
  apns: { payload: { aps: { sound: "default" } } },
});

const fcmSender: Sender = {
  async topic(topic, p) { await getMessaging(adminApp()).send({ topic, ...message(p) }); },
  async tokens(tokens, p) {
    const res = await getMessaging(adminApp()).sendEachForMulticast({ tokens, ...message(p) });
    return res.responses.flatMap((r, i) =>
      !r.success && ["messaging/registration-token-not-registered", "messaging/invalid-registration-token", "messaging/invalid-argument"].includes(r.error?.code ?? "") ? [tokens[i]!] : []);
  },
};
const logSender: Sender = {
  async topic(topic, p) { console.log(`[push] (not configured) topic ${topic}: ${p.title}`); },
  async tokens(tokens, p) { console.log(`[push] (not configured) ${tokens.length} device(s): ${p.title}`); return []; },
};

let override: Sender | null = null;
/** Tests replace the sender to record messages. */
export function setSender(s: Sender | null) { override = s; }
const sender = () => override ?? (canSendPush() ? fcmSender : logSender);

export async function notifyTopic(topic: string, p: Push) {
  try { await sender().topic(topic, p); } catch (e: any) { console.warn(`[push] topic ${topic} failed: ${e?.message}`); }
}

export async function notifyUser(uid: string | null | undefined, p: Push) {
  if (!uid) return;
  try {
    const rows = await query<{ token: string }>("SELECT token FROM device_tokens WHERE uid = ? ORDER BY updated_at DESC LIMIT 20", [uid]);
    if (!rows.length) return;
    const dead = await sender().tokens(rows.map(r => r.token), p);
    if (dead.length) await query("DELETE FROM device_tokens WHERE token IN (?)", [dead]);
  } catch (e: any) { console.warn(`[push] user ${uid} failed: ${e?.message}`); }
}
