#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/patch-manifest.json" ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  cd "${TMP_DIR}"
  curl -fsSL "__FILL_RAW_INSTALL_URL__" -o install.sh
  chmod +x install.sh
  exec bash "${TMP_DIR}/install.sh" "$@"
fi

source "${REPO_ROOT}/scripts/lib/common.sh"

ensure_runtime_tools

ROOT_DIR="$(detect_mcsm_root)"
assert_target_version "${ROOT_DIR}"

PAYLOAD_DIR="${REPO_ROOT}/$(json_get payload_dir)"
[[ -d "${PAYLOAD_DIR}" ]] || fail "payload directory missing: ${PAYLOAD_DIR}"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$(backup_root "${ROOT_DIR}")/${STAMP}"
mkdir -p "${BACKUP_DIR}/daemon" "${BACKUP_DIR}/web/public"

log "detected root: ${ROOT_DIR}"
log "creating backup: ${BACKUP_DIR}"

cp -a "${ROOT_DIR}/daemon/app.js" "${BACKUP_DIR}/daemon/app.js"
cp -a "${ROOT_DIR}/daemon/app.js.map" "${BACKUP_DIR}/daemon/app.js.map"
cp -a "${ROOT_DIR}/web/public/index.html" "${BACKUP_DIR}/web/public/index.html"
cp -a "${ROOT_DIR}/web/public/assets" "${BACKUP_DIR}/web/public/assets"

log "installing payload"
cp -a "${PAYLOAD_DIR}/daemon/app.js" "${ROOT_DIR}/daemon/app.js"
cp -a "${PAYLOAD_DIR}/daemon/app.js.map" "${ROOT_DIR}/daemon/app.js.map"
cp -a "${PAYLOAD_DIR}/web/public/index.html" "${ROOT_DIR}/web/public/index.html"
rm -rf "${ROOT_DIR}/web/public/assets"
cp -a "${PAYLOAD_DIR}/web/public/assets" "${ROOT_DIR}/web/public/assets"

log "syntax check"
node --check "${ROOT_DIR}/daemon/app.js"
node --check "${ROOT_DIR}/web/public/assets/index-eb756f13.js"
node --check "${ROOT_DIR}/web/public/assets/mount-cffdab00.js"

log "restarting services"
restart_services

log "running healthcheck"
bash "${REPO_ROOT}/scripts/healthcheck.sh" --root "${ROOT_DIR}"

log "install complete"
