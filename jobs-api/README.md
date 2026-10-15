# Widgetry Jobs API

Flutter-only jobs board and Talent Network for widgetryacademy.in.
Node.js 22 + TypeScript + Express, **MySQL 8**. Sign-in reuses the website's Firebase Auth (Google or email); the API verifies the Firebase ID token.

```
Browser (jobs.html, job.html, post-job.html, talent.html, admin.html)
   │  /api/...   (same domain: Firebase Hosting rewrite)
   ▼
Cloud Run: widgetry-jobs-api ──▶ TiDB Cloud Starter (MySQL-compatible) or any MySQL 8
                             └──▶ Firebase Auth (token check, admin UID)
```

## What it does

| Area | Endpoints |
|---|---|
| Public | `GET /api/jobs` (search `q`, filters `type` `mode` `level` `city` `skill`, paging), `GET /api/jobs/:id`, `GET /api/meta`, `POST /api/jobs/:id/report` |
| Employers (signed in) | `POST /api/jobs` (goes to review), `GET /api/my/jobs` |
| Job seekers (signed in) | `GET/PUT/DELETE /api/talent/me` |
| Admin (UID in `ADMIN_UIDS`) | `GET /api/admin/stats`, `GET/POST /api/admin/jobs`, `PUT/PATCH/DELETE /api/admin/jobs/:id`, `GET/PATCH /api/admin/reports`, `GET/PATCH /api/admin/candidates` |

Safety built in: every employer post is reviewed before going live; posts that ask candidates for fees are refused; 3 reports from different people send a job back to review; jobs expire after 30 days; contact emails and talent profiles are never public; rate limits on posting and reporting; only `https://` links accepted; all queries parameterised.

## Run locally

```bash
cd jobs-api
npm install
cp .env.example .env          # fill DB_* for your local MySQL 8
npm run migrate:dev
ALLOW_DEV_AUTH=1 SERVE_STATIC_DIR=../public npm run dev
# open http://localhost:8080/jobs.html
```

Tests (need a local MySQL 8 database):

```bash
DB_PORT=3306 DB_PASSWORD=... ALLOW_DEV_AUTH=1 npm test
```

`ALLOW_DEV_AUTH` accepts fake tokens like `Bearer dev:<uid>:<email>` for testing. It is refused automatically on Cloud Run and when `NODE_ENV=production`.

## Hosting (pay only for use)

| Piece | Where | Cost when nobody visits |
|---|---|---|
| API | Cloud Run, `asia-southeast1` (Singapore), min instances 0, max 2 | ₹0 (scales to zero; 2M requests/month free) |
| Database | TiDB Cloud **Starter** (MySQL-compatible), Singapore, port 4000, TLS | ₹0 (free quota: 5 GiB rows + 50M request units/month; spending limit caps anything above) |
| Images | Artifact Registry | a few rupees/month for stored images at most |

The first request after an idle period takes ~1–2 s (cold start); later ones are fast.

## Go live (one-time setup)

1. **Firebase → Blaze plan** (needed for Cloud Run). Then Google Cloud console → Billing → **Budgets & alerts** → budget ₹500/month with email alerts.
2. **TiDB Cloud** (tidbcloud.com) → create a **Starter** cluster in **Singapore (ap-southeast-1)**, set a monthly spending limit (₹0 = free quota only). Connect → "General" → note **host**, **user** (looks like `xxxx.root`) and generate a **password**.
3. **GitHub → repo Settings → Secrets and variables → Actions** → add `JOBS_DB_HOST`, `JOBS_DB_USER`, `JOBS_DB_PASSWORD`.
4. **Google Cloud console → IAM** → on `firebase-adminsdk-fbsvc@flutter-in-10-days.iam.gserviceaccount.com` (already the `FIREBASE_SERVICE_ACCOUNT` secret) add roles: Cloud Run Admin, Artifact Registry Administrator, Service Account User, Service Usage Admin.
5. GitHub → Actions → **Deploy jobs API** → Run workflow (or push to `jobs-api/`). It builds, deploys and creates the tables on first start, then checks `/api/health`.
6. Merge `widgetry-jobs` into `main`. The Hosting rewrite in `firebase.json` connects `/api/**` to the service.

Without the secrets the workflow skips itself harmlessly.

> Merge to `main` only **after** the Cloud Run service exists: the Hosting deploy fails if the `/api/**` rewrite points to a service that isn't there yet.
