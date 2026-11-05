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

# Edit/Write tools always mean a file write. A shell call (R2-36: `echo x > src/app.js` is a write
# the Edit gates never see) counts only when the F2 classifier lists a path the command writes.
if [[ -f "$_sb_runtime_paths_dir/shell-analysis.sh" ]]; then
  # shellcheck source=lib/shell-analysis.sh
  source "$_sb_runtime_paths_dir/shell-analysis.sh"
  sb_tool_input_load "$(cat 2>/dev/null)"
  if [[ "${SB_TI_STATUS:-}" == "ok" && "${SB_TI_TOOL_KIND:-}" == "shell" && -z "${SB_SA_WRITE_PATHS:-}" ]]; then
    exit 0
  fi
fi

rm -f -- "${SB_RUNTIME_STATE_DIR}/trivial"

# R2-36: leave a hook-written trace that the agent itself wrote a file this session, so the
# Stop planning floor can tell the agent's edits from the user's own pending changes.
if [[ -d "${SB_RUNTIME_STATE_DIR}" && ! -L "${SB_RUNTIME_STATE_DIR}/files-written" ]]; then
  : >"${SB_RUNTIME_STATE_DIR}/files-written" 2>/dev/null || true
fi
