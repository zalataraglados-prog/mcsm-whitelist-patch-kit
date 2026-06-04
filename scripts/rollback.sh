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
BACKUP_DIR="$(latest_backup_dir "${ROOT_DIR}" || true)"
[[ -n "${BACKUP_DIR}" ]] || fail "no backup found"

log "restoring backup: ${BACKUP_DIR}"

cp -a "${BACKUP_DIR}/daemon/app.js" "${ROOT_DIR}/daemon/app.js"
cp -a "${BACKUP_DIR}/daemon/app.js.map" "${ROOT_DIR}/daemon/app.js.map"
cp -a "${BACKUP_DIR}/web/public/index.html" "${ROOT_DIR}/web/public/index.html"
rm -rf "${ROOT_DIR}/web/public/assets"
cp -a "${BACKUP_DIR}/web/public/assets" "${ROOT_DIR}/web/public/assets"

restart_services
node --check "${ROOT_DIR}/daemon/app.js"
node --check "$(find_panel_index_bundle "${ROOT_DIR}")"
node --check "$(find_panel_mount_bundle "${ROOT_DIR}")"

log "rollback complete"
