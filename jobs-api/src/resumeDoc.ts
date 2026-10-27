// Resume files made on the server: a PDF (printed by Chromium from the same HTML templates the website shows,
// so it looks exactly like the preview and keeps real, selectable text for ATS) and a Word (.docx) file.
//
// The website and the app both download from here. Premium templates get the watermark here too, so it
// can't be removed in the browser.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import type { Browser } from "playwright-core";
import { AlignmentType, BorderStyle, Document, ExternalHyperlink, LevelFormat, Packer, Paragraph, TabStopType, TextRun } from "docx";
import { renderResume, RESUME_CSS, groupSkills, autoSummary, keyHighlights, ACCENTS, PRO_TEMPLATES } from "./shared/resume-render.js";

const here = dirname(fileURLToPath(import.meta.url));
const env = process.env;

// ---------- Fonts (bundled, so the PDF never depends on Google Fonts being reachable) ----------
let fontCss: string | null = null;
function fonts(): string {
  if (fontCss != null) return fontCss;
  const dir = [join(here, "../fonts"), join(here, "../../fonts")].find(d => { try { readFileSync(join(d, "dm-sans-latin-wght-normal.woff2")); return true; } catch { return false; } });
  if (!dir) return (fontCss = "");
  const face = (family: string, file: string, style: string, range: string) =>
    `@font-face{font-family:"${family}";font-style:${style};font-weight:300 800;font-display:block;src:url(data:font/woff2;base64,${readFileSync(join(dir, file)).toString("base64")}) format("woff2");unicode-range:${range}}`;
  const LATIN = "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD";
  const EXT = "U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF";
  return (fontCss = [
    face("DM Sans", "dm-sans-latin-wght-normal.woff2", "normal", LATIN),
    face("DM Sans", "dm-sans-latin-ext-wght-normal.woff2", "normal", EXT),
    face("Source Serif 4", "source-serif-4-latin-wght-normal.woff2", "normal", LATIN),
    face("Source Serif 4", "source-serif-4-latin-ext-wght-normal.woff2", "normal", EXT),
    face("Source Serif 4", "source-serif-4-latin-wght-italic.woff2", "italic", LATIN),
  ].join("\n"));
}

export interface ResumeLook { template?: string; accent?: string; title?: string | null; showPhoto?: boolean; hide?: string[]; density?: string }

