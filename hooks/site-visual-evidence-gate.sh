#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Stop — require 1280px visual evidence for active site sessions (Wave 2).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"
case "$hook_event" in
  Stop|SubagentStop) ;;
  *) exit 0 ;;
esac

if [[ "$hook_event" == "SubagentStop" && -f "$_lib_dir/orchestrator-parent.sh" ]]; then
  source "$_lib_dir/orchestrator-parent.sh"
  sb_orchestrator_is_worker_session 2>/dev/null && exit 0
fi

config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
trivial_file="${SB_STATE_DIR}/trivial"
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

sb_site_session_active || exit 0
sb_site_session_visual_evidence_valid && exit 0

reason="Site visual evidence gate — active site session requires 1280px light+dark screenshots before Stop.

Capture via Alumnium or host browser MCP (browser_take_screenshot), then record paths in site-visual-evidence.json.
See silver:content site batch protocol step 4 (Visual)."
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
printf '{"decision":"block","reason":%s}' "$json_reason"
exit 0
