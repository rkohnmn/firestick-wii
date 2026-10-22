# Safety and known limits

1. Hardware first. An unbootable USB-connected Fire Stick is not fixable by running ADB scripts. MT65xx Preloader detection is *not* the Android debug bridge. Never issue partition or flash commands.
2. This installation tool is not a ROM replacement, not a root exploit, and cannot guarantee a Fire OS HOME redirect. Stock HOME is intentionally never disabled.
3. The optional debloat is a reviewed subset of upstream `dumbtv`'s Fire OS package list. It uses `pm disable-user`, logs attempted changes, and avoids all `pm uninstall` operations. Firmware package protection may reject calls.
4. Always test ADB, alternative remote navigation, streaming app launch, browser, both casting protocols, and Wii Settings before committing system changes.
5. Packages are chosen by name only; an Amazon OTA or firmware update may change behavior. The list is not validated on model S3L36N here.
6. This tool does not block updates or DNS by default. Firmware updates may be important for security and WebView vulnerabilities.
7. Saving package lists and settings does not back up DRM keys, account logins, app data, or the operating system.
8. Private backup inventories and ADB authorization keys must never be uploaded to GitHub.
9. Third-party repositories are downloaded at runtime; review the captured commit and license before redistribution. Do not auto-update vendored code without checking changes.
10. Proprietary AirScreen and Fire OS system apps cannot legally or safely be bundled into this public source ZIP.
