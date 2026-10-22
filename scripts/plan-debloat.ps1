param([string]$Serial,[string]$FireTvIp,[switch]$IncludeOtaHelpers)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$list=Join-Path $script:Root 'third_party/dumbtv/data/fireos/packages.txt'
$never=Join-Path $script:Root 'third_party/dumbtv/data/fireos/never-disable.txt'
if (-not (Test-Path $list) -or -not (Test-Path $never)) { throw 'dumbtv source lists missing. Run scripts/get-sources.ps1.' }
$installed=@(Shell @('pm','list','packages') | ForEach-Object { $_ -replace '^package:','' })
$disabled=@(Shell @('pm','list','packages','-d') | ForEach-Object { $_ -replace '^package:','' })
$thirdParty=@(Shell @('pm','list','packages','-3') | ForEach-Object { $_ -replace '^package:','' })
$protected=@(Get-Content $never | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ -match '^[a-zA-Z][A-Za-z0-9_.]+$' })
$stock=@('com.amazon.vizzini','com.amazon.vizzini.ftvcds','com.amazon.cloud9')
$knownCritical=@('com.amazon.firehomestarter','com.amazon.tv.launcher','com.amazon.device.software.ota', 'com.amazon.tv.settings','com.amazon.venezia','com.amazon.avod.thirdpartyclient')
$protected += $knownCritical + $stock + $thirdParty + @('io.github.firestickwii','com.phlox.tvwebbrowser')
$plan=@()
foreach ($line in (Get-Content $list)) {
  $name=($line -split '#')[0].Trim()
  if ($name -notmatch '^[a-zA-Z][a-zA-Z0-9_.]+$') { continue }
  if ($installed -notcontains $name -or $disabled -contains $name -or $protected -contains $name) { continue }
  if ($name -match '(?i)(bluetooth|wifi|remote|settings|webview|casting|mirroring|launcher|appstore|inputmethod|cec|vizzini)') { continue }
  if (-not $IncludeOtaHelpers -and $name -match '(?i)(ota|forcedotaupdate|firebat)') { continue }
  $category=if($name -match '(?i)(alexa|\.aca$|audiohome|rtcsession)') {'Alexa'} elseif($name -match '(?i)(acr|ad|promo|recommend|tahoe|sneakpeek)') {'Ads'} else {'Optional debloat'}
  $plan += [pscustomobject]@{Package=$name;Category=$category}
}
$dir=PrivateDir 'state'
$script:AdbSerial | Set-Content -Encoding ASCII (Join-Path $dir 'debloat-device.txt')
$path=Join-Path $dir 'debloat-plan.csv'
$plan | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Say "Read-only debloat plan saved to $path ($($plan.Count) packages). No apps removed."
$plan | Format-Table -AutoSize
Say 'Excludes ALL user-installed streaming apps, Silk, remote/Settings, updates unless explicitly included.'
Say 'Do not proceed if Alexa removal affects remote pairing or your test input method.'
