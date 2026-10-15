// Phones register their FCM token after sign-in so we can send personal notifications
// (job approved, profile verified). Topic notifications don't need this.
import { Router } from "express";
import { z } from "zod";
import { query } from "../db.js";
import { wrap } from "../errors.js";
import { requireAuth } from "../auth.js";

export const devicesRouter = Router();
const tokenBody = z.object({ token: z.string().trim().min(20).max(512), platform: z.enum(["android", "ios", "web"]).default("android") });

devicesRouter.post("/me/devices", requireAuth, wrap(async (req, res) => {
  const { token, platform } = tokenBody.parse(req.body);
  // A token belongs to one phone; if someone else signs in on it, it moves to them
  await query("INSERT INTO device_tokens (token, uid, platform) VALUES (?,?,?) ON DUPLICATE KEY UPDATE uid = VALUES(uid), platform = VALUES(platform), updated_at = CURRENT_TIMESTAMP",
    [token, req.user!.uid, platform]);
  const [{ n }] = await query<{ n: number }>("SELECT COUNT(*) AS n FROM device_tokens WHERE uid = ?", [req.user!.uid]);
  if (Number(n) > 20) await query("DELETE FROM device_tokens WHERE uid = ? ORDER BY updated_at ASC LIMIT ?", [req.user!.uid, Number(n) - 20]);
  res.status(201).json({ ok: true });
}));

devicesRouter.delete("/me/devices", requireAuth, wrap(async (req, res) => {
  const { token } = tokenBody.pick({ token: true }).parse(req.body);
  await query("DELETE FROM device_tokens WHERE token = ? AND uid = ?", [token, req.user!.uid]);
  res.json({ ok: true });
}));
