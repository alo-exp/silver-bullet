#!/usr/bin/env bash
# Silver Bullet — clear the trivial-session marker after edits/writes.

set -euo pipefail
trap 'exit 0' ERR

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi
if [[ -f "$_sb_runtime_paths_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_sb_runtime_paths_dir/sb-project-gate.sh"
  sb_project_active_or_exit
fi

rm -f -- "${SB_RUNTIME_STATE_DIR}/trivial"
