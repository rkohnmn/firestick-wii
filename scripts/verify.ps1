param([string]$Serial,[string]$FireTvIp)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$pkgs=(Shell @('pm','list','packages')) -join "`n"
$home=(Shell @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')) -join "`n"
Say "Device: $(GetProp 'ro.product.model') / API $(GetProp 'ro.build.version.sdk')"
Say "Wii launcher installed: $($pkgs -match 'package:io\.github\.firestickwii')"
Say "TV Bro installed: $($pkgs -match 'package:com\.phlox\.tvwebbrowser')"
Say "Resolved Home: $home"
Say 'AirScreen version/compatibility must be verified on the TV; its package ID varies by distribution.'
Say 'Phone mirroring, remote input, streaming DRM, and visual performance require physical tests.'
Say 'Check Android System WebView and Wi-Fi manually before debloating.'
