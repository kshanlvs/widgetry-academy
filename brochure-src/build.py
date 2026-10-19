#!/usr/bin/env python3
"""
Builds a PDF brochure for each course in courses.py, in the same style as the Flutter in 10 Days brochure.

    pip install qrcode pillow        # once
    python3 brochure-src/build.py    # writes brochure-src/out/<slug>.html
    node brochure-src/print.cjs      # prints them to public/brochures/<slug>.pdf (needs Playwright + Chromium)

Fonts: Unbounded, DM Sans and JetBrains Mono must be installed on the machine (Google Fonts).
"""
import base64
import html
import io
import pathlib

import qrcode

from courses import COURSES, MENTOR

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / "out"
ROOT = HERE.parent
e = lambda s: html.escape(str(s), quote=True)

CSS = r"""
@page { size: A4; margin: 0; }
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body { font-family: "DM Sans", sans-serif; color: #0e1f1a; font-size: 10.5pt; line-height: 1.5; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.page { width: 210mm; height: 297mm; padding: 14mm 15mm 12mm; position: relative; overflow: hidden; page-break-after: always; display: flex; flex-direction: column; background: #fff; }
.page:last-child { page-break-after: auto; }
.mono { font-family: "JetBrains Mono", monospace; }
.run { display: flex; justify-content: space-between; font-family: "JetBrains Mono", monospace; font-size: 7pt; letter-spacing: .12em; text-transform: uppercase; color: #56695f; margin-bottom: 9mm; }
.foot { margin-top: auto; display: flex; justify-content: space-between; font-family: "JetBrains Mono", monospace; font-size: 7pt; color: #56695f; padding-top: 5mm; border-top: 1px solid #d8e2dc; }
h1, h2, h3 { font-family: "Unbounded", sans-serif; letter-spacing: -.02em; line-height: 1.12; margin: 0; }
.eyebrow { font-family: "JetBrains Mono", monospace; font-size: 7.5pt; letter-spacing: .14em; text-transform: uppercase; color: #0f6b56; font-weight: 700; margin: 0 0 3mm; }
h2 { font-size: 19pt; margin-bottom: 3mm; }
p { margin: 0 0 3mm; }
.muted { color: #4f6359; }

/* Cover */
.cover { background: #0c2a23; color: #eaf3ee; padding: 16mm 16mm 14mm; }
.cover .brand { display: flex; align-items: center; gap: 3mm; font-family: "Unbounded"; font-weight: 700; font-size: 12pt; color: #fff; }
.mark { display: grid; grid-template-columns: 1fr 1fr; gap: 1.2mm; width: 8mm; height: 8mm; }
.mark i { border-radius: 1mm; background: #3fc79f; } .mark i:nth-child(2), .mark i:nth-child(3) { background: #f2a900; }
.cover .tag { font-family: "JetBrains Mono"; font-size: 6.5pt; letter-spacing: .16em; color: #a8c2b6; margin-top: .8mm; }
.cover .kicker { margin-top: 16mm; display: inline-block; background: rgba(255,255,255,.08); border: 1px solid #245446; border-radius: 99px; padding: 1.6mm 4mm; font-size: 8.5pt; color: #cfe0da; align-self: flex-start; }
.cover h1 { font-size: 33pt; font-weight: 800; color: #fff; margin-top: 9mm; max-width: 160mm; }
.cover h1 em { font-style: normal; color: #f2a900; }
.cover .desc { font-size: 11.5pt; color: #cfe0da; max-width: 130mm; margin-top: 6mm; }
.chips { display: flex; gap: 2.5mm; flex-wrap: wrap; margin-top: 6mm; }
.chips span { border: 1px solid #245446; border-radius: 99px; padding: 1.4mm 3.5mm; font-size: 8.5pt; color: #eaf3ee; }
.visual { margin-top: 10mm; align-self: flex-end; }
.stats { margin-top: auto; display: grid; grid-template-columns: repeat(4, 1fr); gap: 6mm; border-top: 1px solid #245446; padding-top: 6mm; }
.stats b { display: block; font-family: "Unbounded"; font-size: 17pt; color: #fff; }
.stats span { font-size: 8pt; color: #a8c2b6; line-height: 1.35; display: block; margin-top: 1mm; }

/* Cover visuals */
.vis-card { width: 104mm; border-radius: 5mm; padding: 6mm; transform: rotate(-2deg); }
.code { background: #06140f; border: 1px solid #1e4a3e; font-family: "JetBrains Mono"; font-size: 8.4pt; line-height: 1.65; color: #d7efe5; white-space: pre; }
.code .k { color: #ffd166; } .code .t { color: #7fdcc0; } .code .c { color: #86a79a; }
.score { background: #f6f4ee; color: #0c2a23; }
.score .top { display: flex; justify-content: space-between; font-size: 8pt; font-weight: 700; color: #33433e; }
.score .big { font-family: "Unbounded"; font-weight: 800; font-size: 28pt; line-height: 1.1; margin-top: 1mm; }
.balls { display: flex; gap: 2mm; margin-top: 4mm; }
.balls i { width: 10mm; height: 10mm; border-radius: 50%; display: grid; place-items: center; font-style: normal; font-family: "JetBrains Mono"; font-size: 8.5pt; background: #e3efe9; }
.balls .b4 { background: #0f6b56; color: #fff; } .balls .bw { background: #c23b3b; color: #fff; } .balls .b6 { background: #f2a900; }
.score .line { margin-top: 4mm; border-top: 1px solid #d8e2dc; padding-top: 3mm; font-family: "JetBrains Mono"; font-size: 8pt; color: #0f6b56; }
.food { background: #f6f4ee; color: #0c2a23; width: 92mm; }
.food .row { display: flex; justify-content: space-between; align-items: center; padding: 2.4mm 0; border-bottom: 1px dashed #d8e2dc; font-size: 9pt; }
.food .row:last-of-type { border-bottom: 0; }
.food .status { margin-top: 3mm; display: flex; gap: 2mm; align-items: center; font-size: 8.5pt; font-weight: 700; color: #0f6b56; }
.food .bar { flex: 1; height: 2mm; background: #e3efe9; border-radius: 1mm; overflow: hidden; }
.food .bar i { display: block; width: 66%; height: 100%; background: #0f6b56; }

/* Overview */
.cmp { display: grid; grid-template-columns: 1fr 1fr; border: 1px solid #d8e2dc; border-radius: 3mm; overflow: hidden; margin: 4mm 0 7mm; }
.cmp div { padding: 4mm 5mm; }
.cmp div + div { background: #e3efe9; }
.cmp h4 { margin: 0 0 2mm; font-size: 9.5pt; }
.cmp li { list-style: none; font-size: 9.5pt; margin: 1mm 0; }
.cmp ul { margin: 0; padding: 0; }
.x { color: #c23b3b; font-weight: 700; margin-right: 1.5mm; } .ok { color: #0f6b56; font-weight: 700; margin-right: 1.5mm; }
.grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 4mm 8mm; }
.who b { display: block; font-size: 10pt; } .who span { font-size: 9pt; color: #4f6359; }
.take { display: grid; grid-template-columns: repeat(4, 1fr); gap: 4mm; margin-top: 3mm; }
.take > div { border: 1px solid #d8e2dc; border-radius: 3mm; padding: 4mm; }
.take .num { font-family: "Unbounded"; font-weight: 800; font-size: 15pt; color: #0f6b56; }
.take b { display: block; margin-top: 1mm; font-size: 10pt; } .take span { font-size: 8.5pt; color: #4f6359; }

/* Syllabus */
table.syl { width: 100%; border-collapse: collapse; margin: 3mm 0 6mm; font-size: 9.2pt; }
.syl th { background: #0c2a23; color: #fff; text-align: left; font-family: "JetBrains Mono"; font-size: 7pt; letter-spacing: .1em; padding: 2.5mm 3mm; text-transform: uppercase; }
.syl td { padding: 2.6mm 3mm; border-bottom: 1px solid #d8e2dc; vertical-align: top; }
.syl td.n { font-family: "Unbounded"; font-weight: 700; color: #0f6b56; width: 12mm; }
.syl td.t { font-weight: 700; width: 58mm; }
.tools { display: flex; gap: 2mm; flex-wrap: wrap; margin-top: 2mm; }
.tools span { font-family: "JetBrains Mono"; font-size: 7.6pt; background: #e3efe9; color: #0f6b56; border-radius: 1.5mm; padding: 1.2mm 2.5mm; }

/* Sessions */
.sess { border: 1px solid #d8e2dc; border-radius: 3.5mm; overflow: hidden; margin-bottom: 6mm; }
.sess .hd { display: flex; align-items: center; gap: 3mm; background: #0f6b56; color: #fff; padding: 3mm 4.5mm; }
.sess .badge { font-family: "Unbounded"; font-weight: 700; font-size: 9pt; background: #f2a900; color: #0c2a23; border-radius: 1.5mm; padding: .8mm 2.4mm; }
.sess .hd h3 { font-size: 11.5pt; color: #fff; flex: 1; }
.sess .hd .when { font-family: "JetBrains Mono"; font-size: 7pt; color: #cfe0da; }
.sess .bd { display: grid; grid-template-columns: 1.4fr 1fr; gap: 6mm; padding: 4.5mm; }
.lbl { font-family: "JetBrains Mono"; font-size: 6.8pt; letter-spacing: .12em; text-transform: uppercase; color: #56695f; margin-bottom: 1.5mm; }
.sess ol { margin: 0; padding-left: 5mm; font-size: 9.4pt; } .sess li { margin: .8mm 0; }
.sess .side p { font-size: 9.2pt; }
.outcome { background: #fff7e0; border: 1px solid #f2d28a; border-radius: 2mm; padding: 2.5mm 3mm; font-size: 9pt; }
.compact .sess { margin-bottom: 4mm; } .compact .sess .bd { padding: 3.5mm 4.5mm; gap: 5mm; } .compact .sess ol { font-size: 9pt; }

/* Mentor + details */
.mentor { display: flex; gap: 6mm; align-items: center; background: #0c2a23; color: #eaf3ee; border-radius: 4mm; padding: 7mm; margin-bottom: 8mm; }
.mentor .av { width: 26mm; height: 26mm; border-radius: 50%; object-fit: cover; border: 1mm solid #3fc79f; flex: none; }
.mentor h3 { color: #fff; font-size: 15pt; } .mentor .role { color: #f2a900; font-size: 9pt; margin: 1.5mm 0 2.5mm; font-weight: 700; }
.mentor p { font-size: 9.5pt; color: #cfe0da; margin: 0; }
table.det { width: 100%; border-collapse: collapse; font-size: 9.5pt; }
.det td { padding: 2.6mm 0; border-bottom: 1px solid #d8e2dc; vertical-align: top; }
.det td:first-child { font-family: "JetBrains Mono"; font-size: 7.2pt; letter-spacing: .1em; text-transform: uppercase; color: #56695f; width: 38mm; padding-top: 3.2mm; }

/* FAQ + reserve */
.faq { display: grid; grid-template-columns: 1fr 1fr; gap: 5mm 8mm; margin: 3mm 0 8mm; }
.faq b { display: block; font-size: 10pt; margin-bottom: 1mm; } .faq span { font-size: 9pt; color: #4f6359; }
.reserve { margin-top: auto; background: #0c2a23; color: #eaf3ee; border-radius: 4mm; padding: 8mm; display: flex; gap: 8mm; align-items: center; }
.reserve h3 { color: #fff; font-size: 17pt; margin: 1mm 0 3mm; }
.reserve ol { margin: 0; padding-left: 5mm; font-size: 9.5pt; color: #cfe0da; } .reserve li { margin: 1mm 0; }
.reserve .url { display: inline-block; margin-top: 4mm; font-family: "JetBrains Mono"; font-size: 8.5pt; background: rgba(255,255,255,.08); border: 1px solid #245446; border-radius: 1.5mm; padding: 1.5mm 3mm; color: #fff; }
.qr { background: #fff; border-radius: 3mm; padding: 3mm; text-align: center; flex: none; }
.qr img { width: 34mm; height: 34mm; display: block; } .qr span { font-size: 7pt; color: #4f6359; }
"""

