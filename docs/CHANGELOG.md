# Changelog & Technical Modifications

All notable changes, bug fixes, automated test additions, and build pipeline enhancements made to the **firestick-wii** project are documented here.

---

## [1.1.0] - 2026-10-22

### 🚀 Major Enhancements & New Features

1. **Local Wii Launcher Build Engine (`scripts/build-launcher.ps1`)**:
   - Added `-BuildOnly` flag allowing local compilation of the Wii launcher without requiring an active Android device connection.
   - Built a local release APK: `dist/firestick-wii-launcher.apk` (755,371 bytes) using R8 code shrinking, resource minification, and debug signing.
   - SHA-256 Checksum: `B332D73CBA8CCDA8B35EA2192DA1E185AAD0C7C9C129A6A5493B460C1D9148E8`.
   - Automatically outputs compiled artifacts to `dist/firestick-wii-launcher.apk`.

2. **Automated Android SDK Bootstrapper (`scripts/setup-android-sdk.ps1`)**:
   - Created standalone script that downloads Google's official Android Command-Line Tools, installs `platforms;android-34`, `build-tools;34.0.0`, and the latest `platform-tools` (ADB 1.0.41), and auto-accepts SDK licenses.

3. **Comprehensive Automated Test Suite (`scripts/test-suite.ps1`)**:
   - Implemented a 33-test automated test suite with full in-process mock ADB routing.
   - Validates PowerShell AST syntax across all workspace `.ps1` files.
   - Verifies `config/preferences.json` invariants and `run.bat` integrity.
   - Verifies XML patching, Java fallback intent patching, and TV Bro SHA-256 hash checking.
   - Simulates 9 hardware connection & failure scenarios:
     - Scenario A: No Android device detected.
     - Scenario B: MediaTek Preloader COM port detected (distinguished from ADB).
     - Scenario C: Unauthorized Fire TV device (triggers authorization guidance).
     - Scenario D: Offline Fire TV device.
     - Scenario E: Multiple ADB devices (prompts for explicit `-Serial`).
     - Scenario F: Non-Amazon device (e.g. Pixel phone) strictly blocked from modification.
     - Scenario G: Unsupported legacy Android API (< 26) rejected.
     - Scenario H: Authorized Amazon Fire TV (API 28) correctly selected.
     - Scenario I: Fire TV connected over Wi-Fi (`IP:5555`) correctly targeted.
   - Validates package protection invariants (ensuring streaming apps, remote daemons, Settings, and stock Home are never debloated).
   - Validates journaled debloat and restore engine functionality.

4. **Offline TV Bro Download Mode (`scripts/install-browser.ps1`)**:
   - Added `-DownloadOnly` switch to verify and fetch the official v2.1.6 `geckoExcluded` WebView APK and its SHA-256 signature without an active device.

---

### 🐛 Critical Bug Fixes

1. **PowerShell Automatic Variable Collision (`$Args`)**:
   - **Root Cause**: In `scripts/common.ps1`, `function Device([string[]]$Args)` and `function Shell([string[]]$Args)` used `$Args` as a parameter name. In PowerShell, `$args` is a reserved automatic variable for unbound arguments. Declaring `$Args` caused PowerShell's binder to wipe the variable on invocation, effectively stripping all command arguments and sending empty commands to `adb`.
   - **Fix**: Renamed the parameter to `[string[]]$CommandArgs` in both `Device` and `Shell`.

2. **Windows Carriage Return (CRLF) Truncation**:
   - **Root Cause**: `adb shell` output contains `\r\n`. Trailing `\r` caused .NET regex `(?m)^package:...$` in `activate-home.ps1` to evaluate to `False` even when the package was installed. It also broke array `-contains` matching in `plan-debloat.ps1` and `apply-debloat.ps1`.
   - **Fix**: Updated `RunNative` in `common.ps1` to strip carriage returns via `TrimEnd("`r")`, added `.Trim()` to package list parsers, and updated regex to `\r?$`.

3. **Strict-Mode `$LASTEXITCODE` Variable Exception**:
   - **Root Cause**: `Set-StrictMode -Version Latest` was enabled in `common.ps1`. When evaluating `$LASTEXITCODE` before any external executable ran in the PowerShell session, PowerShell threw `VariableIsUndefined`.
   - **Fix**: Initialized `$global:LASTEXITCODE = 0` at load time and guarded evaluation with `(Test-Path Variable:\LASTEXITCODE)`.

4. **JDK 17/21 Resolution & `java -version` Stderr Handling**:
   - **Root Cause**: `build-launcher.ps1` failed if Java 8 was in system PATH because it skipped looking for JDK 17+. Furthermore, `java -version` outputs to stderr, which triggered PowerShell terminating errors under `$ErrorActionPreference='Stop'`.
   - **Fix**: Implemented `Get-JavaMajorVersion` with temporary error action silencing and added automatic discovery of Android Studio's bundled JBR (`C:\Program Files\Android\Android Studio\jbr`, OpenJDK 21).

5. **Direct ADB Calls vs Mockable Pipeline**:
   - **Root Cause**: Direct calls to `& adb ... 2>&1` in `apply-debloat.ps1`, `restore.ps1`, and `SelectDevice` bypassed unified error handling and prevented mock simulation.
   - **Fix**: Routed invocations through `RunNative` and introduced a `$global:MockAdbHandler` test hook.

6. **Variable Misnaming in `apply-debloat.ps1`**:
   - **Root Cause**: Line 33 printed `$out` instead of `$result`, outputting empty strings on package changes.
   - **Fix**: Corrected variable reference.

7. **Resilient Recovery in `scripts/restore.ps1`**:
   - **Root Cause**: `restore.ps1` previously aborted immediately if any single package failed to re-enable, leaving subsequent journaled packages disabled.
   - **Fix**: Updated to process all journaled packages, log individual warnings, and only archive the journal once all packages succeed.

8. **State Directory Scoping in `setup.ps1`**:
   - **Root Cause**: Marker files were inconsistently addressed between `PrivateDir 'state'` and hardcoded relative paths.
   - **Fix**: Standardized all state marker writes on `PrivateDir 'state'`.

---

### 🛡️ Safety & Reliability Invariants Preserved
- Stock Amazon Home (`com.amazon.tv.launcher`, `com.amazon.firehomestarter`) is strictly protected and never disabled.
- Remote control daemons (`com.amazon.device.rdm`), Bluetooth, Wi-Fi, SystemUI, Settings, and Android System WebView are strictly protected.
- Third-party streaming applications (Netflix, YouTube TV, Prime Video, Disney+, Hulu, etc.) are strictly excluded from debloat proposals.
- No flashing, formatting, unlocking, or firmware write tools are used.
- All package disabling uses `pm disable-user --user 0` and is preceded by intent journaling for instant rollback.
