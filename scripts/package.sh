#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 /path/to/upstream-mcsmanager /path/to/patch-kit-repo" >&2
  exit 1
fi

BUILD_ROOT="$1"
KIT_ROOT="$2"
PAYLOAD_DIR="${KIT_ROOT}/payload/v10.16.1"

rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}/daemon" "${PAYLOAD_DIR}/web/public"

cp -a "${BUILD_ROOT}/production-code/daemon/app.js" "${PAYLOAD_DIR}/daemon/app.js"
cp -a "${BUILD_ROOT}/production-code/daemon/app.js.map" "${PAYLOAD_DIR}/daemon/app.js.map"
cp -a "${BUILD_ROOT}/production-code/web/public/index.html" "${PAYLOAD_DIR}/web/public/index.html"
cp -a "${BUILD_ROOT}/production-code/web/public/assets" "${PAYLOAD_DIR}/web/public/assets"

tar -C "${KIT_ROOT}/payload" -czf "${KIT_ROOT}/payload/mcsm-whitelist-patch-v10.16.1.tar.gz" "v10.16.1"
echo "payload packaged at ${KIT_ROOT}/payload/mcsm-whitelist-patch-v10.16.1.tar.gz"
