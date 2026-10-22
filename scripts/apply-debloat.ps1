param([string]$Serial,[string]$FireTvIp)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$dir=PrivateDir 'state'
$plan=Join-Path $dir 'debloat-plan.csv'
if (-not (Test-Path $plan)) { throw 'Run scripts/plan-debloat.ps1 first and review its contents.' }
$plannedDevice=Join-Path $dir 'debloat-device.txt'
if (-not (Test-Path $plannedDevice)) { throw 'No recorded ADB target for this plan.' }
if ((Get-Content -Raw $plannedDevice).Trim() -cne $script:AdbSerial) { throw 'Debloat plan belongs to a different ADB target. Regenerate plan after confirming the target.' }
if (-not (Test-Path (Join-Path $dir 'browser-tested.ok'))) { throw 'Missing browser-tested.ok. Create ONLY after testing TV Bro manually on the HDMI display.' }
if (-not (Test-Path (Join-Path $dir 'mirroring-tested.ok'))) { throw 'Missing mirroring-tested.ok. Create ONLY after confirming iPhone AND Pixel mirroring.' }
if (-not (Test-Path (Join-Path $dir 'launcher-tested.ok'))) { throw 'Missing launcher-tested.ok. Create ONLY after confirming Wii launch and access to Settings.' }
$items=@(Import-Csv $plan)
if (-not $items.Count) { Say 'Nothing to disable.'; return }
$currentlyDisabled=@(Shell @('pm','list','packages','-d') | ForEach-Object { ($_ -replace '^package:','').Trim() })
$allPackages=@(Shell @('pm','list','packages') | ForEach-Object { ($_ -replace '^package:','').Trim() })
$log=Join-Path $dir 'disabled-by-firestick-wii.txt'
if (Test-Path $log) { throw 'An earlier apply log exists. Restore before a new debloat pass; refusing to overwrite recovery log.' }
$logFile=[IO.File]::Open($log,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
$writer=New-Object System.IO.StreamWriter($logFile,(New-Object System.Text.UTF8Encoding $false))
try {
  Say 'This changes the package states. It does NOT uninstall apps or flash partitions.'
  $items | Format-Table -AutoSize
  ConfirmLiteral 'Apply the displayed debloat plan?' 'APPLY'
  foreach($item in $items) {
    $pkg=$item.Package
    if ($pkg -notmatch '^[a-zA-Z][a-zA-Z0-9_.]+$') { throw "Invalid package identifier $pkg" }
    if ($allPackages -notcontains $pkg -or $currentlyDisabled -contains $pkg) { continue }
    # First journal intent before modification to ensure recovery is available if the process crashes.
    $writer.WriteLine($pkg);$writer.Flush()
    $result=& adb -s $script:AdbSerial shell pm disable-user --user 0 $pkg 2>&1
    Write-Host "$pkg : $($result -join ' ')"
    if ($LASTEXITCODE -ne 0 -or ($result -join ' ') -match 'Exception|Error|Cannot disable') {
      Write-Warning "Cannot disable $pkg; stopping. The journal can restore everything attempted so far."
      throw "Package change failed for $pkg"
    }
  }
} finally { $writer.Dispose() }
Say "Finished. Recovery log: $log. Run restore.ps1 if something stops working."
