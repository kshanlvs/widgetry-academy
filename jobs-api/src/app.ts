import express from "express";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import path from "node:path";
import { config } from "./config.js";
import { pool } from "./db.js";
import { errorHandler } from "./errors.js";
import { optionalAuth } from "./auth.js";
import { jobsRouter } from "./routes/jobs.js";
import { talentRouter } from "./routes/talent.js";
import { adminRouter } from "./routes/admin.js";

export function createApp() {
  const app = express();
  app.disable("x-powered-by");
  app.set("trust proxy", 1);   // behind Firebase Hosting / Cloud Run: use the real client IP for rate limits

  const api = express.Router();
  api.use(helmet());
  api.use(express.json({ limit: "64kb" }));
  api.use(rateLimit({ windowMs: 15 * 60 * 1000, limit: 600, standardHeaders: "draft-7", legacyHeaders: false,
    handler: (_req, res) => res.status(429).json({ error: "Too many requests. Please slow down." }) }));
  api.use(optionalAuth);

  api.get("/health", async (_req, res) => {
    try { await pool.query("SELECT 1"); res.json({ ok: true }); }
    catch { res.status(503).json({ ok: false }); }
  });
  api.use(jobsRouter);
  api.use(talentRouter);
  api.use("/admin", adminRouter);
  api.use((_req, res) => res.status(404).json({ error: "Not found." }));
  api.use(errorHandler);

  app.use("/api", api);

  // Local development only: serve the website from ../public so pages and /api share one origin
  if (config.serveStatic) app.use(express.static(path.resolve(config.serveStatic), { extensions: ["html"] }));

  return app;
}
