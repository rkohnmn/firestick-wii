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
$original=Shell @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
$original | Set-Content -Encoding UTF8 (Join-Path $dir 'previous-home.txt')
ConfirmLiteral 'Attempt reversible Android HOME selection (may not override Amazon Home)?' 'HOME'
$cmd=Shell @('cmd','package','set-home-activity','--user','0','io.github.firestickwii/com.gathin.tvhome.WiiMenuActivity')
Write-Host ($cmd -join "`n")
$res=(Shell @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')) -join "`n"
if ($res -notmatch 'io\.github\.firestickwii') {
  Write-Warning "Fire OS did not select the Wii app as HOME. Actual: $res. Amazon Home remains enabled. Do not disable it."
} else { Say "Selected launcher: $res. Recheck physical Home remote button." }
