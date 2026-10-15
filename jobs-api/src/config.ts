import { createHash } from "node:crypto";
// All settings come from environment variables (Railway variables / .env). Nothing secret is hard-coded.
const env = process.env;

// Hosted (Railway / Cloud Run): dev shortcuts are always refused there.
const onHost = !!(env.K_SERVICE || env.RAILWAY_ENVIRONMENT || env.RAILWAY_PROJECT_ID);

export const config = {
  port: Number(env.PORT || 8080),
  isProduction: env.NODE_ENV === "production" || onHost,

  db: {
    // Either a TCP host (local MySQL, TiDB, Aiven…) or a Cloud SQL unix socket (/cloudsql/PROJECT:REGION:INSTANCE)
    host: env.DB_HOST || "127.0.0.1",
    port: Number(env.DB_PORT || 3306),
    socketPath: env.DB_SOCKET || undefined,
    user: env.DB_USER || "jobs",
    password: env.DB_PASSWORD || "",
    database: env.DB_NAME || "widgetry_jobs",
    ssl: env.DB_SSL === "1",                 // needed for hosted MySQL like TiDB Cloud / Aiven
    connectionLimit: Number(env.DB_POOL || 5),
  },

  // Websites allowed to call the API from the browser (the academy stays on Firebase Hosting).
  corsOrigins: (env.CORS_ORIGINS || "https://widgetryacademy.in,https://www.widgetryacademy.in,https://widgetry-academy.web.app,https://widgetry-academy.firebaseapp.com")
    .split(",").map(s => s.trim()).filter(Boolean),

  firebaseProjectId: env.FIREBASE_PROJECT_ID || "flutter-in-10-days",
  adminUids: (env.ADMIN_UIDS || "E4edbAvcdwTdkTdNwcdWneVWe572").split(",").map(s => s.trim()).filter(Boolean),

  // Local testing only: accept "Bearer dev:<uid>:<email>" tokens. Refused on the live host / production.
  allowDevAuth: env.ALLOW_DEV_AUTH === "1" && !onHost && env.NODE_ENV !== "production",
  // Local testing only: serve ../public so the site and /api share one origin.
  serveStatic: env.SERVE_STATIC_DIR || "",

  // Salt for hashing reporters' IPs. Falls back to a value derived from the DB password so it stays stable.
  hashSalt: env.HASH_SALT || (env.DB_PASSWORD ? createHash("sha256").update("wj-salt|" + env.DB_PASSWORD).digest("hex") : "dev-salt"),
  jobLifetimeDays: Number(env.JOB_LIFETIME_DAYS || 30),
};

if (config.isProduction && config.hashSalt === "dev-salt") console.warn("[config] Set HASH_SALT or DB_PASSWORD in production.");
