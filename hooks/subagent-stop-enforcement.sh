#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse (Task spawn) + PostToolUse (Task return) + beforeSubmitPrompt + Stop — §3c subagent completion.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/shell-analysis.sh" ]] && source "$_lib_dir/shell-analysis.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/cert-bypass.sh" ]] && source "$_lib_dir/cert-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"
[[ -f "$_lib_dir/orchestrator-parent.sh" ]] && source "$_lib_dir/orchestrator-parent.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
if declare -f sb_cert_run_bypass_active >/dev/null 2>&1 && sb_cert_run_bypass_active; then
  exit 0
fi
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

if [[ -f "$_lib_dir/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=lib/e2e-matrix-routing.sh
  source "$_lib_dir/e2e-matrix-routing.sh"
  if sb_e2e_matrix_routing_row_active 2>/dev/null; then
    exit 0
  fi
fi

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
      if [[ -f "$_lib_dir/ups-coalesce.sh" ]]; then
        # shellcheck source=lib/ups-coalesce.sh
        source "$_lib_dir/ups-coalesce.sh"
        sb_ups_emit_additional_context "$reason" "UserPromptSubmit"
      else
        ctx=$(printf '%s' "$reason" | jq -Rs '.')
        printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}' "$ctx"
      fi
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
  grep -Fqx 'silver-completion-audit' <<<"$state_contents" 2>/dev/null
}

# The skill names under which the completion audit is invoked.
sb_subagent_is_audit_skill() {
  case "${1:-}" in
    silver-completion-audit|sb:completion-audit|completion-audit) return 0 ;;
  esac
  return 1
}

# True when this PostToolUse payload ran the completion audit through the Codex adapter
# (`silver-bullet invoke-skill <audit>`). The substring test is only a cheap pre-filter; the
# decision is the shell-analysis classifier's (R2-24).
sb_subagent_bash_invokes_audit() {
  local name
  grep -q 'invoke-skill' <<<"$input" || return 1
  sb_tool_input_load "$input"
  sb_tool_input_ok || return 1
  for name in silver-completion-audit sb:completion-audit completion-audit; do
    sb_shell_analysis_invokes silver-bullet invoke-skill "$name" && return 0
  done
  return 1
}

# The audit invocation is the ONLY command of the call (a chained write is not covered).
sb_subagent_audit_command_alone() {
  printf '%s' "${SB_SA_JSON:-}" | jq -e '[.commands[]?] | length == 1' >/dev/null 2>&1
}

# The adapter ran and succeeded (R2-24): the tool response did not report a failing exit code, and the
# adapter wrote a fresh `loaded` receipt for the audit that is newer than the pending marker.
# Command text alone (`false && silver-bullet invoke-skill ...`) proves nothing.
sb_subagent_audit_succeeded() {
  local code receipt pend cwd_real
  code="$(printf '%s' "$input" | jq -r '(.tool_response.exit_code // .tool_response.exitCode // .tool_response.metadata.exit_code // 0) | tostring' 2>/dev/null)"
  [[ "$code" == "0" ]] || return 1
  pend="$(sb_site_session_pending_audit_file)"
  cwd_real="$(pwd -P)"
  for receipt in "${SB_RUNTIME_STATE_DIR}"/skill-invocations/*.json; do
    [[ -f "$receipt" && ! -L "$receipt" && "$receipt" -nt "$pend" ]] || continue
    if jq -e --arg cwd "$cwd_real" '.channel == "silver-bullet.invoke-skill" and .status == "loaded"
      and .canonical_skill == "silver-completion-audit" and .cwd == $cwd' "$receipt" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

sb_subagent_clear_audit_pending() {
  sb_site_session_clear_subagent_log 2>/dev/null || true
  sb_site_session_clear_pending_completion_audit 2>/dev/null || true
}

# R2-24: every worker return sets the pending marker and only a completion audit invoked AFTER it
# (seen as a Skill call, the Codex adapter, or the user's own /sb:completion-audit) clears it.
# An audit recorded earlier on the branch (the state file keeps one line per skill) does not
# cover a later worker's claim.
sb_subagent_block_pending_audit() {
  sb_site_session_pending_completion_audit || return 1
  emit_block "Subagent completion gate (§3c) — Task worker returned but /sb:completion-audit has not been run since.

Invoke /sb:completion-audit to verify worker claims before the next edit or user-facing reply."
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
    Edit|Write|MultiEdit|Shell|Bash|apply_patch|exec_command)
      sb_orchestrator_is_worker_session 2>/dev/null && exit 0
      # The audit itself must stay reachable: invoking it through the Codex adapter is not
      # blocked by the very gate it satisfies.
      if [[ "$tool_name" == "Bash" || "$tool_name" == "exec_command" || "$tool_name" == "Shell" ]] \
        && sb_subagent_bash_invokes_audit && sb_subagent_audit_command_alone; then
        exit 0
      fi
      sb_subagent_block_pending_audit
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
      if sb_subagent_is_audit_skill "$skill_name"; then
        sb_subagent_clear_audit_pending
      fi
      exit 0
      ;;
    Bash|exec_command|Shell)
      if sb_subagent_bash_invokes_audit && sb_subagent_audit_succeeded; then
        sb_subagent_clear_audit_pending
      fi
      exit 0
      ;;
    *) exit 0 ;;
  esac
  sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  tool_preview="$(printf '%s' "$input" | jq -c '.tool_input // {}' 2>/dev/null || echo '{}')"
  sb_site_session_mark_pending_completion_audit "$tool_preview"
  ctx=$(printf 'SB §3c: Task worker returned — invoke /sb:completion-audit before telling the user work is done.' | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}' "$ctx"
  exit 0
fi

if [[ "$hook_event" == "UserPromptSubmit" ]]; then
  sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  # The user typing the audit command themselves is the audit being run.
  prompt_first="$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null | awk 'NF { print $1; exit }')"
  case "$prompt_first" in
    /silver-completion-audit|/sb:completion-audit|/completion-audit)
      sb_subagent_clear_audit_pending
      exit 0
      ;;
  esac
  sb_subagent_block_pending_audit
fi

# Stop enforcement — parent sessions only
[[ "$hook_event" == "Stop" ]] || exit 0
sb_orchestrator_is_worker_session 2>/dev/null && exit 0
if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

sb_site_session_subagents_spawned || exit 0

# A worker returned and no audit has run since (R2-24): the state file's older audit line does not count.
if sb_site_session_pending_completion_audit; then
  emit_block "Subagent completion gate (§3c) — a Task worker returned and /sb:completion-audit has not been run since.

Invoke /sb:completion-audit to verify worker claims before Stop.
Parent must not accept subagent \"done\" without independent verification."
fi

if sb_subagent_state_has_completion_audit; then
  sb_site_session_clear_subagent_log 2>/dev/null || true
  sb_site_session_clear_pending_completion_audit 2>/dev/null || true
  exit 0
fi

emit_block "Subagent completion gate (§3c) — Task workers ran this session but /sb:completion-audit is not recorded.

Invoke /sb:completion-audit to verify worker claims before Stop.
Parent must not accept subagent \"done\" without independent verification."

