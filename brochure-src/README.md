# Course brochures

Each course's PDF brochure (syllabus) is built from `courses.py`, in the same style as the Flutter in 10 Days brochure.

To change a brochure (topics, price, dates…):

1. Edit the course in `courses.py`. To add a new course, copy one entry and change it.
2. Build the pages: `python3 brochure-src/build.py` (needs `pip install qrcode pillow`).
3. Print them to PDF: `node brochure-src/print.cjs` (needs Playwright with Chromium, and the Unbounded, DM Sans and JetBrains Mono fonts installed).
4. The PDFs land in `public/brochures/<slug>.pdf`. Commit and push to publish them.

Where the brochure appears:

- **Website course pages and homepage cards:** "Download syllabus (PDF)". For homepage cards, set the PDF in Admin → Courses → "Syllabus / brochure PDF" (for example `brochures/my-course.pdf`).
- **App:** "Download syllabus" on the course screen. Short courses use Admin → Courses → Short courses → "Syllabus / brochure PDF".
