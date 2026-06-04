Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$ScriptDir = Split-Path -Parent $ScriptPath
$RepoRoot = Split-Path -Parent $ScriptDir

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
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmpDir "mcsm-whitelist-patch-kit-main\scripts\install.ps1") @args
    exit $LASTEXITCODE
  } finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

. (Join-Path $RepoRoot "scripts\lib\common.ps1")

Ensure-RuntimeTools

$RootDir = Detect-McsmRoot
Assert-TargetVersion -Root $RootDir

$PayloadDir = Join-Path $RepoRoot (Get-ManifestValue "payload_dir")
if (-not (Test-Path -LiteralPath $PayloadDir)) {
  Fail "payload directory missing: $PayloadDir"
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path (Get-BackupRoot -Root $RootDir) $Stamp
New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir "daemon") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BackupDir "web\public") | Out-Null

Write-Log "detected root: $RootDir"
Write-Log "creating backup: $BackupDir"

Copy-Item -LiteralPath (Join-Path $RootDir "daemon\app.js") -Destination (Join-Path $BackupDir "daemon\app.js") -Force
Copy-Item -LiteralPath (Join-Path $RootDir "daemon\app.js.map") -Destination (Join-Path $BackupDir "daemon\app.js.map") -Force
Copy-Item -LiteralPath (Join-Path $RootDir "web\public\index.html") -Destination (Join-Path $BackupDir "web\public\index.html") -Force
Copy-Item -LiteralPath (Join-Path $RootDir "web\public\assets") -Destination (Join-Path $BackupDir "web\public\assets") -Recurse -Force

Write-Log "installing payload"
Copy-Item -LiteralPath (Join-Path $PayloadDir "daemon\app.js") -Destination (Join-Path $RootDir "daemon\app.js") -Force
Copy-Item -LiteralPath (Join-Path $PayloadDir "daemon\app.js.map") -Destination (Join-Path $RootDir "daemon\app.js.map") -Force
Copy-Item -LiteralPath (Join-Path $PayloadDir "web\public\index.html") -Destination (Join-Path $RootDir "web\public\index.html") -Force
if (Test-Path -LiteralPath (Join-Path $RootDir "web\public\assets")) {
  Remove-Item -LiteralPath (Join-Path $RootDir "web\public\assets") -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $PayloadDir "web\public\assets") -Destination (Join-Path $RootDir "web\public\assets") -Recurse -Force

Write-Log "syntax check"
$NodeBin = Get-NodeBin -Root $RootDir
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Join-Path $RootDir "daemon\app.js")
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Get-PanelIndexBundle -Root $RootDir)
Test-NodeSyntax -NodeBin $NodeBin -FilePath (Get-PanelMountBundle -Root $RootDir)

Write-Log "restarting services"
Restart-PanelServices

Write-Log "running healthcheck"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\healthcheck.ps1") -Root $RootDir

Write-Log "install complete"

