#!/usr/bin/env python3
"""
Job landing pages for the searches people actually type ("Flutter jobs in Bengaluru", "remote Flutter jobs").

    python3 jobs-src/landing.py

Writes public/<slug>.html for every page below, adds them to public/sitemap.xml and refreshes the
"Browse jobs" links on public/jobs.html. Each page has its own text and shows the live jobs that
match its filters (from the jobs API), linking to the normal job pages. Commit the generated files.
"""
import datetime as dt
import html
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUB = ROOT / "public"
SITE = "https://widgetryacademy.in"
TODAY = dt.date.today().isoformat()

# filters use the jobs API's names: category, type, mode, level, city
PAGES = [
    dict(slug="flutter-jobs", group="Role", label="Flutter jobs",
         title="Flutter Jobs in India (Latest Openings) | Widgetry Jobs",
         desc="Latest Flutter developer jobs in India: full-time, remote, fresher and internship roles. Every job is checked by a working mobile engineer. Free to apply.",
         h1="Flutter developer jobs in India",
         intro="Open Flutter and Dart roles across India, from internships to lead positions. Companies here build apps in Flutter for Android, iOS and the web, and most ask for state management (Bloc, Provider or Riverpod), REST APIs and Firebase.",
         filters=dict(category="flutter")),
    dict(slug="remote-flutter-jobs", group="Role", label="Remote Flutter jobs",
         title="Remote Flutter Jobs in India (Work From Home) | Widgetry",
         desc="Remote and work-from-home Flutter developer jobs open to developers anywhere in India. Checked by engineers, salary shown when available, free to apply.",
         h1="Remote Flutter jobs in India",
         intro="Flutter roles you can do from home, open to developers anywhere in India. Remote teams look closely at your GitHub and published apps, and expect clear written communication, so link both on your resume.",
         filters=dict(category="flutter", mode="remote")),
    dict(slug="flutter-jobs-for-freshers", group="Role", label="Flutter jobs for freshers",
         title="Flutter Jobs for Freshers in India | Widgetry Jobs",
         desc="Entry-level Flutter developer jobs for freshers in India. No experience needed beyond your own projects. Every job is checked, and applying is always free.",
         h1="Flutter jobs for freshers",
         intro="Entry-level Flutter roles for recent graduates and self-taught developers. Employers hiring freshers mostly judge your projects: one or two complete apps on GitHub (better still, on the Play Store) matter more than certificates.",
         filters=dict(category="flutter", level="fresher")),
    dict(slug="flutter-internships", group="Role", label="Flutter internships",
         title="Flutter Internships in India (Paid & Remote) | Widgetry",
         desc="Flutter internships in India for students and freshers, including remote and paid internships. Every listing is checked; genuine internships never ask for fees.",
         h1="Flutter internships in India",
         intro="Internships for students and freshers who want real Flutter experience. A genuine internship never asks you to pay a fee or buy a course to join; if one does, report it.",
         filters=dict(category="flutter", type="internship")),
    dict(slug="android-developer-jobs", group="Role", label="Android developer jobs",
         title="Android Developer Jobs in India (Kotlin) | Widgetry Jobs",
         desc="Android developer jobs in India for Kotlin and Java developers: Jetpack Compose, MVVM and more. Fresher to senior roles, checked by engineers. Free to apply.",
         h1="Android developer jobs in India",
         intro="Native Android roles for Kotlin (and some Java) developers. Most teams now ask for Jetpack Compose, Coroutines and Flow, MVVM or clean architecture, and dependency injection with Hilt.",
         filters=dict(category="android")),
    dict(slug="ios-developer-jobs", group="Role", label="iOS developer jobs",
         title="iOS Developer Jobs in India (Swift, SwiftUI) | Widgetry",
         desc="iOS developer jobs in India for Swift and SwiftUI developers, from junior to senior roles. Every listing is checked by a working engineer. Free to apply.",
         h1="iOS developer jobs in India",
         intro="Native iOS roles for Swift developers. Expect questions on SwiftUI and UIKit, async/await or Combine, architecture patterns like MVVM, and how you have shipped and maintained apps on the App Store.",
         filters=dict(category="ios")),
    dict(slug="react-native-jobs", group="Role", label="React Native jobs",
         title="React Native Developer Jobs in India | Widgetry Jobs",
         desc="React Native developer jobs in India: JavaScript and TypeScript mobile roles, remote and on-site. Every listing is checked by a working engineer. Free to apply.",
         h1="React Native developer jobs in India",
         intro="Cross-platform roles for React Native developers. Most teams want strong TypeScript, experience with native modules or Expo, and an understanding of performance on real devices.",
         filters=dict(category="react-native")),
]

