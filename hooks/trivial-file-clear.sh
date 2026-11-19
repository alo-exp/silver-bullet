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

# R2-36: record WHAT this call wrote (hooks/lib/agent-writes.sh), so the Stop planning floor can tell the agent's
# own source edits from the user's pending changes. A shell call counts only when the analysis lists a path it
# writes; the file tools always write. The legacy trivial marker is cleared by any write, wherever it lands.
# shellcheck source=lib/shell-analysis.sh
source "$_sb_runtime_paths_dir/shell-analysis.sh"
# shellcheck source=lib/plain-read-only.sh
source "$_sb_runtime_paths_dir/plain-read-only.sh"
# shellcheck source=lib/agent-writes.sh
source "$_sb_runtime_paths_dir/agent-writes.sh"
_tfc_input="$(cat 2>/dev/null || true)"
_tfc_entries="$(sb_aw_entries "$_tfc_input")"
if [[ -n "$_tfc_entries" ]]; then
  rm -f -- "${SB_RUNTIME_STATE_DIR}/trivial"
  sb_aw_record "${SB_RUNTIME_STATE_DIR}" "$_tfc_entries"
fi
exit 0