FONTS = "".join(
    f'@font-face{{font-family:"{fam}";src:url("file://{pathlib.Path.home()}/.fonts/{f}");font-weight:100 900;}}'
    for fam, f in [("Unbounded", "Unbounded.ttf"), ("DM Sans", "DMSans.ttf"), ("JetBrains Mono", "JetBrainsMono.ttf")])


def qr_data_uri(url):
    img = qrcode.make(url, border=1)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def img_uri(path):
    p = ROOT / path
    return "data:image/jpeg;base64," + base64.b64encode(p.read_bytes()).decode() if p.exists() else ""


def visual(kind):
    if kind == "code_cart":
        return ('<div class="vis-card code"><span class="k">class</span> <span class="t">CartCubit</span> <span class="k">extends</span> <span class="t">Cubit</span>&lt;<span class="t">CartState</span>&gt; {\n'
                '  <span class="t">CartCubit</span>(<span class="k">this</span>._repo) : <span class="k">super</span>(<span class="k">const</span> <span class="t">CartState</span>());\n'
                '  <span class="k">final</span> <span class="t">CartRepository</span> _repo;\n\n'
                '  <span class="t">Future</span>&lt;<span class="k">void</span>&gt; add(<span class="t">Product</span> p) <span class="k">async</span> {\n'
                '    emit(state.copyWith(saving: <span class="k">true</span>));\n'
                '    <span class="k">await</span> _repo.add(p);\n'
                '    emit(state.copyWith(items: [...state.items, p]));\n'
                '  }\n}</div>')
    if kind == "scoreboard":
        return ('<div class="vis-card score"><div class="top"><span>HOSTEL XI</span><span>Over 12.4 of 16</span></div>'
                '<div class="big">118/3</div><div style="font-size:8.5pt;color:#33433e">Need 31 off 20 balls</div>'
                '<div class="balls"><i>1</i><i class="b4">4</i><i>wd</i><i class="bw">W</i><i class="b6">6</i></div>'
                '<div class="line">bloc.add(BallBowled(runs: 6))</div></div>')
    return ('<div class="vis-card food"><div style="font-family:Unbounded;font-weight:700;font-size:11pt;margin-bottom:2mm">Your order</div>'
            '<div class="row"><span>Paneer Butter Masala × 1</span><b>₹240</b></div>'
            '<div class="row"><span>Butter Naan × 3</span><b>₹135</b></div>'
            '<div class="row"><span>Coupon FIRST50</span><b style="color:#0f6b56">−₹50</b></div>'
            '<div class="row"><span><b>Total</b></span><b>₹325</b></div>'
            '<div class="status">On the way<div class="bar"><i></i></div>12 min</div></div>')


