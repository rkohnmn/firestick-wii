param([string]$Serial,[string]$FireTvIp)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$installed=(Shell @('pm','list','packages')) -join "`n"
if ($installed -notmatch '(?m)^package:io\.github\.firestickwii\r?$') { throw 'Install and test Wii launcher first.' }
Say 'IMPORTANT: Fire OS may reject a third-party HOME default. We will NOT disable the stock launcher.'
Say 'First verify the Wii menu has actually opened on the HDMI display and Settings still works.'
ConfirmLiteral 'I confirm Wii menu, input, and Settings work and I have an ADB recovery method' 'WORKS'
$dir=PrivateDir 'state'
$homeFile=Join-Path $dir 'previous-home.txt'
$homeDevice=Join-Path $dir 'previous-home-device.txt'
$homeFingerprint=Join-Path $dir 'previous-home-fingerprint.txt'
$fingerprint=GetProp 'ro.build.fingerprint'
if (-not $fingerprint -or $fingerprint -match '[\r\n]') { throw 'Cannot identify current firmware for HOME recovery.' }
if (Test-Path $homeFile) {
  if (-not (Test-Path $homeDevice) -or -not (Test-Path $homeFingerprint)) { throw 'Legacy HOME backup is unbound. Restore or verify it manually before trying again; will not overwrite it.' }
  if ((Get-Content -Raw $homeDevice).Trim() -cne $script:AdbSerial -or (Get-Content -Raw $homeFingerprint).Trim() -cne $fingerprint) {
    throw 'Existing original-HOME backup belongs to another device. Refusing to overwrite it.'
  }
  Say 'Preserving the original HOME recovery record from the first activation attempt.'
} else {
  if ((Test-Path $homeDevice) -or (Test-Path $homeFingerprint)) { throw 'Orphaned HOME device-binding files. Inspect recovery state manually.' }
  $resolved=@(Shell @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME') |
    Where-Object { $_ -match '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$' })
  if ($resolved.Count -ne 1 -or $resolved[0] -match '^io\.github\.firestickwii/') {
    throw 'Cannot unambiguously identify the original non-Wii HOME. Refusing HOME change without a recoverable baseline.'
  }
  $resolved[0] | Set-Content -Encoding UTF8 $homeFile
  $script:AdbSerial | Set-Content -Encoding ASCII $homeDevice
  $fingerprint | Set-Content -Encoding UTF8 $homeFingerprint
}
ConfirmLiteral 'Attempt reversible Android HOME selection (may not override Amazon Home)?' 'HOME'
$cmd=Shell @('cmd','package','set-home-activity','--user','0','io.github.firestickwii/com.gathin.tvhome.WiiMenuActivity')
Write-Host ($cmd -join "`n")
$res=(Shell @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')) -join "`n"
if ($res -notmatch 'io\.github\.firestickwii') {
  Write-Warning "Fire OS did not select the Wii app as HOME. Actual: $res. Amazon Home remains enabled. Do not disable it."
} else { Say "Selected launcher: $res. Recheck physical Home remote button." }
