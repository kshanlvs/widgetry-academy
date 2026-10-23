# Widgetry Jobs API

Flutter-only jobs board and Talent Network for widgetryacademy.in.
Node.js 22 + TypeScript + Express, **MySQL 8**. Sign-in reuses the website's Firebase Auth (Google or email); the API verifies the Firebase ID token.

```
Academy website (Firebase Hosting, free Spark plan)
  jobs.html, job.html, post-job.html, talent.html, admin.html
   │  https://api.widgetryacademy.in/api/...   (CORS: only the academy's domains)
   ▼
Railway (Singapore): widgetry-jobs-api ──▶ TiDB Cloud Starter, Singapore (MySQL-compatible)
                                       └──▶ Firebase Auth token check (free, no Blaze needed)
```

The academy stays entirely on Firebase (Spark plan). Widgetry Jobs runs on its own host and only *checks* Firebase sign-in tokens, which is free.

## What it does

| Area | Endpoints |
|---|---|
| Public | `GET /api/jobs` (search `q`, filters `category` `type` `mode` `level` `city` `skill`, paging), `GET /api/jobs/:id`, `GET /api/meta`, `POST /api/jobs/:id/report` |
| Employers (signed in) | `POST /api/jobs` (goes to review), `GET /api/my/jobs` |
| Job seekers (signed in) | `GET/PUT/DELETE /api/talent/me` |
| Course payments (app) | `GET /api/payments/plans`, `POST /api/payments/order`, `POST /api/payments/verify`, `POST /api/payments/webhook` (Razorpay), `GET /api/payments/mine`. See mobile/README.md → Payments |
| Admin (UID in `ADMIN_UIDS`) | `GET /api/admin/stats`, `GET/POST /api/admin/jobs`, `PUT/PATCH/DELETE /api/admin/jobs/:id`, `GET/PATCH /api/admin/reports`, `GET/PATCH /api/admin/candidates` |

Safety built in: every employer post is reviewed before going live; posts that ask candidates for fees are refused; 3 reports from different people send a job back to review; jobs expire after 30 days; contact emails and talent profiles are never public; rate limits on posting and reporting; only `https://` links accepted; all queries parameterised.

## Job categories

Jobs and seekers have categories (Flutter, Android, iOS). They live in the `job_categories` table, and every page reads them from `GET /api/meta`, so adding one needs no code change. Add a new migration file, for example `migrations/008_react_native.sql`:

```sql
INSERT INTO job_categories (slug, name, sort_order, suggested_skills)
VALUES ('react-native', 'React Native', 40, '["React Native","JavaScript","TypeScript","Redux","REST APIs","Testing","Git"]');
```

Push it; the server applies it on start. To hide a category, set `active = 0`. Existing jobs keep their category.

## AI tutor chat

Students ask Flutter questions and Claude answers (`src/chat.ts`, `src/routes/chat.ts`, tables from `migrations/017_chat.sql`).

| Endpoint | Does |
|---|---|
| `POST /api/chat` `{ conversationId?, message }` | Answers a question. Returns `{ conversationId, reply, truncated }` |
| `GET /api/chat/conversations` | The user's past chats, newest first |
| `GET /api/chat/conversations/:id/messages` | All messages of one chat |

- Signed-in users only; each user sees only their own chats.
- The server owns the history: the app sends only the new message, the API resends the latest `CHAT_HISTORY_LIMIT` (20) messages to Claude.
- Limits: `CHAT_DAILY_LIMIT` (30) questions per user per 24 hours, `CHAT_MAX_TOKENS` (800) per reply. Model: `CHAT_MODEL` (default `claude-haiku-5-5`).
- Token counts are saved on each reply, so cost per user can be checked in `chat_messages`.

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

`ALLOW_DEV_AUTH` accepts fake tokens like `Bearer dev:<uid>:<email>` for testing. It is refused automatically on the live host and when `NODE_ENV=production`.

## Hosting

| Piece | Where | Cost |
|---|---|---|
| Jobs API | Railway, Hobby plan, region Southeast Asia (Singapore), always on, auto-restart | $5/month, which includes $5 of usage; this small server fits inside it |
| Database | TiDB Cloud Starter, Singapore, port 4000, TLS | Free quota; set a spending limit (e.g. ₹500) so it never slows down on busy days |
| Pages | Firebase Hosting (same as the academy) | Free |

## Go live (one-time setup)

1. **TiDB Cloud** (tidbcloud.com) → create a **Starter** cluster in **Singapore**, set a monthly spending limit. Connect → note **host**, **user** (`xxxx.root`), **password**.
2. **Railway** (railway.com) → sign in with GitHub → Hobby plan → New Project → Deploy from GitHub repo → `kshanlvs/widgetry-academy`.
   - Service Settings → **Root Directory** `jobs-api`; **Branch** `main` (or `widgetry-jobs` to test first); **Region** Southeast Asia (Singapore).
   - **Variables**: `DB_HOST`, `DB_PORT=4000`, `DB_USER`, `DB_PASSWORD`, `DB_NAME=widgetry_jobs`, `DB_SSL=1`, `NODE_ENV=production`, `MIGRATE_ON_START=1`, and for app push notifications and payments `FIREBASE_SERVICE_ACCOUNT` (the whole JSON key from Firebase → Project settings → Service accounts → Generate new private key). For in-app course payments also add `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` and `RAZORPAY_WEBHOOK_SECRET`. For the AI tutor chat add `ANTHROPIC_API_KEY` (from console.anthropic.com; set a monthly spend limit there).
   - Settings → Networking → **Custom Domain** `api.widgetryacademy.in`, port 8080. Railway shows a CNAME (and a TXT) record.
3. **GoDaddy DNS** → add the records Railway shows (CNAME `api` → `xxxx.up.railway.app`).
4. Check `https://api.widgetryacademy.in/api/health` returns `{"ok":true}`, then merge `widgetry-jobs` into `main`.

Railway redeploys automatically on every push that touches `jobs-api/` (it builds from the `Dockerfile`; set Deploy → Healthcheck Path to `/api/health`). The server address used by the pages is in `public/jobs-api-url.js`.

> Until the API is live the jobs pages show "Can't reach the jobs server"; the academy is unaffected.
