// Reads a resume file (PDF or Word .docx) into plain text, in the browser. Nothing is uploaded.
// The readers (pdf.js and mammoth) are self-hosted in vendor/ and load only when someone picks a file.

const MAX = 5 * 1024 * 1024;
const loaded = {};
function script(src) {
  return (loaded[src] ??= new Promise((ok, no) => {
    const s = document.createElement("script"); s.src = src; s.onload = ok;
    s.onerror = () => { delete loaded[src]; no(new Error("Couldn't load the file reader. Check your connection and try again.")); };
    document.head.appendChild(s);
  }));
}

async function readPdf(buf) {
  await script("vendor/pdf-3.11.174.min.js");
  const lib = window.pdfjsLib;
  lib.GlobalWorkerOptions.workerSrc = "vendor/pdf-3.11.174.worker.min.js";
  const pdf = await lib.getDocument({ data: buf }).promise;
  const out = [];
  for (let i = 1; i <= Math.min(pdf.numPages, 8); i++) {
    const page = await pdf.getPage(i);
    const { items } = await page.getTextContent();
    // Rebuild lines: pieces on the same baseline join (with a space when there's a gap), a new baseline starts a new line
    let line = "", y = null, lastEnd = null;
    for (const it of items) {
      const iy = Math.round(it.transform[5]), x = it.transform[4];
      if (y !== null && Math.abs(iy - y) > 2) { out.push(line); line = ""; lastEnd = null; }
      if (line && lastEnd !== null && x - lastEnd > 1.5 && !/\s$/.test(line) && !/^\s/.test(it.str)) line += " ";
      line += it.str; y = iy; lastEnd = x + (it.width || 0);
      if (it.hasEOL) { out.push(line); line = ""; y = null; lastEnd = null; }
    }
    if (line) out.push(line);
    out.push("");
  }
  return { text: out.join("\n"), pages: pdf.numPages };
}

async function readDocx(buf) {
  await script("vendor/mammoth-1.6.0.browser.min.js");
  const r = await window.mammoth.extractRawText({ arrayBuffer: buf });
  const text = r.value || "";
  return { text, pages: Math.max(1, Math.round(text.split(/\s+/).filter(Boolean).length / 480)) };
}

/** Returns { name, type: "pdf"|"docx", text, pages }. Throws an Error with a message fit to show people. */
export async function readResumeFile(f) {
  const name = f?.name || "resume";
  const type = /\.pdf$/i.test(name) || f?.type === "application/pdf" ? "pdf" : /\.docx$/i.test(name) ? "docx" : /\.doc$/i.test(name) ? "doc" : "";
  if (type === "doc") throw new Error("Old .doc files can't be read here. Save it as .docx or PDF and try again.");
  if (!type) throw new Error("Choose a PDF or a Word (.docx) file.");
  if (f.size > MAX) throw new Error("That file is over 5 MB. Choose a smaller PDF or Word file.");
  try {
    const buf = await f.arrayBuffer();
    return { name, type, ...(type === "pdf" ? await readPdf(buf) : await readDocx(buf)) };
  } catch (e) {
    if (/password/i.test(e?.message || "")) throw new Error("This PDF is password-protected. Remove the password and try again.");
    if (e?.message?.startsWith("Couldn't")) throw e;
    throw new Error("We couldn't read that file. Save it again as PDF or .docx, or paste the text.");
  }
}
