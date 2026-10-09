# STW Neo: Migration from Supabase to MongoDB Atlas REST Backend

**Document Name:** `docs/MONGODB_REST_API_MIGRATION.md`  
**Date:** October 2026  
**Status:** Completed & Verified  

---

## 1. Executive Summary

In this upgrade, **Supabase was completely eliminated** from the STW Neo project (`neonatal_stw`) and replaced with **MongoDB Atlas**, accessed **strictly via a dedicated Node.js + Express REST API backend** (`/server`).

### Core Guarantees & Constraints Maintained
- **Medical & Clinical Integrity**: Zero changes to medical content, screening criteria, Silverman Anderson Scoring (SAS), Retinopathy of Prematurity (ROP) staging, MCQs, chatbot extractive retrieval, or UI design.
- **Client Security**: The Flutter app contains **zero MongoDB connection strings** and **no direct database drivers** (`mongo_dart` is never used).
- **Strictly De-Identified (Zero PHI)**: No patient identifiers (name, MRN, date of birth, phone, address) are accepted, stored, or logged.
- **Offline-First Resilience**: All writes are committed locally to Hive (IndexedDB on Web/PWA, binary storage on mobile) with client-generated UUIDs and synced in the background with exponential backoff on reconnection.

---

## 2. Secrets Discipline & Credentials Handling

### Mandatory Rules Followed
1. **No Credentials in Code or Git**: No usernames, passwords, or full connection strings are stored in code, prompts, comments, docs, tests, or commit history.
2. **Git-Ignored Environment File**: `server/.env` is strictly git-ignored (verified via `git check-ignore server/.env`).
3. **Dynamic Connection String Construction**: Connection strings are built dynamically in memory in `server/src/config.js` using `encodeURIComponent()` on username and password:
   ```text
   mongodb+srv://<user>:<pass>@<host>/<DB_NAME>?<options>
   ```
4. **Fail-Fast Startup**: Missing required variables (`MONGODB_USERNAME`, `MONGODB_PASSWORD`, `MONGODB_HOST`) halt server startup immediately with a clear message without printing secret values.
5. **Safe Logging**: The server only logs `Connected to MongoDB (db: <DB_NAME>)`. Raw URIs and credentials are never printed to terminal or logs.
6. **Automated Secret Scanner**: Added `scripts/check-secrets.js` (and `npm run check-secrets`) to scan the codebase for embedded connection strings or passwords outside `.env` files.

### Environment Variable Specifications

#### Backend (`server/.env`)
| Variable | Description | Sample / Default |
|---|---|---|
| `MONGODB_USERNAME` | Atlas database username | e.g. `<db-user>` |
| `MONGODB_PASSWORD` | Atlas database user password | *(stored only in git-ignored server/.env)* |
| `MONGODB_HOST` | Cluster host address | e.g. `cluster0.xxxxx.mongodb.net` |
| `MONGODB_OPTIONS` | Connection options query string | `retryWrites=true&w=majority` |
| `DB_NAME` | Target database name | `stw_neo` |
| `API_KEYS` | Comma-separated client write API keys | `stw_dev_client_key_12345,stw_mobile_app_prod_key` |
| `EXPORT_API_KEY` | Dedicated read-only key for `/export` | `stw_research_export_key_67890` |
| `ALLOWED_ORIGINS` | Comma-separated CORS allowed origins | `http://localhost:3000,http://localhost:4000,http://localhost:5000,http://localhost:8080` |
| `PORT` | Server HTTP port | `4000` |

#### Flutter Client (`--dart-define`)
| Flag | Description | Sample Value |
|---|---|---|
| `API_BASE_URL` | Base URL of the REST API backend | `http://localhost:4000` or `https://api.yourdomain.com` |
| `API_KEY` | Client write API key matching `API_KEYS` | `stw_dev_client_key_12345` |

> **Client Key Security Note**: The API key provided to the Flutter app via `--dart-define=API_KEY=...` is embedded in client binaries and is not considered secret. The server enforces role-based authorization so that client keys can only access the limited write routes (`/sessions`, `/screenings`, `/chat-logs`), while research export endpoints (`/export/*`) require the separate `EXPORT_API_KEY`.

---

## 3. Backend Architecture (`/server`)

### Technology Stack
- **Runtime**: Node.js v22 (ECMAScript Modules)
- **Framework**: Express 4
- **Database Driver**: Official `mongodb` driver (v6) with connection pooling and graceful shutdown
- **Validation**: Zod (strict mode with custom recursive PHI keyword detection)
- **Security**: Helmet, CORS allow-list, Express-rate-limit (120 req/min), 1MB JSON body limit
- **Testing**: Node test runner (`node:test`), Supertest, and `mongodb-memory-server`

