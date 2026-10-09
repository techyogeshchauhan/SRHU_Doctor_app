<#
.SYNOPSIS
  Builds the Flutter web app and publishes it to the web deploy repository.

.DESCRIPTION
  1. scripts\build_web.ps1: release build with build.env (API_BASE_URL /
     API_KEY compiled in) and a new service worker version.
  2. Mirrors build\web into the deploy repo (default: ..\neonatal_stw_web).
  3. Commits and pushes it. On the server, `git pull` then updates the site.

  See docs\RELEASE.md.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1
  powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1 -Message "Fix PDF wheel scroll"
  powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1 -NoPush
#>
param(
  [string]$DeployRepo = (Join-Path $PSScriptRoot '..\..\neonatal_stw_web'),
  [string]$Message,
  [switch]$NoPush,
  [switch]$AllowInsecureApi
)

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$DeployRepo = [IO.Path]::GetFullPath($DeployRepo)
$buildDir = Join-Path $root 'build\web'

function Fail([string]$msg) {
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

if (-not (Test-Path (Join-Path $DeployRepo '.git'))) {
  Fail "Deploy repo not found at $DeployRepo (see docs\RELEASE.md)."
}

# 1. Build (same settings and version as the APK).
& (Join-Path $PSScriptRoot 'build_web.ps1') -AllowInsecureApi:$AllowInsecureApi
if ($LASTEXITCODE -ne 0) { Fail 'Web build failed.' }
Push-Location $root
$sourceRev = (& git rev-parse --short HEAD)
$sourceDirty = [bool](& git status --porcelain)
Pop-Location

# 2. Mirror build\web into the deploy repo. Excluded names are neither copied
#    nor deleted, so the repo's own files survive /MIR.
robocopy $buildDir $DeployRepo /MIR /XD .git /XF .gitattributes /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "robocopy failed (exit code $LASTEXITCODE)." }

# 3. Commit and push.
& git -C $DeployRepo add -A
if (-not (& git -C $DeployRepo status --porcelain)) {
  Write-Host 'Web build unchanged; nothing to deploy.' -ForegroundColor Yellow
  exit 0
}
if (-not $Message) {
  $suffix = if ($sourceDirty) { ' (+ uncommitted changes)' } else { '' }
  $Message = "Web build from $sourceRev$suffix"
}
$Message += "`n`nBuilt $(Get-Date -Format 'yyyy-MM-dd HH:mm') from neonatal_stw $sourceRev."
& git -C $DeployRepo commit -q -m $Message
if ($LASTEXITCODE -ne 0) { Fail 'git commit failed.' }

if ($NoPush) {
  Write-Host "Committed to $DeployRepo (not pushed)." -ForegroundColor Green
  exit 0
}
& git -C $DeployRepo push -u origin HEAD
if ($LASTEXITCODE -ne 0) { Fail 'git push failed (has the remote been added? see docs\RELEASE.md).' }
Write-Host 'Pushed. On the server run: git pull' -ForegroundColor Green
