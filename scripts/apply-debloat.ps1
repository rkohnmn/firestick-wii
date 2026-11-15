param([string]$Serial,[string]$FireTvIp,[switch]$IncludeOtaHelpers)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$dir=PrivateDir 'state'
$plan=Join-Path $dir 'debloat-plan.csv'
if (-not (Test-Path $plan)) { throw 'Run scripts/plan-debloat.ps1 first and review its contents.' }
$plannedDevice=Join-Path $dir 'debloat-device.txt'
if (-not (Test-Path $plannedDevice)) { throw 'No recorded ADB target for this plan.' }
if ((Get-Content -Raw $plannedDevice).Trim() -cne $script:AdbSerial) { throw 'Debloat plan belongs to a different ADB target. Regenerate plan after confirming the target.' }
$fingerprintFile=Join-Path $dir 'debloat-fingerprint.txt'
if (-not (Test-Path $fingerprintFile)) { throw 'Plan lacks device firmware binding; rerun plan-debloat.ps1 on the target.' }
$fingerprint=GetProp 'ro.build.fingerprint'
if (-not $fingerprint -or $fingerprint -cne (Get-Content -Raw $fingerprintFile).Trim()) { throw 'Firmware identity changed since planning. Regenerate the plan.' }
if (-not (Test-Path (Join-Path $dir 'browser-tested.ok'))) { throw 'Missing browser-tested.ok. Create ONLY after testing TV Bro manually on the HDMI display.' }
if (-not (Test-Path (Join-Path $dir 'mirroring-tested.ok'))) { throw 'Missing mirroring-tested.ok. Create ONLY after confirming iPhone AND Pixel mirroring.' }
if (-not (Test-Path (Join-Path $dir 'launcher-tested.ok'))) { throw 'Missing launcher-tested.ok. Create ONLY after confirming Wii launch and access to Settings.' }
# Manual safety gates are per-device, not reusable marker-file existence checks.
foreach($gate in @('browser-tested.ok','mirroring-tested.ok','launcher-tested.ok')) {
  $proof=@(Get-Content (Join-Path $dir $gate))
  if ($proof -cnotcontains "adb-serial=$script:AdbSerial" -or $proof -cnotcontains "build-fingerprint=$fingerprint") {
    throw "Manual test gate $gate is missing matching device/firmware proof. Retest on the physical TV through setup.ps1."
  }
}
$items=@(Import-Csv $plan)
if (-not $items.Count) { Say 'Nothing to disable.'; return }
# The CSV is a reviewed *subset*, never an authority to add packages to the allowlist.
$catalogPath=Join-Path $script:Root 'third_party/dumbtv/data/fireos/packages.txt'
$neverPath=Join-Path $script:Root 'third_party/dumbtv/data/fireos/never-disable.txt'
if (-not (Test-Path $catalogPath) -or -not (Test-Path $neverPath)) { throw 'Debloat safety lists missing; refusing all changes.' }
$catalog=@(Get-Content $catalogPath | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ -cmatch '^[A-Za-z][A-Za-z0-9_.]+$' })
$never=@(Get-Content $neverPath | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ -cmatch '^[A-Za-z][A-Za-z0-9_.]+$' })
$thirdParty=@(Shell @('pm','list','packages','-3') | ForEach-Object { ($_ -replace '^package:','').Trim() })
$critical=@('com.amazon.firehomestarter','com.amazon.tv.launcher','com.amazon.device.software.ota','com.amazon.tv.settings','com.amazon.venezia','com.amazon.avod.thirdpartyclient','com.amazon.vizzini','com.amazon.vizzini.ftvcds','com.amazon.cloud9','io.github.firestickwii','com.phlox.tvwebbrowser')
$seen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$hasOta=$false
foreach($item in $items) {
  $pkg=[string]$item.Package
  if ($pkg -cnotmatch '^[A-Za-z][A-Za-z0-9_.]+$') { throw "Invalid package identifier '$pkg' in reviewed CSV." }
  if (-not $seen.Add($pkg)) { throw "Duplicate package in CSV: $pkg" }
  if ($catalog -cnotcontains $pkg) { throw "Package outside reviewed source catalog: $pkg" }
  if ($never -ccontains $pkg -or $critical -ccontains $pkg -or $thirdParty -ccontains $pkg) { throw "Protected or user-installed package in CSV: $pkg" }
  if ($pkg -match '(?i)(bluetooth|wi.?fi|remote|settings|webview|casting|mirroring|launcher|appstore|inputmethod|cec|vizzini|silk|systemui)') { throw "Critical functionality package in CSV: $pkg" }
  if ($pkg -match '(?i)(ota|forcedotaupdate|firebat|update)') {
    if (-not $IncludeOtaHelpers) { throw "OTA/update helpers require separate -IncludeOtaHelpers opt-in: $pkg" }
    $hasOta=$true
  }
}
if ($hasOta) { ConfirmLiteral 'These OTA/update helper changes may prevent security updates. Continue?' 'OTA' }
$currentlyDisabled=@(Shell @('pm','list','packages','-d') | ForEach-Object { ($_ -replace '^package:','').Trim() })
$allPackages=@(Shell @('pm','list','packages') | ForEach-Object { ($_ -replace '^package:','').Trim() })
$log=Join-Path $dir 'disabled-by-firestick-wii.txt'
if (Test-Path $log) { throw 'An earlier apply log exists. Restore before a new debloat pass; refusing to overwrite recovery log.' }
Say 'Review this final device-specific plan before continuing.'
$items | Format-Table -AutoSize
ConfirmLiteral 'Apply the displayed debloat plan?' 'APPLY'
# Do not create a recovery journal on a declined confirmation.
$logFile=[IO.File]::Open($log,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
$writer=New-Object System.IO.StreamWriter($logFile,(New-Object System.Text.UTF8Encoding $false))
# Device binding and intents are flushed before any modification.
$writer.WriteLine("# adb-serial=$script:AdbSerial")
$writer.WriteLine("# build-fingerprint=$fingerprint")
$writer.Flush()
try {
  Say 'This changes the package states. It does NOT uninstall apps or flash partitions.'
  foreach($item in $items) {
    $pkg=$item.Package
    if ($allPackages -notcontains $pkg -or $currentlyDisabled -contains $pkg) { continue }
    # First journal intent before modification to ensure recovery is available if the process crashes.
    $writer.WriteLine($pkg);$writer.Flush()
    $result=& adb -s $script:AdbSerial shell pm disable-user --user 0 $pkg 2>&1
    Write-Host "$pkg : $($result -join ' ')"
    if ($LASTEXITCODE -ne 0 -or ($result -join ' ') -match 'Exception|Error|Failure|Failed|Cannot disable|Unknown package') {
      Write-Warning "Cannot disable $pkg; stopping. The journal can restore everything attempted so far."
      throw "Package change failed for $pkg"
    }
  }
} finally { $writer.Dispose() }
Say "Finished. Recovery log: $log. Run restore.ps1 if something stops working."
