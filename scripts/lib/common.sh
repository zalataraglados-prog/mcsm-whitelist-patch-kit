#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MANIFEST_PATH="${REPO_ROOT}/patch-manifest.json"

log() {
  printf '[mcsm-patch] %s\n' "$*"
}

fail() {
  printf '[mcsm-patch] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

json_get() {
  local expr="$1"
  python3 - "$MANIFEST_PATH" "$expr" <<'PY'
import json, sys
path, expr = sys.argv[1], sys.argv[2]
data = json.load(open(path, encoding="utf-8"))
cur = data
for part in expr.split("."):
    cur = cur[part]
print(cur)
PY
}

realpath_safe() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

service_workdir() {
  local service_name="$1"
  local value
  value="$(systemctl cat "$service_name" 2>/dev/null | sed -n 's/^WorkingDirectory=//p' | tail -n 1 || true)"
  if [[ -n "${value}" ]]; then
    printf '%s\n' "$value"
  fi
}

detect_mcsm_root() {
  if [[ -n "${MCSM_ROOT:-}" ]]; then
    printf '%s\n' "$(realpath_safe "$MCSM_ROOT")"
    return 0
  fi

  local web_service daemon_service web_dir daemon_dir
  web_service="$(json_get services.web)"
  daemon_service="$(json_get services.daemon)"
  web_dir="$(service_workdir "$web_service" || true)"
  daemon_dir="$(service_workdir "$daemon_service" || true)"

  if [[ -n "${web_dir}" ]]; then
    printf '%s\n' "$(dirname "$(realpath_safe "$web_dir")")"
    return 0
  fi

  if [[ -n "${daemon_dir}" ]]; then
    printf '%s\n' "$(dirname "$(realpath_safe "$daemon_dir")")"
    return 0
  fi

  local candidate
  for candidate in /opt/mcsmanager /usr/local/mcsmanager /opt/MCSManager; do
    if [[ -f "${candidate}/web/app.js" && -f "${candidate}/daemon/app.js" ]]; then
      printf '%s\n' "$(realpath_safe "$candidate")"
      return 0
    fi
  done

  fail "unable to detect MCSManager root; set MCSM_ROOT explicitly"
}

panel_version() {
  local root="$1"
  python3 - "$root/web/package.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print(data.get("version", ""))
PY
}

daemon_version() {
  local root="$1"
  python3 - "$root/daemon/package.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print(data.get("version", ""))
PY
}

assert_target_version() {
  local root="$1"
  local panel daemon target_panel target_daemon
  panel="$(panel_version "$root")"
  daemon="$(daemon_version "$root")"
  target_panel="$(json_get target_panel_version)"
  target_daemon="$(json_get target_daemon_version)"
  [[ "$panel" == "$target_panel" ]] || fail "panel version mismatch: got $panel expected $target_panel"
  [[ "$daemon" == "$target_daemon" ]] || fail "daemon version mismatch: got $daemon expected $target_daemon"
}

backup_root() {
  local root="$1"
  printf '%s\n' "${root}/.patch-backups/$(json_get patch_id)"
}

latest_backup_dir() {
  local root="$1" base
  base="$(backup_root "$root")"
  [[ -d "$base" ]] || return 1
  ls -1dt "${base}"/* 2>/dev/null | head -n 1
}

service_name_web() {
  json_get services.web
}

service_name_daemon() {
  json_get services.daemon
}

restart_services() {
  systemctl restart "$(service_name_web)"
  systemctl restart "$(service_name_daemon)"
}

ensure_runtime_tools() {
  require_cmd python3
  require_cmd tar
  require_cmd systemctl
}

find_panel_index_bundle() {
  local root="$1"
  ls -1 "${root}/web/public/assets"/index-*.js 2>/dev/null | head -n 1
}

find_panel_mount_bundle() {
  local root="$1"
  ls -1 "${root}/web/public/assets"/mount-*.js 2>/dev/null | head -n 1
}
