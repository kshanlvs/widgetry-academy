// All settings come from environment variables (Cloud Run / .env). Nothing secret is hard-coded.
const env = process.env;

const onCloudRun = !!env.K_SERVICE;

export const config = {
  port: Number(env.PORT || 8080),
  isProduction: env.NODE_ENV === "production" || onCloudRun,

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

  firebaseProjectId: env.FIREBASE_PROJECT_ID || "flutter-in-10-days",
  adminUids: (env.ADMIN_UIDS || "E4edbAvcdwTdkTdNwcdWneVWe572").split(",").map(s => s.trim()).filter(Boolean),

  // Local testing only: accept "Bearer dev:<uid>:<email>" tokens. Refused on Cloud Run / production.
  allowDevAuth: env.ALLOW_DEV_AUTH === "1" && !onCloudRun && env.NODE_ENV !== "production",
  // Local testing only: serve ../public so the site and /api share one origin.
  serveStatic: env.SERVE_STATIC_DIR || "",

  hashSalt: env.HASH_SALT || "change-me-in-production",
  jobLifetimeDays: Number(env.JOB_LIFETIME_DAYS || 30),
};

if (config.isProduction && config.hashSalt === "change-me-in-production") {
  console.warn("[config] HASH_SALT is not set. Set it in production.");
}
