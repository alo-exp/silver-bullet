#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# UserPromptSubmit + Stop — nested instruction ledger (Phase 103 L-01..L-04).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/instruction-ledger.sh" ]] && source "$_lib_dir/instruction-ledger.sh"
[[ -f "$_lib_dir/prompt-classifier.sh" ]] && source "$_lib_dir/prompt-classifier.sh"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "UserPromptSubmit"' 2>/dev/null || echo UserPromptSubmit)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null || true)"

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

if [[ "$hook_event" == "UserPromptSubmit" ]]; then
  [[ -n "$prompt" ]] || exit 0
  sb_instruction_ledger_seed_from_prompt "$prompt"
  summary="$(sb_instruction_ledger_pending_summary 2>/dev/null || true)"
  [[ -n "$summary" ]] || exit 0
  ctx="$(printf '%s' "$summary" | jq -Rs '.')"
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}' "$ctx"
  exit 0
fi

# Stop / SubagentStop — workers skip ledger block
if [[ "$hook_event" == "SubagentStop" ]]; then
  if [[ -f "$_lib_dir/orchestrator-parent.sh" ]]; then
    source "$_lib_dir/orchestrator-parent.sh"
    sb_orchestrator_is_worker_session 2>/dev/null && exit 0
  fi
fi

if declare -f sb_trivial_bypass >/dev/null 2>&1; then
  sb_trivial_bypass "$trivial_file"
fi

sb_instruction_ledger_auto_resolve_parents 2>/dev/null || true
if sb_instruction_ledger_all_resolved; then
  exit 0
fi

summary="$(sb_instruction_ledger_pending_summary)"
reason=$(printf 'Cannot complete — instruction ledger has unresolved items.\n\n%s\n\nResolve each item or defer to project planning before Stop.' "$summary")
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
printf '{"decision":"block","reason":%s}' "$json_reason"
exit 0
