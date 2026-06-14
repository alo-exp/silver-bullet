#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse guard for implementation edits inside composed Silver Bullet
# workflows.
#
# The workflow tracker (.planning/workflows/<id>.md) is the admission ticket.
# Once a silver:feature / silver:ui / silver:devops / silver:research
# composition is active, this hook blocks implementation edits until the
# pre-execution dependency chain has been recorded in the Silver Bullet state
# file. It deliberately does not require execute, review, verify, or ship
# markers before edits; those are post-implementation and final-delivery gates.

umask 0077

# Source runtime path selector for the state ledger fallback.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck source=lib/required-skills.sh
  source "$_lib_dir/required-skills.sh"
fi
if [[ -f "$_lib_dir/hook-audit.sh" ]]; then
  # shellcheck source=lib/hook-audit.sh
  source "$_lib_dir/hook-audit.sh"
fi

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

resolve_repo_root() {
  local d="$PWD"
  while [[ "$d" != "/" && -n "$d" ]]; do
    if [[ -d "$d/.planning" || -d "$d/.git" ]]; then
      printf '%s' "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  return 1
}

emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  sb_hook_audit_record "workflow-chain-guard" "PreToolUse" "deny" "$reason" "${workflow_file:-}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

composer_slug_from_value() {
  local composer="${1:-}"
  composer=$(printf '%s' "$composer" | tr '[:upper:]' '[:lower:]')
  composer="${composer#/}"
  composer=$(printf '%s' "$composer" | sed 's|[:/]|-|g; s|[^a-z0-9-]|-|g; s|--*|-|g; s|^-||; s|-$||')
  printf '%s' "$composer"
}

repo_root="$(resolve_repo_root 2>/dev/null || true)"
[[ -n "$repo_root" ]] || exit 0

wf_dir="$repo_root/.planning/workflows"
[[ -d "$wf_dir" && ! -L "$wf_dir" ]] || exit 0

shopt -s nullglob
active_workflows=("$wf_dir"/*.md)
shopt -u nullglob
[[ ${#active_workflows[@]} -gt 0 ]] || exit 0

if [[ ${#active_workflows[@]} -gt 1 ]]; then
  active_names=""
  for wf in "${active_workflows[@]}"; do
    active_names+="  • $(basename "$wf" .md)"$'\n'
  done
  emit_block "$(printf 'WORKFLOW DEPENDENCY GATE — multiple active composed workflows are present.\n\nActive workflows:\n%s\nResolve the active workflow selection before making implementation edits.' "$active_names")"
  exit 0
fi

workflow_file="${active_workflows[0]}"
workflow_id="$(basename "$workflow_file" .md)"
composer_raw="$(awk -F': ' '/^composer: / { print $2; exit }' "$workflow_file" 2>/dev/null || true)"
composer_slug="$(composer_slug_from_value "$composer_raw")"

required_markers=()
case "$composer_slug" in
  silver-feature)
    required_markers=(silver-quality-gates silver-context silver-plan)
    ;;
  silver-ui)
    required_markers=(silver-quality-gates silver-context silver-ui-contract silver-plan)
    ;;
  silver-devops)
    required_markers=(silver-blast-radius devops-quality-gates silver-context silver-plan)
    ;;
  silver-research)
    required_markers=(silver-clarify)
    ;;
  silver-bugfix)
    # Bugfix is diagnosis-first: the documented pre-execution chain is
    # ORIENT → DEBUG → PLAN (see skills/silver-bugfix/SKILL.md). Quality-gates
    # and context are not part of the bugfix pre-execution chain (quality-gates
    # runs post-execute at Step 7b). Require only the DEBUG and PLAN markers
    # that are genuinely recorded before the first fix/test edit.
    required_markers=(silver-debug silver-plan)
    ;;
  *)
    exit 0
    ;;
esac

config_file=""
if [[ -f "$repo_root/.silver-bullet.json" ]]; then
  config_file="$repo_root/.silver-bullet.json"
fi

state_file="${SILVER_BULLET_STATE_FILE:-${SB_RUNTIME_STATE_DIR}/state}"
if [[ -n "$config_file" ]]; then
  cfg_state="$(jq -r '.state.state_file // ""' "$config_file" 2>/dev/null || true)"
  [[ -n "$cfg_state" ]] && state_file="${cfg_state/#\~/$HOME}"
fi
if ! sb_runtime_path_is_state_scoped "$state_file"; then
  state_file="${SB_RUNTIME_STATE_DIR}/state"
fi

missing_markers=()
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")
for marker in "${required_markers[@]}"; do
  if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
    sb_required_skill_is_recorded "$state_contents" "$marker" && continue
  elif grep -Fqx -- "$marker" "$state_file" 2>/dev/null; then
    continue
  fi
  missing_markers+=("$marker")
done

[[ ${#missing_markers[@]} -eq 0 ]] && exit 0

missing_lines=""
for marker in "${missing_markers[@]}"; do
  missing_lines+="  • ${marker}"$'\n'
done

emit_block "$(printf 'WORKFLOW DEPENDENCY GATE — %s (%s) is active, but the pre-execution SB lifecycle chain is not yet recorded.\n\nMissing markers:\n%s\nBefore making implementation edits, complete the missing pre-execution SB steps. Execute, review, verify, and ship markers are checked later by completion gates, not here.' "$composer_raw" "$workflow_id" "$missing_lines")"
