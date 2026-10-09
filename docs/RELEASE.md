# Releasing STW Neo: Web, PWA and APK

One project, one set of settings, three outputs. The Web app and the PWA are
the same build (the PWA is the website installed to the home screen). The APK
is built from the same code with the same settings and version number.

```
App/
├── neonatal_stw/        source (this repo)
└── neonatal_stw_web/    built web files only (deploy repo, pulled by the server)
```

| What | Command (from `neonatal_stw/`) | Result |
| --- | --- | --- |
| Web + PWA | `powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1` | Builds, commits and pushes `neonatal_stw_web`; on the server run `git pull` |
| APK | `powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1` | `dist\STW-Neo-<version>.apk`, ready to share |
| Web build only (local test) | `powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1` | `build\web` |

After any change: run both commands, so the website, the installed PWAs and
the next shared APK all carry it.

## Settings: `build.env`

`build.env` (project root, ignored by git) is compiled into both the web and
the Android build:

```
API_BASE_URL=https://<production API host>
API_KEY=<client API key>
```

The build scripts refuse to build when the API address cannot work on users'
devices:

- `localhost` / `127.0.0.1`: on a phone or browser that is the user's own
  device, so nothing would be uploaded.
- `http://`: Android blocks plain http, and an https website cannot call an
  http API.

`-AllowInsecureApi` skips these checks for a local test build. Never deploy
or share such a build.

The API key ends up inside the app (`main.dart.js`, the APK), so keep the
deploy repo **private** and replace the development key from `.env.example`.

## Version

Both builds get the same version: `pubspec.yaml` version + the git commit
count, e.g. `0.1.0+57`. It appears in:

- `version.json` of the website, and Android's app info (version code 57);
- every session stored in MongoDB (`appVersion`, with the commit id), so data
  can be traced to the build that produced it.

Commit before building, so the number moves forward. Android installs an APK
over an older one only if its version code is not lower.

## Web and PWA

### Deploy

```powershell
powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1
# optional: -Message "Fix PDF wheel scroll"   -NoPush (commit only)
```

The script runs `build_web.ps1` (release build, CanvasKit bundled so the PWA
also starts offline, new service worker), copies `build\web` into
`neonatal_stw_web`, commits and pushes. Then on the server:

```bash
cd /var/www/stwneo-web && git pull
```

The server only receives built web files: no Dart source, no Android code.

### How users get the update

`build\web\sw.js` is generated for each build from `tool/sw_template.js`
(do not edit `build\web\sw.js`):

- **Online:** app code is fetched network-first, so the next load or the
  in-app refresh button runs the new version. Installed PWAs behave the same.
- **Offline:** the app starts from the cache of the last version that browser
  installed. PDFs and page images are cached too.
- Each build has a new cache; the old one (including the pre-generator
  `stwneo-offline-cache-v2`) is deleted when the new version activates.

A plain `flutter build web` has no `sw.js` (no offline use): always deploy
with the script.

### One-time setup

**Deploy repo remote.** Create an empty **private** GitHub repository (e.g.
`SRHU_Doctor_app_web`, no README), then:

```powershell
git -C ..\neonatal_stw_web remote add origin https://github.com/techyogeshchauhan/SRHU_Doctor_app_web.git
```

**Server.** Add the server's SSH key as a read-only deploy key (repo Settings
> Deploy keys), then:

```bash
git clone git@github.com:techyogeshchauhan/SRHU_Doctor_app_web.git /var/www/stwneo-web
```

Serve that folder over **HTTPS** (required for the PWA and its service
worker). nginx example:

```nginx
root /var/www/stwneo-web;
location ~ /\.git { deny all; }                 # never serve the repo history
types { application/wasm wasm; text/javascript mjs; }
location ~ ^/(sw\.js|index\.html|flutter_bootstrap\.js|version\.json|manifest\.json)$ {
  add_header Cache-Control "no-cache";
}
location / { try_files $uri $uri/ /index.html; }
```

Don't edit files on the server; local changes make `git pull` fail. To
discard them: `git reset --hard origin/main`.

