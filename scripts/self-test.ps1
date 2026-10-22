# Project layout / statically safe source checks, no ADB device needed.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$expected = @(
 'setup.ps1', 'scripts/common.ps1', 'scripts/diagnose.ps1',
 'scripts/get-sources.ps1', 'scripts/install-browser.ps1',
 'scripts/prepare-launcher.ps1', 'scripts/build-launcher.ps1',
 'scripts/activate-home.ps1', 'scripts/plan-debloat.ps1',
 'scripts/apply-debloat.ps1', 'scripts/restore.ps1',
 'config/preferences.json', 'README.md', 'AGENTS.md'
)
foreach ($f in $expected) {
 if (-not (Test-Path (Join-Path $root $f))) { throw "Missing $f" }
}
$prefs = Get-Content -Raw (Join-Path $root 'config/preferences.json') | ConvertFrom-Json
if ($prefs.dnsFiltering -or $prefs.autoOtaBlocking -or -not $prefs.keepStockLauncherEnabled) {
 throw 'Unsafe default configuration.'
}
if ($prefs.browser.variant -cne 'geckoExcluded') { throw 'Browser variant differs from user preference.' }
Write-Host 'Static project configuration/layout check: PASS'
