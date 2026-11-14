#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Stop — block when active site-session V-loops lack evidence (sb:content profile).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"
[[ "$hook_event" == "Stop" ]] || exit 0

# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
search_dir="${config_file:+${config_file%/*}}"
search_dir="${search_dir:-$PWD}"
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

if [[ -f "$_lib_dir/orchestrator-parent.sh" ]]; then
  source "$_lib_dir/orchestrator-parent.sh"
  sb_orchestrator_is_worker_session 2>/dev/null && exit 0
fi

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
trivial_file="${SB_STATE_DIR}/trivial"
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

sb_site_session_gates_apply || exit 0
sb_site_session_sync_vloops_from_state 2>/dev/null || true
sb_site_session_vloop_pending || exit 0

summary="$(sb_site_session_vloop_pending_summary)"
reason=$(printf 'Site V-loop rollup gate — active site session has incomplete child V-loops.\n\n%s\n\nComplete sb:content batch steps (preflight → implement → regression → visual → publish).' "$summary")
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
printf '{"decision":"block","reason":%s}' "$json_reason"
exit 0
