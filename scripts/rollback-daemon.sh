#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/scripts/lib/common.sh"

ensure_runtime_tools

ROOT_DIR="$(detect_mcsm_root)"
BACKUP_BASE="${ROOT_DIR}/.patch-backups/$(json_get patch_id)-daemon"
BACKUP_DIR="$(ls -1dt "${BACKUP_BASE}"/* 2>/dev/null | head -n 1 || true)"
[[ -n "${BACKUP_DIR}" ]] || fail "no daemon backup found"

log "restoring daemon backup: ${BACKUP_DIR}"

cp -a "${BACKUP_DIR}/daemon/app.js" "${ROOT_DIR}/daemon/app.js"
cp -a "${BACKUP_DIR}/daemon/app.js.map" "${ROOT_DIR}/daemon/app.js.map"

NODE_BIN="$(detect_node_bin "${ROOT_DIR}")"
"${NODE_BIN}" --check "${ROOT_DIR}/daemon/app.js"
systemctl restart "$(service_name_daemon)"
systemctl is-active --quiet "$(service_name_daemon)" || fail "daemon service inactive after rollback"

log "daemon rollback complete"
