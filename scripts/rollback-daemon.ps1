Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$ScriptDir = Split-Path -Parent $ScriptPath
$RepoRoot = Split-Path -Parent $ScriptDir

. (Join-Path $RepoRoot "scripts\lib\common.ps1")

Ensure-RuntimeTools

$RootDir = Detect-McsmRoot
$BackupDir = Get-LatestDaemonBackupDir -Root $RootDir
if ([string]::IsNullOrWhiteSpace($BackupDir)) {
  Fail "no daemon backup found"
}

Write-Log "restoring daemon backup: $BackupDir"

Copy-Item -LiteralPath (Join-Path $BackupDir "daemon\app.js") -Destination (Join-Path $RootDir "daemon\app.js") -Force
Copy-Item -LiteralPath (Join-Path $BackupDir "daemon\app.js.map") -Destination (Join-Path $RootDir "daemon\app.js.map") -Force

$NodeBin = Get-NodeBin -Root $RootDir
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Join-Path $RootDir "daemon\app.js")
Restart-RoleService -Role "daemon"

Write-Log "daemon rollback complete"

