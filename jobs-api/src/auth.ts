// Verifies the Firebase ID token the website already has (Google or email login). No second login system.
import type { Request, Response, NextFunction } from "express";
import { initializeApp, getApps, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { config } from "./config.js";
import { HttpError } from "./errors.js";

export interface AuthUser { uid: string; email: string | null; emailVerified: boolean; name: string | null }
declare global { namespace Express { interface Request { user?: AuthUser } } }

function admin() {
  if (!getApps().length) {
    // Only the project id is needed to verify sign-in tokens (no service account, no Blaze plan).
    initializeApp({ projectId: config.firebaseProjectId, ...(process.env.GOOGLE_APPLICATION_CREDENTIALS ? { credential: applicationDefault() } : {}) });
  }
  return getAuth();
}

async function readUser(req: Request): Promise<AuthUser | undefined> {
  const h = req.get("authorization") || "";
  const m = /^Bearer (.+)$/.exec(h);
  if (!m) return undefined;
  const token = m[1];
  if (config.allowDevAuth && token.startsWith("dev:")) {
    const [, uid, email = "", name = ""] = token.split(":");
    if (!uid) throw new HttpError(401, "Invalid dev token");
    return { uid, email: email || null, emailVerified: true, name: name || null };
  }
  try {
    const d = await admin().verifyIdToken(token);
    return { uid: d.uid, email: d.email ?? null, emailVerified: !!d.email_verified, name: (d.name as string) ?? null };
  } catch {
    throw new HttpError(401, "Your sign-in has expired. Please sign in again.");
  }
}

/** Attaches req.user when a valid token is sent; never fails the request. */
export function optionalAuth(req: Request, _res: Response, next: NextFunction) {
  readUser(req).then(u => { req.user = u; next(); }).catch(() => next());
}

export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  readUser(req).then(u => {
    if (!u) return next(new HttpError(401, "Please sign in first."));
    req.user = u; next();
  }).catch(next);
}

export function requireAdmin(req: Request, res: Response, next: NextFunction) {
  requireAuth(req, res, err => {
    if (err) return next(err);
    if (!config.adminUids.includes(req.user!.uid)) return next(new HttpError(403, "Admins only."));
    next();
  });
}
