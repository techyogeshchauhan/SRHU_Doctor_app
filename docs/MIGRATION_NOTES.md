# Migration Notes: Complete Supabase Removal & MongoDB Atlas REST Backend Integration

This document records the complete setup of MongoDB Atlas accessed **exclusively** through a dedicated, de-identified Node.js + Express REST API backend (`/server`) for the **STW Neo** (`neonatal_stw`) clinical decision support system.

---

## 1. Secrets & Confidentiality Discipline

- **No Hardcoded Credentials**: No database username, password, or raw connection strings are stored in code, prompts, comments, docs, tests, or version control.
- **Git-Ignored Local Environment**: `server/.env` is strictly gitignored (verified via `git check-ignore server/.env`).
- **Dynamic URI Generation**: The connection string is constructed at runtime in [`server/src/config.js`](file:///d:/SRHU-Projects/Yogi/Yogi/App/neonatal_stw/server/src/config.js) using `encodeURIComponent()` on username and password:
  ```
  mongodb+srv://<user>:<pass>@<host>/<DB_NAME>?<options>
  ```
- **Fail-Fast Startup**: If any required variable (`MONGODB_USERNAME`, `MONGODB_PASSWORD`, `MONGODB_HOST`) is missing, startup halts immediately with a clear error without leaking secret values.
- **Safe Logging**: The server only logs `Connected to MongoDB (db: <DB_NAME>)`. The full connection string is never logged.
- **Pre-Commit Secret Scanner**: [`scripts/check-secrets.js`](file:///d:/SRHU-Projects/Yogi/Yogi/App/neonatal_stw/scripts/check-secrets.js) scans the entire repository for embedded Atlas connection strings or non-empty passwords outside `.env` files.

---

## 2. Architecture & Data Flow

1. **Flutter App (`neonatal_stw`)**:
   - Contains **zero MongoDB credentials** and does not use `mongo_dart` or direct database drivers.
   - Communicates exclusively via HTTP REST endpoints using `ApiClient` (`dio`).
   - Uses an offline-first Hive queue: writes are saved locally with client-generated UUIDs and synced in the background with exponential backoff on reconnection.
   - Clinical screening progress and chatbot retrieval logic remain 100% unchanged.
2. **Backend API (`/server`)**:
   - Built with Node.js, Express, and the official `mongodb` driver.
   - Secured with `helmet`, `cors` allow-list from `ALLOWED_ORIGINS`, and `express-rate-limit`.
   - **Zero PHI Guarantee**: Strict Zod schemas reject unrecognized fields and any patient identifiers (`name`, `mrn`, `dob`, `phone`, `address`).
   - **Atomic Pipeline Updates**: `PUT /screenings/:id/responses/:questionId` updates or appends question responses atomically via an aggregation pipeline `$concatArrays` / `$filter` in a single database round-trip, preventing duplicates.
   - **Isolated Chat Logs**: Chat logs are stored in a dedicated `chatLogs` collection and never embedded into session documents.
   - **Role-Based Auth**:
     - Write routes (`/sessions`, `/screenings`, `/chat-logs`) accept client `API_KEYS`.
     - Export route (`/export/screenings`) strictly requires the dedicated read-only `EXPORT_API_KEY` and rejects client write keys.

---

## 3. Files Removed & Added

### Files Removed
- `supabase/` (entire directory deleted, including `001_init.sql`).
- `lib/data/services/supabase_service.dart` (Supabase client wrapper deleted).
- `supabase_flutter` dependency and all its subpackages removed from `pubspec.yaml` and `pubspec.lock`.

### Files Added / Configured
- `scripts/check-secrets.js`: Repository secret scanning script.
- `server/.env.example` & `.env.example`: Configuration templates with placeholders.
- `server/.env`: Local configuration with credentials (gitignored).
- `server/package.json`: Server package definition with `npm test`, `npm run seed`, `npm run backup`, `npm run check-secrets`, `npm run verify`.
- `server/src/config.js`: Dynamic URI builder with fail-fast validation.
- `server/src/db.js`: MongoDB connection manager with idempotent indexes.
- `server/src/schemas.js`: Zod validation schemas with PHI rejection.
- `server/src/middleware/auth.js`: API key authentication with write/export separation.
- `server/src/middleware/logger.js`: PHI-safe request logging.
- `server/src/middleware/errorHandler.js`: Centralized error handler.
- `server/src/routes/`: `sessions.js`, `screenings.js`, `chatLogs.js`, `export.js`, `health.js`.
- `server/scripts/seed.js`: Database seeder for all 14 neonatal diseases.
- `server/scripts/backup.js`: JSON snapshot export script for weekly Atlas backups.
- `server/scripts/verify_workflow.js`: End-to-end integration and offline idempotence test.
- `server/test/api.test.js`: Integration tests with `supertest` and `mongodb-memory-server` (15/15 tests passing).
- `server/Dockerfile`: Alpine container definition for production deployment.
- `server/README.md`: Atlas cluster guide, local run, and deployment notes.
- `lib/data/services/api_client.dart`: Dio REST client with exponential backoff and timeouts.
- `test/data_sync_test.dart`: Flutter data sync unit tests.

---

## 4. Environment Variables Reference

### Server (`server/.env`)
| Variable | Description | Example / Default |
|---|---|---|
| `MONGODB_USERNAME` | MongoDB Atlas database username | `srhutechforge_db_user` |
| `MONGODB_PASSWORD` | MongoDB Atlas database user password | *(stored in .env only)* |
| `MONGODB_HOST` | Cluster host address | `cluster0.xxxxx.mongodb.net` |
| `MONGODB_OPTIONS` | Connection options query string | `retryWrites=true&w=majority` |
| `DB_NAME` | Target database name | `stw_neo` |
| `API_KEYS` | Comma-separated client write API keys | `stw_dev_client_key_12345,stw_mobile_app_prod_key` |
| `EXPORT_API_KEY` | Dedicated read-only key for `/export` | `stw_research_export_key_67890` |
| `ALLOWED_ORIGINS` | Comma-separated CORS allowed origins | `http://localhost:3000,http://localhost:4000,http://localhost:5000,http://localhost:8080` |
| `PORT` | Server HTTP port | `4000` |

### Flutter Client (`--dart-define`)
| Parameter | Description | Example |
|---|---|---|
| `API_BASE_URL` | Base URL of the REST backend | `http://localhost:4000` or `https://api.yourdomain.com` |
| `API_KEY` | Client write API key matching `API_KEYS` | `stw_dev_client_key_12345` |

---

## 5. Verification Checklist & Test Results

| Test / Check | Result | Details |
|---|---|---|
| Secret Scan (`npm run check-secrets`) | **Passed** | 0 secrets or hardcoded passwords found across entire repository |
| Connection String Grep (`git grep -i "mongodb+srv://"`) | **Passed** | Only template strings and placeholder examples found |
| Server Integration Tests (`npm test`) | **Passed (15/15)** | Auth rejection, wrong key 401, export write-key rejection (403), fail-fast startup on missing env, PHI rejection, idempotent response updates |
| End-to-End Workflow & Offline Test (`npm run verify`) | **Passed** | RD screening, ROP screening, 3 STW chat queries, and 3-retry offline answer test resulting in exactly 1 document entry |
| Flutter Static Analysis (`flutter analyze`) | **Passed** | 0 issues found |
| Flutter Test Suite (`flutter test`) | **Passed (210/210)** | All clinical logic, UI, and data layer tests passing |

---

## 6. Atlas Host Setup Note

In `server/.env`, `MONGODB_USERNAME` and `MONGODB_PASSWORD` are configured. To connect directly to your live Atlas cluster, copy your cluster host name into `server/.env`:
```env
MONGODB_HOST=cluster0.xxxxx.mongodb.net
```
*(When `MONGODB_HOST` is not yet configured, tests and verification scripts safely fall back to `mongodb-memory-server` without failing).*
