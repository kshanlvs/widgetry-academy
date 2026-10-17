#!/usr/bin/env python3
"""
Widgetry blog builder.

Write posts as Markdown in blog-src/posts/<slug>.md with a front-matter block, then run:

    python3 blog-src/build.py

It writes public/blog/<slug>.html, public/blog/index.html, public/blog/feed.xml (RSS), public/blog/feed.json (for the app) and refreshes the
blog entries in public/sitemap.xml. Commit the generated files; pushing to main publishes them.

Front matter (between --- lines, one "key: value" per line):
    title, description, date (YYYY-MM-DD), updated (optional), tag, keywords (comma separated),
    cta (jobs | resume | course), image (optional, path under public/)
FAQs: a "## Frequently asked questions" section whose questions are "### ..." headings becomes FAQ structured data.
"""
import datetime as dt
import html
import json
import math
import pathlib
import re

import markdown

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "blog-src" / "posts"
OUT = ROOT / "public" / "blog"
SITE = "https://widgetryacademy.in"
AUTHOR = {"name": "Kishan Kumar Sharma", "url": f"{SITE}/mentor.html",
          "bio": "Flutter developer with 5+ years of experience, Senior Software Engineer at Relevance Lab and founder of Widgetry Academy. MCA."}
REDIRECT = '<script>(function(h){if(h==="widgetry-academy.web.app"||h==="widgetry-academy.firebaseapp.com"||h==="www.widgetryacademy.in"){location.replace("https://widgetryacademy.in"+location.pathname+location.search+location.hash)}})(location.hostname)</script>'
FONTS = "https://fonts.googleapis.com/css2?family=Unbounded:wght@700;800&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700;9..40,800&family=JetBrains+Mono:wght@500;600&display=swap"

CTAS = {
    "jobs": ("Looking for your next mobile developer role?", "Browse Flutter, Android and iOS jobs reviewed by working engineers. Free for job seekers.", "../jobs.html", "Browse jobs"),
    "resume": ("Build your ATS-friendly resume in 5 minutes", "Free, no watermark, three professional templates and a resume strength score.", "../resume-builder.html", "Create my resume free"),
    "course": ("Learn Flutter by building a real app", "Flutter in 10 Days: live weekend classes, a real app in your portfolio, and mentor support.", "../#courses", "See the course"),
}


def esc(s):
    return html.escape(str(s), quote=True)


def read_post(path):
    raw = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", raw, re.S)
    if not m:
        raise SystemExit(f"{path.name}: missing front matter")
    meta = {}
    for line in m.group(1).splitlines():
        if line.strip():
            k, _, v = line.partition(":")
            v = v.strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":   # allow quoted values
                v = v[1:-1]
            meta[k.strip()] = v
    for k in ("title", "description", "date"):
        if not meta.get(k):
            raise SystemExit(f"{path.name}: front matter needs '{k}'")
    if len(meta["description"]) > 165:
        print(f"  ! {path.name}: description is {len(meta['description'])} chars (Google shows ~155)")
    meta["slug"] = path.stem
    meta["body_md"] = m.group(2)
    meta.setdefault("updated", meta["date"])
    meta.setdefault("tag", "Careers")
    meta.setdefault("cta", "jobs")
    return meta


def render_body(md_text):
    md = markdown.Markdown(extensions=["toc", "tables", "fenced_code", "attr_list", "sane_lists"],
                           extension_configs={"toc": {"toc_depth": "2-2", "permalink": False}})
    body = md.convert(md_text)
    toc = [(t["id"], t["name"]) for t in md.toc_tokens]
    # External links open safely in a new tab; internal ones stay
    body = re.sub(r'<a href="(https?://(?!widgetryacademy\.in)[^"]+)"', r'<a href="\1" target="_blank" rel="noopener">', body)
    # Tables scroll on small screens
    body = body.replace("<table>", '<div class="tablewrap"><table>').replace("</table>", "</table></div>")
    words = len(re.sub(r"<[^>]+>", " ", body).split())
    return body, toc, max(1, math.ceil(words / 220)), words


def faqs_from(md_text):
    m = re.search(r"^## Frequently asked questions\s*$(.*?)(?=^## |\Z)", md_text, re.M | re.S)
    if not m:
        return []
    out = []
    for q, a in re.findall(r"^### (.+?)\s*$(.*?)(?=^### |\Z)", m.group(1), re.M | re.S):
        text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", a).strip()
        text = re.sub(r"[*_`]", "", text)
        if text:
            out.append({"@type": "Question", "name": q.strip(), "acceptedAnswer": {"@type": "Answer", "text": " ".join(text.split())}})
    return out


def ld_script(obj):
    data = json.dumps(obj, ensure_ascii=False).replace("</", "<\\/")   # never let text close the script tag
    return f'<script type="application/ld+json">{data}</script>'


def nice_date(d):
    return dt.date.fromisoformat(d).strftime("%-d %B %Y")


