#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Stop + PreToolUse (git push) — site regression tests when site/** touched.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo Stop)"

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

repo_root="$(dirname "$config_file")"
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
trivial_file="${SB_STATE_DIR}/trivial"

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
  else
    printf '{"decision":"block","reason":%s}' "$json_reason"
  fi
  exit 0
}

should_check=false
if [[ "$hook_event" == "Stop" || "$hook_event" == "SubagentStop" ]]; then
  if [[ "$hook_event" == "SubagentStop" && -f "$_lib_dir/orchestrator-parent.sh" ]]; then
    source "$_lib_dir/orchestrator-parent.sh"
    sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  fi
  sb_site_session_active && should_check=true
elif [[ "$hook_event" == "PreToolUse" ]]; then
  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Bash|Shell|shell|exec_command) ;;
    *) exit 0 ;;
  esac
  cmd="$(sb_tool_command_string "$input" 2>/dev/null || true)"
  if printf '%s' "$cmd" | grep -qE '\bgit push\b'; then
    sb_site_session_mark_push_intent 2>/dev/null || true
    sb_site_session_active && should_check=true
  else
    exit 0
  fi
else
  exit 0
fi

[[ "$should_check" == true ]] || exit 0
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

if sb_site_session_regression_current; then
  exit 0
fi

log_file=""
if log_file="$(sb_site_session_run_regression_tests "$repo_root" 2>/dev/null)"; then
  exit 0
fi

reason="Site session regression gate — run site freshness + chrome regression before push/Stop.

Required (all must pass):
  bash tests/scripts/test-site-chrome-regression.sh
  bash tests/scripts/test-site-doc-freshness.sh
  bash tests/scripts/test-site-content-freshness.sh

Fix failures then retry. Log: ${log_file:-unknown}"
emit_block "$reason"
