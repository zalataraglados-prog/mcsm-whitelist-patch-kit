Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = $null
if ($PSCommandPath) {
  $ScriptPath = $PSCommandPath
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
  $ScriptPath = $MyInvocation.MyCommand.Path
}

if ($ScriptPath) {
  $ScriptDir = Split-Path -Parent $ScriptPath
  $RepoRoot = Split-Path -Parent $ScriptDir
} else {
  $ScriptDir = (Get-Location).Path
  $RepoRoot = Split-Path -Parent $ScriptDir
}

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "patch-manifest.json"))) {
  $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("mcsm-whitelist-patch-kit-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  try {
    Set-Location $tmpDir
    if (Get-Command git -ErrorAction SilentlyContinue) {
      git clone --depth 1 --branch main "https://github.com/zalataraglados-prog/mcsm-whitelist-patch-kit.git" "mcsm-whitelist-patch-kit-main" | Out-Null
    } else {
      $zipPath = Join-Path $tmpDir "repo.zip"
      Invoke-WebRequest -Uri "https://github.com/zalataraglados-prog/mcsm-whitelist-patch-kit/archive/refs/heads/main.zip" -OutFile $zipPath
      Expand-Archive -LiteralPath $zipPath -DestinationPath $tmpDir -Force
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmpDir "mcsm-whitelist-patch-kit-main\scripts\install-daemon.ps1") @args
    exit $LASTEXITCODE
  } finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

. (Join-Path $RepoRoot "scripts\lib\common.ps1")

Ensure-RuntimeTools

$RootDir = Detect-McsmRoot
$DaemonVersionExpected = [string](Get-ManifestValue "target_daemon_version")
$DaemonVersionActual = Get-DaemonVersion -Root $RootDir
if ($DaemonVersionActual -ne $DaemonVersionExpected) {
  Fail "daemon version mismatch: got $DaemonVersionActual expected $DaemonVersionExpected"
}

$PayloadDir = Join-Path $RepoRoot (Get-ManifestValue "payload_dir")
if (-not (Test-Path -LiteralPath $PayloadDir)) {
  Fail "payload directory missing: $PayloadDir"
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path (Get-DaemonBackupRoot -Root $RootDir) $Stamp
New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir "daemon") | Out-Null

Write-Log "detected root: $RootDir"
Write-Log "creating daemon backup: $BackupDir"

Copy-Item -LiteralPath (Join-Path $RootDir "daemon\app.js") -Destination (Join-Path $BackupDir "daemon\app.js") -Force
Copy-Item -LiteralPath (Join-Path $RootDir "daemon\app.js.map") -Destination (Join-Path $BackupDir "daemon\app.js.map") -Force

Write-Log "installing daemon payload"
Copy-Item -LiteralPath (Join-Path $PayloadDir "daemon\app.js") -Destination (Join-Path $RootDir "daemon\app.js") -Force
Copy-Item -LiteralPath (Join-Path $PayloadDir "daemon\app.js.map") -Destination (Join-Path $RootDir "daemon\app.js.map") -Force

Write-Log "syntax check"
$NodeBin = Get-NodeBin -Root $RootDir
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Join-Path $RootDir "daemon\app.js")

Write-Log "restarting daemon service"
Restart-RoleService -Role "daemon"

Write-Log "running daemon healthcheck"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\healthcheck-daemon.ps1") -Root $RootDir

Write-Log "daemon install complete"