CITIES = [
    ("bengaluru", "Bengaluru", "Bengaluru has the most mobile developer jobs in India, from product startups to large tech companies, and many hybrid roles in Koramangala, HSR Layout, Whitefield and the Outer Ring Road."),
    ("hyderabad", "Hyderabad", "Hyderabad's IT corridors around HITEC City, Madhapur and Gachibowli have a steady stream of mobile roles at product companies, global capability centres and agencies."),
    ("pune", "Pune", "Pune has a mix of product companies, IT services firms and startups hiring mobile developers, around Hinjewadi, Kharadi, Baner and Magarpatta."),
    ("mumbai", "Mumbai", "Mumbai's fintech, media and e-commerce companies hire mobile developers across the city, from Lower Parel and BKC to Andheri, Powai, Navi Mumbai and Thane."),
    ("delhi-ncr", "Delhi NCR", "Delhi NCR, including Delhi, Noida and Gurugram, is one of India's largest hubs for startups and product companies hiring Flutter, Android and iOS developers."),
    ("chennai", "Chennai", "Chennai has a growing number of mobile roles at SaaS companies, IT services firms and startups, many of them along OMR and in Guindy."),
    ("kolkata", "Kolkata", "Kolkata's mobile jobs come from IT companies in Salt Lake Sector V and New Town, agencies and a growing set of startups. Widgetry Academy is based here too."),
]
for slug, name, blurb in CITIES:
    PAGES.append(dict(
        slug=f"mobile-developer-jobs-{slug}", group="City", label=f"Jobs in {name}",
        title=f"Flutter & Mobile Developer Jobs in {name} | Widgetry",
        desc=f"Flutter, Android, iOS and React Native developer jobs in {name}. On-site and hybrid roles from fresher to senior, checked by engineers. Free to apply.",
        h1=f"Flutter and mobile developer jobs in {name}",
        intro=blurb + " Below are the open Flutter, Android, iOS and React Native roles in and around the city.",
        filters=dict(city=name)))


def esc(s):
    return html.escape(str(s), quote=True)


def jobs_link(f):
    """The same search on the main jobs page (it calls the category 'cat')."""
    q = {("cat" if k == "category" else k): v for k, v in f.items()}
    return "jobs.html" + ("?" + "&".join(f"{k}={v.replace(' ', '+')}" for k, v in q.items()) if q else "")


