param([string]$Serial,[string]$FireTvIp)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
[void](SelectDevice $Serial $FireTvIp)
Need 'git'
$vendor=Join-Path $script:Root 'third_party/wii-tv/launcher'
if (-not (Test-Path $vendor)) { throw 'Vendored launcher missing. Run scripts/get-sources.ps1.' }
& "$PSScriptRoot/prepare-launcher.ps1"

$project=Join-Path $script:Root 'build/wii-tv/launcher'
if (-not (Test-Path (Join-Path $project 'gradlew.bat'))) { throw 'Gradle wrapper missing.' }
if (-not $env:JAVA_HOME) {
  $java=Get-Command java -ErrorAction SilentlyContinue
  if (-not $java) {
    $jb=Get-ChildItem 'C:\Program Files\Android' -ErrorAction SilentlyContinue -Directory |
      ForEach-Object { Join-Path $_.FullName 'jbr' } |
      Where-Object { Test-Path (Join-Path $_ 'bin/java.exe') } | Select-Object -First 1
    if ($jb) { $env:JAVA_HOME=$jb } else { throw 'JDK 17 required. Install Android Studio or JDK 17 and set JAVA_HOME.' }
  }
}
if (-not $env:ANDROID_HOME) {
  $sdk=Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  if (-not (Test-Path $sdk)) { throw 'Android SDK not found. Install Android SDK with platform android-34 and build-tools 34.0.0.' }
  $env:ANDROID_HOME=$sdk
}
$lp=Join-Path $project 'local.properties'
("sdk.dir=" + ($env:ANDROID_HOME -replace '\\','/')) | Set-Content -Encoding ASCII $lp
Say 'Building customized Wii launcher locally with upstream Gradle wrapper.'
Push-Location $project
try {
  & '.\gradlew.bat' ':app:assembleRelease' '--no-daemon' '--console=plain'
  if ($LASTEXITCODE -ne 0) { throw "Gradle build failed: $LASTEXITCODE" }
} finally { Pop-Location }
$apk=Join-Path $project 'app/build/outputs/apk/release/app-release.apk'
if (-not (Test-Path $apk)) { throw 'Gradle reported success, but APK not found.' }
$hash=(Get-FileHash -Path $apk -Algorithm SHA256).Hash
Say "Build complete; SHA256 $hash"
ConfirmLiteral 'Install custom Wii launcher APK (without replacing Amazon Home yet)?' 'INSTALL'
$out=Device @('install','-r',$apk)
if (($out -join ' ') -notmatch 'Success') { throw "APK install failed: $($out -join ' ')" }
$out=Shell @('am','start','-W','-n','io.github.firestickwii/com.gathin.tvhome.WiiMenuActivity')
Write-Host ($out -join "`n")
if (($out -join ' ') -match 'Error:|Exception') { throw 'Wii Activity did not launch. Stock HOME remains enabled.' }
Say 'Check the HDMI display and navigation manually. Stock Home was NOT disabled or replaced.'
