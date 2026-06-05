Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Script:ManifestPath = Join-Path $Script:RepoRoot "patch-manifest.json"
$Script:ManifestCache = $null

function Write-Log {
  param([string]$Message)
  Write-Host "[mcsm-patch] $Message"
}

function Fail {
  param([string]$Message)
  throw "[mcsm-patch] ERROR: $Message"
}

function Get-Manifest {
  if ($null -eq $Script:ManifestCache) {
    if (-not (Test-Path -LiteralPath $Script:ManifestPath)) {
      Fail "missing manifest: $Script:ManifestPath"
    }
    $Script:ManifestCache = Get-Content -LiteralPath $Script:ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  return $Script:ManifestCache
}

function Get-ManifestValue {
  param([string]$Path)

  $current = Get-Manifest
  foreach ($segment in $Path.Split(".")) {
    $current = $current.$segment
  }
  return $current
}

function Resolve-CanonicalPath {
  param([string]$Path)
  return (Resolve-Path -LiteralPath $Path).Path
}

function Test-McsmRoot {
  param([string]$Root)

  if ([string]::IsNullOrWhiteSpace($Root)) {
    return $false
  }

  return (
    (Test-Path -LiteralPath (Join-Path $Root "web\package.json")) -and
    (Test-Path -LiteralPath (Join-Path $Root "daemon\package.json"))
  )
}

function Get-ServiceCandidates {
  param([ValidateSet("web", "daemon")] [string]$Role)

  $hint = [string](Get-ManifestValue "services.$Role")
  $hintTrimmed = $hint -replace '\.service$', ''
  $display = if ($Role -eq "web") { "MCSManager Web" } else { "MCSManager Daemon" }

  return @($hint, $hintTrimmed, $display) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
}

function Get-ServiceAppJsPath {
  param(
    [string]$PathName,
    [ValidateSet("web", "daemon")] [string]$Role
  )

  if ([string]::IsNullOrWhiteSpace($PathName)) {
    return $null
  }

  $segment = if ($Role -eq "web") { "web" } else { "daemon" }
  $quotedPattern = '(?i)"(?<p>[A-Z]:[^"]+[\\/]' + $segment + '[\\/]app\.js)"'
  $unquotedPattern = '(?i)(?<p>[A-Z]:\S+[\\/]' + $segment + '[\\/]app\.js)'

  foreach ($pattern in @($quotedPattern, $unquotedPattern)) {
    $match = [regex]::Match($PathName, $pattern)
    if ($match.Success) {
      return $match.Groups["p"].Value
    }
  }

  return $null
}

function Get-ServiceExecutablePath {
  param([string]$PathName)

  if ([string]::IsNullOrWhiteSpace($PathName)) {
    return $null
  }

  foreach ($pattern in @('(?i)^"(?<p>[^"]+?\.exe)"', '(?i)^(?<p>[A-Z]:\S+?\.exe)\b')) {
    $match = [regex]::Match($PathName, $pattern)
    if ($match.Success) {
      return $match.Groups["p"].Value
    }
  }

  return $null
}

function Find-ServiceRecord {
  param([ValidateSet("web", "daemon")] [string]$Role)

  $services = @(Get-CimInstance Win32_Service)
  foreach ($candidate in Get-ServiceCandidates -Role $Role) {
    $exact = $services | Where-Object { $_.Name -eq $candidate -or $_.DisplayName -eq $candidate } | Select-Object -First 1
    if ($null -ne $exact) {
      return $exact
    }
  }

  foreach ($service in $services) {
    $appJs = Get-ServiceAppJsPath -PathName $service.PathName -Role $Role
    if (-not [string]::IsNullOrWhiteSpace($appJs)) {
      return $service
    }
  }

  return $null
}

function Get-RoleRootFromService {
  param([ValidateSet("web", "daemon")] [string]$Role)

  $service = Find-ServiceRecord -Role $Role
  if ($null -eq $service) {
    return $null
  }

  $appJs = Get-ServiceAppJsPath -PathName $service.PathName -Role $Role
  if ([string]::IsNullOrWhiteSpace($appJs)) {
    return $null
  }

  return Split-Path -Parent (Split-Path -Parent $appJs)
}

function Detect-McsmRoot {
  if (-not [string]::IsNullOrWhiteSpace($env:MCSM_ROOT)) {
    $resolved = Resolve-CanonicalPath -Path $env:MCSM_ROOT
    if (Test-McsmRoot -Root $resolved) {
      return $resolved
    }
    Fail "MCSM_ROOT is set but invalid: $resolved"
  }

  foreach ($role in @("web", "daemon")) {
    $root = Get-RoleRootFromService -Role $role
    if (Test-McsmRoot -Root $root) {
      return (Resolve-CanonicalPath -Path $root)
    }
  }

  foreach ($candidate in @(
    "C:\MCSManager",
    "D:\MCSManager",
    "C:\opt\mcsmanager",
    "D:\opt\mcsmanager",
    "C:\Program Files\MCSManager",
    "D:\Program Files\MCSManager"
  )) {
    if (Test-McsmRoot -Root $candidate) {
      return (Resolve-CanonicalPath -Path $candidate)
    }
  }

  Fail "unable to detect MCSManager root; set MCSM_ROOT explicitly"
}

function Get-PanelVersion {
  param([string]$Root)
  $packagePath = Join-Path $Root "web\package.json"
  return ([string]((Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json).version))
}

function Get-DaemonVersion {
  param([string]$Root)
  $packagePath = Join-Path $Root "daemon\package.json"
  return ([string]((Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json).version))
}

function Assert-TargetVersion {
  param([string]$Root)

  $panel = Get-PanelVersion -Root $Root
  $daemon = Get-DaemonVersion -Root $Root
  $targetPanel = [string](Get-ManifestValue "target_panel_version")
  $targetDaemon = [string](Get-ManifestValue "target_daemon_version")

  if ($panel -ne $targetPanel) {
    Fail "panel version mismatch: got $panel expected $targetPanel"
  }
  if ($daemon -ne $targetDaemon) {
    Fail "daemon version mismatch: got $daemon expected $targetDaemon"
  }
}

function Get-BackupRoot {
  param([string]$Root)
  return Join-Path $Root (".patch-backups\" + (Get-ManifestValue "patch_id"))
}

function Get-LatestBackupDir {
  param([string]$Root)

  $backupRoot = Get-BackupRoot -Root $Root
  if (-not (Test-Path -LiteralPath $backupRoot)) {
    return $null
  }

  $latest = Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($null -eq $latest) {
    return $null
  }
  return $latest.FullName
}

function Get-DaemonBackupRoot {
  param([string]$Root)
  return Join-Path $Root (".patch-backups\" + (Get-ManifestValue "patch_id") + "-daemon")
}

function Get-LatestDaemonBackupDir {
  param([string]$Root)

  $backupRoot = Get-DaemonBackupRoot -Root $Root
  if (-not (Test-Path -LiteralPath $backupRoot)) {
    return $null
  }

  $latest = Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($null -eq $latest) {
    return $null
  }
  return $latest.FullName
}

function Get-ServiceNameForRole {
  param([ValidateSet("web", "daemon")] [string]$Role)

  $service = Find-ServiceRecord -Role $Role
  if ($null -eq $service) {
    Fail "unable to detect Windows service for role: $Role"
  }
  return $service.Name
}

function Get-ServiceWrapperExecutable {
  param([ValidateSet("web", "daemon")] [string]$Role)

  $service = Find-ServiceRecord -Role $Role
  if ($null -eq $service) {
    return $null
  }

  $exe = Get-ServiceExecutablePath -PathName $service.PathName
  if ([string]::IsNullOrWhiteSpace($exe) -or -not (Test-Path -LiteralPath $exe)) {
    return $null
  }

  $baseName = [System.IO.Path]::GetFileName($exe)
  if ($baseName -match '^(mcsm-|winsw)') {
    return $exe
  }

  return $null
}

function Restart-RoleService {
  param([ValidateSet("web", "daemon")] [string]$Role)

  $serviceName = Get-ServiceNameForRole -Role $Role
  $wrapperExe = Get-ServiceWrapperExecutable -Role $Role
  if ($wrapperExe) {
    & $wrapperExe restart | Out-Null
  } else {
    Restart-Service -Name $serviceName -Force
  }
  Start-Sleep -Seconds 2
  $status = (Get-Service -Name $serviceName).Status
  if ($status -ne "Running") {
    Fail "$serviceName is not running after restart"
  }
}

function Restart-PanelServices {
  Restart-RoleService -Role "web"
  Restart-RoleService -Role "daemon"
}

function Ensure-RuntimeTools {
  if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
    Fail "Expand-Archive is unavailable"
  }
}

function Get-NodeBin {
  param([string]$Root)

  foreach ($candidate in @(
    (Join-Path $Root "daemon\node_app.exe"),
    (Join-Path $Root "web\node_app.exe"),
    (Join-Path $Root "node.exe"),
    (Join-Path $Root "node")
  )) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  $service = Find-ServiceRecord -Role "daemon"
  if ($null -ne $service) {
    $exe = Get-ServiceExecutablePath -PathName $service.PathName
    $baseName = if (-not [string]::IsNullOrWhiteSpace($exe)) { [System.IO.Path]::GetFileName($exe) } else { "" }
    if (
      -not [string]::IsNullOrWhiteSpace($exe) -and
      (Test-Path -LiteralPath $exe) -and
      $baseName -notmatch '^(mcsm-|winsw)'
    ) {
      return $exe
    }
  }

  $command = Get-Command node -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  Fail "unable to locate node runtime"
}

function Get-PanelIndexBundle {
  param([string]$Root)
  $file = Get-ChildItem -LiteralPath (Join-Path $Root "web\public\assets") -Filter "index-*.js" | Select-Object -First 1
  if ($null -eq $file) {
    Fail "missing panel index bundle"
  }
  return $file.FullName
}

function Get-PanelMountBundle {
  param([string]$Root)
  $file = Get-ChildItem -LiteralPath (Join-Path $Root "web\public\assets") -Filter "mount-*.js" | Select-Object -First 1
  if ($null -eq $file) {
    Fail "missing panel mount bundle"
  }
  return $file.FullName
}

function Test-NodeSyntax {
  param(
    [string]$NodeBin,
    [string]$FilePath
  )

  & $NodeBin --check $FilePath | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Fail "node syntax check failed: $FilePath"
  }
}
