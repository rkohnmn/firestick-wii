param([string]$Serial,[string]$FireTvIp,[switch]$DownloadOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
$cfg = JsonPreferences
$tag = $cfg.browser.releaseTag
if ($tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Unrecognized release tag.' }
$dest=PrivateDir 'downloads'
$assetName = "tvbro-$($tag.Substring(1))-generic-geckoExcluded.apk"
$apk=Join-Path $dest $assetName
if (-not (Test-Path $apk)) {
  Say 'Retrieving TV Bro release metadata directly from its official GitHub project.'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $headers=@{'User-Agent'='firestick-wii-installer';'Accept'='application/vnd.github+json'}
  $uri="https://api.github.com/repos/truefedex/tv-bro/releases/tags/$tag"
  $release=Invoke-RestMethod -Uri $uri -Headers $headers -UseBasicParsing
  $matches = @($release.assets | Where-Object { $_.name -match 'geckoExcluded.*\.apk$' -and $_.browser_download_url -match '^https://github\.com/truefedex/tv-bro/' })
  if ($matches.Count -ne 1) {
    throw "Expected exactly one official Gecko Excluded APK asset, found $($matches.Count). Inspect $uri manually."
  }
  $asset=$matches[0]
  $assetName=$asset.name
  $apk=Join-Path $dest $assetName
  Say "Downloading $assetName ($($asset.size) bytes)"
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $apk -UseBasicParsing
  if ((Get-Item $apk).Length -ne [long]$asset.size) { throw 'APK file length differs from published release metadata.' }
}
$hash=(Get-FileHash -Algorithm SHA256 -Path $apk).Hash
$record="tag=$tag`nfile=$assetName`nsha256=$hash`n"
$record | Set-Content -Encoding ASCII (Join-Path $dest 'tvbro-checksum.txt')
Say "SHA256: $hash (recorded locally; upstream signature not independently verified)"
if ($DownloadOnly) {
  Say "TV Bro APK downloaded and verified: $apk"
  return
}
[void](SelectDevice $Serial $FireTvIp)
$api = [int](GetProp 'ro.build.version.sdk')
if ($api -lt 26) { throw 'TV Bro 2.1.6 requires Android API 26 or later.' }
ConfirmLiteral 'Install this third-party APK from the official TV Bro GitHub release?' 'INSTALL'
$out=Device @('install','-r',$apk)
Write-Host ($out -join "`n")
if (($out -join ' ') -notmatch 'Success') { throw 'ADB did not confirm install.' }
$pkgs=(Shell @('pm','list','packages')) -join "`n"
if ($pkgs -notmatch 'com\.phlox\.tvwebbrowser') { Write-Warning 'Package name differed or install was not visible. Inspect manually.' }
Say 'Launch TV Bro on the television and test keyboard navigation, ordinary sites, and HTTPS. Never disable WebView.'
