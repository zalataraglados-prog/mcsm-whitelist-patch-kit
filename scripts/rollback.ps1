Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$ScriptDir = Split-Path -Parent $ScriptPath
$RepoRoot = Split-Path -Parent $ScriptDir

. (Join-Path $RepoRoot "scripts\lib\common.ps1")

Ensure-RuntimeTools

$RootDir = Detect-McsmRoot
$BackupDir = Get-LatestBackupDir -Root $RootDir
if ([string]::IsNullOrWhiteSpace($BackupDir)) {
  Fail "no backup found"
}

Write-Log "restoring backup: $BackupDir"

Copy-Item -LiteralPath (Join-Path $BackupDir "daemon\app.js") -Destination (Join-Path $RootDir "daemon\app.js") -Force
Copy-Item -LiteralPath (Join-Path $BackupDir "daemon\app.js.map") -Destination (Join-Path $RootDir "daemon\app.js.map") -Force
Copy-Item -LiteralPath (Join-Path $BackupDir "web\public\index.html") -Destination (Join-Path $RootDir "web\public\index.html") -Force
if (Test-Path -LiteralPath (Join-Path $RootDir "web\public\assets")) {
  Remove-Item -LiteralPath (Join-Path $RootDir "web\public\assets") -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $BackupDir "web\public\assets") -Destination (Join-Path $RootDir "web\public\assets") -Recurse -Force

$NodeBin = Get-NodeBin -Root $RootDir
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Join-Path $RootDir "daemon\app.js")
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Get-PanelIndexBundle -Root $RootDir)
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Get-PanelMountBundle -Root $RootDir)

Restart-PanelServices

Write-Log "rollback complete"

