#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Stop + PreToolUse (git push main) — live publish evidence before LIVE claims / site push.
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

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
trivial_file="${SB_STATE_DIR}/trivial"
evidence_file="$(sb_site_session_live_evidence_file)"

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

needs_evidence=false

if [[ "$hook_event" == "PreToolUse" ]]; then
  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Bash|Shell|shell|exec_command) ;;
    *) exit 0 ;;
  esac
  cmd="$(sb_tool_command_string "$input" 2>/dev/null || true)"
  if sb_site_session_push_targets_main "$cmd" && sb_site_session_active; then
    needs_evidence=true
  fi
elif [[ "$hook_event" == "Stop" ]]; then
  if [[ -f "$_lib_dir/orchestrator-parent.sh" ]]; then
    source "$_lib_dir/orchestrator-parent.sh"
    sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  fi
  if sb_site_session_active; then
    if [[ -f "${SB_STATE_DIR}/site-session.json" ]]; then
      push_intent="$(jq -r '.push_intent // false' "${SB_STATE_DIR}/site-session.json" 2>/dev/null || echo false)"
      live_pending="$(jq -r '.live_claim_pending // false' "${SB_STATE_DIR}/site-session.json" 2>/dev/null || echo false)"
      [[ "$push_intent" == "true" || "$live_pending" == "true" ]] && needs_evidence=true
    fi
  fi
else
  exit 0
fi

[[ "$needs_evidence" == true ]] || exit 0
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

if sb_live_publish_evidence_valid; then
  exit 0
fi

reason="Live publish evidence required before push/Stop with site changes.

Write ${evidence_file} with:
  commit_sha, urls[], markers_matched[], status (LIVE|NOT_LIVE), verified_at

Verify deployed content at https://sb.alolabs.dev/ (fetch + marker match) before claiming LIVE.
See silver-bullet.md §8.2 and AGENTS.md publish policy."
emit_block "$reason"