## APK

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1
```

Share `dist\STW-Neo-<version>.apk` (not `build\…\app-release.apk`, and not the
old `STW Neo.apk` in the project root).

- Recipients install it over their current version. If Android says the app
  "conflicts with an existing package", the APK was signed on a different
  computer: release builds are currently signed with this PC's debug key.
  Build every APK on the same PC, or set up a release keystore (one-time;
  keep it safe, it cannot be replaced).
- The APK syncs screenings and chat logs to `API_BASE_URL` (Internet
  permission is declared in `android/app/src/main/AndroidManifest.xml`).

## API server (MongoDB Atlas)

The apps never talk to MongoDB: they send data to the REST API in `server/`,
which alone holds the database credentials. Deploy API changes **before**
releasing app builds that depend on them.

### What is stored

| Collection | Contents |
| --- | --- |
| `sessions` | One per assessment: `selectedConditions`, `platform`, `appVersion`, `status` (in_progress / completed / abandoned), `createdAt`, `endedAt`. A chat outside an assessment opens a session with no conditions. |
| `screenings` | One per condition in a session: `diseaseCode`, `responses[]` (every checkbox, number and choice, with `answeredAt`), `findings[]` (results shown), `mcqAttempts[]`, `status`, `startedAt`, `completedAt`. |
| `chatLogs` | Question, lines shown, STW box, source page, outcome, `sessionId`, `createdAt`. |

Date of birth, exam dates, next exam place, facility and SNCU/CR number stay
on the device (de-identified data).

### Settings: `server/.env`

Never commit this file and never paste the password into chats or code.
`node server/scripts/check-secrets.js` fails if any of its values appears in
a project file.

| Variable | Value |
| --- | --- |
| `MONGODB_HOST` | Atlas > Connect > Drivers: the part after `@`, e.g. `cluster0.ab1cd.mongodb.net` |
| `MONGODB_USERNAME`, `MONGODB_PASSWORD` | Atlas > Database Access: a user with **readWrite on `DB_NAME` only** |
| `MONGODB_OPTIONS` | `retryWrites=true&w=majority` |
| `DB_NAME` | `stw_neo` |
| `API_KEYS` | Random write key(s); the same key is `API_KEY` in `build.env` |
| `EXPORT_API_KEY` | Random read-only key for `/export` (research), different from `API_KEYS` |
| `ALLOWED_ORIGINS` | `https://stwneo.epulse.in` (+ `http://localhost:8080` for local testing; the APK needs none) |
| `TRUST_PROXY` | `1` behind nginx |
| `PORT` | `4000` |

With `NODE_ENV=production` the server refuses to start without real keys or
with the old development keys.

Check the connection (read-only, prints no credentials or data):

```powershell
node server\scripts\check-db.js
```

### Deploy on the VPS (shared server)

The server (`187.127.178.185`) also hosts other critical sites. Everything
below stays inside our own paths and never touches theirs:

| Ours (created or changed) | Never touched |
| --- | --- |
| `/opt/stwneo/` (API, its own Node.js, deploy key) | System Node.js, apt packages |
| `/var/www/neonatal-stw-web` (site files, as today) | Other `/var/www/*` folders |
| nginx file for `stwneo.epulse.in` only | Other nginx files, `default` |
| `stwneo` system user, `stwneo-api` service | Other users, services, ports, firewall |

The only shared action is `systemctl reload nginx`, run after `nginx -t`
passes: a reload is graceful, so no site goes offline, and a failing test
changes nothing.

Files used: `server/deploy/stwneo-api.service`,
`server/deploy/nginx-stwneo.epulse.in.conf`.

**1. Read-only checks (change nothing).**

```bash
grep -ls "stwneo.epulse.in" /etc/nginx/sites-available/* /etc/nginx/conf.d/* 2>/dev/null   # our nginx file
ss -ltnp | grep -E ':4000\b' || echo "port 4000 free"
systemctl list-unit-files | grep -i stwneo || echo "no stwneo service yet"
id stwneo 2>/dev/null || echo "no stwneo user yet"
git -C /var/www/neonatal-stw-web remote -v
uname -m && git --version
for h in mybharat.io admin.mybharat.io booth.mybharat.io campus.mybharat.io insta.mybharat.io whatsapp.mybharat.io youtube.mybharat.io sst.ved.bio stwneo.epulse.in; do
  printf "%-24s %s\n" "$h" "$(curl -s -o /dev/null -w '%{http_code}' https://$h/)"; done > /root/sites-before.txt; cat /root/sites-before.txt
```

If port 4000 is taken, use a free port in `.env` (`PORT=`) and in the nginx
file's `proxy_pass`.

