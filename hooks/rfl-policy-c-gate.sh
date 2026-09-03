#!/usr/bin/env bash
# PreToolUse / Stop — deny RFL advance when Policy C or sibling artifacts are missing.
# Active only when .planning/rfl-*/LADDER-STATUS.json has status: active.
set -euo pipefail

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in runtime-paths.sh sb-project-gate.sh hook-audit.sh orchestrator-parent.sh rfl-policy-c-assert.sh; do
  # shellcheck source=lib/runtime-paths.sh
  # shellcheck source=lib/sb-project-gate.sh
  # shellcheck source=lib/hook-audit.sh
  # shellcheck source=lib/orchestrator-parent.sh
  # shellcheck source=lib/rfl-policy-c-assert.sh
  [[ -f "$_lib_dir/$_lib" ]] && source "$_lib_dir/$_lib"
done

sb_rfl_policy_c_gate_disabled 2>/dev/null && exit 0

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // .hookEventName // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || true)"

config_file=""
if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
  config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
fi
[[ -n "$config_file" ]] || exit 0
project_root="$(dirname "$config_file")"

if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then
  sb_project_gate_or_exit 2>/dev/null || exit 0
fi

if declare -f sb_orchestrator_is_worker_session >/dev/null 2>&1; then
  sb_orchestrator_is_worker_session 2>/dev/null && exit 0
fi

sb_rfl_policy_c_has_active_run "$project_root" || exit 0

prompt=""
cmd=""
skill_name=""
case "$tool_name" in
  Task|Subagent|Agent)
    prompt="$(printf '%s' "$input" | jq -r '.tool_input.prompt // .tool_input.description // ""' 2>/dev/null || true)"
    ;;
  Skill)
    skill_name="$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.name // ""' 2>/dev/null || true)"
    prompt="$skill_name $(printf '%s' "$input" | jq -r '.tool_input.args // .tool_input.prompt // ""' 2>/dev/null || true)"
    ;;
  Bash|Shell|exec_command)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
    prompt="$cmd"
    if ! printf '%s' "$cmd" | grep -qiE 'agent-pi|agent-opencode|agent-codex/invoke|agent-claude/invoke|review-fix-ladder|rung_.*review|verify_1|verify_2|mark-ladder-status'; then
      exit 0
    fi
    ;;
  *)
    if [[ "$hook_event" != "Stop" && "$hook_event" != "stop" ]]; then
      exit 0
    fi
    ;;
esac

action="$(sb_rfl_policy_c_infer_action "$hook_event" "$prompt")"

emit_deny() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if declare -f sb_hook_audit_record >/dev/null 2>&1; then
    sb_hook_audit_record "rfl-policy-c-gate" "$hook_event" "deny" "$reason" ""
  fi
  case "$hook_event" in
    PreToolUse|preToolUse)
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
      ;;
    *)
      printf '{"decision":"block","reason":%s}' "$json_reason"
      ;;
  esac
}

assert_json=""
if ! assert_json="$(sb_rfl_policy_c_run_assert "$project_root" "$action" "$prompt")"; then
  reason="$(sb_rfl_policy_c_reason_from_json "$assert_json")"
  emit_deny "$reason"
  exit 0
fi

exit 0
