#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# SessionStart (compact) — record LeanCTX lifecycle phase after AM snapshot marker.
# Ordering target: CM PreCompact → agentmemory snapshot → LeanCTX compact → stop-check.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/recommended-tools.sh" ]] && source "$_lib_dir/recommended-tools.sh"
[[ -f "$_lib_dir/stack-compression-coordinator.sh" ]] && source "$_lib_dir/stack-compression-coordinator.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
session_source="$(printf '%s' "$input" | jq -r '.session_source // .source // ""' 2>/dev/null || true)"
[[ "$session_source" == "compact" ]] || exit 0

config_file=""
if declare -f sb_find_project_config >/dev/null 2>&1; then
  config_file="$(sb_find_project_config 2>/dev/null || true)"
fi
[[ -n "$config_file" ]] || exit 0

sb_stack_coordinator_needed "$config_file" || exit 0

if sb_stack_leanctx_active "$config_file"; then
  sb_stack_lifecycle_mark "leanctx_compact" 2>/dev/null || true
fi

exit 0
