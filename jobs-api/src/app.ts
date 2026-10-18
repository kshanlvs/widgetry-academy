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
import { devicesRouter } from "./routes/devices.js";
import { paymentsRouter } from "./routes/payments.js";
import { accountRouter } from "./routes/account.js";
import { mockRouter, mockAdminRouter } from "./routes/mock.js";
import { mentorsRouter } from "./routes/mentors.js";
import { requireAdmin } from "./auth.js";

export function createApp() {
  const app = express();
  app.disable("x-powered-by");
  app.set("trust proxy", 1);   // behind the host's load balancer: use the real client IP for rate limits

  const api = express.Router();
  // CORS: only the academy's own websites may call the API from a browser.
  const allowed = new Set(config.corsOrigins);
  api.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && allowed.has(origin)) {
      res.setHeader("Access-Control-Allow-Origin", origin);
      res.setHeader("Vary", "Origin");
      res.setHeader("Access-Control-Allow-Headers", "authorization, content-type");
      res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE");
      res.setHeader("Access-Control-Max-Age", "86400");
    }
    if (req.method === "OPTIONS") return res.status(origin && allowed.has(origin) ? 204 : 403).end();
    next();
  });
  api.use(helmet({ crossOriginResourcePolicy: { policy: "cross-origin" } }));
  // Small bodies everywhere; only the photo upload and bulk job import may be larger
  const smallJson = express.json({ limit: "64kb" }), photoJson = express.json({ limit: "400kb" });
  // The Razorpay webhook keeps its raw body: its signature is computed over the exact bytes
  const webhookRaw = express.raw({ type: "*/*", limit: "256kb" });
  api.use((req, res, next) => {
    if (req.path === "/payments/webhook") return webhookRaw(req, res, err => { (req as any).rawBody = req.body; next(err); });
    return (req.path === "/talent/me/photo" || req.path === "/admin/jobs/import" ? photoJson : smallJson)(req, res, next);
  });
  api.use(rateLimit({ windowMs: 15 * 60 * 1000, limit: 600, standardHeaders: "draft-7", legacyHeaders: false,
    handler: (_req, res) => res.status(429).json({ error: "Too many requests. Please slow down." }) }));
  api.use(optionalAuth);

  api.get("/health", async (_req, res) => {
    try { await pool.query("SELECT 1"); res.json({ ok: true }); }
    catch { res.status(503).json({ ok: false }); }
  });
  api.use(jobsRouter);
  api.use(talentRouter);
  api.use(devicesRouter);
  api.use(paymentsRouter);
  api.use(accountRouter);
  api.use(mockRouter);
  api.use(mentorsRouter);
  api.use("/admin", requireAdmin, mockAdminRouter);
  api.use("/admin", adminRouter);
  api.use((_req, res) => res.status(404).json({ error: "Not found." }));
  api.use(errorHandler);

  app.use("/api", api);

  // Local development only: serve the website from ../public so pages and /api share one origin
  if (config.serveStatic) app.use(express.static(path.resolve(config.serveStatic), { extensions: ["html"] }));

  return app;
}
