param([string]$Serial,[string]$FireTvIp,[switch]$BuildOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/common.ps1"
Need 'git'
$vendor=Join-Path $script:Root 'third_party/wii-tv/launcher'
if (-not (Test-Path $vendor)) { throw 'Vendored launcher missing. Run scripts/get-sources.ps1.' }
& "$PSScriptRoot/prepare-launcher.ps1"

$project=Join-Path $script:Root 'build/wii-tv/launcher'
if (-not (Test-Path (Join-Path $project 'gradlew.bat'))) { throw 'Gradle wrapper missing.' }

# Resolve JDK 17+
function Get-JavaMajorVersion([string]$JavaExe) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $verOutput = @(& $JavaExe -version 2>&1 | ForEach-Object { [string]$_ })
    $joined = $verOutput -join ' '
    if ($joined -match 'version "([0-9]+)') {
      $major = [int]$Matches[1]
      if ($major -eq 1 -and $joined -match 'version "1\.([0-9]+)') {
        $major = [int]$Matches[1]
      }
      return $major
    }
  } catch {}
  finally {
    $ErrorActionPreference = $prev
  }
  return 0
}

$needJdk = $true
if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin/java.exe'))) {
  $ver = Get-JavaMajorVersion (Join-Path $env:JAVA_HOME 'bin/java.exe')
  if ($ver -ge 17) { $needJdk = $false }
}

if ($needJdk) {
  # Check if java on PATH is >= 17
  $cmdJava = Get-Command java -ErrorAction SilentlyContinue
  if ($cmdJava) {
    $ver = Get-JavaMajorVersion $cmdJava.Source
    if ($ver -ge 17) {
      $env:JAVA_HOME = (Split-Path -Parent (Split-Path -Parent $cmdJava.Source))
      $needJdk = $false
    }
  }
}

if ($needJdk) {
  # Search known JDK 17+ locations (Android Studio JBR, Eclipse Adoptium, Microsoft OpenJDK, etc.)
  $candidates = @(
    'C:\Program Files\Android\Android Studio\jbr',
    'C:\Program Files\Android\jbr'
  )
  $candidates += @(Get-ChildItem 'C:\Program Files\Android' -ErrorAction SilentlyContinue -Directory |
    ForEach-Object { Join-Path $_.FullName 'jbr' } |
    Where-Object { Test-Path (Join-Path $_ 'bin/java.exe') })
  $candidates += @(Get-ChildItem 'C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Microsoft' -ErrorAction SilentlyContinue -Directory |
    Where-Object { $_.Name -match 'jdk-?(1[7-9]|2[0-9])' } |
    ForEach-Object { $_.FullName })

  foreach ($cand in $candidates) {
    if ($cand -and (Test-Path (Join-Path $cand 'bin/java.exe'))) {
      $ver = Get-JavaMajorVersion (Join-Path $cand 'bin/java.exe')
      if ($ver -ge 17) {
        $env:JAVA_HOME = $cand
        $env:PATH = "$cand\bin;$env:PATH"
        $needJdk = $false
        break
      }
    }
  }
}

if ($needJdk) {
  throw 'JDK 17 or newer required. Android Studio JBR or JDK 17+ not found. Install JDK 17 or Android Studio and set JAVA_HOME.'
}
Say "Using JDK at: $env:JAVA_HOME"

# Resolve Android SDK
if (-not $env:ANDROID_HOME) {
  $sdkCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
    'C:\Android\android-sdk',
    'C:\Android\Sdk'
  )
  foreach ($cand in $sdkCandidates) {
    if ($cand -and (Test-Path $cand)) {
      $env:ANDROID_HOME = $cand
      break
    }
  }
}
if (-not $env:ANDROID_HOME -or -not (Test-Path $env:ANDROID_HOME)) {
  throw 'Android SDK not found. Install Android SDK with platform android-34 and build-tools 34.0.0, or use the included GitHub Actions cloud build.'
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
$distDir = Join-Path $script:Root 'dist'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$distApk = Join-Path $distDir 'firestick-wii-launcher.apk'
Copy-Item -Path $apk -Destination $distApk -Force
Say "Build complete; SHA256 $hash (copied to $distApk)"

if ($BuildOnly) {
  Say "Wii launcher APK built successfully: $distApk"
  return
}

[void](SelectDevice $Serial $FireTvIp)
ConfirmLiteral 'Install custom Wii launcher APK (without replacing Amazon Home yet)?' 'INSTALL'
$out=Device @('install','-r',$apk)
if (($out -join ' ') -notmatch 'Success') { throw "APK install failed: $($out -join ' ')" }
$out=Shell @('am','start','-W','-n','io.github.firestickwii/com.gathin.tvhome.WiiMenuActivity')
Write-Host ($out -join "`n")
if (($out -join ' ') -match 'Error:|Exception') { throw 'Wii Activity did not launch. Stock HOME remains enabled.' }
Say 'Check the HDMI display and navigation manually. Stock Home was NOT disabled or replaced.'
