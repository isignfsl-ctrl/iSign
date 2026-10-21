# One-command release: builds the signed APK, builds the admin site, deploys
# the admin site to Firebase Hosting, publishes the APK as a GitHub release
# asset (public repo), then publishes the version doc the in-app update
# popup reads (Firestore config/appVersion).
#
#   .\release.ps1 -Notes "What's new in this release"
#   .\release.ps1 -Notes "Critical fix" -ForceUpdate
param(
    [string]$Notes = "",
    [switch]$ForceUpdate
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 1) Version truth = pubspec "version: 1.0.1+2"  (name + build number)
$m = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)' | Select-Object -First 1).Matches[0]
$parts = $m.Groups[1].Value.Split('+')
$versionName = $parts[0]
$versionCode = [int]$parts[1]
Write-Host "Releasing iSign $versionName (build $versionCode)..." -ForegroundColor Cyan

# 2) Signed release APK (versionCode/versionName come from pubspec via gradle)
flutter build apk --release --no-pub
if ($LASTEXITCODE -ne 0) { throw "APK build failed" }

# 3) Admin web build + deploy (this wipes admin/build/web)
Push-Location admin
flutter build web --release --no-pub
if ($LASTEXITCODE -ne 0) { throw "Admin web build failed" }
firebase deploy --only hosting --project isign-fsl --non-interactive
if ($LASTEXITCODE -ne 0) { throw "Hosting deploy failed" }
Pop-Location

# 4) Publish the APK as a GitHub release asset (public repo => direct URL)
$apkUrl = (node (Join-Path $PSScriptRoot 'tools\publish_apk.mjs') `
    (Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk') `
    $versionName $versionCode $Notes | Select-Object -Last 1)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apkUrl)) { throw "APK publish failed" }

# 5) Publish the version doc the app polls
$forceFlag = if ($ForceUpdate) { 'true' } else { 'false' }
node (Join-Path $PSScriptRoot 'tools\set_app_version.mjs') $versionCode $versionName $apkUrl $Notes $forceFlag
if ($LASTEXITCODE -ne 0) { throw "Version doc update failed" }

Write-Host "Released $versionName ($versionCode) -> $apkUrl" -ForegroundColor Green
