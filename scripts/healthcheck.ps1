param(
  [string]$Root = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$ScriptDir = Split-Path -Parent $ScriptPath
$RepoRoot = Split-Path -Parent $ScriptDir

. (Join-Path $RepoRoot "scripts\lib\common.ps1")

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = Detect-McsmRoot
}

$daemonPath = Join-Path $Root "daemon\app.js"
$indexBundle = Get-PanelIndexBundle -Root $Root
$mountBundle = Get-PanelMountBundle -Root $Root

if (-not (Test-Path -LiteralPath $daemonPath)) { Fail "missing daemon app.js" }
if (-not (Test-Path -LiteralPath $indexBundle)) { Fail "missing index bundle" }
if (-not (Test-Path -LiteralPath $mountBundle)) { Fail "missing mount bundle" }

$daemonText = Get-Content -LiteralPath $daemonPath -Raw -Encoding UTF8
$mountText = Get-Content -LiteralPath $mountBundle -Raw -Encoding UTF8

if ($daemonText -notmatch "whitelist\.json") { Fail "daemon patch marker missing" }
if ($mountText -notmatch "whitelist\.json") { Fail "frontend patch marker missing" }

foreach ($role in @("web", "daemon")) {
  $serviceName = Get-ServiceNameForRole -Role $role
  if ((Get-Service -Name $serviceName).Status -ne "Running") {
    Fail "$serviceName is not running"
  }
}

Write-Log "healthcheck ok"
