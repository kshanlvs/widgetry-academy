// Prints brochure-src/out/*.html to public/brochures/*.pdf (A4) with Playwright's Chromium.
// Run after build.py:  node brochure-src/print.cjs
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

(async () => {
  const out = path.join(__dirname, "out");
  const dest = path.join(__dirname, "..", "public", "brochures");
  fs.mkdirSync(dest, { recursive: true });
  const exe = fs.existsSync("/opt/pw-browsers/chromium") ? "/opt/pw-browsers/chromium" : undefined;
  const browser = await chromium.launch(exe ? { executablePath: exe } : {});
  for (const f of fs.readdirSync(out).filter(x => x.endsWith(".html"))) {
    const page = await browser.newPage();
    await page.goto("file://" + path.join(out, f), { waitUntil: "load" });
    await page.evaluate(() => document.fonts.ready);
    const pdf = path.join(dest, f.replace(/\.html$/, ".pdf"));
    await page.pdf({ path: pdf, format: "A4", printBackground: true, preferCSSPageSize: true });
    console.log("  ✓", path.relative(process.cwd(), pdf));
    await page.close();
  }
  await browser.close();
})();
