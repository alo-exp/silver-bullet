#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse guard for implementation edits inside composed Silver Bullet
# workflows.
#
# The workflow tracker (.planning/workflows/<id>.md) is the admission ticket.
# Once a silver:feature / silver:ui / silver:research composition is active,
# this hook blocks implementation edits until the downstream dependency chain
# has actually been recorded in the Silver Bullet state file. That prevents the
# model from "pretending" the GSD / brainstorming / research steps happened and
# then jumping straight to local edits.

umask 0077

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
    required_markers=(gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-verify-work)
    ;;
  silver-ui)
    required_markers=(gsd-discuss-phase gsd-ui-phase gsd-plan-phase gsd-execute-phase gsd-ui-review gsd-verify-work)
    ;;
  silver-research)
    required_markers=(gsd-explore brainstorming)
    ;;
  *)
    exit 0
    ;;
esac

config_file=""
if [[ -f "$repo_root/.silver-bullet.json" ]]; then
  config_file="$repo_root/.silver-bullet.json"
fi

state_file="${SILVER_BULLET_STATE_FILE:-${HOME}/.claude/.silver-bullet/state}"
if [[ -n "$config_file" ]]; then
  cfg_state="$(jq -r '.state.state_file // ""' "$config_file" 2>/dev/null || true)"
  [[ -n "$cfg_state" ]] && state_file="${cfg_state/#\~/$HOME}"
fi
case "$state_file" in
  "$HOME"/.claude/*) ;;
  *) state_file="${HOME}/.claude/.silver-bullet/state" ;;
esac

missing_markers=()
for marker in "${required_markers[@]}"; do
  if ! grep -qx "$marker" "$state_file" 2>/dev/null; then
    missing_markers+=("$marker")
  fi
done

[[ ${#missing_markers[@]} -eq 0 ]] && exit 0

missing_lines=""
for marker in "${missing_markers[@]}"; do
  missing_lines+="  • ${marker}"$'\n'
done

emit_block "$(printf 'WORKFLOW DEPENDENCY GATE — %s (%s) is active, but the downstream dependency chain is not yet recorded.\n\nMissing markers:\n%s\nBefore making implementation edits, invoke the missing downstream skills via the Skill tool and wait for them to complete. If any dependency skill is unavailable, stop and notify the user; offer install-and-retry first.' "$composer_raw" "$workflow_id" "$missing_lines")"
