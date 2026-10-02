# AI Teaching Coach: installation and deployment guide

This guide takes you from two GitHub repositories to a running AI Teaching Coach that you own and operate: backend, database, file storage, the teacher app, and the monitoring dashboard. It assumes general software-engineering experience but no prior knowledge of this project.

- [1. What you are deploying](#1-what-you-are-deploying)
- [2. Prerequisites](#2-prerequisites)
- [3. Get the code](#3-get-the-code)
- [4. Configure](#4-configure)
- [5. Start the backend stack](#5-start-the-backend-stack)
- [6. Create the first accounts](#6-create-the-first-accounts)
- [7. Build and run the app (Flutter)](#7-build-and-run-the-app-flutter)
- [8. Run the monitoring dashboard](#8-run-the-monitoring-dashboard)
- [9. Deploying on a server](#9-deploying-on-a-server)
- [10. Day-to-day operations](#10-day-to-day-operations)
- [11. Configuration reference](#11-configuration-reference)
- [12. Troubleshooting](#12-troubleshooting)
- [13. Code map](#13-code-map)
- [14. Known limitations](#14-known-limitations)

---

## 1. What you are deploying

Teachers (or pedagogy coordinators observing them) record a lesson in the app. The backend stores the audio, sends it to Google Gemini, and gets back an analysis against the World Bank's **TEACH** classroom-observation framework: scores and evidence for each TEACH element, strengths, and recommendations. Users can then chat with an AI coach about the lesson. A separate web dashboard lets programme staff monitor usage across schools and countries and export the data.

```
 ┌───────────────────────────┐        ┌───────────────────────────────┐
 │  Flutter app              │        │  Monitoring dashboard         │
 │  Android · iOS · web ·    │        │  Next.js, in its own repo     │
 │  Windows (teachers and    │        │  (admins and viewers)         │
 │  coordinators)            │        │                               │
 └─────────────┬─────────────┘        └───────────────┬───────────────┘
               │  HTTPS/HTTP  /api/v1/*               │  /api/v1/admin/*
               └──────────────────┬───────────────────┘
                     ┌────────────▼────────────┐
                     │  Backend: Go (Gin), :8080│──────► Google Gemini API
                     └──────┬───────────┬──────┘        (gemini-2.5-flash)
                            │           │
               ┌────────────▼──┐   ┌────▼────────────────┐
               │ PostgreSQL 15 │   │ MinIO (S3-compatible)│
               │ users, lessons│   │ audio recordings     │
               │ analyses, chat│   │                      │
               └───────────────┘   └──────────────────────┘
```

| Component | Repository | Tech | How it runs |
|---|---|---|---|
| Backend API | [`tecktal/ai_coach_wb_prototype`](https://github.com/tecktal/ai_coach_wb_prototype), `backend/` | Go 1.24, Gin | Docker Compose |
| Database | (image) | PostgreSQL 15 | Docker Compose |
| Audio storage | (image) | MinIO | Docker Compose |
| Teacher app | same repo, `flutter_app/` | Flutter 3.35 / Dart 3 | Built per platform (APK, web, desktop) |
| Monitoring dashboard | [`tecktal/ai_coach_monitoring_dashboard`](https://github.com/tecktal/ai_coach_monitoring_dashboard) | Next.js 16, React 19 | Docker Compose profile, or `npm` |

The database schema is created and migrated automatically every time the backend starts. There are no migration commands to run.

## 2. Prerequisites

| You need | For | Notes |
|---|---|---|
| **Docker** with Compose v2 (Docker Desktop on Windows/macOS, Docker Engine on Linux) | Backend stack and dashboard | Check with `docker compose version` |
| **Git** | Cloning | |
| **A Google Gemini API key** | Lesson analysis and chat | Free key at <https://aistudio.google.com/apikey>. Analysis of real lessons uses paid quota at scale; see Google's pricing. |
| **Flutter SDK 3.35+** | Building the app | <https://docs.flutter.dev/get-started/install>. Android builds also need Android Studio (SDK and an emulator). iOS builds need a Mac with Xcode. |
| Node.js 20+ | Dashboard, only if you run it outside Docker | |
| Go 1.24+ | Backend, only if you run it outside Docker or run its tests | |

Hardware: the stack is light. 2 CPU cores and 4 GB RAM are enough for a pilot; disk use is dominated by audio recordings (the app records AAC at 128 kbps, about 58 MB per lesson hour).

## 3. Get the code

Clone the main repository, then clone the dashboard **inside it** as `monitoring-dashboard/`. The main repository ignores that folder, and Docker Compose builds the dashboard from it.

```bash
git clone https://github.com/tecktal/ai_coach_wb_prototype.git ai_coach
cd ai_coach
git clone https://github.com/tecktal/ai_coach_monitoring_dashboard.git monitoring-dashboard
```

If you plan to change the code, fork both repositories first and clone your forks instead. On Windows, clone into a short path such as `C:\src\ai_coach`; deep folders hit the 260-character path limit (see section 12).

## 4. Configure

All backend and stack settings live in one file, `.env`, at the repository root:

```bash
cp .env.example .env        # Windows PowerShell:  Copy-Item .env.example .env
```

Edit `.env`. Two values are required:

| Setting | What to put |
|---|---|
| `GEMINI_API_KEY` | Your Gemini key |
| `JWT_SECRET` | A long random string, e.g. the output of `openssl rand -hex 32` |

Everything else has a working default for a single machine. Before any shared or server deployment, also change `POSTGRES_PASSWORD`, `S3_ACCESS_KEY` and `S3_SECRET_KEY` (the MinIO secret must be at least 8 characters). Section 11 describes every setting.

> `.env` holds secrets and is gitignored. Never commit it. Share it through a password manager or your platform's secret store.

## 5. Start the backend stack

```bash
docker compose up -d --build
```

The first build downloads base images and Go modules and takes a few minutes. Compose starts PostgreSQL and MinIO, waits until both report healthy, then starts the backend, which creates the database tables and the `ai-coach-recordings` storage bucket.

Check it:

```bash
docker compose ps                                # all services "Up" / "healthy"
curl http://localhost:8080/api/v1/health         # {"status":"healthy",...}
docker compose logs -f backend                   # follow the backend log
```

| URL | What |
|---|---|
| <http://localhost:8080/api/v1/health> | Backend health check |
| <http://localhost:9001> | MinIO console (log in with `S3_ACCESS_KEY` / `S3_SECRET_KEY`) |

PostgreSQL (`localhost:5432`) and MinIO (`localhost:9000`, `:9001`) are bound to `127.0.0.1` only. They are reachable from the host machine, not from the network.

## 6. Create the first accounts

**Teachers and coordinators register themselves in the app.** At sign-up they choose a role:

| Role | Who | Gets |
|---|---|---|
| `teacher` | A teacher recording their own lessons | Feedback addressed to them ("you") |
| `coordinator` | A pedagogy coordinator observing other teachers | Feedback written for the coordinator, plus a step-by-step coaching-conversation guide for each TEACH element |
| `viewer` | Programme staff | Read-only access to the monitoring dashboard |
| `admin` | Programme administrators | Dashboard access, plus managing other users' roles |

Users can pick only `teacher` or `coordinator` themselves. Dashboard roles are granted by an admin, and the first admin is created like this:

1. Register an account in the app (or via the API, below) **with an email address**.
2. Put that email in `.env` as `ADMIN_BOOTSTRAP_EMAIL=you@example.org`.
3. Recreate the backend so it reads the new `.env`: `docker compose up -d --force-recreate backend`. (A plain `restart` keeps the old environment.) The promotion runs at startup, so the account must exist first.
4. Sign in to the dashboard with that account's **username** and password. From its **Users** page, promote further users to `viewer` or `admin`.

To create the admin account without the app, call the API directly:

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","email":"you@example.org","password":"a-strong-password",
       "first_name":"Ada","last_name":"Admin","country":"Senegal"}'
```

**Email.** Without `RESEND_API_KEY`, the backend sends no emails. It prints them to its log instead, verification codes included:

```bash
docker compose logs backend | grep 'class="code"'     # verification codes
docker compose logs backend | grep -o 'token=[^"<]*'   # password-reset tokens
```

An unverified email does not block sign-in; the app shows a reminder banner. To send real emails, create an account at <https://resend.com>, verify a sending domain, then set `RESEND_API_KEY` and `RESEND_FROM_EMAIL`.

## 7. Build and run the app (Flutter)

The app's backend address is set **at build time** with `--dart-define=API_BASE_URL=...` (no trailing slash, no `/api/v1`). If you leave it out, the app uses `http://localhost:8080`, which only works when the app runs on the same machine as the backend (web or desktop).

Which address to use:

| Where the app runs | `API_BASE_URL` |
|---|---|
| Chrome or Windows desktop, on the backend machine | `http://localhost:8080` (the default) |
| Android emulator, backend on the same PC | `http://10.0.2.2:8080` (the emulator's alias for the host) |
| Physical phone on the same Wi-Fi/LAN | `http://<backend machine's LAN IP>:8080`, e.g. `http://192.168.1.50:8080` |
| Any device, server deployment | `https://api.your-domain.org` (see section 9) |

Find the LAN IP with `ipconfig` (Windows) or `ip addr` (Linux). Allow inbound TCP 8080 in the host firewall.

```bash
cd flutter_app
flutter pub get

# Develop / try it
flutter run -d chrome
flutter run -d windows
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
flutter run                  --dart-define=API_BASE_URL=http://192.168.1.50:8080   # phone over USB

# Android APK to install on phones
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.50:8080
#   → build/app/outputs/flutter-apk/app-release.apk

# Web app (static files, serve with any web server, e.g. behind the reverse proxy in section 9)
flutter build web --release --dart-define=API_BASE_URL=https://api.your-domain.org
#   → build/web/
```

**Android signing.** Without your own keystore, release APKs are signed with Flutter's debug key. They install fine on phones but cannot be published to Google Play. To publish, [create a keystore](https://docs.flutter.dev/deployment/android#sign-the-app) and add `flutter_app/android/key.properties` (gitignored) with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. The build picks it up automatically. To publish under your own organisation, also change `applicationId` (currently `com.tecktal.ai_coach`) in `android/app/build.gradle.kts`.

**Plain HTTP.** Android is configured to allow `http://` backends so LAN deployments work. iOS allows plain HTTP only to local-network hosts; internet-facing backends must use HTTPS.

## 8. Run the monitoring dashboard

**With Docker (recommended).** With the dashboard cloned into `monitoring-dashboard/` (section 3):

```bash
docker compose --profile dashboard up -d --build
```

Open <http://localhost:3000> and sign in with an `admin` or `viewer` account.

The backend address is compiled into the dashboard at build time from `DASHBOARD_API_BASE_URL` in `.env`. It is the address **the user's browser** uses, so `http://localhost:8080` only works when the browser runs on the same machine. If people open the dashboard from other computers, set it to the backend's reachable address (e.g. `https://api.your-domain.org`) and rebuild with the command above.

**Without Docker** (for dashboard development):

```bash
cd monitoring-dashboard
npm install
cp .env.example .env.local        # NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
npm run dev                       # http://localhost:3000
```

Dashboard pages: **Overview** (headline counts), **Lessons** (filterable log of every recording, with the full analysis, audio player, manual scoring and Excel export), **Usage** (teachers per school), **Teachers** (roster), and **Users** (admin only, role management).

## 9. Deploying on a server

Sections 3–8 work unchanged on a Linux server; follow them there. To make the deployment safe for real users and data:

1. **Use HTTPS.** Put a reverse proxy in front of the backend (and the dashboard) with a TLS certificate. A minimal [Caddy](https://caddyserver.com) setup, with certificates obtained automatically:

   ```caddy
   api.your-domain.org {
       request_body {
           max_size 250MB            # lesson recordings can be large
       }
       reverse_proxy localhost:8080 {
           transport http {
               read_timeout  10m     # analysis can take several minutes
               write_timeout 10m
           }
       }
   }

   dashboard.your-domain.org {
       reverse_proxy localhost:3000
   }
   ```

   For nginx, set `client_max_body_size 250m;` and `proxy_read_timeout 600s;`. Then build the app and dashboard with the `https://` addresses (`API_BASE_URL`, `DASHBOARD_API_BASE_URL`).

2. **Restrict browser access.** Set `CORS_ORIGINS=https://dashboard.your-domain.org` (comma-separate several origins; add the web app's origin if you host it). This does not affect the mobile apps.

3. **Change every default secret** in `.env`: `JWT_SECRET`, `POSTGRES_PASSWORD`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`. Changing `JWT_SECRET` later signs everyone out. Changing the Postgres password after the first start requires changing it inside the database too, because the volume keeps the original.

4. **Firewall.** Expose only 80/443 (the proxy). With a proxy in place you can also bind the backend and dashboard to localhost: `BACKEND_HOST_PORT=127.0.0.1:8080` and `DASHBOARD_HOST_PORT=127.0.0.1:3000` in `.env`.

5. **Back up** the database and recordings (section 10). They are the only state.

6. **Data protection.** The system stores teacher names, schools and classroom audio, and sends audio to Google's Gemini API for analysis. Check this against your data-protection obligations and consent process. `METADATA.md` lists exactly what is collected.

## 10. Day-to-day operations

```bash
docker compose ps                         # status
docker compose logs -f backend            # logs (also: ai_coach_db, minio, dashboard)
docker compose restart backend            # restart one service
docker compose down                       # stop everything (data is kept in volumes)
```

**Update to a new version of the code:**

```bash
git pull
git -C monitoring-dashboard pull
docker compose --profile dashboard up -d --build
```

Schema changes apply automatically when the new backend starts. Rebuild and redistribute the app when `flutter_app/` changes.

**Back up:**

```bash
# Database (--clean lets the dump restore over an existing schema)
docker compose exec -T ai_coach_db pg_dump -U postgres --clean --if-exists ai_coach > backup_$(date +%F).sql
# Recordings (MinIO data volume)
docker run --rm -v ai_coach_minio_data:/data -v "$PWD":/backup alpine \
  tar czf /backup/recordings_$(date +%F).tgz -C /data .
```

The volume names are prefixed with the Compose project name, which defaults to the folder name. Check yours with `docker volume ls`.

**Restore the database:**

```bash
docker compose exec -T ai_coach_db psql -U postgres ai_coach < backup_YYYY-MM-DD.sql
```

**Wipe everything and start fresh** (deletes all users, lessons and recordings):

```bash
docker compose down -v
```

## 11. Configuration reference

Root `.env`, read by `docker-compose.yml`:

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `GEMINI_API_KEY` | yes | none | Google Gemini key used for analysis, chat and coaching scripts |
| `JWT_SECRET` | yes | none | Secret that signs login tokens |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | yes | `postgres` / `postgres` / `ai_coach` | Database credentials, used by both the DB container and the backend |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | yes | `minioadmin` / `minioadmin` | MinIO root credentials, used by both MinIO and the backend |
| `ADMIN_BOOTSTRAP_EMAIL` | no | empty | Account promoted to `admin` at backend startup |
| `RESEND_API_KEY` / `RESEND_FROM_EMAIL` | no | empty | Real email delivery via Resend; when empty, emails go to the backend log |
| `CORS_ORIGINS` | no | `*` | Browser origins allowed to call the API, comma-separated |
| `DASHBOARD_API_BASE_URL` | no | `http://localhost:8080` | Backend URL compiled into the dashboard |
| `GIN_MODE` | no | `release` | `debug` for verbose backend logging |
| `S3_BUCKET` | no | `ai-coach-recordings` | Bucket name; created automatically |
| `BACKEND_HOST_PORT`, `DASHBOARD_HOST_PORT` | no | `8080`, `3000` | Host ports; may include an address, e.g. `127.0.0.1:8080` |
| `POSTGRES_HOST_PORT`, `MINIO_API_HOST_PORT`, `MINIO_CONSOLE_HOST_PORT` | no | `5432`, `9000`, `9001` | Host ports (always bound to 127.0.0.1) |

Build-time settings for the clients:

| Where | Setting | Set with |
|---|---|---|
| Flutter app | `API_BASE_URL` | `--dart-define=API_BASE_URL=...` on `flutter run` / `flutter build` |
| Dashboard | `NEXT_PUBLIC_API_BASE_URL` | `DASHBOARD_API_BASE_URL` in `.env` (Docker), or `.env.local` (npm) |

Running the backend **outside Docker** (e.g. `go run ./cmd/server` for development): it reads `backend/.env`. Start from `backend/.env.example`, which also documents the optional Google Drive copy of recordings (`GOOGLE_SERVICE_ACCOUNT_KEY_PATH`, `GOOGLE_DRIVE_FOLDER_ID`).

## 12. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Windows: clone reports `Filename too long`, or files such as `flutter_app/pubspec.yaml` are missing | Windows' 260-character path limit (some repo paths are ~95 characters). Clone into a short folder such as `C:\src\ai_coach`, or run `git config --global core.longpaths true` and clone again. |
| `docker compose up` fails with `TLS handshake timeout` or `failed to resolve source metadata` | Network trouble reaching Docker Hub. Retry; `docker pull golang:1.24-alpine` first can help. |
| Backend keeps restarting | `docker compose logs backend`. Usually a missing required variable (`GEMINI_API_KEY is required`, `JWT_SECRET is required`) or wrong DB credentials. |
| `password authentication failed` after changing `POSTGRES_PASSWORD` | The database volume keeps the password from its first start. Change it inside Postgres (`ALTER USER postgres PASSWORD '...'`) or, on a fresh install, `docker compose down -v`. |
| Port already in use | Another service uses 8080/5432/9000/9001/3000. Set the matching `*_HOST_PORT` in `.env`. |
| App shows a connection error | Wrong `API_BASE_URL` for that device (see the table in section 7), the host firewall blocks 8080, or the phone isn't on the same network. Test by opening `http://<address>:8080/api/v1/health` in the phone's browser. |
| Dashboard login says "does not have monitoring access" | The account is `teacher`/`coordinator`. Promote it (section 6). |
| Dashboard can't reach the API from another computer | `DASHBOARD_API_BASE_URL` is `localhost`. Set the real address and rebuild the dashboard. |
| Analysis fails | `docker compose logs backend`. Look for Gemini errors: invalid key, quota exhausted, or an unsupported or very long audio file. |
| No verification or reset email arrives | Expected without `RESEND_API_KEY`; read it from the backend log (section 6). |

## 13. Code map

```
ai_coach/
├── docker-compose.yml        # the whole stack
├── .env.example              # stack configuration template
├── backend/
│   ├── cmd/server/main.go    # entry point, routes, CORS
│   └── internal/
│       ├── config/           # environment variables
│       ├── database/         # connection + automatic schema migrations
│       ├── handlers/         # HTTP endpoints (auth, recordings, analysis, chat, coach, admin)
│       ├── middleware/       # JWT auth, role checks
│       ├── repository/       # SQL queries
│       ├── models/           # data types, roles
│       └── services/
│           ├── gemini/       # prompts and the TEACH framework; most behaviour lives here
│           ├── exporter/     # Excel workbooks
│           ├── storage/      # MinIO / S3
│           ├── email/        # Resend
│           └── googledrive/  # optional recording backup
├── flutter_app/lib/
│   ├── core/                 # API address, translations (en/fr/pt/sw/am), theme, TEACH metadata
│   ├── data/                 # models, providers (state), API client
│   └── presentation/         # screens and widgets
└── monitoring-dashboard/     # separate repository (Next.js), see its README
```

Run the backend tests with `cd backend && go test ./...`. Other references in this repository: `USER_ACCESS_CONTROL.md` (who can see what), `METADATA.md` (data collected), `TESTING.md` (manual API testing).

## 14. Known limitations

- **Password-reset links** in emails point to `https://aicoach.app/reset-password?token=...`, which is not a working page. Users copy the `token` value from the email into the app's reset screen. To change the link, edit `SendPasswordResetEmail` in `backend/internal/services/email/email_service.go`.
- **Google Drive backup** of recordings is optional and not wired into `docker-compose.yml`. Recordings are stored in MinIO either way.
- **iOS** builds have not been tested in this handover. They need a Mac, an Apple developer account and your own bundle identifier.
- **Gemini dependency.** Analysis quality, cost and availability depend on Google's `gemini-2.5-flash` model. The model name is set in `backend/internal/services/gemini/gemini.go`.
