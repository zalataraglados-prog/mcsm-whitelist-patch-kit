Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
  [string]$Root = ""
)

$ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$ScriptDir = Split-Path -Parent $ScriptPath
$RepoRoot = Split-Path -Parent $ScriptDir

. (Join-Path $RepoRoot "scripts\lib\common.ps1")

if ([string]::IsNullOrWhiteSpace($Root)) {
  $Root = Detect-McsmRoot
}

$daemonPath = Join-Path $Root "daemon\app.js"
if (-not (Test-Path -LiteralPath $daemonPath)) {
  Fail "missing daemon app.js"
}

$daemonText = Get-Content -LiteralPath $daemonPath -Raw -Encoding UTF8
if ($daemonText -notmatch "whitelist\.json") {
  Fail "daemon patch marker missing"
}

$serviceName = Get-ServiceNameForRole -Role "daemon"
if ((Get-Service -Name $serviceName).Status -ne "Running") {
  Fail "$serviceName is not running"
}

Write-Log "daemon healthcheck ok"
