// Applies migrations/*.sql in order, once each. Usage: npm run migrate
import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import mysql from "mysql2/promise";
import { config } from "./config.js";

const dir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../migrations");

export async function migrate(log = console.log) {
  const conn = await mysql.createConnection({
    host: config.db.socketPath ? undefined : config.db.host,
    port: config.db.socketPath ? undefined : config.db.port,
    socketPath: config.db.socketPath,
    user: config.db.user, password: config.db.password, database: config.db.database,
    ssl: config.db.ssl ? { minVersion: "TLSv1.2", rejectUnauthorized: true } : undefined,
    multipleStatements: true,
  });
  try {
    await conn.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      version VARCHAR(100) NOT NULL PRIMARY KEY, applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)`);
    const [rows] = await conn.query("SELECT version FROM schema_migrations");
    const done = new Set((rows as any[]).map(r => r.version));
    const files = (await readdir(dir)).filter(f => f.endsWith(".sql")).sort();
    for (const f of files) {
      if (done.has(f)) continue;
      const sql = await readFile(path.join(dir, f), "utf8");
      log(`[migrate] applying ${f}`);
      // MySQL DDL auto-commits, so each file should be safe to re-run only after a fix; keep files small.
      await conn.query(sql);
      await conn.query("INSERT INTO schema_migrations (version) VALUES (?)", [f]);
    }
    log("[migrate] up to date");
  } finally {
    await conn.end();
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  migrate().catch(e => { console.error(e); process.exit(1); });
}