def page(p):
    url = f"{SITE}/{p['slug']}.html"
    ld = {"@context": "https://schema.org", "@graph": [
        {"@type": "CollectionPage", "url": url, "name": p["h1"], "description": p["desc"], "inLanguage": "en-IN",
         "isPartOf": {"@id": f"{SITE}/#website"}, "publisher": {"@id": f"{SITE}/#org"}},
        {"@type": "BreadcrumbList", "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Widgetry Jobs", "item": f"{SITE}/jobs.html"},
            {"@type": "ListItem", "position": 2, "name": p["label"], "item": url}]}]}
    roles = [x for x in PAGES if x["group"] == "Role" and x is not p]
    cities = [x for x in PAGES if x["group"] == "City" and x is not p]
    links = lambda xs: " · ".join(f'<a href="{x["slug"]}.html">{esc(x["label"])}</a>' for x in xs)
    return f"""<!doctype html>
<html lang="en-IN"><head><meta charset="utf-8"><script>(function(h){{if(h==="widgetry-academy.web.app"||h==="widgetry-academy.firebaseapp.com"||h==="www.widgetryacademy.in"){{location.replace("https://widgetryacademy.in"+location.pathname+location.search+location.hash)}}}})(location.hostname)</script>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(p["title"])}</title>
<meta name="description" content="{esc(p["desc"])}">
<link rel="canonical" href="{url}">
<meta property="og:type" content="website"><meta property="og:site_name" content="Widgetry Jobs">
<meta property="og:title" content="{esc(p["title"])}"><meta property="og:description" content="{esc(p["desc"])}">
<meta property="og:url" content="{url}"><meta property="og:image" content="{SITE}/og-image.jpg">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" type="image/svg+xml" href="favicon.svg">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Unbounded:wght@700;800&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700;9..40,800&family=JetBrains+Mono:wght@600;700&display=swap">
<link rel="stylesheet" href="jobs.css">
<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>
</head><body>
<nav class="jnav"><div class="wrap">
  <a class="brand" href="jobs.html">Widgetry<span> Jobs</span></a>
  <div class="jlinks" style="white-space:nowrap"><a href="jobs.html">All jobs</a><a href="resume-builder.html" class="hide-m">Free resume</a><a href="mock-interview.html" class="hide-m">Mock interview</a><a href="post-job.html">Post a job</a><a href="./" class="hide-m">Academy</a></div>
</div></nav>
<header class="jhero"><div class="wrap">
  <p class="eyebrow"><a href="jobs.html" style="color:inherit">Widgetry Jobs</a> › {esc(p["label"])}</p>
  <h1>{esc(p["h1"])}</h1>
  <p>{esc(p["intro"])}</p>
  <div class="trustline"><span><b id="liveCount">…</b> open now</span><span>✓ Every job reviewed</span><span>✓ Free for job seekers</span></div>
</div></header>
<main class="wrap">
  <p class="notice" style="margin:16px 0 4px"><span aria-hidden="true">🛡️</span><span><b>Widgetry never charges job seekers.</b> No genuine employer asks you to pay for a job. If anyone asks for money, don't pay. Report the job and we'll remove it.</span></p>
  <div class="results" id="results" style="margin-top:14px"><div class="skel"></div><div class="skel"></div><div class="skel"></div></div>
  <p style="text-align:center;margin:18px 0 40px"><a class="btn ghost" href="{jobs_link(p["filters"])}">Search and filter all jobs →</a></p>
</main>
<section class="wrap" style="padding:0 0 48px;max-width:860px">
  <h2 style="font-size:22px">Get hired faster</h2>
  <p>Apply on the company's own careers page, using a resume that applicant tracking systems can read. Our <a href="resume-builder.html">free ATS resume builder</a> makes one in minutes, and the <a href="talent.html">Talent Network</a> lets companies hiring mobile developers find you, only with your approval.</p>
  <p>Useful guides: <a href="blog/flutter-developer-jobs-india.html">finding Flutter jobs in India</a> · <a href="blog/flutter-developer-salary-india.html">Flutter salaries</a> · <a href="blog/flutter-interview-questions.html">interview questions</a> · <a href="blog/flutter-internship-fresher-jobs.html">fresher jobs and internships</a></p>
  <h3 style="font-size:17px;margin-top:22px">More jobs by role</h3><p>{links(roles)}</p>
  <h3 style="font-size:17px;margin-top:18px">Jobs by city</h3><p>{links(cities)}</p>
</section>
<footer class="jfoot"><div class="wrap">
  <span>© 2026 Widgetry Jobs · a part of <a href="./">Widgetry Academy</a> · Kolkata, India</span>
  <nav><a href="blog/">Blog</a><a href="jobs-terms.html">Posting rules & terms</a><a href="privacy.html">Privacy</a><a href="contact.html">Contact</a></nav>
</div></footer>
<script type="module">
import {{ $, esc, api, LABEL, salaryText, timeAgo, logo, getCategories, catName }} from "./jobs.js";
const FILTERS = {json.dumps(p["filters"])};
const cats = await getCategories();
function card(j) {{
  const where = j.mode === "remote" ? "Remote" : `${{esc(j.city || "")}} · ${{LABEL.mode[j.mode]}}`;
  return `<a class="jcard${{j.featured ? " featured" : ""}}" href="job.html?id=${{encodeURIComponent(j.id)}}">
    ${{logo(j.company.name)}}
    <div style="min-width:0">
      <h3>${{esc(j.title)}} <span class="catbadge c-${{esc(j.category)}}">${{esc(catName(cats, j.category))}}</span></h3>
      <div class="co">${{esc(j.company.name)}}${{j.company.verified ? ' <span class="badge ok" title="Verified company">✓ Verified</span>' : ""}}</div>
      <div class="meta"><span class="pill">💼 ${{LABEL.type[j.type]}}</span><span class="pill">📍 ${{where}}</span><span class="pill">🎯 ${{LABEL.level[j.level]}}</span></div>
      ${{j.skills.length ? `<div class="tags">${{j.skills.slice(0, 6).map(s => `<span class="tag">${{esc(s)}}</span>`).join("")}}</div>` : ""}}
    </div>
    <div class="side">
      ${{j.featured ? '<span class="badge feat">★ Featured</span>' : ""}}
      ${{j.salary ? `<span class="sal">${{esc(salaryText(j.salary, true))}}</span>` : ""}}
      <span class="when">${{timeAgo(j.postedAt)}}</span>
    </div></a>`;
}}
try {{
  const r = await api("/jobs?" + new URLSearchParams({{ ...FILTERS, pageSize: 50 }}));
  $("liveCount").textContent = r.total;
  $("results").innerHTML = r.items.length ? r.items.map(card).join("")
    : `<div class="empty"><h3 style="font-family:var(--body);font-size:18px">No open jobs here right now</h3><p style="margin:6px 0 14px">New roles are added every week. Browse all mobile jobs, or join the Talent Network so companies can find you.</p><a class="btn" href="jobs.html">See all jobs</a></div>`;
}} catch (e) {{
  $("liveCount").textContent = "–";
  $("results").innerHTML = `<div class="empty"><p>Couldn't load jobs right now. <a href="{jobs_link(p["filters"])}">Open the jobs page</a>.</p></div>`;
}}
</script>
</body></html>
"""


