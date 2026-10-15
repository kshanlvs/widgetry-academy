# Widgetry Jobs API

Flutter-only jobs board and Talent Network for widgetryacademy.in.
Node.js 22 + TypeScript + Express, **MySQL 8**. Sign-in reuses the website's Firebase Auth (Google or email); the API verifies the Firebase ID token.

```
Browser (jobs.html, job.html, post-job.html, talent.html, admin.html)
   │  /api/...   (same domain: Firebase Hosting rewrite)
   ▼
Cloud Run: widgetry-jobs-api ──▶ MySQL (Cloud SQL or any MySQL 8 host)
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

## Go live (one-time setup)

### Option A: Cloud SQL (everything inside Google, paid)
1. Firebase console → switch the project to the **Blaze** plan.
2. Google Cloud console → **SQL** → Create instance → **MySQL 8.0**, region **asia-south1 (Mumbai)**, smallest machine (Enterprise edition, shared core), instance ID `widgetry-jobs`.
3. In the instance: **Databases** → create `widgetry_jobs`; **Users** → create user `jobs` with a strong password.
4. **Secret Manager** → create secrets `jobs-db-password` (that password) and `jobs-hash-salt` (any long random text).
5. **IAM** → create a service account for GitHub deploys with roles: Cloud Run Admin, Cloud Build Editor, Service Account User, Artifact Registry Admin, Storage Admin, Cloud SQL Client, Secret Manager Secret Accessor. Create a JSON key and add it to GitHub → Settings → Secrets → `GCP_SA_KEY`.
6. GitHub → Actions → **Deploy jobs API** → Run workflow. The first run also creates the tables.
7. Merge the `widgetry-jobs` branch into `main`. The Hosting rewrite in `firebase.json` connects `/api/**` to the service.

### Option B: free MySQL-compatible host (TiDB Cloud Serverless, Aiven free MySQL)
Create the database there, then deploy to Cloud Run as above but set `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_NAME`, `DB_SSL=1` instead of `DB_SOCKET` and drop `--add-cloudsql-instances`. Cloud Run itself still needs the Blaze plan, but stays within the free tier at small traffic.

> Merge to `main` only **after** the Cloud Run service exists: the Hosting deploy fails if the `/api/**` rewrite points to a service that isn't there yet.
