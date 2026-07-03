#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# UserPromptSubmit + Stop — per-prompt outcome checklist (C-01).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/outcomes-gate.sh" ]]; then
  # shellcheck source=lib/outcomes-gate.sh
  source "$_lib_dir/outcomes-gate.sh"
fi
if [[ -f "$_lib_dir/trivial-bypass.sh" ]]; then
  # shellcheck source=lib/trivial-bypass.sh
  source "$_lib_dir/trivial-bypass.sh"
fi

_sb_outcomes_have_jq=false
if command -v jq >/dev/null 2>&1 && printf '{}' | jq . >/dev/null 2>&1; then
  _sb_outcomes_have_jq=true
fi

input="$(cat 2>/dev/null || true)"
if [[ "$_sb_outcomes_have_jq" == true ]]; then
  hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "UserPromptSubmit"' 2>/dev/null || echo "UserPromptSubmit")
  prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null || true)
else
  hook_event="UserPromptSubmit"
  if grep -qE '"hook_event_name"[[:space:]]*:[[:space:]]*"(Stop|SubagentStop)"' <<<"$input" 2>/dev/null; then
    hook_event="$(printf '%s' "$input" | grep -oE '"(Stop|SubagentStop)"' | head -1 | tr -d '"' || echo Stop)"
  elif ! grep -qE '"hook_event_name"[[:space:]]*:[[:space:]]*"(Stop|SubagentStop)"' <<<"$input" 2>/dev/null; then
    # Without jq we cannot seed UserPromptSubmit outcomes.
    exit 0
  fi
  prompt=""
fi

# Resolve SB project
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done
[[ -n "$config_file" ]] || exit 0

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_gate_or_exit
fi

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
state_file="${SILVER_BULLET_STATE_FILE:-${SB_STATE_DIR}/state}"
trivial_file="${SB_STATE_DIR}/trivial"

if [[ "$hook_event" == "UserPromptSubmit" ]]; then
  [[ -n "$prompt" ]] || exit 0
  printf '%s' "$prompt" >"${SB_STATE_DIR}/orchestrator-intent.txt" 2>/dev/null || true
  if [[ -f "$_lib_dir/prompt-classifier.sh" ]]; then
    # shellcheck source=lib/prompt-classifier.sh
    source "$_lib_dir/prompt-classifier.sh"
  fi
  if [[ -f "$_lib_dir/orchestrator-state.sh" ]]; then
    # shellcheck source=lib/orchestrator-state.sh
    source "$_lib_dir/orchestrator-state.sh"
    sb_orchestrator_clear_queue_on_interrupt "$prompt" 2>/dev/null || true
  fi
  sb_outcomes_seed_for_prompt "$prompt"
  if [[ -f "$_lib_dir/orchestrator-directive.sh" ]]; then
    if [[ -f "$_lib_dir/orchestrator-parent.sh" ]]; then
      # shellcheck source=lib/orchestrator-parent.sh
      source "$_lib_dir/orchestrator-parent.sh"
    fi
    # shellcheck source=lib/orchestrator-directive.sh
    source "$_lib_dir/orchestrator-directive.sh"
    if sb_orchestrator_prompt_has_override "$prompt"; then
      repo_root="$(dirname "$config_file")"
      sb_orchestrator_log_override "$repo_root" "$(sb_orchestrator_extract_override_reason "$prompt")" "$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
      sb_orchestrator_directive_clear
    elif ! ( declare -f sb_prompt_is_orchestrator_followup >/dev/null 2>&1 && sb_prompt_is_orchestrator_followup "$prompt" ); then
      sb_orchestrator_directive_from_pending_outcome 2>/dev/null || true
    fi
  fi
  summary="$(sb_outcomes_pending_summary)"
  [[ -n "$summary" ]] || exit 0
  ctx=$(printf '%s' "$summary" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}' "$ctx"
  exit 0
fi

# Stop / SubagentStop
if [[ "$hook_event" == "SubagentStop" ]]; then
  if [[ -f "$_lib_dir/orchestrator-parent.sh" ]]; then
    # shellcheck source=lib/orchestrator-parent.sh
    source "$_lib_dir/orchestrator-parent.sh"
    sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  fi
fi

state_contents=""
[[ -f "$state_file" && ! -L "$state_file" ]] && state_contents=$(cat "$state_file" 2>/dev/null || true)

if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

[[ -z "$state_contents" ]] && exit 0

sb_outcomes_auto_evaluate "$state_contents" "$trivial_file"

if sb_outcomes_all_done; then
  exit 0
fi

summary="$(sb_outcomes_pending_summary)"
if [[ -z "$summary" && "$_sb_outcomes_have_jq" != true ]]; then
  summary="Outstanding per-prompt outcomes (jq unavailable — inspect outcomes-session.json)"
fi
if [[ -f "$_lib_dir/stop-coalesce.sh" ]]; then
  # shellcheck source=lib/stop-coalesce.sh
  source "$_lib_dir/stop-coalesce.sh"
  if sb_stop_coalesce_suppress_secondary_block 2>/dev/null; then
    exit 0
  fi
fi
reason=$(printf 'Cannot complete — per-prompt outcome checklist incomplete.\n\n%s\n\nUpdate %s (mark outcomes done with evidence) or complete the missing work.' \
  "$summary" "$(sb_outcomes_session_file)")
if [[ "$_sb_outcomes_have_jq" == true ]]; then
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if declare -f sb_stop_coalesce_record >/dev/null 2>&1; then
    sb_stop_coalesce_record "$reason"
  fi
  printf '{"decision":"block","reason":%s}' "$json_reason"
else
  json_reason=$(printf '%s' "$reason" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  if declare -f sb_stop_coalesce_record >/dev/null 2>&1; then
    sb_stop_coalesce_record "$reason"
  fi
  printf '{"decision":"block","reason":%s}' "$json_reason"
fi
exit 0
