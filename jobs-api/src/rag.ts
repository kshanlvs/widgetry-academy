// Retrieval for the AI tutor (the "R" in RAG).
//
// 1. Load: every Markdown file in jobs-api/knowledge (course pages, blog posts, FAQ; built by `npm run knowledge`).
// 2. Chunk: split each file at its "## " headings, and long sections again by paragraph, so each chunk is about one idea.
// 3. Index: count the words in every chunk (BM25, the classic search-engine formula).
// 4. Retrieve: score every chunk against the student's question and return the best few.
//
// The chunks that come back are pasted into the prompt, so Claude answers from Widgetry's own material
// instead of only from memory, and the app can show where the answer came from.
//
// Why word matching and not embeddings? The knowledge base is small (a few hundred chunks) and full of exact
// technical words (Cubit, bloc_test, copyWith) that word matching finds very well. It needs no second API key
// and costs nothing per question. If the library grows a lot, swap `score` for embeddings + a vector search;
// the rest of the pipeline (chunks in, best chunks out) stays the same.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export interface Chunk {
  id: number;
  /** The document's title, e.g. "Flutter Bloc Tutorial for Beginners…" */
  title: string;
  /** The section heading inside the document, if any */
  section: string | null;
  url: string;
  kind: string;
  text: string;
}
export interface Hit { chunk: Chunk; score: number }

const MAX_CHUNK = 1400;   // characters; roughly 350 tokens
const K1 = 1.2, B = 0.75; // standard BM25 settings

// Words too common to tell chunks apart
const STOP = new Set(("a an and are as at be but by can do does for from how i if in into is it its me my of on or so " +
  "that the their them then there these this to was we what when where which who why will with you your " +
  "should would could about use using get make i'm im it's").split(" "));

/** Lower-case words without stop words, crudely stemmed ("states" → "state", "testing" → "test") so word forms match. */
export function tokens(text: string): string[] {
  return (text.toLowerCase().match(/[a-z0-9_]+/g) ?? [])
    .filter(w => w.length > 1 && !STOP.has(w))
    .map(w => (w.length > 5 && w.endsWith("ing") ? w.slice(0, -3) : w))
    .map(w => (w.length > 3 && w.endsWith("s") && !w.endsWith("ss") ? w.slice(0, -1) : w));
}

function frontMatter(raw: string): { meta: Record<string, string>; body: string } {
  const m = /^---\n([\s\S]*?)\n---\n([\s\S]*)$/.exec(raw);
  if (!m) return { meta: {}, body: raw };
  const meta: Record<string, string> = {};
  for (const line of m[1].split("\n")) {
    const kv = /^(\w+):\s*(.*)$/.exec(line);
    if (kv) meta[kv[1]] = kv[2].replace(/^"(.*)"$/, "$1");
  }
  return { meta, body: m[2] };
}

