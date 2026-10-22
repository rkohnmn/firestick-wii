param([switch]$Refresh)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"
Need 'git'
$third = PrivateDir 'third_party'
$projects = @(
  @{Name='wii-tv';Url='https://github.com/MauroProto/wii-tv.git'},
  @{Name='dumbtv';Url='https://github.com/humblemuzzu/dumbtv.git'}
)
foreach($p in $projects) {
  $target = Join-Path $third $p.Name
  if (Test-Path $target) {
    if ($Refresh) { throw "Refusing to overwrite vendored $target. Review and remove it manually before refreshing." }
    if (-not (Test-Path (Join-Path $target 'LICENSE'))) { throw "Missing upstream license in $target" }
    Say "Using existing vendored source: $($p.Name)"
    continue
  }
  $temp = Join-Path $third ('.staging/' + $p.Name)
  New-Item -ItemType Directory -Force (Split-Path $temp -Parent) | Out-Null
  if (Test-Path $temp) { Remove-Item $temp -Force -Recurse }
  Say "Fetching $($p.Url)"
  $out = @(RunNative 'git' @('clone','--depth','1','--branch','main',$p.Url,$temp))
  $commit = (@(RunNative 'git' @('-C',$temp,'rev-parse','HEAD')) -join '').Trim()
  $ignore = Join-Path $temp '.git'
  Remove-Item $ignore -Force -Recurse
  Move-Item -Path $temp -Destination $target
  $commit | Set-Content -Encoding ascii (Join-Path $target 'FIRESTICK_WII_UPSTREAM_COMMIT.txt')
  Say "Vendored $($p.Name) at commit $commit"
}
Say 'These folders are now self-contained sources. Include third_party/ when committing to your GitHub repository.'
