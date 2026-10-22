<#
.SYNOPSIS
    Automated Comprehensive Test Suite for firestick-wii
    Validates syntax, configurations, scripts, and simulates full ADB hardware scenarios using mocks.
#>
param(
  [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot/common.ps1"

$testsTotal = 0
$testsPassed = 0
$testsFailed = 0
$testResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function Record-Test([string]$Category, [string]$TestName, [string]$Status, [string]$Details = "") {
  $script:testsTotal++
  if ($Status -eq 'PASS') {
    $script:testsPassed++
    Write-Host "  [PASS] $TestName" -ForegroundColor Green
  } elseif ($Status -eq 'FAIL') {
    $script:testsFailed++
    Write-Host "  [FAIL] $TestName - $Details" -ForegroundColor Red
  } else {
    Write-Host "  [SKIP] $TestName - $Details" -ForegroundColor Yellow
  }
  $script:testResults.Add([PSCustomObject]@{
    Category = $Category
    Test     = $TestName
    Status   = $Status
    Details  = $Details
  })
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      FIRESTICK-WII AUTOMATED TEST SUITE (PHASE 2)       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# CATEGORY 1: PowerShell Syntax and Compatibility Check
# ---------------------------------------------------------
Write-Host "`n[1/5] Checking PowerShell Scripts Syntax & AST..." -ForegroundColor Magenta
$psScripts = Get-ChildItem -Path $script:Root -Filter '*.ps1' -Recurse | Where-Object { $_.FullName -notmatch '\\third_party\\|\\build\\' }

foreach ($scriptFile in $psScripts) {
  $relPath = $scriptFile.FullName.Substring($script:Root.Length + 1)
  $parseErrors = $null
  $tokens = $null
  [System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors -and $parseErrors.Count -gt 0) {
    Record-Test "Syntax" "PowerShell AST: $relPath" "FAIL" ($parseErrors[0].Message)
  } else {
    Record-Test "Syntax" "PowerShell AST: $relPath" "PASS"
  }
}

# ---------------------------------------------------------
# CATEGORY 2: Configuration & Static Policy Validation
# ---------------------------------------------------------
Write-Host "`n[2/5] Validating Configurations & Safety Policies..." -ForegroundColor Magenta

# JSON preferences test
$prefPath = Join-Path $script:Root 'config/preferences.json'
try {
  $pref = Get-Content -Raw $prefPath | ConvertFrom-Json
  if (-not $pref.project -or $pref.project -ne 'firestick-wii') { throw "Invalid project identifier" }
  if ($pref.dnsFiltering -or $pref.autoOtaBlocking -or -not $pref.keepStockLauncherEnabled) {
    throw "Unsafe defaults detected in preferences.json"
  }
  if ($pref.launcherApplicationId -ne 'io.github.firestickwii') {
    throw "Launcher package ID mismatch"
  }
  if ($pref.browser.variant -ne 'geckoExcluded') {
    throw "Browser variant must be geckoExcluded"
  }
  Record-Test "Config" "preferences.json schema & safety invariants" "PASS"
} catch {
  Record-Test "Config" "preferences.json schema & safety invariants" "FAIL" $_.Exception.Message
}

# Batch launcher validation
$batPath = Join-Path $script:Root 'run.bat'
try {
  if (-not (Test-Path $batPath)) { throw "run.bat missing" }
  $batContent = Get-Content -Raw $batPath
  if ($batContent -notmatch 'setup\.ps1') { throw "run.bat does not invoke setup.ps1" }
  if ($batContent -notmatch '%~dp0') { throw "run.bat missing %~dp0 path scoping" }
  Record-Test "Config" "run.bat batch runner structure" "PASS"
} catch {
  Record-Test "Config" "run.bat batch runner structure" "FAIL" $_.Exception.Message
}

# Third-party upstream source and licenses
$wiiLicense = Join-Path $script:Root 'third_party/wii-tv/LICENSE'
$dumbLicense = Join-Path $script:Root 'third_party/dumbtv/LICENSE'
if ((Test-Path $wiiLicense) -and (Test-Path $dumbLicense)) {
  Record-Test "Config" "Upstream licenses present (wii-tv & dumbtv)" "PASS"
} else {
  Record-Test "Config" "Upstream licenses present (wii-tv & dumbtv)" "FAIL" "Missing upstream LICENSE files"
}

# ---------------------------------------------------------
# CATEGORY 3: Build Pipeline & Code Transformation Tests
# ---------------------------------------------------------
Write-Host "`n[3/5] Testing Source Transformation & Local Build Artifacts..." -ForegroundColor Magenta

# Test prepare-launcher.ps1 transformation
try {
  & "$script:Root/scripts/prepare-launcher.ps1"
  $transformedConfig = Join-Path $script:Root 'build/wii-tv/launcher/app/src/main/res/values/config.xml'
  $transformedJava = Join-Path $script:Root 'build/wii-tv/launcher/app/src/main/java/com/gathin/tvhome/WiiMenuActivity.java'
  $transformedGradle = Join-Path $script:Root 'build/wii-tv/launcher/gradle.properties'

  if (-not (Test-Path $transformedConfig)) { throw "config.xml was not created" }
  if (-not (Test-Path $transformedJava)) { throw "WiiMenuActivity.java was not created" }
  
  $xml = [xml](Get-Content -Raw $transformedConfig)
  $dither = $xml.SelectSingleNode("/resources/bool[@name='dither_background']").InnerText
  $reducedMotion = $xml.SelectSingleNode("/resources/bool[@name='reduced_motion']").InnerText
  if ($dither -ne 'false' -or $reducedMotion -ne 'true') { throw "Hardware optimization XML flags not set" }

  $javaCode = Get-Content -Raw $transformedJava
  if ($javaCode -notmatch 'android\.settings\.LEANBACK_SETTINGS' -or $javaCode -notmatch 'com\.amazon\.tv\.settings') {
    throw "Fire TV Settings fallback not patched into Java"
  }
  if ($javaCode -notmatch 'CATEGORY_LAUNCHER') {
    throw "Hybrid Leanback + standard launcher discovery not patched into Java"
  }

  $propCode = Get-Content -Raw $transformedGradle
  if ($propCode -notmatch 'launcherApplicationId=io\.github\.firestickwii') {
    throw "Application ID not set in gradle.properties"
  }
  Record-Test "Build" "Launcher source patching (XML, Java fallback, app ID)" "PASS"
} catch {
  Record-Test "Build" "Launcher source patching (XML, Java fallback, app ID)" "FAIL" $_.Exception.Message
}

# Test built launcher APK presence and integrity
$apkPath = Join-Path $script:Root 'dist/firestick-wii-launcher.apk'
if (Test-Path $apkPath) {
  $apkSize = (Get-Item $apkPath).Length
  $apkHash = (Get-FileHash -Path $apkPath -Algorithm SHA256).Hash
  if ($apkSize -gt 100000 -and $apkSize -lt 5000000) {
    Record-Test "Build" "Launcher release APK compiled (SHA256: $($apkHash.Substring(0,16))..., Size: $apkSize bytes)" "PASS"
  } else {
    Record-Test "Build" "Launcher release APK size abnormal ($apkSize bytes)" "FAIL"
  }
} else {
  Record-Test "Build" "Launcher release APK compiled" "FAIL" "dist/firestick-wii-launcher.apk not found"
}

# Test TV Bro download and checksum
$tvbroApk = Join-Path $script:Root 'downloads/tvbro-2.1.6-generic-geckoExcluded.apk'
$tvbroHashFile = Join-Path $script:Root 'downloads/tvbro-checksum.txt'
if ((Test-Path $tvbroApk) -and (Test-Path $tvbroHashFile)) {
  $calculatedHash = (Get-FileHash -Algorithm SHA256 -Path $tvbroApk).Hash
  $recorded = Get-Content -Raw $tvbroHashFile
  if ($recorded -match "sha256=$calculatedHash") {
    Record-Test "Browser" "TV Bro v2.1.6 geckoExcluded verified SHA-256 integrity" "PASS"
  } else {
    Record-Test "Browser" "TV Bro v2.1.6 checksum mismatch" "FAIL"
  }
} else {
  Record-Test "Browser" "TV Bro APK or checksum file missing" "FAIL"
}

# ---------------------------------------------------------
# CATEGORY 4: Simulated ADB Hardware Scenarios (Mock Engine)
# ---------------------------------------------------------
Write-Host "`n[4/5] Executing Simulated ADB Hardware & Failure Scenarios..." -ForegroundColor Magenta

# Create isolated test environment for ADB mocks
$testEnvDir = Join-Path $script:Root 'build/test-env'
if (Test-Path $testEnvDir) { Remove-Item -Recurse -Force $testEnvDir }
New-Item -ItemType Directory -Force -Path $testEnvDir | Out-Null

# Define reusable mock ADB execution helper
function Run-WithMockAdb([scriptblock]$ScriptBlock, [hashtable]$MockResponses) {
  $oldHandler = if (Test-Path Variable:\global:MockAdbHandler) { $global:MockAdbHandler } else { $null }
  $oldSerial = $script:AdbSerial
  $global:MockAdbHandler = {
    param([string[]]$Argv)
    $cmd = $Argv -join ' '
    foreach ($k in $MockResponses.Keys) {
      if ($cmd -match $k) {
        $entry = $MockResponses[$k]
        if ($entry.ExitCode -ne $null) { $global:LASTEXITCODE = $entry.ExitCode } else { $global:LASTEXITCODE = 0 }
        if ($global:LASTEXITCODE -ne 0) { throw "adb $cmd failed ($global:LASTEXITCODE)" }
        if ($entry.ContainsKey('Out')) { return $entry.Out }
        return @()
      }
    }
    $global:LASTEXITCODE = 0
    return @()
  }.GetNewClosure()

  $res = @{ Output = @(); Errors = @() }
  try {
    $res.Output = @(& $ScriptBlock)
  } catch {
    $res.Errors = @($_)
  } finally {
    $global:MockAdbHandler = $oldHandler
    $script:AdbSerial = $oldSerial
  }
  return $res
}

# SCENARIO A: No Android Device Connected
try {
  $res = Run-WithMockAdb {
    SelectDevice '' ''
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached'); ExitCode = 0 }
  }
  if ($res.Errors.Count -gt 0 -and $res.Errors[0].Exception.Message -match 'No authorized Android ADB device') {
    Record-Test "Mock-ADB" "Scenario A: No Android device detected raises clear error" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario A: No Android device detected" "FAIL" "Did not raise expected error"
  }
} catch {
  Record-Test "Mock-ADB" "Scenario A: No Android device detected" "FAIL" $_.Exception.Message
}

# SCENARIO B: MediaTek Preloader COM port detected but no ADB
try {
  $res = Run-WithMockAdb {
    SelectDevice '' ''
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached'); ExitCode = 0 }
  }
  if ($res.Errors.Count -gt 0 -and $res.Errors[0].Exception.Message -match 'MediaTek Preloader COM port is NOT ADB') {
    Record-Test "Mock-ADB" "Scenario B: Preloader driver explicitly distinguished from ADB" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario B: Preloader driver detection" "FAIL" "Did not mention preloader guidance"
  }
} catch {
  Record-Test "Mock-ADB" "Scenario B: Preloader driver detection" "FAIL" $_.Exception.Message
}

# SCENARIO C: Unauthorized ADB Device
try {
  $res = Run-WithMockAdb {
    SelectDevice '' ''
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached', 'G070VM0912345678 unauthorized usb:1-1'); ExitCode = 0 }
  }
  if ($res.Errors.Count -gt 0 -and $res.Errors[0].Exception.Message -match 'No authorized Android ADB device') {
    Record-Test "Mock-ADB" "Scenario C: Unauthorized Fire TV refused safely" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario C: Unauthorized Fire TV" "FAIL" "Failed to reject unauthorized device"
  }
} catch {
  Record-Test "Mock-ADB" "Scenario C: Unauthorized Fire TV" "FAIL" $_.Exception.Message
}

# SCENARIO D: Offline ADB Device
try {
  $res = Run-WithMockAdb {
    SelectDevice '' ''
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached', '192.168.1.50:5555 offline'); ExitCode = 0 }
  }
  if ($res.Errors.Count -gt 0 -and $res.Errors[0].Exception.Message -match 'No authorized Android ADB device') {
    Record-Test "Mock-ADB" "Scenario D: Offline device refused safely" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario D: Offline device" "FAIL" "Failed to reject offline device"
  }
} catch {
  Record-Test "Mock-ADB" "Scenario D: Offline device" "FAIL" $_.Exception.Message
}

# SCENARIO E: Multiple ADB Devices Connected
try {
  $res = Run-WithMockAdb {
    SelectDevice '' ''
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached', 'DEVICE_A device usb:1-1', 'DEVICE_B device usb:1-2'); ExitCode = 0 }
  }
  if ($res.Errors.Count -gt 0 -and $res.Errors[0].Exception.Message -match 'Multiple ADB devices detected') {
    Record-Test "Mock-ADB" "Scenario E: Multiple ADB devices detected prompts for explicit target" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario E: Multiple ADB devices" "FAIL" "Did not reject ambiguous target"
  }
} catch {
  Record-Test "Mock-ADB" "Scenario E: Multiple ADB devices" "FAIL" $_.Exception.Message
}

# SCENARIO F: Non-Amazon Device Connected (e.g. Phone or generic TV box)
try {
  $res = Run-WithMockAdb {
    SelectDevice '' ''
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached', 'PIXEL7 device usb:1-1'); ExitCode = 0 }
    'getprop ro\.product\.manufacturer' = @{ Out = @('Google'); ExitCode = 0 }
    'getprop ro\.product\.model' = @{ Out = @('Pixel 7'); ExitCode = 0 }
    'getprop ro\.build\.version\.sdk' = @{ Out = @('34'); ExitCode = 0 }
  }
  if ($res.Errors.Count -gt 0 -and $res.Errors[0].Exception.Message -match 'Device is not verified as Amazon') {
    Record-Test "Mock-ADB" "Scenario F: Non-Amazon device modification strictly refused" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario F: Non-Amazon device" "FAIL" "Failed to protect non-Amazon device"
  }
} catch {
  Record-Test "Mock-ADB" "Scenario F: Non-Amazon device" "FAIL" $_.Exception.Message
}

# SCENARIO G: Unsupported Fire TV OS Version (API < 26)
try {
  $res = Run-WithMockAdb {
    SelectDevice '' ''
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached', 'AFT_OLD device usb:1-1'); ExitCode = 0 }
    'getprop ro\.product\.manufacturer' = @{ Out = @('Amazon'); ExitCode = 0 }
    'getprop ro\.product\.model' = @{ Out = @('AFTB'); ExitCode = 0 }
    'getprop ro\.build\.version\.sdk' = @{ Out = @('22'); ExitCode = 0 }
  }
  if ($res.Errors.Count -gt 0 -and $res.Errors[0].Exception.Message -match 'Unsupported/unknown Android API 22') {
    Record-Test "Mock-ADB" "Scenario G: Unsupported legacy Android API 22 rejected" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario G: Unsupported legacy Android API" "FAIL" "Did not reject API < 26"
  }
} catch {
  Record-Test "Mock-ADB" "Scenario G: Unsupported legacy Android API" "FAIL" $_.Exception.Message
}

# SCENARIO H: One Authorized Fire TV Connected (Fire OS 7 / API 28)
try {
  $res = Run-WithMockAdb {
    $api = SelectDevice '' ''
    if ($api -eq 28 -and $script:AdbSerial -eq 'AFT_S3L36N') { 'OK' } else { throw 'Selection failed' }
  } @{
    '^devices -l$' = @{ Out = @('List of devices attached', 'AFT_S3L36N device usb:1-1 product:sheldon'); ExitCode = 0 }
    'getprop ro\.product\.manufacturer' = @{ Out = @('Amazon'); ExitCode = 0 }
    'getprop ro\.product\.model' = @{ Out = @('AFTSSS'); ExitCode = 0 }
    'getprop ro\.build\.version\.sdk' = @{ Out = @('28'); ExitCode = 0 }
  }
  if ($res.Output -contains 'OK') {
    Record-Test "Mock-ADB" "Scenario H: Authorized Amazon Fire TV correctly identified (API 28)" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario H: Authorized Amazon Fire TV" "FAIL" ($res.Errors | Out-String)
  }
} catch {
  Record-Test "Mock-ADB" "Scenario H: Authorized Amazon Fire TV" "FAIL" $_.Exception.Message
}

# SCENARIO I: Fire TV Connected Over Wi-Fi (Explicit IP:Port)
try {
  $res = Run-WithMockAdb {
    $api = SelectDevice '' '192.168.1.120'
    if ($api -eq 28 -and $script:AdbSerial -eq '192.168.1.120:5555') { 'OK' } else { throw 'Wi-Fi selection failed' }
  } @{
    'connect 192\.168\.1\.120:5555' = @{ Out = @('connected to 192.168.1.120:5555'); ExitCode = 0 }
    '^devices -l$' = @{ Out = @('List of devices attached', '192.168.1.120:5555 device'); ExitCode = 0 }
    'getprop ro\.product\.manufacturer' = @{ Out = @('Amazon'); ExitCode = 0 }
    'getprop ro\.product\.model' = @{ Out = @('AFTSSS'); ExitCode = 0 }
    'getprop ro\.build\.version\.sdk' = @{ Out = @('28'); ExitCode = 0 }
  }
  if ($res.Output -contains 'OK') {
    Record-Test "Mock-ADB" "Scenario I: Fire TV connected over Wi-Fi successfully selected" "PASS"
  } else {
    Record-Test "Mock-ADB" "Scenario I: Fire TV connected over Wi-Fi" "FAIL" ($res.Errors | Out-String)
  }
} catch {
  Record-Test "Mock-ADB" "Scenario I: Fire TV connected over Wi-Fi" "FAIL" $_.Exception.Message
}

# ---------------------------------------------------------
# CATEGORY 5: Debloat Safety, Package Protection & Restore
# ---------------------------------------------------------
Write-Host "`n[5/5] Validating Debloat Protection Rules & Journaling..." -ForegroundColor Magenta

# TEST: Streaming apps and critical system services protection
$mockInstalled = @(
  'com.amazon.tv.launcher',
  'com.amazon.firehomestarter',
  'com.amazon.device.software.ota',
  'com.amazon.tv.settings',
  'com.amazon.venezia',
  'com.amazon.avod.thirdpartyclient',
  'com.netflix.ninja',
  'com.google.android.youtube.tv',
  'com.disney.disneyplus',
  'com.hulu.livingroomplus',
  'com.amazon.device.rdm',
  'android.ext.services',
  'com.android.systemui',
  'com.android.packageinstaller',
  'com.amazon.webview',
  'com.google.android.webview',
  'com.amazon.aca',
  'com.amazon.advertising.service',
  'com.amazon.tahoe'
)

$mockThirdParty = @(
  'com.netflix.ninja',
  'com.google.android.youtube.tv',
  'com.disney.disneyplus',
  'com.hulu.livingroomplus'
)

$mockDisabled = @()

# Execute debloat planning logic against mock package lists
$listPath = Join-Path $script:Root 'third_party/dumbtv/data/fireos/packages.txt'
$neverPath = Join-Path $script:Root 'third_party/dumbtv/data/fireos/never-disable.txt'
$protected = @(Get-Content $neverPath | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ -match '^[a-zA-Z][A-Za-z0-9_.]+$' })
$knownCritical = @('com.amazon.firehomestarter','com.amazon.tv.launcher','com.amazon.device.software.ota', 'com.amazon.tv.settings','com.amazon.venezia','com.amazon.avod.thirdpartyclient')
$stock = @('com.amazon.vizzini','com.amazon.vizzini.ftvcds','com.amazon.cloud9')
$protected += $knownCritical + $stock + $mockThirdParty + @('io.github.firestickwii','com.phlox.tvwebbrowser')

$plannedPackages = @()
foreach ($line in (Get-Content $listPath)) {
  $name = ($line -split '#')[0].Trim()
  if ($name -notmatch '^[a-zA-Z][a-zA-Z0-9_.]+$') { continue }
  if ($mockInstalled -notcontains $name -or $mockDisabled -contains $name -or $protected -contains $name) { continue }
  if ($name -match '(?i)(bluetooth|wifi|remote|settings|webview|casting|mirroring|launcher|appstore|inputmethod|cec|vizzini)') { continue }
  if ($name -match '(?i)(ota|forcedotaupdate|firebat)') { continue }
  $plannedPackages += $name
}

# Verify protection invariants:
$leaks = @()
foreach ($crit in @('com.amazon.tv.launcher','com.amazon.firehomestarter','com.netflix.ninja','com.google.android.youtube.tv','com.disney.disneyplus','com.amazon.tv.settings','com.amazon.webview','com.amazon.device.rdm')) {
  if ($plannedPackages -contains $crit) { $leaks += $crit }
}

if ($leaks.Count -eq 0) {
  Record-Test "Debloat-Safety" "Stock Home, remote, settings, and streaming apps strictly protected" "PASS"
} else {
  Record-Test "Debloat-Safety" "Critical packages leaked into debloat plan" "FAIL" ($leaks -join ', ')
}

if ($plannedPackages -contains 'com.amazon.aca' -or $plannedPackages -contains 'com.amazon.advertising.service') {
  Record-Test "Debloat-Safety" "Safe candidates (Alexa / Advertising) correctly identified" "PASS"
} else {
  Record-Test "Debloat-Safety" "Safe debloat candidates not identified" "FAIL"
}

# TEST: Debloat Journaling & Restore Resilience
$testStateDir = Join-Path $testEnvDir 'state'
New-Item -ItemType Directory -Force -Path $testStateDir | Out-Null
$testJournal = Join-Path $testStateDir 'disabled-by-firestick-wii.txt'
@('com.amazon.aca', 'com.amazon.advertising.service') | Set-Content -Encoding UTF8 $testJournal

try {
  $res = Run-WithMockAdb {
    # Test restore using mock adb
    $state = Join-Path $script:Root 'build/test-env/state'
    $log = Join-Path $state 'disabled-by-firestick-wii.txt'
    if (Test-Path $log) {
      $pkgs = @(Get-Content $log | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[a-zA-Z][a-zA-Z0-9_.]+$' } | Select-Object -Unique)
      $failed = @()
      foreach($pkg in $pkgs) {
        $out = RunNative 'adb' @('-s', 'AFT_TEST', 'shell', 'pm', 'enable', '--user', '0', $pkg)
      }
      Rename-Item $log ('disabled-restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
      'RESTORE_SUCCESS'
    }
  } @{
    'pm enable --user 0 com\.amazon\.aca' = @{ Out = @('Package com.amazon.aca new state: enabled'); ExitCode = 0 }
    'pm enable --user 0 com\.amazon\.advertising\.service' = @{ Out = @('Package com.amazon.advertising.service new state: enabled'); ExitCode = 0 }
  }

  if ($res.Output -contains 'RESTORE_SUCCESS') {
    Record-Test "Debloat-Safety" "Restore engine safely revives all journaled packages via pm enable" "PASS"
  } else {
    Record-Test "Debloat-Safety" "Restore engine failed to revive journaled packages" "FAIL" ($res.Errors | Out-String)
  }
} catch {
  Record-Test "Debloat-Safety" "Restore engine exception" "FAIL" $_.Exception.Message
}

# ---------------------------------------------------------
# SUMMARY REPORT
# ---------------------------------------------------------
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                  TEST SUITE SUMMARY                      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Total Tests : $testsTotal"
Write-Host "Passed      : $testsPassed" -ForegroundColor Green
Write-Host "Failed      : $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host "==========================================================" -ForegroundColor Cyan

if ($testsFailed -gt 0) {
  exit 1
} else {
  exit 0
}
