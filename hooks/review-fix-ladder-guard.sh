#!/usr/bin/env bash
# PreToolUse/PostToolUse — review-fix-ladder state machine enforcement.
# Active only when ladder session state exists (skill invoke or test harness).
set -euo pipefail
trap 'exit 0' ERR

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in runtime-paths.sh sb-project-gate.sh hook-audit.sh tool-input.sh orchestrator-parent.sh review-fix-ladder-state.sh; do
  # shellcheck disable=SC1090
  [[ -f "$_lib_dir/$_lib" ]] && source "$_lib_dir/$_lib"
done

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""')"

config_file=""
if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
  config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
fi
[[ -n "$config_file" ]] || exit 0
if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then
  sb_project_gate_or_exit 2>/dev/null || exit 0
fi

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR:-${HOME}/.cursor/.silver-bullet}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true

emit_deny() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if declare -f sb_hook_audit_record >/dev/null 2>&1; then
    sb_hook_audit_record "review-fix-ladder-guard" "$hook_event" "deny" "$reason" ""
  fi
  case "$hook_event" in
    PreToolUse)
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
      ;;
    *)
      printf '{"decision":"block","reason":%s}' "$json_reason"
      ;;
  esac
  exit 0
}

# --- PostToolUse: activate ladder / advance state / detect PM filing ---
if [[ "$hook_event" == "PostToolUse" ]]; then
  case "$tool_name" in
    Skill)
      skill_name="$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.name // ""' 2>/dev/null || true)"
      if declare -f sb_skill_canonical_name >/dev/null 2>&1; then
        skill_name="$(sb_skill_canonical_name "$skill_name" 2>/dev/null || printf '%s' "$skill_name")"
      fi
      sb_rfl_on_skill_invoke "$skill_name"
      ;;
    Task|Subagent|Agent)
      sb_orchestrator_is_worker_session 2>/dev/null && exit 0
      prompt="$(printf '%s' "$input" | jq -r '.tool_input.prompt // .tool_input.description // ""' 2>/dev/null || true)"
      sb_rfl_advance_after_task "$prompt"
      ;;
    Bash|Shell|exec_command)
      cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
      if sb_rfl_is_active && sb_rfl_detect_pm_filing_command "$cmd"; then
        phase="$(sb_rfl_read_field phase "")"
        [[ "$phase" == "file_valid_issues" ]] && sb_rfl_mark_pm_filed
      fi
      ;;
  esac
  exit 0
fi

# --- PreToolUse Skill: activate on ladder skill ---
if [[ "$hook_event" == "PreToolUse" && "$tool_name" == "Skill" ]]; then
  skill_name="$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.name // ""' 2>/dev/null || true)"
  if declare -f sb_skill_canonical_name >/dev/null 2>&1; then
    skill_name="$(sb_skill_canonical_name "$skill_name" 2>/dev/null || printf '%s' "$skill_name")"
  fi
  sb_rfl_on_skill_invoke "$skill_name"
  exit 0
fi

sb_rfl_is_active || exit 0

if [[ "$(sb_rfl_read_field compliance_stop false)" == "true" ]]; then
  reason="$(sb_rfl_read_field stop_reason "Review-fix-ladder compliance STOP — fix process before continuing.")"
  emit_deny "$reason"
fi

case "$hook_event" in
  PreToolUse) ;;
  *) exit 0 ;;
esac

case "$tool_name" in
  Task|Subagent|Agent)
    sb_orchestrator_is_worker_session 2>/dev/null && exit 0
    prompt="$(printf '%s' "$input" | jq -r '.tool_input.prompt // .tool_input.description // ""' 2>/dev/null || true)"
    model="$(printf '%s' "$input" | jq -r '.tool_input.model // ""' 2>/dev/null || true)"
    readonly_flag="$(printf '%s' "$input" | jq -r '.tool_input.readonly // .tool_input.readonly_mode // ""' 2>/dev/null || true)"
    subagent_type="$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // .tool_input.subagent // ""' 2>/dev/null || true)"
  ;;
  Bash|Shell|exec_command)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
    phase="$(sb_rfl_read_field phase "")"
  if [[ "$phase" == orchestrator_grep_1 || "$phase" == orchestrator_grep_2 ]]; then
    if printf '%s' "$cmd" | grep -qiE 'grep |rg |git diff|charter'; then
      sb_rfl_mark_orchestrator_grep
    fi
  fi
    exit 0
    ;;
  Edit|Write|MultiEdit|apply_patch)
    phase="$(sb_rfl_read_field phase "")"
    case "$phase" in
      verify_1|verify_2|orchestrator_grep_1|orchestrator_grep_2)
        sb_orchestrator_is_worker_session 2>/dev/null && emit_deny "Review-fix-ladder: verify phase is readonly — subagents must not edit files."
        ;;
    esac
    exit 0
    ;;
  *) exit 0 ;;
esac

if violation="$(sb_rfl_validate_task_spawn "$prompt" "$model" "$readonly_flag" "$subagent_type" 2>&1)"; then
  exit 0
fi

# State-recording is best-effort. sb_rfl_compliance_stop() bubbles up the exit
# code of sb_rfl_set_bool/sb_rfl_set_field, which return non-zero when the
# ladder state file is unwritable or unparseable. Left bare, that non-zero
# trips `set -e` -> the `trap 'exit 0' ERR` above -> exit 0, which the host
# reads as ALLOW: emit_deny below would never run and the gate would fail OPEN.
sb_rfl_compliance_stop "$violation" || true
emit_deny "$violation"
