param([string]$Serial,[string]$FireTvIp,[switch]$RemoveWii)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$state=PrivateDir 'state'
$log=Join-Path $state 'disabled-by-firestick-wii.txt'
if (Test-Path $log) {
  # Fail closed on wrong-device restore; old journals require an explicit manual gate.
  $journalLines=@(Get-Content $log)
  $serialLines=@($journalLines | Where-Object { $_ -clike '# adb-serial=*' })
  $fingerprintLines=@($journalLines | Where-Object { $_ -clike '# build-fingerprint=*' })
  if ($serialLines.Count -eq 0 -and $fingerprintLines.Count -eq 0) {
    ConfirmLiteral 'Legacy unbound recovery journal. Verify the connected TV manually before recovery' 'LEGACY'
  } elseif ($serialLines.Count -ne 1 -or $fingerprintLines.Count -ne 1) {
    throw 'Incomplete/ambiguous journal device binding. Do not apply to an unverified TV.'
  } else {
    $boundSerial=$serialLines[0].Substring('# adb-serial='.Length)
    $boundFingerprint=$fingerprintLines[0].Substring('# build-fingerprint='.Length)
    if ($boundSerial -cne $script:AdbSerial -or $boundFingerprint -cne (GetProp 'ro.build.fingerprint')) {
      throw 'Recovery journal belongs to another ADB device/firmware. No package states changed.'
    }
  }
  Say 'Restoring only packages journaled by firestick-wii. Existing disabled states were never touched.'
  $pkgs = @($journalLines | ForEach-Object { $_.Trim() } | Where-Object { $_ -cmatch '^[A-Za-z][A-Za-z0-9_.]+$' } | Select-Object -Unique)
  $failed = @()
  foreach($pkg in $pkgs) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      $out = & adb -s $script:AdbSerial shell pm enable --user 0 $pkg 2>&1
    } finally {
      $ErrorActionPreference = $prev
    }
    Write-Host "$pkg : $($out -join ' ')"
    if ($LASTEXITCODE -ne 0 -or ($out -join ' ') -match 'Exception|Error|Failure|Failed|Unknown package') {
      Write-Warning "Failed to enable $pkg"
      $failed += $pkg
    }
  }
  if ($failed.Count -eq 0) {
    Rename-Item $log ('disabled-restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
    Say 'All journaled packages successfully restored.'
  } else {
    Write-Warning "Some packages could not be enabled: $($failed -join ', '). Recovery log retained at $log."
  }
}
$home=(Join-Path $state 'previous-home.txt')
if (Test-Path $home) {
  $homeSerial=Join-Path $state 'previous-home-device.txt'
  $homeFingerprint=Join-Path $state 'previous-home-fingerprint.txt'
  if (-not (Test-Path $homeSerial) -and -not (Test-Path $homeFingerprint)) {
    ConfirmLiteral 'Legacy original-HOME backup is not device-bound. Verify device manually' 'LEGACY'
  } elseif (-not (Test-Path $homeSerial) -or -not (Test-Path $homeFingerprint)) {
    throw 'Incomplete original-HOME device binding. Refusing HOME change.'
  } elseif ((Get-Content -Raw $homeSerial).Trim() -cne $script:AdbSerial -or
          (Get-Content -Raw $homeFingerprint).Trim() -cne (GetProp 'ro.build.fingerprint')) {
    throw 'Original-HOME backup belongs to another device/firmware. Refusing HOME change.'
  }
  $line=@(Get-Content $home | Where-Object { $_ -match '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$' } | Select-Object -Last 1)
  if ($line.Count) {
    Write-Host "Previously resolved Home: $($line[0])"
    ConfirmLiteral 'Attempt to restore original Home selection?' 'HOME'
    $out=Shell @('cmd','package','set-home-activity','--user','0',$line[0])
    Write-Host ($out -join "`n")
    if (($out -join ' ') -match 'Exception|Error|Failure|Failed') { throw 'Android rejected the HOME restore. Retaining original-HOME recovery record.' }
  }
}
if ($RemoveWii) {
  ConfirmLiteral 'Uninstall ONLY our Wii launcher package (not your streaming apps)?' 'UNINSTALL'
  Device @('uninstall','io.github.firestickwii') | Write-Host
}
Say 'Restore finished. Private backup data left intact. No factory reset was performed.'
