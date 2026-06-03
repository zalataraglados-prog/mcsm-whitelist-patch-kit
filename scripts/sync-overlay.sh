#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/upstream-mcsmanager" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="$1"

rsync -a "${REPO_ROOT}/src-overlay/" "${TARGET_ROOT}/"
echo "overlay synced to ${TARGET_ROOT}"
