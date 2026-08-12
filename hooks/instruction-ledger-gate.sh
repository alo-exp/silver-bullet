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

if [[ -f "$_lib_dir/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=lib/e2e-matrix-routing.sh
  source "$_lib_dir/e2e-matrix-routing.sh"
  if [[ "$hook_event" == "Stop" || "$hook_event" == "SubagentStop" ]] \
    && sb_e2e_matrix_routing_row_active 2>/dev/null; then
    exit 0
  fi
fi

SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
trivial_file="${SB_STATE_DIR}/trivial"

if [[ "$hook_event" == "UserPromptSubmit" ]]; then
  [[ -n "$prompt" ]] || exit 0
  sb_instruction_ledger_seed_from_prompt "$prompt"
  summary="$(sb_instruction_ledger_pending_summary 2>/dev/null || true)"
  [[ -n "$summary" ]] || exit 0
  if [[ -f "$_lib_dir/ups-coalesce.sh" ]]; then
    # shellcheck source=lib/ups-coalesce.sh
    source "$_lib_dir/ups-coalesce.sh"
    sb_ups_emit_additional_context "$summary" "UserPromptSubmit"
  else
    ctx="$(printf '%s' "$summary" | jq -Rs '.')"
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}' "$ctx"
  fi
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

# Foreign branch/worktree ledger must not deadlock Stop (SB-BUG-C #249).
if declare -f sb_instruction_ledger_drop_if_scope_mismatch >/dev/null 2>&1; then
  sb_instruction_ledger_drop_if_scope_mismatch "$PWD" 2>/dev/null || true
fi

sb_instruction_ledger_auto_resolve_parents 2>/dev/null || true
if sb_instruction_ledger_all_resolved; then
  exit 0
fi

summary="$(sb_instruction_ledger_pending_summary)"
if [[ -f "$_lib_dir/stop-coalesce.sh" ]]; then
  # shellcheck source=lib/stop-coalesce.sh
  source "$_lib_dir/stop-coalesce.sh"
  if sb_stop_coalesce_suppress_secondary_block 2>/dev/null; then
    exit 0
  fi
fi
reason=$(printf 'Cannot complete — instruction ledger has unresolved items.\n\n%s\n\nDo not Edit %s/instruction-ledger.json (state tamper blocks it). Use scripts/resolve-instruction-ledger.sh to mark each leaf done or deferred with evidence, then Stop.' \
  "$summary" "${SB_RUNTIME_STATE_DIR}")
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
if declare -f sb_stop_coalesce_record >/dev/null 2>&1; then
  sb_stop_coalesce_record "$reason"
fi
printf '{"decision":"block","reason":%s}' "$json_reason"
exit 0