def page(c, section, body, n, total, cls=""):
    return (f'<section class="page {cls}"><div class="run"><span>Widgetry Academy</span><span>{e(section)}</span></div>'
            f'{body}<div class="foot"><span>{e(c["name"])}</span><span>{n:02d} / {total:02d}</span></div></section>')


def session_html(s):
    topics = "".join(f"<li>{e(t)}</li>" for t in s["topics"])
    return (f'<div class="sess"><div class="hd"><span class="badge">{e(s["n"])}</span><h3>{e(s["title"])}</h3><span class="when">{e(s["when"])}</span></div>'
            f'<div class="bd"><div><div class="lbl">Topics covered</div><ol>{topics}</ol></div>'
            f'<div class="side"><div class="lbl">Hands-on lab</div><p>{e(s["lab"])}</p>'
            f'<div class="lbl">Outcome</div><div class="outcome">{e(s["outcome"])}</div></div></div></div>')


def build(c):
    sessions = c["sessions"]
    short = len(sessions) <= 2           # a crash course: sessions go on the syllabus page itself
    per_page = 4 if len(sessions) > 6 else 3
    chunks = [] if short else [sessions[i:i + per_page] for i in range(0, len(sessions), per_page)]
    total = 3 + len(chunks) + 2
    pages = []

    # 1. Cover (no running header/footer)
    chips = "".join(f"<span>{e(x)}</span>" for x in c["chips"])
    stats = "".join(f"<div><b>{e(a)}</b><span>{e(b)}</span></div>" for a, b in c["stats"])
    pages.append(f'<section class="page cover"><div class="brand"><span class="mark"><i></i><i></i><i></i><i></i></span><div>Widgetry Academy'
                 f'<div class="tag">LEARN · BUILD · SHIP</div></div></div>'
                 f'<span class="kicker">{e(c["kicker"])}</span><h1>{c["cover_title"]}</h1>'
                 f'<p class="desc">{e(c["cover_desc"])}</p><div class="chips">{chips}</div>'
                 f'<div class="visual">{visual(c["visual"])}</div><div class="stats">{stats}</div></section>')

    # 2. Overview
    bad, good = c["compare"]
    cmp = ('<div class="cmp"><div><h4>Learning alone from tutorials</h4><ul>' + "".join(f'<li><span class="x">✕</span>{e(x)}</li>' for x in bad) +
           '</ul></div><div><h4>This course</h4><ul>' + "".join(f'<li><span class="ok">✓</span>{e(x)}</li>' for x in good) + "</ul></div></div>")
    who = "".join(f'<div class="who"><b><span class="ok">✓</span>{e(a)}</b><span>{e(b)}</span></div>' for a, b in c["who"])
    take = "".join(f'<div><div class="num">0{i + 1}</div><b>{e(a)}</b><span>{e(b)}</span></div>' for i, (a, b) in enumerate(c["take_home"]))
    pages.append(page(c, "Program overview",
                      f'<div class="eyebrow">Why this course</div><h2>{c["why_head"]}</h2><p class="muted">{e(c["why_p"])}</p>{cmp}'
                      f'<div class="eyebrow">Who it’s for</div><div class="grid2">{who}</div>'
                      f'<div class="eyebrow" style="margin-top:8mm">What you take home</div><div class="take">{take}</div>', 2, total))

    # 3. Syllabus table
    rows = "".join(f'<tr><td class="n">{e(s["n"])}</td><td class="t">{e(s["title"])}</td><td class="muted">{e(s["when"])}</td>'
                   f'<td>{e(s["outcome"])}</td></tr>' for s in sessions)
    tools = "".join(f"<span>{e(t)}</span>" for t in c["tools"])
    middle = ("".join(session_html(s) for s in sessions) if short
              else f'<table class="syl"><tr><th>#</th><th>Title</th><th>When</th><th>Outcome</th></tr>{rows}</table>')
    pages.append(page(c, "Syllabus",
                      f'<div class="eyebrow">Syllabus</div><h2>{e(c["modules_title"])}</h2><p class="muted">{e(c["modules_intro"])}</p>'
                      f'{middle}<div class="eyebrow">Tools & packages</div><div class="tools">{tools}</div>', 3, total, "compact" if short else ""))

    # 4+. Session details
    for i, chunk in enumerate(chunks):
        pages.append(page(c, "Syllabus · in detail", "".join(session_html(s) for s in chunk), 4 + i, total, "compact" if per_page > 3 else ""))

    # Mentor + program details
    photo = img_uri("public/shots/mentor-square.jpg")
    av = f'<img class="av" src="{photo}" alt="">' if photo else ""
    det = "".join(f"<tr><td>{e(a)}</td><td>{e(b)}</td></tr>" for a, b in c["details"])
    pages.append(page(c, "Your mentor · Program details",
                      f'<div class="eyebrow">Your mentor</div><div class="mentor">{av}<div><h3>{e(MENTOR["name"])}</h3>'
                      f'<div class="role">{e(MENTOR["role"])}</div><p>{e(MENTOR["bio"])}</p></div></div>'
                      f'<div class="eyebrow">Program details</div><table class="det">{det}</table>', total - 1, total))

    # FAQ + reserve
    faq = "".join(f"<div><b>{e(q)}</b><span>{e(a)}</span></div>" for q, a in c["faq"])
    pages.append(page(c, "FAQ · Enrolment",
                      f'<div class="eyebrow">Questions</div><h2>Frequently asked</h2><div class="faq">{faq}</div>'
                      f'<div class="reserve"><div style="flex:1"><div class="eyebrow" style="color:#3fc79f">Seats are limited per batch</div>'
                      f'<h3>Reserve your seat</h3><ol><li>Scan the QR code or open the link below</li><li>Sign in and fill in your details</li>'
                      f'<li>Pay securely online. Joining details come on WhatsApp</li></ol>'
                      f'<span class="url">{e(c["url"].replace("https://", ""))}</span></div>'
                      f'<div class="qr"><img src="{qr_data_uri(c["url"])}" alt="QR code"><span>Scan to enrol</span></div></div>', total, total))

    doc = (f'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{e(c["full"])} | Widgetry Academy</title>'
           f"<style>{FONTS}{CSS}</style></head><body>{''.join(pages)}</body></html>")
    OUT.mkdir(exist_ok=True)
    (OUT / f'{c["slug"]}.html').write_text(doc, encoding="utf-8")
    print(f"  ✓ {c['slug']}.html ({total} pages)")


if __name__ == "__main__":
    for c in COURSES:
        build(c)
