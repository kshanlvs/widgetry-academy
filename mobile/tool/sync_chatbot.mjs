// Copies the website assistant's answers (public/chatbot.js) into the app (assets/chatbot/intents.json),
// so the app and the website always give the same answers.
//
//   node mobile/tool/sync_chatbot.mjs        (run from the repo root, after editing public/chatbot.js)
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "../../public/chatbot.js"), "utf8");

function grab(name, open, close) {
  const start = src.indexOf(`var ${name} = ${open}`);
  if (start < 0) throw new Error(`Could not find ${name} in chatbot.js`);
  let depth = 0, i = src.indexOf(open, start);
  for (let j = i; j < src.length; j++) {
    if (src[j] === open) depth++;
    else if (src[j] === close && --depth === 0) return src.slice(i, j + 1);
  }
  throw new Error(`Unclosed ${name}`);
}

const intents = Function(`"use strict"; return ${grab("INTENTS", "[", "]")};`)();
const starters = Function(`"use strict"; return ${grab("STARTERS", "[", "]")};`)();
const genericMatch = src.match(/var GENERIC = \{\}; (\[[\s\S]*?\])\.forEach/);
if (!genericMatch) throw new Error("Could not find GENERIC in chatbot.js");
const generic = Function(`"use strict"; return ${genericMatch[1]};`)();
const course = (src.match(/var COURSE = "([^"]+)"/) || [])[1] || "Flutter in 10 Days";

const out = {
  source: "public/chatbot.js",
  course,
  starters,
  generic,
  intents: intents.map((x) => ({
    id: x.id, q: x.q, k: x.k, a: x.a,
    act: (x.act || []).map(([label, type, target]) => ({ label, type, target })),
    rel: x.rel || [],
  })),
};
const dest = join(here, "../assets/chatbot/intents.json");
writeFileSync(dest, JSON.stringify(out, null, 1) + "\n");
console.log(`Wrote ${out.intents.length} answers to ${dest}`);
