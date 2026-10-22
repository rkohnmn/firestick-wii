param([string]$Serial,[string]$FireTvIp,[switch]$RemoveWii)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
$state=PrivateDir 'state'
$log=Join-Path $state 'disabled-by-firestick-wii.txt'
if (Test-Path $log) {
  Say 'Restoring only packages journaled by firestick-wii. Existing disabled states were never touched.'
  foreach($pkg in (Get-Content $log | Select-Object -Unique)) {
    if ($pkg -match '^[a-zA-Z][a-zA-Z0-9_.]+$') {
      $out=& adb -s $script:AdbSerial shell pm enable --user 0 $pkg 2>&1
      Write-Host "$pkg : $($out -join ' ')"
      if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to enable $pkg; recovery log retained."; return }
    }
  }
  Rename-Item $log ('disabled-restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
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
