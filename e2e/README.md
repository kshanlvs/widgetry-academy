# Website end-to-end tests

Real browser tests (Playwright) of the website against the real API and a test database.
GitHub Actions runs them on every push (`.github/workflows/ci.yml`); the website only deploys when they pass.

What they cover:

- **Every page** (desktop and phone): opens without script errors, its files load, internal links work, nothing scrolls sideways on a phone.
- **Jobs**: list, featured first, search, filters, categories, job page with apply link and Google for Jobs data, city and role pages.
- **Employers**: post a job; it waits for review; after approval it is live.
- **Resume**: ATS checker upload; build signed out by importing a Word file, preview with ATS score, sign in and it saves;
  signed-in preview, PDF and Word downloads, "Fit more" density; my profile page.
- **Blog**: index lists every post, structured data is valid JSON, canonical URLs, the app's feed.
- **Phone menus** on the home and jobs pages.

Sign-in is faked: the pages load Firebase from Google's CDN, and the tests serve a small stand-in that signs in a test user.
The API accepts those test users only with `ALLOW_DEV_AUTH=1`, which is never on in production.

## Run locally

Needs Node 22 and MySQL with an empty database (default `widgetry_e2e`, user `jobs` / `devpass`).

```bash
cd e2e
npm ci
npx playwright install chromium
DB_PORT=3306 npm test             # all tests
npx playwright test tests/jobs.spec.ts   # one file
npm run report                    # open the HTML report
```

Set `CHROMIUM_PATH` to a Chromium binary to include the PDF download test (the API makes PDFs with it).
