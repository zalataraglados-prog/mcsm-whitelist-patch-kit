#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${REPO_ROOT}/patch-manifest.json" ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  cd "${TMP_DIR}"
  curl -fsSL "https://github.com/zalataraglados-prog/mcsm-whitelist-patch-kit/archive/refs/heads/main.tar.gz" -o repo.tar.gz
  tar -xzf repo.tar.gz
  exec bash "${TMP_DIR}/mcsm-whitelist-patch-kit-main/scripts/install-daemon.sh" "$@"
fi

source "${REPO_ROOT}/scripts/lib/common.sh"

ensure_runtime_tools

ROOT_DIR="$(detect_mcsm_root)"
DAEMON_VERSION_EXPECTED="$(json_get target_daemon_version)"
DAEMON_VERSION_ACTUAL="$(daemon_version "${ROOT_DIR}")"
[[ "${DAEMON_VERSION_ACTUAL}" == "${DAEMON_VERSION_EXPECTED}" ]] || fail "daemon version mismatch: got ${DAEMON_VERSION_ACTUAL} expected ${DAEMON_VERSION_EXPECTED}"

PAYLOAD_DIR="${REPO_ROOT}/$(json_get payload_dir)"
[[ -d "${PAYLOAD_DIR}" ]] || fail "payload directory missing: ${PAYLOAD_DIR}"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_BASE="${ROOT_DIR}/.patch-backups/$(json_get patch_id)-daemon"
BACKUP_DIR="${BACKUP_BASE}/${STAMP}"
mkdir -p "${BACKUP_DIR}/daemon"

log "detected root: ${ROOT_DIR}"
log "creating daemon backup: ${BACKUP_DIR}"

cp -a "${ROOT_DIR}/daemon/app.js" "${BACKUP_DIR}/daemon/app.js"
cp -a "${ROOT_DIR}/daemon/app.js.map" "${BACKUP_DIR}/daemon/app.js.map"

log "installing daemon payload"
cp -a "${PAYLOAD_DIR}/daemon/app.js" "${ROOT_DIR}/daemon/app.js"
cp -a "${PAYLOAD_DIR}/daemon/app.js.map" "${ROOT_DIR}/daemon/app.js.map"

log "syntax check"
NODE_BIN="$(detect_node_bin "${ROOT_DIR}")"
"${NODE_BIN}" --check "${ROOT_DIR}/daemon/app.js"

log "restarting daemon service"
systemctl restart "$(service_name_daemon)"

log "running daemon healthcheck"
bash "${REPO_ROOT}/scripts/healthcheck-daemon.sh" --root "${ROOT_DIR}"

log "daemon install complete"
