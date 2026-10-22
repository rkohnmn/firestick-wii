Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSScriptRoot
$script:AdbSerial = $null
function Say([string]$Text) { Write-Host "[firestick-wii] $Text" -ForegroundColor Cyan }
function Need([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "Missing '$Name'. Install it and put it on PATH." }
}
function RunNative([string]$Exe, [string[]]$Argv) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $lines = @(& $Exe @Argv 2>&1 | ForEach-Object { "$_" })
  } finally {
    $ErrorActionPreference = $prev
  }
  if ($LASTEXITCODE -ne 0) { throw "$Exe $($Argv -join ' ') failed ($LASTEXITCODE): $($lines -join ' ')" }
  return $lines
}
function Device([string[]]$Args) {
  if (-not $script:AdbSerial) { throw 'ADB target not selected' }
  return @(RunNative 'adb' (@('-s', $script:AdbSerial) + $Args))
}
function Shell([string[]]$Args) { return @(Device (@('shell') + $Args)) }
function GetProp([string]$Key) { return ((Shell @('getprop',$Key)) -join "`n").Trim() }
function SelectDevice([string]$RequestedSerial, [string]$FireTvIp) {
  Need 'adb'
  Say 'Examining authorized ADB devices (USB and Wi-Fi).'
  $info = @(RunNative 'adb' @('devices','-l'))
  if ($FireTvIp) {
    $ipPort = "${FireTvIp}:5555"
    Say "Attempting normal network ADB: $ipPort"
    $result = & adb connect $ipPort 2>&1
    Write-Host ($result -join "`n")
    $info = @(RunNative 'adb' @('devices','-l'))
  }
  $online = @($info | Where-Object { $_ -match '^(\S+)\s+device(?:\s|$)' } | ForEach-Object { $Matches[1] })
  $blocked = @($info | Where-Object { $_ -match '\s+(unauthorized|offline)(?:\s|$)' })
  if ($blocked.Count) { Write-Host ($blocked -join "`n") -ForegroundColor Yellow }
  if ($RequestedSerial) {
    if ($online -notcontains $RequestedSerial) { throw "Requested device '$RequestedSerial' is not authorized/online. Check HDMI screen, debugging authorization, and power." }
    $script:AdbSerial = $RequestedSerial
  } elseif ($FireTvIp -and $online -contains "${FireTvIp}:5555") {
    $script:AdbSerial = "${FireTvIp}:5555"
  } elseif ($online.Count -eq 1) {
    $script:AdbSerial = $online[0]
  } elseif ($online.Count -gt 1) {
    throw "Multiple ADB devices detected: $($online -join ', '). Rerun with -Serial <device> (or -FireTvIp)."
  } else {
    throw 'No authorized Android ADB device. A MediaTek Preloader COM port is NOT ADB. Verify Fire Stick HDMI boot, a data-capable micro-USB cable, power, or enable Wi-Fi ADB with TV-side authorization. Nothing was modified.'
  }
  Say "ADB target: $script:AdbSerial"
  $manufacturer = GetProp 'ro.product.manufacturer'
  $model = GetProp 'ro.product.model'
  $sdk = GetProp 'ro.build.version.sdk'
  Say "Model: $model; manufacturer: $manufacturer; Android API: $sdk"
  if ($manufacturer -notmatch 'Amazon') { throw "Device is not verified as Amazon. Refusing changes: $manufacturer / $model" }
  $api = 0
  if (-not [int]::TryParse($sdk, [ref]$api) -or $api -lt 26) { throw "Unsupported/unknown Android API $sdk" }
  return $api
}
function PrivateDir([string]$Name) {
  $dir = Join-Path $script:Root $Name
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  return $dir
}
function Snapshot([string]$Folder) {
  Say "Saving read-only inventory to $Folder"
  $commands = @{
    'device-properties.txt'=@('getprop')
    'packages-all.txt'=@('pm','list','packages')
    'packages-user.txt'=@('pm','list','packages','-3')
    'packages-disabled.txt'=@('pm','list','packages','-d')
    'settings-global.txt'=@('settings','list','global')
    'settings-secure.txt'=@('settings','list','secure')
    'storage.txt'=@('df','-h','/data')
    'memory.txt'=@('dumpsys','meminfo')
    'home.txt'=@('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
  }
  foreach($name in $commands.Keys) {
    $data = @(Shell $commands[$name])
    [IO.File]::WriteAllLines((Join-Path $Folder $name), [string[]]$data, (New-Object System.Text.UTF8Encoding $false))
  }
  [IO.File]::WriteAllText((Join-Path $Folder 'target.txt'), $script:AdbSerial)
  Say 'Snapshot complete. This is NOT a full app-data or firmware image backup.'
}
function ConfirmLiteral([string]$Prompt, [string]$Token) {
  $answer = Read-Host "$Prompt (type $Token)"
  if ($answer -cne $Token) { throw "Confirmation not provided; stopped without doing that action." }
}
function JsonPreferences() {
  return (Get-Content -Raw (Join-Path $script:Root 'config/preferences.json') | ConvertFrom-Json)
}