def head(title, description, canonical, og_type="website", extra=""):
    return f"""<!doctype html>
<html lang="en-IN"><head><meta charset="utf-8">{REDIRECT}<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<link rel="canonical" href="{canonical}">
<meta property="og:type" content="{og_type}"><meta property="og:site_name" content="Widgetry Academy">
<meta property="og:title" content="{esc(title)}"><meta property="og:description" content="{esc(description)}">
<meta property="og:url" content="{canonical}"><meta property="og:image" content="{SITE}/og-image.jpg">
<meta name="twitter:card" content="summary_large_image">
<link rel="alternate" type="application/rss+xml" title="Widgetry blog" href="{SITE}/blog/feed.xml">
<link rel="icon" type="image/svg+xml" href="../favicon.svg">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="{FONTS}">
<link rel="stylesheet" href="blog.css">
{extra}
<script src="../site-config.js" defer></script>
</head><body>
<nav class="bnav"><div class="bwrap">
  <a class="brand" href="../">Widgetry<span>.</span></a>
  <div class="blinks"><a href="../#courses" class="hide-s">Courses</a><a href="../jobs.html">Jobs</a><a href="../resume-builder.html" class="hide-s">Free resume</a><a href="./" aria-current="page">Blog</a></div>
</div></nav>"""


FOOT = """<footer class="bfoot"><div class="bwrap">
  <span>© 2026 Widgetry Academy · Kolkata, India</span>
  <nav><a href="../">Academy</a><a href="../jobs.html">Jobs</a><a href="../resume-builder.html">Free resume</a><a href="./">Blog</a><a href="../privacy.html">Privacy</a><a href="../contact.html">Contact</a></nav>
</div></footer>
</body></html>
"""


def cta_box(kind):
    t, d, href, btn = CTAS.get(kind, CTAS["jobs"])
    return f'<aside class="cta"><div><b>{esc(t)}</b><p>{esc(d)}</p></div><a class="btn" href="{href}">{esc(btn)} →</a></aside>'


def post_page(p, all_posts):
    body, toc, minutes, words = render_body(p["body_md"])
    url = f"{SITE}/blog/{p['slug']}.html"
    # Put a call-to-action after the second section, and another at the end
    parts = re.split(r"(?=<h2 )", body)
    if len(parts) > 3:
        body = "".join(parts[:3]) + cta_box(p["cta"]) + "".join(parts[3:])
    ld = [{
        "@context": "https://schema.org", "@type": "BlogPosting",
        "headline": p["title"], "description": p["description"], "mainEntityOfPage": url, "url": url,
        "datePublished": p["date"], "dateModified": p["updated"], "wordCount": words,
        "keywords": p.get("keywords", ""), "inLanguage": "en-IN", "image": f"{SITE}/og-image.jpg",
        "author": {"@type": "Person", "name": AUTHOR["name"], "url": AUTHOR["url"]},
        "publisher": {"@type": "Organization", "name": "Widgetry Academy", "url": SITE, "logo": {"@type": "ImageObject", "url": f"{SITE}/favicon.svg"}},
    }, {
        "@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Home", "item": f"{SITE}/"},
            {"@type": "ListItem", "position": 2, "name": "Blog", "item": f"{SITE}/blog/"},
            {"@type": "ListItem", "position": 3, "name": p["title"], "item": url}]}]
    faqs = faqs_from(p["body_md"])
    if faqs:
        ld.append({"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": faqs})
    ld_html = "\n".join(ld_script(x) for x in ld)
    related = [q for q in all_posts if q["slug"] != p["slug"]][:3]
    toc_html = "".join(f'<li><a href="#{esc(i)}">{esc(n)}</a></li>' for i, n in toc)
    updated = f' · Updated {nice_date(p["updated"])}' if p["updated"] != p["date"] else ""
    return head(f'{p["title"]} | Widgetry Blog', p["description"], url, "article",
                f'<meta property="article:published_time" content="{p["date"]}"><meta property="article:modified_time" content="{p["updated"]}">\n{ld_html}') + f"""
<main class="bwrap post">
  <p class="crumbs"><a href="../">Home</a> › <a href="./">Blog</a> › <span>{esc(p["tag"])}</span></p>
  <header class="phead">
    <p class="tag">{esc(p["tag"])}</p>
    <h1>{esc(p["title"])}</h1>
    <p class="lede">{esc(p["description"])}</p>
    <div class="byline"><img src="../shots/mentor-square.jpg" alt="" width="40" height="40"><div><a href="../mentor.html">{AUTHOR["name"]}</a><span>{nice_date(p["date"])}{updated} · {minutes} min read</span></div></div>
  </header>
  <div class="layout">
    <article class="prose">
      {body}
      {cta_box(p["cta"] if p["cta"] != "jobs" else "resume")}
      <section class="author"><img src="../shots/mentor-square.jpg" alt="{AUTHOR["name"]}" width="72" height="72" loading="lazy"><div><b>Written by <a href="../mentor.html">{AUTHOR["name"]}</a></b><p>{esc(AUTHOR["bio"])}</p></div></section>
    </article>
    <aside class="side">
      {f'<nav class="toc" aria-label="On this page"><b>On this page</b><ol>{toc_html}</ol></nav>' if toc else ""}
      <div class="sidecta"><b>Widgetry Jobs</b><p>Flutter, Android and iOS jobs, checked by engineers.</p><a href="../jobs.html">Browse jobs →</a><a href="../resume-builder.html">Free ATS resume →</a></div>
    </aside>
  </div>
  <section class="related"><h2>Keep reading</h2><div class="cards">{"".join(card(q) for q in related)}</div></section>
</main>
""" + FOOT