### Collections & Indexing
1. **`sessions`**:
   - Fields: `_id` (UUID), `sessionToken`, `facilityName`, `platform`, `appVersion`, `status` (`in_progress` | `completed` | `abandoned`), `createdAt`, `updatedAt`.
   - Index: `createdAt` (1).
2. **`screenings`**:
   - Fields: `_id` (UUID), `sessionId`, `diseaseCode`, `progressState`, `isEligible`, `startedAt`, `completedAt`, `status`, `responses: []`, `findings: []`, `mcqAttempts: []`.
   - Indexes: `sessionId` (1), `(diseaseCode, startedAt)` (1, 1).
3. **`chatLogs`**:
   - Fields: `_id` (UUID), `sessionId`, `userQuery`, `extractedAnswer`, `regionId`/`chunkIds`, `source: { document, page, section }`, `found`, `retrieverType`, `createdAt`.
   - Indexes: `sessionId` (1), `createdAt` (1).
   - *Note*: Kept in an isolated collection; never embedded into session documents.
4. **`diseases`**:
   - Fields: `code` (unique), `name`, `isActive`.
   - Unique Index: `code` (1).

### REST Endpoints
| Method | Route | Description | Auth Required |
|---|---|---|---|
| `GET` | `/health` | Container health check and database ping | None (Open) |
| `POST` | `/sessions` | Create or ensure clinical session (idempotent) | `API_KEYS` |
| `PATCH` | `/sessions/:id` | Update session facility or status | `API_KEYS` |
| `GET` | `/sessions/:id` | Retrieve session document | `API_KEYS` |
| `PUT` | `/screenings/:id` | Create or ensure disease screening document | `API_KEYS` |
| `PUT` | `/screenings/:id/responses/:questionId` | **Atomic pipeline update**: Replaces existing answer or appends new; zero duplicates | `API_KEYS` |
| `POST` | `/screenings/:id/findings` | Append derived clinical findings | `API_KEYS` |
| `PUT` | `/screenings/:id/findings` | Replace findings with the latest snapshot (used by the app) | `API_KEYS` |
| `POST` | `/screenings/:id/mcq-attempts` | Append MCQ question attempt | `API_KEYS` |
| `PATCH` | `/screenings/:id/status` | Update progress/status (`in_progress`, `completed`, `abandoned`) | `API_KEYS` |
| `GET` | `/screenings?sessionId=...` | Retrieve screenings for a session | `API_KEYS` |
| `POST` | `/chat-logs` | Record STW-grounded query, answer, and citations | `API_KEYS` |
| `GET` | `/chat-logs?sessionId=...` | Retrieve chat logs for a session | `API_KEYS` |
| `GET` | `/export/screenings` | Paginated de-identified export (cursor/page) | **`EXPORT_API_KEY` only** |

### Automated Scripts & Containerization
- **`scripts/seed.js`**: Seeds all 14 neonatal diseases (marking active: `respiratory_distress` and `rop`).
- **`scripts/backup.js`**: Self-contained JSON export script that backs up all collections into timestamped folders under `server/backups/`.
- **`scripts/check-secrets.js`**: Pre-commit scanner detecting exposed credentials.
- **`scripts/verify_workflow.js`**: End-to-end integration and offline idempotence test script.
- **`Dockerfile`**: Lightweight Alpine production container running as non-root user.

---

## 4. Flutter Client Data Layer (`neonatal_stw`)

### Package Changes
- **Removed**: `supabase_flutter: ^2.18.0` and all transitive dependencies (`postgrest`, `gotrue`, `realtime_client`, `storage_client`, etc.).
- **Added**: `dio: ^5.8.0`.
- **Retained**: `hive_flutter`, `hive`, `connectivity_plus`, `uuid`.

### Architecture & Service Classes
1. **`lib/data/services/api_client.dart`**:
   - Connects to REST backend using `dio`.
   - Reads `--dart-define` keys `API_BASE_URL` and `API_KEY`.
   - Enforces 10-second connect timeout and 15-second receive timeout.
   - Exponential backoff retries (300ms, 600ms, 1200ms) for transient network and 5xx errors.
   - PHI-safe logging: logs only HTTP method and route in debug mode; never logs payloads or response bodies.
