// One shared Firebase Admin app. Verifying sign-in tokens needs only the project id;
// sending push notifications also needs a service account (FIREBASE_SERVICE_ACCOUNT = the JSON key, on Railway).
import { initializeApp, getApps, applicationDefault, cert, type App } from "firebase-admin/app";
import { config } from "./config.js";

let app: App | null = null;

export const canSendPush = () => !!(process.env.FIREBASE_SERVICE_ACCOUNT || process.env.GOOGLE_APPLICATION_CREDENTIALS);

export function adminApp(): App {
  if (app) return app;
  if (getApps().length) return (app = getApps()[0]!);
  const sa = process.env.FIREBASE_SERVICE_ACCOUNT;
  const credential = sa ? cert(JSON.parse(sa)) : process.env.GOOGLE_APPLICATION_CREDENTIALS ? applicationDefault() : undefined;
  app = initializeApp({ projectId: config.firebaseProjectId, ...(credential ? { credential } : {}) });
  return app;
}
