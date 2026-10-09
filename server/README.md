# Neonatal STW REST API Backend (MongoDB Atlas)

Secure, de-identified REST API backend for the STW Neo clinical decision support system, providing persistence for clinical screenings, MCQ evaluations, and grounding-verified chatbot query logs.

---

## 1. Secrets & Environment Configuration

The backend reads credentials **strictly** from environment variables and constructs the connection string in memory at runtime:
```
mongodb+srv://<user>:<pass>@<host>/<DB_NAME>?<options>
```
Credentials and connection strings are **never logged**, printed, or committed to version control.

### Required Environment Variables (`server/.env`)

```env
MONGODB_USERNAME=srhutechforge_db_user
MONGODB_PASSWORD=<your_password>
MONGODB_HOST=cluster0.xxxxx.mongodb.net
MONGODB_OPTIONS=retryWrites=true&w=majority
DB_NAME=stw_neo

# Comma-separated API keys for Flutter client write routes
API_KEYS=stw_dev_client_key_12345,stw_mobile_app_prod_key

# Dedicated read-only key for /export endpoints (write keys are rejected)
EXPORT_API_KEY=stw_research_export_key_67890

# CORS Allowed Origins (comma-separated, includes Flutter web/PWA origins)
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:4000,http://localhost:5000,http://localhost:8080

# Server HTTP Port
PORT=4000
```

> **Client Key Security Note**: The API key provided to the Flutter app via `--dart-define=API_KEY=...` is embedded in the client binary/PWA and is therefore not considered secret. The server enforces role-based authorization so that client keys can only access the limited write routes (`/sessions`, `/screenings`, `/chat-logs`), while research export endpoints (`/export/*`) require the separate `EXPORT_API_KEY`.

---

## 2. Quick Start (Local Run)

### Prerequisites
- Node.js >= 20 (Node 22 recommended)
- MongoDB Atlas M0 cluster or local MongoDB instance

### Setup
```bash
cd server
npm install

# Copy example environment configuration
cp .env.example .env
```

Edit `.env` with your Atlas credentials:
```env
MONGODB_USERNAME=srhutechforge_db_user
MONGODB_PASSWORD=<your_password>
MONGODB_HOST=cluster0.xxxxx.mongodb.net
MONGODB_OPTIONS=retryWrites=true&w=majority
DB_NAME=stw_neo
API_KEYS=stw_dev_client_key_12345
EXPORT_API_KEY=stw_research_export_key_67890
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:4000,http://localhost:5000,http://localhost:8080
PORT=4000
```

### Seed Diseases
```bash
npm run seed
```

### Start Server
```bash
npm start
```
The server starts at `http://localhost:4000`. Health check: `http://localhost:4000/health`.

### Run Test Suite & Secret Scanner
```bash
npm test
npm run check-secrets
```

---

## 3. MongoDB Atlas Setup (M0 Free Tier)

1. **Create Free M0 Cluster**:
   - Sign up or log in at [cloud.mongodb.com](https://cloud.mongodb.com).
   - Click **Create Deployment** -> Select **M0 (Free)**.
   - Choose a cloud provider (AWS/GCP/Azure) and a nearby region (e.g. Mumbai / `ap-south-1`).
   - Click **Create**.

2. **Create Database User**:
   - Under **Security** -> **Database Access**, click **Add New Database User**.
   - Authentication Method: **Password**.
   - Username: e.g. `srhutechforge_db_user`.
   - Password: generate a strong password and save it securely.
   - Database User Privileges: Select **Built-in Role** -> **Read and write to any database** (or restrict to `stw_neo`).
   - Click **Add User**.

3. **Configure Network Access**:
   - Under **Security** -> **Network Access**, click **Add IP Address**.
   - For local development and serverless hosts (Render/Railway), choose **Allow Access From Anywhere** (`0.0.0.0/0`) or specify your static egress IP.
   - Click **Confirm**.

4. **Copy Host Details**:
   - Under **Databases** -> Click **Connect** on your cluster.
   - Choose **Drivers** (Node.js).
   - The connection string looks like:
     `mongodb+srv://<user>:<password>@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority`
   - Extract the host part: `cluster0.abcde.mongodb.net`.
   - Set in `server/.env`:
     ```env
     MONGODB_HOST=cluster0.abcde.mongodb.net
     ```

5. **Rotating Passwords**:
   - In MongoDB Atlas -> **Database Access** -> Click **Edit** next to the user.
   - Select **Edit Password**, generate/enter a new password, and save.
   - Update `MONGODB_PASSWORD` in your production hosting dashboard (e.g. Render / Railway).

---

## 4. Deployment Notes

### Deploying to Render
1. Create a new **Web Service** on [Render](https://render.com).
2. Connect your repository.
3. Configure:
   - **Root Directory**: `server`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start` (or use Dockerfile)
4. Add Environment Variables under **Environment**:
   - `MONGODB_USERNAME`: your Atlas database username
   - `MONGODB_PASSWORD`: your Atlas database password
   - `MONGODB_HOST`: your cluster host (e.g. `cluster0.abcde.mongodb.net`)
   - `MONGODB_OPTIONS`: `retryWrites=true&w=majority`
   - `DB_NAME`: `stw_neo`
   - `API_KEYS`: production client API key
   - `EXPORT_API_KEY`: research export key
   - `ALLOWED_ORIGINS`: web app domain(s)
   - `PORT`: `10000` (Render default)

### Deploying to Railway
1. Create a new project on [Railway](https://railway.app).
2. Deploy from GitHub repo and set root directory to `/server`.
3. Set the environment variables in the Railway dashboard variables tab.
4. Railway automatically detects `server/Dockerfile` or `package.json` and exposes the service.

---

## 5. Weekly Backups (Free Tier)

Since MongoDB Atlas M0 free tier does not include automated point-in-time restores, run the built-in backup script weekly:
```bash
npm run backup
```
This exports all collections (`sessions`, `screenings`, `chatLogs`, `diseases`) into timestamped JSON files under `server/backups/backup_<timestamp>/`.

### Scheduling Weekly Backups via Cron
On Linux/macOS or a CI/worker server, edit crontab (`crontab -e`):
```cron
# Run weekly on Sunday at midnight UTC
0 0 * * 0 cd /path/to/server && /usr/bin/node scripts/backup.js >> /var/log/stw_backup.log 2>&1
```
