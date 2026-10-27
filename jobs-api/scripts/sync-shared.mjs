// The resume engine (templates, ATS check, resume import) lives in the website's public/ folder, where the
// browser uses it directly. The API runs the very same code to make PDFs and Word files, check ATS scores and
// read uploaded resumes for the app. This copies it into src/shared/ so the two never drift.
//
//   npm run sync-shared     (after editing public/resume-render.js, resume-ats.js or resume-parse.js)
//
// A test fails if the copies are out of date.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
export const SHARED = ["resume-render.js", "resume-ats.js", "resume-parse.js"];
export const header = f => `// GENERATED from public/${f} by \`npm run sync-shared\`. Edit the website file, not this one.\n`;
export const copyOf = f => header(f) + readFileSync(join(here, "../../public", f), "utf8");

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  for (const f of SHARED) writeFileSync(join(here, "../src/shared", f), copyOf(f));
  console.log(`Copied ${SHARED.length} files into src/shared/`);
}
