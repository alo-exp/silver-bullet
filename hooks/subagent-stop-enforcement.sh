#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse (Task spawn) + PostToolUse (Task return) + beforeSubmitPrompt + Stop — §3c subagent completion.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/orchestrator-parent.sh" ]] && source "$_lib_dir/orchestrator-parent.sh"

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
state_file="${SILVER_BULLET_STATE_FILE:-${SB_STATE_DIR}/state}"
trivial_file="${SB_STATE_DIR}/trivial"

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  case "$hook_event" in
    PreToolUse)
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
      [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
      ;;
    UserPromptSubmit|beforeSubmitPrompt)
      ctx=$(printf '%s' "$reason" | jq -Rs '.')
      printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}' "$ctx"
      ;;
    *)
      printf '{"decision":"block","reason":%s}' "$json_reason"
      ;;
  esac
  exit 0
}

sb_subagent_state_has_completion_audit() {
  local state_contents=""
  [[ -f "$state_file" && ! -L "$state_file" ]] && state_contents="$(cat "$state_file" 2>/dev/null || true)"
  printf '%s\n' "$state_contents" | grep -Fqx 'silver-completion-audit' 2>/dev/null
}

sb_subagent_block_pending_audit() {
  sb_site_session_pending_completion_audit || return 1
  sb_subagent_state_has_completion_audit && return 1
  emit_block "Subagent completion gate (§3c) — Task worker returned but /silver:completion-audit is not recorded.

Invoke /silver:completion-audit to verify worker claims before the next edit or user-facing reply."
}

if [[ "$hook_event" == "PreToolUse" ]]; then
  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Task|Subagent|Agent)
      sb_orchestrator_is_worker_session 2>/dev/null && exit 0
      tool_preview="$(printf '%s' "$input" | jq -c '.tool_input // {}' 2>/dev/null || echo '{}')"
      sb_site_session_record_subagent_spawn "$tool_preview"
      sb_subagent_block_pending_audit
      ;;
    Edit|Write|MultiEdit|Shell|Bash)
      sb_orchestrator_is_worker_session 2>/dev/null && exit 0
      sb_subagent_block_pending_audit
      ;;
    Skill)
      skill_name="$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.name // ""' 2>/dev/null || true)"
      case "$skill_name" in
        silver-completion-audit|silver:completion-audit|completion-audit)
          sb_site_session_clear_subagent_log 2>/dev/null || true
          sb_site_session_clear_pending_completion_audit 2>/dev/null || true
          ;;
      esac
      exit 0
      ;;
    *) exit 0 ;;
  esac
fi

if [[ "$hook_event" == "PostToolUse" ]]; then
  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Task|Subagent|Agent) ;;
    Skill)
      skill_name="$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.name // ""' 2>/dev/null || true)"
      case "$skill_name" in
        silver-completion-audit|silver:completion-audit|completion-audit)
          sb_site_session_clear_subagent_log 2>/dev/null || true
          sb_site_session_clear_pending_completion_audit 2>/dev/null || true
          ;;
      esac
      exit 0
      ;;
    *) exit 0 ;;
  esac
  sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  tool_preview="$(printf '%s' "$input" | jq -c '.tool_input // {}' 2>/dev/null || echo '{}')"
  sb_site_session_mark_pending_completion_audit "$tool_preview"
  ctx=$(printf 'SB §3c: Task worker returned — invoke /silver:completion-audit before telling the user work is done.' | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}' "$ctx"
  exit 0
fi

if [[ "$hook_event" == "UserPromptSubmit" ]]; then
  sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  sb_subagent_block_pending_audit
fi

# Stop enforcement — parent sessions only
[[ "$hook_event" == "Stop" ]] || exit 0
sb_orchestrator_is_worker_session 2>/dev/null && exit 0
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

sb_site_session_subagents_spawned || exit 0

if sb_subagent_state_has_completion_audit; then
  sb_site_session_clear_subagent_log 2>/dev/null || true
  sb_site_session_clear_pending_completion_audit 2>/dev/null || true
  exit 0
fi

emit_block "Subagent completion gate (§3c) — Task workers ran this session but /silver:completion-audit is not recorded.

Invoke /silver:completion-audit to verify worker claims before Stop.
Parent must not accept subagent \"done\" without independent verification."
