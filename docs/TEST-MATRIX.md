# Manual acceptance tests (fill in results before debloating)

| Test | Expected outcome | Result |
|---|---|---|
| Power / boot | Fire TV logo and home visible over HDMI | NOT TESTED |
| USB ADB | Authorized `adb devices -l`, not a preloader COM port | NOT TESTED |
| Wi-Fi ADB (fallback) | Authorized from Windows 10, same LAN | NOT TESTED |
| Alternate navigation | HDMI-CEC / phone remote / keyboard works | NOT TESTED |
| TV Bro WebView | https://example.com and your chosen sites open | NOT TESTED |
| Wii launcher | Grid, arrows/OK/Back, Settings button work | NOT TESTED |
| Home takeover | HOME goes to Wii and back after reboot (may be blocked by Fire OS) | NOT TESTED |
| iPhone | AirPlay screen mirror actually works | NOT TESTED |
| Pixel | Google Cast screen mirror actually works | NOT TESTED |
| Streaming apps | At least your primary apps still play video/audio | NOT TESTED |
| Backup | `backups/` contains initial state | NOT TESTED |
| Recovery | `scripts/restore.ps1` is available and ADB works | NOT TESTED |

The three state marker files under `state/` are created only after explicit manual responses. Do not bypass gates or mark a test passed without testing.