/** Splits one document into chunks at "## " headings, then by paragraph when a section is long. */
export function chunkDocument(raw: string, fallbackTitle: string): Omit<Chunk, "id">[] {
  const { meta, body } = frontMatter(raw);
  const title = meta.title || fallbackTitle, url = meta.url || "", kind = meta.kind || "doc";
  const out: Omit<Chunk, "id">[] = [];
  // Text before the first heading is the introduction
  const parts = body.split(/\n(?=## )/);
  for (const part of parts) {
    const h = /^## (.+)\n?/.exec(part);
    const section = h ? h[1].trim() : null;
    const text = (h ? part.slice(h[0].length) : part).trim();
    if (!text) continue;
    // Long sections: pack paragraphs (keeping code blocks whole) into chunks of up to MAX_CHUNK characters
    const paras: string[] = [];
    for (const p of text.split(/\n{2,}/)) {
      const last = paras[paras.length - 1];
      // Inside an open ``` code block: keep joining, so code is never cut in half
      if (last !== undefined && (last.match(/```/g)?.length ?? 0) % 2 === 1) paras[paras.length - 1] = last + "\n\n" + p;
      else paras.push(p);
    }
    let buf = "";
    for (const p of paras) {
      if (buf && buf.length + p.length > MAX_CHUNK) { out.push({ title, section, url, kind, text: buf.trim() }); buf = ""; }
      buf += p + "\n\n";
    }
    if (buf.trim()) out.push({ title, section, url, kind, text: buf.trim() });
  }
  return out;
}

export class KnowledgeIndex {
  readonly chunks: Chunk[] = [];
  private tf: Map<string, number>[] = [];
  private heads: Set<string>[] = [];
  private len: number[] = [];
  private df = new Map<string, number>();
  private avgLen = 1;

  constructor(docs: { name: string; raw: string }[]) {
    for (const d of docs) for (const c of chunkDocument(d.raw, d.name)) this.chunks.push({ id: this.chunks.length, ...c });
    for (const c of this.chunks) {
      const words = tokens(`${c.title} ${c.section ?? ""} ${c.text}`);
      this.heads.push(new Set(tokens(c.section ?? c.title)));
      const tf = new Map<string, number>();
      for (const w of words) tf.set(w, (tf.get(w) ?? 0) + 1);
      for (const w of tf.keys()) this.df.set(w, (this.df.get(w) ?? 0) + 1);
      this.tf.push(tf);
      this.len.push(words.length);
    }
    this.avgLen = this.len.reduce((a, b) => a + b, 0) / Math.max(1, this.len.length);
  }

  /** BM25: words that are rare across the library but frequent in this chunk score highest. */
  private score(i: number, q: string[]): number {
    const N = this.chunks.length, tf = this.tf[i];
    let s = 0;
    for (const w of new Set(q)) {
      const f = tf.get(w);
      if (!f) continue;
      const n = this.df.get(w) ?? 0;
      const idf = Math.log(1 + (N - n + 0.5) / (n + 0.5));
      s += idf * (f * (K1 + 1)) / (f + K1 * (1 - B + B * this.len[i] / this.avgLen));
      // A question word in the section heading is a strong signal: "Cubit vs Bloc" is about exactly that
      if (this.heads[i].has(w)) s += idf;
    }
    return s;
  }

  /**
   * The best [k] chunks for a question. Weak matches are dropped (a question about something we never wrote about
   * should bring back nothing, so Claude doesn't get unrelated text), and at most 2 chunks per document,
   * so one long post can't crowd out everything else.
   */
  search(question: string, k = 4, minScore = 3): Hit[] {
    const q = tokens(question);
    if (!q.length) return [];
    const hits = this.chunks.map((c, i) => ({ chunk: c, score: this.score(i, q) }))
      .filter(h => h.score >= minScore)
      .sort((a, b) => b.score - a.score);
    const perDoc = new Map<string, number>(), out: Hit[] = [];
    for (const h of hits) {
      const n = perDoc.get(h.chunk.url) ?? 0;
      if (n >= 2) continue;
      perDoc.set(h.chunk.url, n + 1);
      out.push(h);
      if (out.length >= k) break;
    }
    return out;
  }
}

const dir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../knowledge");
let index: KnowledgeIndex | null = null;

/** Built once, on the first question after the server starts. */
export function knowledge(): KnowledgeIndex {
  if (!index) {
    const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.endsWith(".md")).sort() : [];
    index = new KnowledgeIndex(files.map(f => ({ name: f.replace(/\.md$/, ""), raw: fs.readFileSync(path.join(dir, f), "utf8") })));
    console.log(`[rag] ${files.length} documents, ${index.chunks.length} chunks`);
  }
  return index;
}

/** The chunks as they go into the prompt. Each is numbered so Claude (and we) can tell them apart. */
export function formatReferences(hits: Hit[]): string {
  return hits.map((h, i) =>
    `<reference id="${i + 1}" title="${h.chunk.title.replace(/"/g, "'")}"${h.chunk.section ? ` section="${h.chunk.section.replace(/"/g, "'")}"` : ""}>\n${h.chunk.text}\n</reference>`).join("\n");
}

/** One link per document, for the app to show under the answer. */
export function sourcesOf(hits: Hit[]): { title: string; url: string }[] {
  const seen = new Set<string>(), out: { title: string; url: string }[] = [];
  for (const h of hits) {
    if (!h.chunk.url || seen.has(h.chunk.url)) continue;
    seen.add(h.chunk.url);
    out.push({ title: h.chunk.title, url: h.chunk.url });
  }
  return out;
}