/** The full HTML page that is printed to PDF (also used by tests). [pro]: the person has Resume Premium. */
export function resumeHtml(p: any, look: ResumeLook, watermark: boolean, pro = false): string {
  const t = look.template || "modern";
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${String(p.fullName || "Resume").replace(/[<&]/g, "")} - Resume</title>
<style>${fonts()}
@page{size:A4;margin:12mm 14mm}
html,body{margin:0;background:#fff;-webkit-print-color-adjust:exact;print-color-adjust:exact}
${RESUME_CSS}
.resume .row{flex-direction:row!important}
</style></head><body>${renderResume(p, t, { ...look, watermark, pro })}</body></html>`;
}

export const needsWatermark = (template: string | undefined, premium: boolean) => PRO_TEMPLATES.has(template || "") && !premium;

// ---------- PDF (Chromium) ----------
let browser: Promise<Browser> | null = null;
let running = 0;
const waiting: (() => void)[] = [];
const MAX_PARALLEL = Number(env.PDF_PARALLEL || 2);

/** Chromium installed in the container (Dockerfile), or CHROMIUM_PATH for local runs. */
export const chromiumPath = () => env.CHROMIUM_PATH || "/usr/bin/chromium";

async function getBrowser(): Promise<Browser> {
  if (!browser) {
    const { chromium } = await import("playwright-core");
    browser = chromium.launch({ executablePath: chromiumPath(), args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--font-render-hinting=none"] })
      .then(b => { b.on("disconnected", () => { browser = null; }); return b; })
      .catch(e => { browser = null; throw e; });
  }
  return browser;
}

/** Prints the HTML to an A4 PDF. Returns the bytes and the number of pages. */
export async function htmlToPdf(html: string): Promise<{ pdf: Buffer; pages: number }> {
  if (running >= MAX_PARALLEL) await new Promise<void>(r => waiting.push(r));
  running++;
  try {
    const b = await getBrowser();
    const page = await b.newPage();
    try {
      await page.setContent(html, { waitUntil: "load", timeout: 15000 });
      await page.evaluate(() => (document as any).fonts.ready);
      const pdf = await page.pdf({ format: "A4", printBackground: true, preferCSSPageSize: true });
      const pages = (pdf.toString("latin1").match(/\/Type\s*\/Page(?!s)/g) || []).length || 1;
      return { pdf, pages };
    } finally { await page.close().catch(() => {}); }
  } finally {
    running--;
    waiting.shift()?.();
  }
}

export async function closePdfBrowser() { const b = browser; browser = null; if (b) await (await b).close().catch(() => {}); }

// ---------- Word (.docx) ----------
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const ym = (v?: string | null) => { if (!v) return "Present"; const [y, m] = String(v).split("-"); return `${MONTHS[Number(m) - 1] || ""} ${y}`.trim(); };
const pts = (t?: string | null) => String(t || "").split(/\n+/).map(s => s.replace(/^\s*[-•*·]\s*/, "").trim()).filter(Boolean);
const short = (u: string) => u.replace(/^https?:\/\/(www\.)?/i, "").replace(/\/$/, "");
const isUrl = (u?: string | null) => /^https?:\/\//i.test(u || "");

/** A plain, ATS-friendly Word file: one column, standard headings, real bullet lists. */
/** Word file (Resume Premium): the chosen accent colour and Key highlights, like the Pro PDF. */
export async function resumeDocx(p: any, look: ResumeLook): Promise<Buffer> {
  const hide = new Set(look.hide || []), show = (k: string) => !hide.has(k);
  const ACCENT = ((ACCENTS as Record<string, string>)[look.accent || ""] || "#0f6b56").slice(1).toUpperCase(), FONT = "Calibri";
  const kids: Paragraph[] = [];
  const heading = (text: string) => kids.push(new Paragraph({
    spacing: { before: 220, after: 80 }, border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: "B9D3C8", space: 2 } },
    children: [new TextRun({ text: text.toUpperCase(), bold: true, size: 21, color: ACCENT, font: FONT })],
  }));
  const bullet = (text: string) => kids.push(new Paragraph({ numbering: { reference: "dots", level: 0 }, spacing: { after: 40 }, children: [new TextRun({ text, size: 20, font: FONT })] }));
  const row = (left: TextRun[], right?: string) => kids.push(new Paragraph({
    tabStops: [{ type: TabStopType.RIGHT, position: 10200 }], spacing: { before: 80, after: 30 },
    children: [...left, ...(right ? [new TextRun({ text: `\t${right}`, size: 19, color: "555555", font: FONT })] : [])],
  }));

  kids.push(new Paragraph({ children: [new TextRun({ text: p.fullName || "", bold: true, size: 44, font: FONT })] }));
  kids.push(new Paragraph({ spacing: { after: 60 }, children: [new TextRun({ text: (look.title || "").trim() || p.headline || "", bold: true, size: 23, color: ACCENT, font: FONT })] }));
  const contact: (TextRun | ExternalHyperlink)[] = [];
  const add = (x: TextRun | ExternalHyperlink) => { if (contact.length) contact.push(new TextRun({ text: "  |  ", size: 19, color: "777777", font: FONT })); contact.push(x); };
  if (show("city") && p.city) add(new TextRun({ text: `${p.city}, India`, size: 19, font: FONT }));
  if (show("phone") && p.phone) add(new TextRun({ text: p.phone, size: 19, font: FONT }));
  if (show("email") && p.email) add(new TextRun({ text: p.email, size: 19, font: FONT }));
  for (const u of [p.linkedinUrl, p.githubUrl, p.portfolioUrl].filter(isUrl)) add(new ExternalHyperlink({ link: u, children: [new TextRun({ text: short(u), size: 19, font: FONT, color: "1F4E79" })] }));
  kids.push(new Paragraph({ spacing: { after: 120 }, border: { bottom: { style: BorderStyle.SINGLE, size: 12, color: ACCENT, space: 4 } }, children: contact }));

  if (show("summary")) { heading("Professional Summary"); kids.push(new Paragraph({ children: [new TextRun({ text: (p.about || "").trim() || autoSummary(p), size: 20, font: FONT })] })); }
  const hl = show("highlights") ? keyHighlights(p) : [];
  if (hl.length >= 2) { heading("Key Highlights"); hl.forEach(bullet); }
  const groups = groupSkills(p.skills || []);
  if (groups.length) {
    heading("Technical Skills");
    for (const [label, list] of groups) kids.push(new Paragraph({ spacing: { after: 30 }, children: [new TextRun({ text: `${label}: `, bold: true, size: 20, font: FONT }), new TextRun({ text: list.join(", "), size: 20, font: FONT })] }));
  }
  const work = p.experience || [];
  if (work.length || p.currentCompany) {
    heading("Professional Experience");
    if (!work.length) row([new TextRun({ text: p.headline, bold: true, size: 20, font: FONT }), new TextRun({ text: ` | ${p.currentCompany}`, size: 20, font: FONT })], "Present");
    for (const w of work) {
      row([new TextRun({ text: w.role, bold: true, size: 20, font: FONT }), new TextRun({ text: ` | ${w.company}`, size: 20, font: FONT })], `${ym(w.start)} – ${ym(w.end)}`);
      pts(w.points).forEach(bullet);
    }
  }
  if (show("projects") && (p.apps || []).length) {
    heading("Projects");
    for (const a of p.apps) {
      row([new TextRun({ text: a.name, bold: true, size: 20, font: FONT }), ...(a.role ? [new TextRun({ text: ` | ${a.role}`, size: 20, font: FONT })] : [])], isUrl(a.url) ? short(a.url).slice(0, 60) : undefined);
      if (a.about) bullet(a.about);
    }
  }
  if (show("achievements") && (p.achievements || []).length) { heading("Achievements"); (p.achievements as string[]).forEach(bullet); }
  if (show("education") && (p.education || []).length) {
    heading("Education");
    for (const e of p.education) row([new TextRun({ text: e.degree, bold: true, size: 20, font: FONT }), new TextRun({ text: ` | ${e.institute}${e.score ? ` | ${e.score}` : ""}`, size: 20, font: FONT })], e.year ? String(e.year) : undefined);
  }
  const certs = [...(p.certifications || [])];
  if (p.verification === "verified") certs.unshift({ name: "Widgetry Verified Flutter Developer (technical interview)", issuer: "Widgetry Academy" });
  if (show("certifications") && certs.length) { heading("Certifications"); for (const c of certs) bullet(`${c.name}${c.issuer ? ` – ${c.issuer}` : ""}${c.year ? ` (${c.year})` : ""}`); }
  if (show("languages") && (p.languages || []).length) { heading("Languages"); kids.push(new Paragraph({ children: [new TextRun({ text: p.languages.join(", "), size: 20, font: FONT })] })); }

  const doc = new Document({
    creator: "Widgetry Academy", title: `${p.fullName} - Resume`,
    styles: { default: { document: { run: { font: FONT, size: 20 } } } },
    numbering: { config: [{ reference: "dots", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 360, hanging: 220 } } } }] }] },
    sections: [{ properties: { page: { margin: { top: 720, bottom: 720, left: 800, right: 800 } } }, children: kids }],
  });
  return Packer.toBuffer(doc);
}

/** "Priya Nair" -> "Priya-Nair-Resume" */
export const fileBase = (name: string) => `${String(name || "My").replace(/[^A-Za-z0-9 ]/g, "").trim().replace(/\s+/g, "-") || "My"}-Resume`;
