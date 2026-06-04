#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
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
grep -q 'whitelist.json' "${ROOT_DIR}/daemon/app.js" || fail "daemon patch marker missing"
systemctl is-active --quiet "$(service_name_daemon)" || fail "daemon service inactive"

log "daemon healthcheck ok"
