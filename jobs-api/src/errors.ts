import type { Request, Response, NextFunction } from "express";
import { ZodError } from "zod";

export class HttpError extends Error {
  constructor(public status: number, message: string, public details?: unknown) { super(message); }
}

export const wrap = (fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>) =>
  (req: Request, res: Response, next: NextFunction) => { fn(req, res, next).catch(next); };

export function errorHandler(err: any, req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ZodError) {
    const issues = err.issues.map(i => ({ field: i.path.join("."), message: i.message }));
    return res.status(400).json({ error: issues[0] ? `${issues[0].field ? issues[0].field + ": " : ""}${issues[0].message}` : "Invalid input", issues });
  }
  if (err instanceof HttpError) return res.status(err.status).json({ error: err.message, ...(err.details ? { details: err.details } : {}) });
  if (err?.type === "entity.too.large") return res.status(413).json({ error: "Request too large." });
  if (err?.type === "entity.parse.failed") return res.status(400).json({ error: "Invalid JSON." });
  console.error(`[error] ${req.method} ${req.path}`, err);
  res.status(500).json({ error: "Something went wrong on our side. Please try again." });
}
