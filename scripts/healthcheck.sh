#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/scripts/lib/common.sh"

ROOT_DIR=""
if [[ "${1:-}" == "--root" ]]; then
  ROOT_DIR="${2:-}"
fi
if [[ -z "${ROOT_DIR}" ]]; then
  ROOT_DIR="$(detect_mcsm_root)"
fi

[[ -f "${ROOT_DIR}/daemon/app.js" ]] || fail "missing daemon app.js"
[[ -f "${ROOT_DIR}/web/public/index.html" ]] || fail "missing index.html"
INDEX_BUNDLE="$(find_panel_index_bundle "${ROOT_DIR}")"
MOUNT_BUNDLE="$(find_panel_mount_bundle "${ROOT_DIR}")"
[[ -n "${INDEX_BUNDLE}" ]] || fail "missing frontend index bundle"
[[ -n "${MOUNT_BUNDLE}" ]] || fail "missing frontend mount bundle"

grep -q 'whitelist.json' "${ROOT_DIR}/daemon/app.js" || fail "daemon patch marker missing"
grep -q 'common/whitelist.json' "${MOUNT_BUNDLE}" || fail "frontend patch marker missing"

systemctl is-active --quiet "$(service_name_web)" || fail "web service inactive"
systemctl is-active --quiet "$(service_name_daemon)" || fail "daemon service inactive"

log "healthcheck ok"
