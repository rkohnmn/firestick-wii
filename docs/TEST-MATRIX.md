# Acceptance Test Matrix

For complete technical logs and evidence, refer to [reports/TEST-REPORT.md](../reports/TEST-REPORT.md).

### Automated Suite (Executed locally via `scripts/test-suite.ps1` — 33/33 PASS)
| Category | Scope | Result |
|---|---|:---:|
| Syntax & AST | All 15 PowerShell `.ps1` scripts validated | **PASS** |
| Configurations | `preferences.json` invariants & `run.bat` | **PASS** |
| Source Transformation | XML optimization & Fire TV Java fallback intent | **PASS** |
| Compilation | Release APK minification & SHA-256 integrity | **PASS** |
| Browser Integrity | TV Bro v2.1.6 `geckoExcluded` SHA-256 verified | **PASS** |
| Simulated Hardware | 9 Mock ADB connection & failure scenarios | **PASS** |
| Package Safety | Streaming apps, remote daemons, Settings, Home | **PASS** |
| Reversibility | Intent journaling & recovery via `restore.ps1` | **PASS** |

### Physical Acceptance Tests (To be completed upon TV connection)
| Test | Expected outcome | Result |
|---|---|:---:|
| Power / boot | Fire TV logo and home visible over HDMI | NOT TESTED |
| USB ADB | Authorized `adb devices -l`, not a preloader COM port | NOT TESTED |
| Wi-Fi ADB (fallback) | Authorized from Windows 10, same LAN | NOT TESTED |
| Alternate navigation | HDMI-CEC / phone remote / keyboard works | NOT TESTED |
| TV Bro WebView | https://example.com and chosen sites open on TV | NOT TESTED |
| Wii launcher | Grid, arrows/OK/Back, Settings button work | NOT TESTED |
| Home takeover | HOME goes to Wii and back after reboot (may be blocked by Fire OS) | NOT TESTED |
| iPhone | AirPlay screen mirror actually works | NOT TESTED |
| Pixel | Google Cast screen mirror actually works | NOT TESTED |
| Streaming apps | Primary native apps still play DRM video/audio | NOT TESTED |
| Backup | `backups/` contains initial state | NOT TESTED |
| Recovery | `scripts/restore.ps1` restores all altered packages | NOT TESTED |

The three state marker files under `state/` are created only after explicit manual responses. Do not bypass gates or mark a test passed without testing.
