param([string]$FireTvIp,[string]$Serial)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
Say 'USB / ADB probe. USB enumeration below is diagnostic only.'
$present = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
  $_.FriendlyName -match 'Android|ADB|MT65|Preloader|MediaTek|Fire TV|Unknown USB'
}
if ($present) {
  $present | Select-Object Status,Class,FriendlyName,InstanceId | Format-Table -AutoSize
} else {
  Write-Host 'No matching Android/MediaTek USB devices currently connected.' -ForegroundColor Yellow
}
$preloaderHistory = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
  $_.FriendlyName -match 'MT65xx Preloader' -and -not $_.Present
}
if ($preloaderHistory) {
  Write-Host 'Note: MT65xx Preloader driver was previously installed on this PC, but no device is currently in Preloader mode.' -ForegroundColor Gray
}
try {
  Need 'adb'
  adb version
  if ($FireTvIp) {
    $cleanIp = ($FireTvIp -replace ':5555$', '').Trim()
    Say "Testing network ADB probe to ${cleanIp}:5555"
    & adb connect "${cleanIp}:5555" 2>&1 | Write-Host
  }
  adb devices -l
} catch {
  Write-Warning "ADB probe issue: $_"
}
Say 'If device is stuck in preloader, do not use flashing, erasing, unlock, or mtkclient.'
Say 'Power the Stick from a stable adapter and connect its HDMI to a display (a PC HDMI output is not an input).'

