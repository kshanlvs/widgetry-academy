// Builds the tutor's knowledge files (RAG sources) in jobs-api/knowledge from content that lives elsewhere in the repo:
//   - blog posts:  blog-src/posts/*.md               → knowledge/blog-<slug>.md
//   - FAQ answers: mobile/assets/chatbot/intents.json → knowledge/faq.md
//   - course pages: public/*-course.html             → knowledge/course-<slug>.md (syllabus text; prices and dates come live from the database)
// Hand-written files in knowledge/ (e.g. academy-courses.md) are left alone.
// Run after editing a blog post or the chatbot:  npm run knowledge
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const out = path.resolve(here, "../knowledge");
const SITE = "https://widgetryacademy.in";
fs.mkdirSync(out, { recursive: true });

// Old generated files go first, so a deleted post disappears from the tutor too
for (const f of fs.readdirSync(out)) if (f.startsWith("blog-") || f.startsWith("course-") || f === "faq.md") fs.unlinkSync(path.join(out, f));

const head = (meta) => "---\n" + Object.entries(meta).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join("\n") + "\n---\n\n";

// Blog posts
const postsDir = path.join(root, "blog-src/posts");
let posts = 0;
for (const f of fs.readdirSync(postsDir).filter(f => f.endsWith(".md")).sort()) {
  const raw = fs.readFileSync(path.join(postsDir, f), "utf8");
  const m = /^---\n([\s\S]*?)\n---\n([\s\S]*)$/.exec(raw);
  if (!m) continue;
  const fm = Object.fromEntries(m[1].split("\n").map(l => /^(\w+):\s*(.*)$/.exec(l)).filter(Boolean).map(([, k, v]) => [k, v.replace(/^"(.*)"$/, "$1")]));
  const slug = f.replace(/\.md$/, "");
  fs.writeFileSync(path.join(out, `blog-${slug}.md`),
    head({ title: fm.title || slug, url: `${SITE}/blog/${slug}.html`, kind: "blog" }) + (fm.description ? fm.description + "\n\n" : "") + m[2].trim() + "\n");
  posts++;
}

// FAQ from the website/app assistant. Course lists, greetings and anything about fees or dates are left out:
// live facts from the database answer those, so the tutor never repeats an old price.
const kb = JSON.parse(fs.readFileSync(path.join(root, "mobile/assets/chatbot/intents.json"), "utf8"));
const skip = new Set(["hello", "thanks", "courses", "fee", "batch"]);
const faq = kb.intents.filter(i => !skip.has(i.id)).map(i => `## ${i.q}\n\n${i.a}`).join("\n\n");
fs.writeFileSync(path.join(out, "faq.md"),
  head({ title: `${kb.course || "Flutter in 10 Days"}: frequently asked questions`, url: `${SITE}/#faq`, kind: "faq" }) + faq + "\n");

// Course pages: visible text only, one line per heading, list item or paragraph
const decode = t => t.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;|&rsquo;/g, "'").replace(/&nbsp;/g, " ").replace(/&middot;/g, "·").replace(/&[a-z]+;/g, " ");
let coursePages = 0;
for (const f of fs.readdirSync(path.join(root, "public")).filter(f => /-course\.html$/.test(f)).sort()) {
  const html = fs.readFileSync(path.join(root, "public", f), "utf8");
  const title = decode((/<title>([^<]*)<\/title>/i.exec(html) || [])[1] || f).replace(/\s*\|.*$/, "").trim();
  const body = html
    .replace(/<(script|style|nav|footer|svg|head)\b[\s\S]*?<\/\1>/gi, "")
    .replace(/<h[1-3][^>]*>/gi, "\n## ").replace(/<(li)[^>]*>/gi, "\n- ").replace(/<(p|div|br|tr|section|article)[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, "");
  const lines = decode(body).split("\n").map(l => l.replace(/\s+/g, " ").trim()).filter(l => l.length > 2 && !/^(-|##)\s*$/.test(l));
  // Drop the enrol box and anything after the FAQ's end: it holds prices and buttons, not teaching content
  const text = lines.join("\n").replace(/\n## (Enrol|Reserve|Book)[\s\S]*$/i, "").slice(0, 9000);
  fs.writeFileSync(path.join(out, `course-${f.replace(/\.html$/, "")}.md`), head({ title, url: `${SITE}/${f}`, kind: "course" }) + text + "\n");
  coursePages++;
}

console.log(`knowledge: ${coursePages} course pages, ${posts} blog posts + FAQ (${kb.intents.length - skip.size} answers) written to ${path.relative(root, out)}`);
