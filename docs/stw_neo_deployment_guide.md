# STW Neo — Web & PWA Deployment Guide

---

## 1. Local PC Deployment (PowerShell)

### A. Pre-Deployment Checks & Commit
Run these commands inside PowerShell on your PC:

```powershell
# 1. Navigate to the main project folder
cd D:\SRHU-Projects\Yogi\Yogi\App\neonatal_stw

# 2. Switch to main branch and fetch latest changes
git switch main
git pull

# ... Make your code modifications ...

# 3. Run Flutter tests (must all pass)
flutter test

# 4. Only if you changed anything inside 'server\':
cd server; npm test; cd ..

# 5. Verify changed files before committing
git status

# 6. Stage and commit changes
git add -A
git commit -m "Short description of the change"
git push
```

### B. Build and Push Web/PWA Assets
```powershell
powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1
```

> **Important Deployment Reminders:**
> - **Always commit before running `deploy_web.ps1`:** The script compiles whatever is currently in the folder and stamps the build with the current commit hash.
> - **Main Branch:** Ensure you are working on `main` or merge your working branch into `main` first. The build number is derived from the commit count of the branch you build from.
> - **"What's New" Popup (Optional for major/announced releases):**
>   1. Add a `ReleaseNote` entry at the top of `kAppReleaseNotes` in `lib\core\config\release_notes.dart` and update `kCurrentAppVersion` (e.g. `1.2.0`).
>   2. Update `version: 1.2.0+1` in `pubspec.yaml`. Both must match or tests will fail. For small bug fixes, leave both untouched for silent background updates.

---

## 2. Server Deployment (SSH)

### Step 1: Update API (Run ONLY if you modified `server\`)
The API must always be updated before the frontend to prevent client mismatch.

```bash
cd /opt/stwneo/api && sudo -u stwneo git pull && cd server && sudo -u stwneo env PATH=/opt/stwneo/node/bin:$PATH npm ci --omit=dev && systemctl restart stwneo-api
```

**Verify API Health:**
```bash
curl -s https://stwneo.epulse.in/api/health
```
*Expected response:* `{"status":"ok","db":"connected"}`

---

### Step 2: Update Web & PWA (Run EVERY TIME)
Pull the newly compiled frontend artifacts to the production web directory:

```bash
sudo -u stwneo git -C /var/www/neonatal-stw-web pull
```

**Verify Web Build Version:**
```bash
curl -s https://stwneo.epulse.in/version.json
```
*Expected output:* Should match the build version printed by `deploy_web.ps1` (e.g., `Web/PWA 1.1.0+32`).

**Client Update:**
- Force reload your browser tab: `Ctrl + Shift + R`
- Installed PWAs update automatically upon next launch or reload.

---

## 3. Emergency Rollback

If a deployment breaks the production site:

### On Local PC (PowerShell):
```powershell
cd D:\SRHU-Projects\Yogi\Yogi\App\neonatal_stw_web
git revert --no-edit HEAD
git push
```

### On Server:
```bash
sudo -u stwneo git -C /var/www/neonatal-stw-web pull
```
*This reverts the production site to the previous working build. Fix the issue inside `neonatal_stw` locally and deploy normally.*

---

## 4. Operational Restrictions (Never Run on STW Neo)

- ❌ **Do NOT reload or restart Nginx** (`systemctl reload/restart nginx` is unnecessary).
- ❌ **Do NOT run Git commands as `root`** (always use `sudo -u stwneo`).
- ❌ **Do NOT run `git config --global ...`** on the server.
- ❌ **Do NOT `chown` outside `/var/www/neonatal-stw-web` or `/opt/stwneo`**.