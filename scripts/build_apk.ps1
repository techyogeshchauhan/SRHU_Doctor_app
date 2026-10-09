<#
.SYNOPSIS
  Release build of the Android app, ready to share.

.DESCRIPTION
  flutter build apk with the same build.env settings and version as the Web
  build, then copies it to dist\STW-Neo-<version>.apk.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1
#>
param([switch]$AllowInsecureApi)

. (Join-Path $PSScriptRoot 'build_common.ps1')

Assert-ReleaseApi (Read-BuildEnv) -AllowInsecureApi:$AllowInsecureApi
$info = Get-BuildInfo
Write-Host "Building APK $($info.Label)" -ForegroundColor Cyan

Push-Location $ProjectRoot
try {
  $flutterArgs = @('build', 'apk', '--release') + (Get-ReleaseArgs $info)
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) { Fail 'flutter build apk failed.' }
} finally {
  Pop-Location
}

$apk = Join-Path $ProjectRoot 'build\app\outputs\flutter-apk\app-release.apk'
$dist = Join-Path $ProjectRoot 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$out = Join-Path $dist "STW-Neo-$($info.Name)+$($info.Number).apk"
Copy-Item $apk $out -Force
Write-Host "APK $($info.Label): $out" -ForegroundColor Green
