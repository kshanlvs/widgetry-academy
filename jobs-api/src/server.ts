import { createApp } from "./app.js";
import { config } from "./config.js";
import { pool } from "./db.js";
import { migrate } from "./migrate.js";
import { reportPendingExternal } from "./play.js";

async function main() {
  if (process.env.MIGRATE_ON_START === "1") await migrate();
  const server = createApp().listen(config.port, () => console.log(`[jobs-api] listening on :${config.port}${config.allowDevAuth ? " (DEV AUTH ON)" : ""}`));
  // Google Play needs alternative-billing payments reported within 24 hours: retry any that failed
  const reporter = setInterval(() => { reportPendingExternal().catch(e => console.warn(`[play] retry failed: ${e?.message}`)); }, 10 * 60 * 1000);
  reporter.unref();
  const stop = () => server.close(() => pool.end().finally(() => process.exit(0)));
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
}
main().catch(e => { console.error(e); process.exit(1); });
