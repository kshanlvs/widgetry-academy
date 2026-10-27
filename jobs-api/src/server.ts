import { createApp } from "./app.js";
import { config } from "./config.js";
import { pool } from "./db.js";
import { migrate } from "./migrate.js";
import { reportPendingExternal } from "./play.js";
import { sendReminders } from "./mock.js";
import { remindPremiumEnding } from "./resume.js";
import { closePdfBrowser } from "./resumeDoc.js";

async function main() {
  if (process.env.MIGRATE_ON_START === "1") await migrate();
  const server = createApp().listen(config.port, () => console.log(`[jobs-api] listening on :${config.port}${config.allowDevAuth ? " (DEV AUTH ON)" : ""}`));
  // Google Play needs alternative-billing payments reported within 24 hours: retry any that failed
  const reporter = setInterval(() => { reportPendingExternal().catch(e => console.warn(`[play] retry failed: ${e?.message}`)); }, 10 * 60 * 1000);
  reporter.unref();
  // Mock interview reminders, about an hour before
  const reminders = setInterval(() => { sendReminders().catch(e => console.warn(`[mock] reminders failed: ${e?.message}`)); }, 5 * 60 * 1000);
  reminders.unref();
  // Resume Premium: a reminder 3 days before it ends
  const premium = setInterval(() => { remindPremiumEnding().catch(e => console.warn(`[resume] reminders failed: ${e?.message}`)); }, 60 * 60 * 1000);
  premium.unref();
  const stop = () => server.close(() => Promise.all([pool.end(), closePdfBrowser()]).finally(() => process.exit(0)));
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
}
main().catch(e => { console.error(e); process.exit(1); });
