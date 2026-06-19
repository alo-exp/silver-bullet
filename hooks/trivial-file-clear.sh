#!/usr/bin/env bash
# Silver Bullet — clear the trivial-session marker after edits/writes.

set -euo pipefail
trap 'exit 0' ERR

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi

rm -f -- "${SB_RUNTIME_STATE_DIR}/trivial"
