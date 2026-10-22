param([string]$FireTvIp,[string]$Serial)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
Say 'USB / ADB probe. USB enumeration below is diagnostic only.'
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
  $_.FriendlyName -match 'Android|ADB|MT65|Preloader|MediaTek|Fire TV|Unknown USB'
} | Select-Object Status,Class,FriendlyName,InstanceId | Format-Table -AutoSize
if (Get-Command adb -ErrorAction SilentlyContinue) {
  adb version
  adb devices -l
} else { Write-Warning 'ADB not found. Android SDK Platform-Tools required.' }
Say 'If device is stuck in preloader, do not use flashing, erasing, unlock, or mtkclient.'
Say 'Power the Stick from a stable adapter and connect its HDMI to a display (a PC HDMI output is not an input).'