**2. Own user, folders and Node.js** (system Node is not used):

```bash
useradd --system --home /opt/stwneo --shell /usr/sbin/nologin stwneo
mkdir -p /opt/stwneo/keys
curl -fsSL https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-x64.tar.xz -o /tmp/stwneo-node.tar.xz
mkdir -p /opt/stwneo/node && tar -xJf /tmp/stwneo-node.tar.xz -C /opt/stwneo/node --strip-components=1 && rm /tmp/stwneo-node.tar.xz
/opt/stwneo/node/bin/node -v
```

**3. Read-only deploy key for the API repo** (kept in `/opt/stwneo/keys`;
root's SSH config is not changed):

```bash
ssh-keygen -t ed25519 -f /opt/stwneo/keys/api -N "" -C "stwneo-api@srv1970015"
cat /opt/stwneo/keys/api.pub   # GitHub > SRHU_Doctor_app > Settings > Deploy keys > Add (read-only)
```

**4. API code** (`server/` only, sparse checkout):

```bash
export GIT_SSH_COMMAND="ssh -i /opt/stwneo/keys/api -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
git clone --filter=blob:none --no-checkout git@github.com:techyogeshchauhan/SRHU_Doctor_app.git /opt/stwneo/api
cd /opt/stwneo/api && git config core.sshCommand "$GIT_SSH_COMMAND"
git sparse-checkout set server && git checkout main
cd server && PATH=/opt/stwneo/node/bin:$PATH npm ci --omit=dev
```

**5. Settings.** From the PC: `scp server\.env root@187.127.178.185:/opt/stwneo/api/server/.env`. Then:

```bash
printf '\nHOST=127.0.0.1\nTRUST_PROXY=1\n' >> /opt/stwneo/api/server/.env
chown -R stwneo:stwneo /opt/stwneo && chmod 600 /opt/stwneo/api/server/.env /opt/stwneo/keys/api
```

**6. Start the API:**

```bash
cp /opt/stwneo/api/server/deploy/stwneo-api.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now stwneo-api
sleep 3; curl -s http://127.0.0.1:4000/health      # "db":"connected"
ss -ltnp | grep ':4000'                            # must show 127.0.0.1:4000, not 0.0.0.0
```

**7. nginx (our file only).** Replace `<OUR_FILE>` with the path from step 1:

```bash
cp <OUR_FILE> /root/stwneo-nginx.backup
cp /opt/stwneo/api/server/deploy/nginx-stwneo.epulse.in.conf <OUR_FILE>
nginx -t && systemctl reload nginx || { cp /root/stwneo-nginx.backup <OUR_FILE>; echo "nginx test failed: restored, nothing reloaded"; }
```

**8. Website.** On the PC: `scripts\deploy_web.ps1`. On the server:
`git -C /var/www/neonatal-stw-web pull` (as before).

**9. Verify, including the other sites:**

```bash
curl -s https://stwneo.epulse.in/api/health                       # "db":"connected"
curl -s -o /dev/null -w '%{http_code}\n' https://stwneo.epulse.in/.git/HEAD   # 403
for h in $(cut -d' ' -f1 /root/sites-before.txt); do
  printf "%-24s %s\n" "$h" "$(curl -s -o /dev/null -w '%{http_code}' https://$h/)"; done > /root/sites-after.txt
diff /root/sites-before.txt /root/sites-after.txt && echo "other sites unchanged"
```

**Rollback** (ours only): `cp /root/stwneo-nginx.backup <OUR_FILE> && nginx -t && systemctl reload nginx`;
`systemctl disable --now stwneo-api`.

**Update the API later:**
`cd /opt/stwneo/api && sudo -u stwneo git pull && cd server && sudo -u stwneo env PATH=/opt/stwneo/node/bin:$PATH npm ci --omit=dev && systemctl restart stwneo-api`
(`git pull` runs as `stwneo`, which owns the checkout and the key).

### End-to-end test against Atlas

Writes only to a separate database (`stw_neo_e2e`), never to `stw_neo`:

```powershell
cd server; node scripts\e2e_server.js 4100 --atlas      # leave running
$env:E2E_API_URL='http://127.0.0.1:4100'; flutter test test\e2e_mongo_sync_test.dart
node server\scripts\check-db.js stw_neo_e2e
```

Delete the `stw_neo_e2e` database in Atlas afterwards.
