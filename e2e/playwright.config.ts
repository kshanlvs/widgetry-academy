// End-to-end tests of the website: the real API (with dev sign-in) serves the site and a test database.
// Run locally:  cd e2e && npm test     (needs MySQL; see README.md)
import { defineConfig, devices } from "@playwright/test";

const PORT = Number(process.env.E2E_PORT || 8090);
const chromium = process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {};
export const DB = {
  host: process.env.DB_HOST || "127.0.0.1",
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || "jobs",
  password: process.env.DB_PASSWORD || "devpass",
  database: process.env.E2E_DB_NAME || "widgetry_e2e",
};

export default defineConfig({
  testDir: "./tests",
  fullyParallel: false,
  workers: 1, // one shared database
  retries: process.env.CI ? 1 : 0,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: process.env.CI ? [["github"], ["html", { open: "never" }], ["list"]] : [["list"], ["html", { open: "never" }]],
  globalSetup: "./global-setup.ts",
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    launchOptions: chromium,
  },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"], launchOptions: chromium }, testIgnore: /phone\.spec\.ts/ },
    { name: "phone", use: { ...devices["Pixel 7"], launchOptions: chromium }, testMatch: /(pages|phone)\.spec\.ts/ },
  ],
  webServer: {
    command: "npx tsx src/server.ts",
    cwd: "../jobs-api",
    url: `http://127.0.0.1:${PORT}/api/health`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: "pipe",
    env: {
      PORT: String(PORT),
      SERVE_STATIC_DIR: "../public",
      ALLOW_DEV_AUTH: "1",
      MIGRATE_ON_START: "1",
      NODE_ENV: "test",
      DB_HOST: DB.host, DB_PORT: String(DB.port), DB_USER: DB.user, DB_PASSWORD: DB.password, DB_NAME: DB.database,
      ...(process.env.CHROMIUM_PATH ? { CHROMIUM_PATH: process.env.CHROMIUM_PATH } : {}),
    },
  },
});
