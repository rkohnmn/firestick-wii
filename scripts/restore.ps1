param([string]$Serial,[string]$FireTvIp,[switch]$RemoveWii)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$state=PrivateDir 'state'
$log=Join-Path $state 'disabled-by-firestick-wii.txt'
if (Test-Path $log) {
  Say 'Restoring only packages journaled by firestick-wii. Existing disabled states were never touched.'
  $pkgs = @(Get-Content $log | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[a-zA-Z][a-zA-Z0-9_.]+$' } | Select-Object -Unique)
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
    if ($LASTEXITCODE -ne 0 -or ($out -join ' ') -match 'Exception|Error') {
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
  $line=@(Get-Content $home | Where-Object { $_ -match '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$' } | Select-Object -Last 1)
  if ($line.Count) {
    Write-Host "Previously resolved Home: $($line[0])"
    ConfirmLiteral 'Attempt to restore original Home selection?' 'HOME'
    $out=& adb -s $script:AdbSerial shell cmd package set-home-activity --user 0 $line[0] 2>&1
    Write-Host ($out -join "`n")
  }
}
if ($RemoveWii) {
  ConfirmLiteral 'Uninstall ONLY our Wii launcher package (not your streaming apps)?' 'UNINSTALL'
  Device @('uninstall','io.github.firestickwii') | Write-Host
}
Say 'Restore finished. Private backup data left intact. No factory reset was performed.'