2. **`lib/data/local/offline_queue.dart`**:
   - Writes are first committed locally to Hive boxes with client UUIDs.
   - Listens to connectivity changes via `connectivity_plus`.
   - On connection, flushes FIFO to the REST backend.
   - Supports offline queueing when air-gapped or when network drops; duplicates are prevented via client UUID keys.
3. **Repository Implementations**:
   - `ScreeningSyncRepository` and `ChatLogRepository` interfaces remain completely unchanged, ensuring full compatibility with existing controllers.

### Lifecycle Hooks
- **Disease Selected**: Session ensured + Screening created (`PUT /screenings/:id`).
- **Question Answered**: Atomic upsert (`PUT /screenings/:id/responses/:questionId`); a cleared answer is sent as `null`. Date and free-text answers are never sent, and the server rejects PHI-like question ids such as `dob`.
- **Findings Computed**: Current findings replace earlier ones (`PUT /screenings/:id/findings`), so completing again does not duplicate them.
- **MCQ Answered**: Case attempt stored (`POST /screenings/:id/mcq-attempts`).
- **Screening Completed**: Status patched (`PATCH /screenings/:id/status` -> `completed`).
- **Home / Back-to-Selection Exit**: Active screenings marked `abandoned` on server (not deleted).
- **Chatbot Query & Answer**: Logged to separate collection (`POST /chat-logs`).

---

## 5. Verification & Test Suite Summary

### 1. Secret Scanner (`npm run check-secrets`)
- Scanned entire repository for exposed credentials, raw connection strings, and non-empty passwords outside `.env`.
- **Result: PASSED (0 findings)**.

### 2. Connection String Grep (`git grep -i "mongodb+srv://"`)
- Confirmed that only documentation placeholders and dynamic template strings exist.
- **Result: PASSED**.

### 3. Server Automated Tests (`npm test`)
- 15/15 tests passing via `supertest` and `mongodb-memory-server`:
  - `GET /health` returns 200 and DB connected status.
  - Auth: Missing key returns 401.
  - Auth: Wrong key returns 401.
  - Auth: Write key rejected on export route (403 Forbidden).
  - Validation: Unknown and PHI-like fields rejected with 400.
  - Startup: Missing required environment variable fails fast with clear message.
  - Idempotence: Putting same response twice results in exactly 1 entry.
  - Session creation and updates.
  - Screenings, findings, and MCQ attempts.
  - Isolated chat logs storage.
  - Paginated export with `EXPORT_API_KEY`.
- **Result: PASSED (15/15)**.

### 4. End-to-End Workflow Verification (`npm run verify`)
- Executed full Respiratory Distress workflow (GA 31, SAS 5, grunting, CPAP + caffeine findings, MCQ, completion).
- Executed full ROP workflow (GA 29, BW 1100g, Zone II Stage 3 with Plus, findings, MCQ, completion).
- Logged 3 STW-grounded queries.
- Simulated offline re-connections with 3 repeated response updates for `gestational_age`.
- Verified that **exactly 1 document entry** exists with the updated value and zero duplicates.
- **Result: PASSED**.

### 5. Flutter Static Analysis (`flutter analyze`)
- Analyzed entire Flutter application.
- **Result: PASSED (0 issues found)**.

### 6. Flutter Test Suite (`flutter test`)
- Ran all 210 clinical logic, UI smoke, layout overflow, and data sync tests.
- **Result: PASSED (210/210 passed)**.

---

## 6. How to Run Locally

### Start Backend Server
```bash
cd server
npm install
npm run seed     # Seeds 14 neonatal conditions
npm start        # Starts server on http://localhost:4000
```

### Run Flutter Client
```bash
# Web / PWA
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:4000 \
  --dart-define=API_KEY=stw_dev_client_key_12345

# Android APK Build
flutter build apk \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=API_KEY=stw_mobile_app_prod_key
```

*(If `--dart-define` parameters are omitted, the Flutter app gracefully functions in full offline mode).*

---

## 7. MongoDB Atlas Production Setup Checklist

1. **Cluster**: Free M0 cluster created on [cloud.mongodb.com](https://cloud.mongodb.com).
2. **Database User**: User created with `readWrite` access to `stw_neo`.
3. **Network Access**: IP whitelist configured (`0.0.0.0/0` for cloud services like Render/Railway).
4. **Host Configuration**: Set your cluster host in `server/.env`:
   ```env
   MONGODB_HOST=cluster0.xxxxx.mongodb.net
   ```
5. **Backups**: Schedule weekly JSON backups via cron:
   ```cron
   0 0 * * 0 cd /path/to/server && /usr/bin/node scripts/backup.js >> /var/log/stw_backup.log 2>&1
   ```
