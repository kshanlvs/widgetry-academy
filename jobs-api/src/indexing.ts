// Tells Google the moment a job goes live or closes (Google Indexing API, which Google offers
// specifically for job posting pages). Without it Google may take days to find a new job.
//
// Turned on with INDEXING_ENABLED=1 on the server. It uses INDEXING_SERVICE_ACCOUNT if set, otherwise
// the same service account as Google Play / Firebase. That account's email must be added as an
// Owner of widgetryacademy.in in Google Search Console, and the "Web Search Indexing API" enabled
// in its Google Cloud project.
import { GoogleAuth } from "google-auth-library";
import { SITE } from "./notify.js";

export type IndexEvent = "URL_UPDATED" | "URL_DELETED";
export interface Indexer { notify(url: string, type: IndexEvent): Promise<void> }

const env = process.env;
const serviceAccount = () => env.INDEXING_SERVICE_ACCOUNT || env.PLAY_SERVICE_ACCOUNT || env.FIREBASE_SERVICE_ACCOUNT || "";

let auth: GoogleAuth | null = null;
const googleIndexer: Indexer = {
  async notify(url, type) {
    if (env.INDEXING_ENABLED !== "1") return;
    const sa = serviceAccount();
    if (!sa) { console.warn("[indexing] INDEXING_ENABLED=1 but no service account is set"); return; }
    auth ??= new GoogleAuth({ credentials: JSON.parse(sa), scopes: ["https://www.googleapis.com/auth/indexing"] });
    const client = await auth.getClient();
    const r = await client.request({ url: "https://indexing.googleapis.com/v3/urlNotifications:publish", method: "POST",
      data: { url, type }, validateStatus: () => true, timeout: 10000 });
    if (r.status >= 300) console.warn(`[indexing] ${type} ${url}: HTTP ${r.status} ${JSON.stringify(r.data).slice(0, 300)}`);
  },
};

let override: Indexer | null = null;
export function setIndexer(i: Indexer | null) { override = i; }

export const jobUrl = (publicId: string) => `${SITE}/job.html?id=${publicId}`;

/** Fire-and-forget: never slows down or fails the request that triggered it. */
export function pingJob(publicId: string, type: IndexEvent) {
  void (override ?? googleIndexer).notify(jobUrl(publicId), type).catch(e => console.warn(`[indexing] ${e?.message ?? e}`));
}
