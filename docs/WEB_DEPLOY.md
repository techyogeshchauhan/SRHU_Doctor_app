# Web deployment (git pull on the server)

The built web app lives in its own git repository, `neonatal_stw_web`, next to
this project. It holds only the contents of `build/web`: no Dart source, no
Android/iOS code. The server clones it once and afterwards updates with
`git pull`.

```
App/
├── neonatal_stw/        source (this repo, SRHU_Doctor_app)
└── neonatal_stw_web/    built web files only (deploy repo)
```

## Deploy (every release)

From `neonatal_stw/`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1
# optional: -Message "Fix PDF wheel scroll"   -NoPush (commit only)
```

The script builds the web app, copies `build/web` into `neonatal_stw_web`,
commits and pushes. Then on the server:

```bash
cd /var/www/stwneo-web && git pull
```

## Build settings: `web_build.env`

`web_build.env` (project root, ignored by git) is passed to
`flutter build web --dart-define-from-file`:

```
API_BASE_URL=https://<production API host>
API_KEY=<client API key>
```

It must hold the **production** API URL. `localhost` would point each
visitor's browser at their own computer. Without the file, the build runs in
offline-only mode.

The API key ends up inside `main.dart.js`, so keep the deploy repo **private**.

## One-time setup

### 1. Remote for the deploy repo

Create an empty **private** GitHub repository (e.g. `SRHU_Doctor_app_web`,
with no README), then:

```powershell
git -C ..\neonatal_stw_web remote add origin https://github.com/techyogeshchauhan/SRHU_Doctor_app_web.git
```

The first `deploy_web.ps1` run pushes `main` to it.

### 2. Server

```bash
# Read access for a private repo: add the server's SSH key as a read-only
# deploy key (repo Settings > Deploy keys), then clone over SSH.
git clone git@github.com:techyogeshchauhan/SRHU_Doctor_app_web.git /var/www/stwneo-web
```

Point the web server's document root at that folder. **Block `.git`** so the
repository history cannot be downloaded. For nginx:

```nginx
root /var/www/stwneo-web;
location ~ /\.git { deny all; }
location / { try_files $uri $uri/ /index.html; }
```

Don't edit files on the server. Local changes there make `git pull` fail.
To discard them: `git reset --hard origin/main`.

## Notes

- Each deploy adds roughly the size of the changed files (mostly
  `main.dart.js`, ~1 MB compressed) to the repo history. Unchanged PDFs,
  page images and CanvasKit are stored once.
- After a deploy, browsers get the new version on the next reload: `web/sw.js`
  fetches app code network-first.
