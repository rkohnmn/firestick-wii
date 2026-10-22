# Instructions for local coding agents (Antigravity / Flash / Copilot)

- Start by reading README.md, docs/SAFETY.md, and config/preferences.json.
- Do not assume PC has USB ADB merely because it has MT65xx Preloader drivers. Hardware must be booted and ADB `device` authorized.
- Never flash, format, root, unlock, factory reset, wipe, or use preloader/bootloader tools.
- Never disable the Amazon stock HOME package, remote, Bluetooth, Wi-Fi, SystemUI, Settings, Package Installer, WebView, or a user streaming app.
- Fetch MIT-licensed upstream wii-tv + dumbtv source using scripts/get-sources.ps1. Do not merge or execute cleanyourtv's parallel debloat scripts.
- Do not execute dumbtv scripts/all.sh, debloat.sh, lockdown.sh, dnsfilter.sh, launcher.sh, or youtube.sh. Its preflight.sh is read-only; other operations are replaced with this repo's own reversible code.
- Use uniquely signed app ID io.github.firestickwii; do not hardcode com.gathin.tvhome in ADB install targets (Java namespace can remain upstream namespace).
- Do not claim HOME replacement works until verified on real Fire OS firmware; don't offer to bypass ADB authorization.
- Keep TV Bro WebView variant; AirScreen via official Appstore and physical phone tests.
- Stage plan, require explicit APPLY for each change; journal before disabling; recovery through scripts/restore.ps1.
- Keep complete project self-contained by committing upstream third_party/ source and licenses after fetching. Keep logs and device data git-ignored.
- When modifying Java sources, run Gradle build and unit tests on Windows before suggesting install. Explain if SDK/JDK unavailable.
