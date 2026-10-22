param([switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
if (-not (Test-Path $sdkRoot)) { New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null }

$p34 = Join-Path $sdkRoot 'platforms/android-34'
$bt34 = Join-Path $sdkRoot 'build-tools/34.0.0'

if (-not $Force -and (Test-Path $p34) -and (Test-Path $bt34)) {
  Say "Android SDK Platform 34 and Build-Tools 34.0.0 are already present at $sdkRoot"
  return
}

# Find JDK for sdkmanager
$javaExe = $null
if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin/java.exe'))) {
  $javaExe = Join-Path $env:JAVA_HOME 'bin/java.exe'
} else {
  $candidates = @(
    'C:\Program Files\Android\Android Studio\jbr',
    'C:\Program Files\Android\jbr'
  )
  foreach ($cand in $candidates) {
    if (Test-Path (Join-Path $cand 'bin/java.exe')) {
      $env:JAVA_HOME = $cand
      $javaExe = Join-Path $cand 'bin/java.exe'
      break
    }
  }
}

if (-not $javaExe) {
  throw "JDK 17+ (or Android Studio JBR) is required to run sdkmanager. Set JAVA_HOME."
}

$cmdlineToolsDir = Join-Path $sdkRoot 'cmdline-tools\latest'
$sdkmanager = Join-Path $cmdlineToolsDir 'bin\sdkmanager.bat'

if (-not (Test-Path $sdkmanager)) {
  $dlDir = PrivateDir 'downloads'
  $zip = Join-Path $dlDir 'commandlinetools-win-latest.zip'
  $url = 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'
  if (-not (Test-Path $zip)) {
    Say "Downloading official Android command-line tools from Google ($url)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  }
  Say "Extracting command-line tools..."
  $extractTemp = Join-Path $dlDir 'cmdline-tools-extract'
  if (Test-Path $extractTemp) { Remove-Item -Recurse -Force $extractTemp }
  Expand-Archive -Path $zip -DestinationPath $extractTemp -Force
  New-Item -ItemType Directory -Force -Path (Join-Path $sdkRoot 'cmdline-tools') | Out-Null
  if (Test-Path $cmdlineToolsDir) { Remove-Item -Recurse -Force $cmdlineToolsDir }
  Move-Item -Path (Join-Path $extractTemp 'cmdline-tools') -Destination $cmdlineToolsDir
  Remove-Item -Recurse -Force $extractTemp
}

Say "Installing Android SDK platforms;android-34 and build-tools;34.0.0..."
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  # Accept licenses and install platform-34, build-tools 34.0.0, platform-tools
  $processInfo = New-Object System.Diagnostics.ProcessStartInfo
  $processInfo.FileName = $sdkmanager
  $processInfo.Arguments = "--sdk_root=`"$sdkRoot`" `"platforms;android-34`" `"build-tools;34.0.0`" `"platform-tools`""
  $processInfo.RedirectStandardInput = $true
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  $processInfo.UseShellExecute = $false
  $processInfo.EnvironmentVariables["JAVA_HOME"] = $env:JAVA_HOME

  $process = [System.Diagnostics.Process]::Start($processInfo)
  # Pipe "y" to accept license agreements
  $writer = $process.StandardInput
  for ($i = 0; $i -lt 10; $i++) {
    $writer.WriteLine("y")
  }
  $writer.Flush()
  $writer.Close()

  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  Write-Host $stdout
  if ($process.ExitCode -ne 0) {
    Write-Warning $stderr
    throw "sdkmanager exited with code $($process.ExitCode)"
  }
} finally {
  $ErrorActionPreference = $prev
}

$env:ANDROID_HOME = $sdkRoot
Say "Android SDK setup complete at $sdkRoot"
