param(
  [string]$FireTvIp,
  [string]$Serial,
  [switch]$SkipBrowser,
  [switch]$SkipLauncher,
  [switch]$SkipDebloat,
  [switch]$SkipVendor
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/scripts/common.ps1"
Say 'FIRESTICK-WII guided one-run setup (Windows 10 / Fire OS). No rooting or flashing.'
Say 'First verify the Stick reaches a TV through HDMI. Windows HDMI outputs are NOT capture inputs.'
Say 'USB micro-B may supply power but may NOT expose ADB; the MT65xx Preloader driver is not ADB.'
if (-not $FireTvIp -and -not $Serial) {
  Say 'ADB may work over your USB cable. If it does not, turn on ADB debugging on the TV, then rerun with -FireTvIp <IP>.'
}
& "$PSScriptRoot/scripts/diagnose.ps1" -FireTvIp $FireTvIp -Serial $Serial
$api=SelectDevice $Serial $FireTvIp
$dev=$script:AdbSerial
if ($api -lt 26) { throw 'The Wii project requires Android 8/API26 or newer.' }
$session=Get-Date -Format 'yyyyMMdd-HHmmss'
$folder=Join-Path (PrivateDir 'backups') $session
New-Item -ItemType Directory -Force $folder | Out-Null
Snapshot $folder
$session | Set-Content -Encoding ASCII (Join-Path (PrivateDir 'state') 'latest-backup.txt')
if (-not $SkipVendor) { & "$PSScriptRoot/scripts/get-sources.ps1" }
if (-not (Test-Path "$PSScriptRoot/third_party/wii-tv/LICENSE")) { throw 'Missing Wii launcher source. Run scripts/get-sources.ps1 first.' }
if (-not (Test-Path "$PSScriptRoot/third_party/dumbtv/LICENSE")) { throw 'Missing dumbtv source. Run scripts/get-sources.ps1 first.' }
# Run upstream preflight ONLY if Git Bash exists; do not execute any upstream all.sh, launcher.sh or debloat.sh.
$bash=Get-Command bash.exe -ErrorAction SilentlyContinue
if ($bash) {
  Say 'Upstream dumbtv preflight is available; running its read-only snapshot.'
  Push-Location "$PSScriptRoot/third_party/dumbtv"
  try {
    $env:ANDROID_SERIAL=$dev
    & $bash.Source 'scripts/preflight.sh'
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Upstream preflight returned an error; custom snapshot was retained.' }
  } finally { Pop-Location }
} else { Say 'Git Bash unavailable; own ADB read-only snapshot was saved instead.' }
if (-not $SkipBrowser) {
  $pkgs=(Shell @('pm','list','packages')) -join "`n"
  if ($pkgs -notmatch 'package:com\.phlox\.tvwebbrowser') {
    & "$PSScriptRoot/scripts/install-browser.ps1" -Serial $dev
  } else { Say 'TV Bro is already installed; will not reinstall.' }
  Say 'TEST TV Bro on HDMI display. Navigate https://example.com and your ordinary websites.'
  $answer=Read-Host 'Type BROWSER only if TV Bro works with navigation and HTTPS (or press Enter to skip)'
  if ($answer -ceq 'BROWSER') {
    'Manual browser test confirmed' | Set-Content -Encoding ASCII "$PSScriptRoot/state/browser-tested.ok"
  }
}
Say 'AIRSCREEN: Open Amazon Appstore on Fire TV and install official AirScreen by Ionitech.'
Say 'Then test iPhone via Control Center > Screen Mirroring; Pixel via Cast/Google Home.'
Say 'Both phones must have actual successful screen sharing, not just receiver detection.'
$answer=Read-Host 'Type MIRROR only if BOTH Pixel and iPhone mirroring work (or Enter to skip)'
if ($answer -ceq 'MIRROR') {
  'Manual iPhone + Pixel tests confirmed' | Set-Content -Encoding ASCII "$PSScriptRoot/state/mirroring-tested.ok"
}
if (-not $SkipLauncher) {
  & "$PSScriptRoot/scripts/build-launcher.ps1" -Serial $dev
  Say 'TEST Wii menu navigation and the Settings button on your HDMI display.'
  $answer=Read-Host 'Type WII only if the launcher and Settings work (or Enter to skip)'
  if ($answer -ceq 'WII') {
    'Manual launcher navigation + Settings confirmed' | Set-Content -Encoding ASCII "$PSScriptRoot/state/launcher-tested.ok"
    Say 'You can now separately attempt HOME takeover with scripts/activate-home.ps1. Fire OS may reject it.'
  }
}
& "$PSScriptRoot/scripts/verify.ps1" -Serial $dev
if (-not $SkipDebloat) {
  Say 'Review a conservative disable-only plan. Existing streaming apps, browser, mirroring, and stock Home are excluded.'
  & "$PSScriptRoot/scripts/plan-debloat.ps1" -Serial $dev
  $answer=Read-Host 'Apply plan now ONLY after all manual tests passed? Type REVIEWED (or Enter to skip)'
  if ($answer -ceq 'REVIEWED') {
    & "$PSScriptRoot/scripts/apply-debloat.ps1" -Serial $dev
    & "$PSScriptRoot/scripts/verify.ps1" -Serial $dev
  }
}
Say 'Setup pass completed. Backups/ and state/ are local and git-ignored; never upload to GitHub.'
Say 'To try Wii as Home: powershell -File scripts/activate-home.ps1 -Serial <your ADB serial>.'
Say 'Restore: powershell -File scripts/restore.ps1 -Serial <your ADB serial>.'
