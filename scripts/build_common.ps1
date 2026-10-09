<#
  Shared by build_web.ps1 and build_apk.ps1 (dot-sourced), so the Web/PWA
  and Android builds get the same settings and the same version.

  - Settings: build.env in the project root (git-ignored), passed to Flutter
    with --dart-define-from-file:
        API_BASE_URL=https://<production API host>
        API_KEY=<client API key>
  - Version: pubspec.yaml build name + git commit count as build number,
    e.g. 0.1.0+57. Also compiled in as APP_VERSION (stored with each session).
#>

$ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$BuildEnvFile = Join-Path $ProjectRoot 'build.env'

function Fail([string]$msg) {
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

function Read-BuildEnv {
  $values = @{}
  if (-not (Test-Path $BuildEnvFile)) { return $values }
  foreach ($line in Get-Content $BuildEnvFile) {
    if ($line -match '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$') {
      $values[$Matches[1]] = $Matches[2]
    }
  }
  return $values
}

# Stops a release build that could not reach the API from users' devices.
function Assert-ReleaseApi([hashtable]$values, [switch]$AllowInsecureApi) {
  $url = $values['API_BASE_URL']
  if (-not $url -or -not $values['API_KEY']) {
    Fail "build.env must set API_BASE_URL and API_KEY (see docs\RELEASE.md). Without them the app never uploads screenings or chat logs."
  }
  if ($AllowInsecureApi) {
    Write-Warning "API checks skipped (-AllowInsecureApi): $url. Do not share this build."
    return
  }
  if ($url -match '^https?://(localhost|127\.|10\.0\.2\.2|0\.0\.0\.0)') {
    Fail "API_BASE_URL points at '$url': on a phone or browser that is the user's own device, not your server."
  }
  if ($url -notmatch '^https://') {
    Fail "API_BASE_URL must use https:// ($url). Android blocks plain http and an https site cannot call an http API."
  }
  if ($values['API_KEY'] -eq 'stw_dev_client_key_12345') {
    Write-Warning 'API_KEY is the public development key from .env.example; replace it on the server and in build.env.'
  }
}

function Get-BuildInfo {
  $pubspec = Get-Content (Join-Path $ProjectRoot 'pubspec.yaml') -Raw
  if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    Fail 'Could not read the version from pubspec.yaml.'
  }
  $name = $Matches[1]
  Push-Location $ProjectRoot
  $count = (& git rev-list --count HEAD 2>$null)
  $rev = (& git rev-parse --short HEAD 2>$null)
  $dirty = [bool](& git status --porcelain 2>$null)
  Pop-Location
  if (-not $count) { $count = '1'; $rev = 'nogit' }
  $label = "$name+$count ($rev$(if ($dirty) { '+changes' }))"
  return [pscustomobject]@{
    Name = $name
    Number = [int]$count
    Rev = $rev
    Dirty = $dirty
    Label = $label
  }
}

# Flutter arguments shared by every release build.
function Get-ReleaseArgs($info) {
  return @(
    "--dart-define-from-file=$BuildEnvFile",
    "--dart-define=APP_VERSION=$($info.Label)",
    "--build-name=$($info.Name)",
    "--build-number=$($info.Number)"
  )
}