def card(p):
    return f'<a class="pcard" href="{p["slug"]}.html"><span class="tag">{esc(p["tag"])}</span><b>{esc(p["title"])}</b><p>{esc(p["description"])}</p><span class="more">Read →</span></a>'


def index_page(posts):
    url = f"{SITE}/blog/"
    ld = {"@context": "https://schema.org", "@type": "Blog", "name": "Widgetry Blog", "url": url,
          "description": "Career guides for Flutter, Android and iOS developers in India: jobs, salaries, resumes and interviews.",
          "blogPost": [{"@type": "BlogPosting", "headline": p["title"], "url": f"{SITE}/blog/{p['slug']}.html", "datePublished": p["date"]} for p in posts]}
    ld_html = ld_script(ld)
    return head("Flutter & Mobile Developer Career Blog | Widgetry", "Practical guides for Flutter, Android and iOS developers in India: finding jobs, salaries, resumes, interview questions and learning roadmaps.", url, "website", ld_html) + f"""
<header class="bhero"><div class="bwrap">
  <p class="tag" style="color:var(--gold)">Widgetry blog</p>
  <h1>Career guides for <em>mobile developers.</em></h1>
  <p>Honest, practical advice on Flutter, Android and iOS jobs in India: where to find them, what they pay, and how to get hired.</p>
</div></header>
<main class="bwrap"><div class="cards grid">{"".join(card(p) for p in posts)}</div></main>
""" + FOOT


def rss(posts):
    items = "".join(f"""<item><title>{esc(p["title"])}</title><link>{SITE}/blog/{p["slug"]}.html</link><guid>{SITE}/blog/{p["slug"]}.html</guid><pubDate>{dt.datetime.fromisoformat(p["date"]).strftime("%a, %d %b %Y 09:00:00 +0530")}</pubDate><description>{esc(p["description"])}</description></item>""" for p in posts)
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Widgetry Blog</title><link>{SITE}/blog/</link><description>Career guides for Flutter, Android and iOS developers in India.</description><language>en-in</language>{items}</channel></rss>
"""


def update_sitemap(posts):
    path = ROOT / "public" / "sitemap.xml"
    s = path.read_text(encoding="utf-8")
    s = re.sub(r"\s*<!-- blog:start -->.*?<!-- blog:end -->", "", s, flags=re.S)
    newest = max(p["updated"] for p in posts)
    entries = [f'  <url><loc>{SITE}/blog/</loc><lastmod>{newest}</lastmod><changefreq>weekly</changefreq><priority>0.7</priority></url>']
    entries += [f'  <url><loc>{SITE}/blog/{p["slug"]}.html</loc><lastmod>{p["updated"]}</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>' for p in posts]
    block = "\n  <!-- blog:start -->\n" + "\n".join(entries) + "\n  <!-- blog:end -->"
    s = s.replace("</urlset>", block.lstrip("\n") + "\n</urlset>") if "</urlset>" in s else s
    s = re.sub(r"\n\s*\n  <!-- blog:start -->", "\n  <!-- blog:start -->", s)
    path.write_text(s, encoding="utf-8")


def main():
    posts = sorted((read_post(p) for p in SRC.glob("*.md")), key=lambda p: (p["date"], p["title"]), reverse=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for p in posts:
        (OUT / f"{p['slug']}.html").write_text(post_page(p, posts), encoding="utf-8")
        print(f"  ✓ blog/{p['slug']}.html")
    (OUT / "index.html").write_text(index_page(posts), encoding="utf-8")
    (OUT / "feed.xml").write_text(rss(posts), encoding="utf-8")
    # JSON feed for the mobile app (newest first)
    feed = {"version": "https://jsonfeed.org/version/1.1", "title": "Widgetry Blog", "home_page_url": f"{SITE}/blog/",
            "items": [{"id": p["slug"], "url": f"{SITE}/blog/{p['slug']}.html", "title": p["title"], "summary": p["description"],
                       "date_published": p["date"], "date_modified": p["updated"], "tags": [p["tag"]],
                       "reading_minutes": render_body(p["body_md"])[2]} for p in posts]}
    (OUT / "feed.json").write_text(json.dumps(feed, ensure_ascii=False, indent=1), encoding="utf-8")
    update_sitemap(posts)
    print(f"Built {len(posts)} posts, index, feed and sitemap.")


if __name__ == "__main__":
    main()
