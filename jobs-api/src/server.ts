import { createApp } from "./app.js";
import { config } from "./config.js";
import { pool } from "./db.js";
import { migrate } from "./migrate.js";

async function main() {
  if (process.env.MIGRATE_ON_START === "1") await migrate();
  const server = createApp().listen(config.port, () => console.log(`[jobs-api] listening on :${config.port}${config.allowDevAuth ? " (DEV AUTH ON)" : ""}`));
  const stop = () => server.close(() => pool.end().finally(() => process.exit(0)));
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
}
main().catch(e => { console.error(e); process.exit(1); });
