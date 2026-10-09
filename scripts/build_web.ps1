<#
.SYNOPSIS
  Release build of the Web app / PWA into build\web.

.DESCRIPTION
  flutter build web with build.env settings, CanvasKit bundled (so the PWA
  also starts offline), then tool\generate_service_worker.dart writes
  build\web\sw.js with a new cache version for this build.

  deploy_web.ps1 runs this; run it alone to test a build locally.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1
#>
param([switch]$AllowInsecureApi)

. (Join-Path $PSScriptRoot 'build_common.ps1')

Assert-ReleaseApi (Read-BuildEnv) -AllowInsecureApi:$AllowInsecureApi
$info = Get-BuildInfo
Write-Host "Building Web/PWA $($info.Label)" -ForegroundColor Cyan

Push-Location $ProjectRoot
try {
  $flutterArgs = @('build', 'web', '--release', '--no-web-resources-cdn') + (Get-ReleaseArgs $info)
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) { Fail 'flutter build web failed.' }
  & dart run tool/generate_service_worker.dart
  if ($LASTEXITCODE -ne 0) { Fail 'Service worker generation failed.' }
} finally {
  Pop-Location
}
Write-Host "Web/PWA $($info.Label) built in build\web" -ForegroundColor Green