def browse_block():
    roles = [x for x in PAGES if x["group"] == "Role"]
    cities = [x for x in PAGES if x["group"] == "City"]
    a = lambda xs: " · ".join(f'<a href="{x["slug"]}.html">{esc(x["label"])}</a>' for x in xs)
    return f'<!-- browse:start --><p style="margin-top:22px"><b>Browse jobs:</b> {a(roles)}</p><p><b>By city:</b> {a(cities)}</p><!-- browse:end -->'


def main():
    for p in PAGES:
        assert len(p["title"]) <= 62, (p["slug"], len(p["title"]))
        assert len(p["desc"]) <= 165, (p["slug"], len(p["desc"]))
        (PUB / f"{p['slug']}.html").write_text(page(p), encoding="utf-8")
        print("  ✓", p["slug"] + ".html")
    # Links from the main jobs page, so Google finds every landing page
    jobs = (PUB / "jobs.html").read_text(encoding="utf-8")
    block = browse_block()
    if "<!-- browse:start -->" in jobs:
        jobs = re.sub(r"<!-- browse:start -->.*?<!-- browse:end -->", lambda _: block, jobs, flags=re.S)
    else:
        anchor = '  <p style="margin-top:22px">Read more:'
        assert anchor in jobs, "jobs.html: couldn't find where to add the browse links"
        jobs = jobs.replace(anchor, "  " + block + "\n" + anchor, 1)
    (PUB / "jobs.html").write_text(jobs, encoding="utf-8")
    # Sitemap
    sm = (PUB / "sitemap.xml").read_text(encoding="utf-8")
    sm = re.sub(r"\s*<!-- job pages:start -->.*?<!-- job pages:end -->", "", sm, flags=re.S)
    rows = "".join(f'\n  <url><loc>{SITE}/{p["slug"]}.html</loc><lastmod>{TODAY}</lastmod><changefreq>daily</changefreq><priority>0.8</priority></url>' for p in PAGES)
    sm = sm.replace("</urlset>", f"  <!-- job pages:start -->{rows}\n  <!-- job pages:end -->\n</urlset>")
    (PUB / "sitemap.xml").write_text(sm, encoding="utf-8")
    print(f"Built {len(PAGES)} job pages, links on jobs.html and the sitemap.")


if __name__ == "__main__":
    main()
