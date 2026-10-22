$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
$source = Join-Path $script:Root 'third_party/wii-tv'
if (-not (Test-Path (Join-Path $source 'LICENSE'))) { throw 'First run scripts/get-sources.ps1' }
$dest = Join-Path $script:Root 'build/wii-tv'
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $dest -Recurse -Force
$config = Join-Path $dest 'launcher/app/src/main/res/values/config.xml'
[xml]$doc = Get-Content -Raw $config
function XmlSet([string]$Tag,[string]$Name,[string]$Value) {
  $node=$doc.SelectSingleNode("/resources/$Tag[@name='$Name']")
  if (-not $node) { throw "Upstream layout changed: missing $Tag $Name" }
  $node.InnerText=$Value
}
XmlSet 'bool' 'dither_background' 'false'
XmlSet 'bool' 'advanced_effects' 'false'
XmlSet 'bool' 'animations' 'false'
XmlSet 'bool' 'reduced_motion' 'true'
XmlSet 'bool' 'module_cards' 'false'
XmlSet 'bool' 'app_library' 'true'
XmlSet 'string' 'wii_settings_label' 'Settings'
$dock=$doc.SelectSingleNode("/resources/string-array[@name='dock_apps']")
if (-not $dock) { throw 'Upstream dock_apps not found' }
while ($dock.HasChildNodes) { [void]$dock.RemoveChild($dock.FirstChild) }
foreach ($package in @('com.phlox.tvwebbrowser','com.netflix.ninja','com.google.android.youtube.tv','com.amazon.avod.thirdpartyclient')) {
  $item=$doc.CreateElement('item'); $item.InnerText=$package; [void]$dock.AppendChild($item)
}
# Save XML after editing only child nodes; preserve array name attribute.
$doc.Save($config)
# Keep original Java namespace while using a unique install identity through upstream Gradle property.
$gradleProp=Join-Path $dest 'launcher/gradle.properties'
Add-Content -Encoding ascii -Path $gradleProp -Value "`nlauncherApplicationId=io.github.firestickwii"
# Fire TV fallback: the default settings intent is not always exported on Fire OS.
$java=Join-Path $dest 'launcher/app/src/main/java/com/gathin/tvhome/WiiMenuActivity.java'
$j=[IO.File]::ReadAllText($java).Replace("`r`n", "`n")
$needle='open(new Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));'
if (-not $j.Contains($needle)) { throw 'Upstream Java changed: Settings action not found, refusing partial adaptation.' }
$replacement=@'
        try {
            startActivity(new Intent("android.settings.LEANBACK_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } catch (ActivityNotFoundException | SecurityException ignored) {
            Intent fallback = getPackageManager().getLaunchIntentForPackage("com.amazon.tv.settings");
            if (fallback != null) open(fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            else open(new Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
'@
$j=$j.Replace($needle,$replacement.TrimEnd())
# Also expose ordinary launchable apps (not just LEANBACK): TV Bro and receivers may be ordinary apps.
$old='List<ResolveInfo> found = pm.queryIntentActivities(query, 0);'
$new=@'
List<ResolveInfo> found = new ArrayList<>(pm.queryIntentActivities(query, 0));
        Set<String> leanbackActivities = new HashSet<>();
        for (ResolveInfo item : found) {
            if (item.activityInfo != null)
                leanbackActivities.add(item.activityInfo.packageName + "/" + item.activityInfo.name);
        }
        found.addAll(pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER), 0));
'@
if (-not $j.Contains($old)) { throw 'Upstream Java changed: app discovery patch requires review' }
$j=$j.Replace($old,$new.TrimEnd())
$oldcat='.addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER)' + "`n" + '                    .setClassName(pkg, ri.activityInfo.name)'
$newcat='.addCategory(leanbackActivities.contains(pkg + "/" + ri.activityInfo.name)' + "`n" + '                            ? Intent.CATEGORY_LEANBACK_LAUNCHER : Intent.CATEGORY_LAUNCHER)' + "`n" + '                    .setClassName(pkg, ri.activityInfo.name)'
if (-not $j.Contains($oldcat)) { throw 'Upstream Java changed: launcher intent patch requires review' }
$j=$j.Replace($oldcat,$newcat)
[IO.File]::WriteAllText($java,$j,(New-Object System.Text.UTF8Encoding $false))
Say "Prepared Wii source at $dest with lightweight settings, Fire TV settings fallback, and browser/receiver app discovery."
