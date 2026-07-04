#!/usr/bin/env bash
# PreToolUse — active delegation guard: block Claude/Codex parent edits; advise Cursor parent.
set -euo pipefail
trap 'exit 0' ERR

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in runtime-paths.sh sb-project-gate.sh agent-delegation-state.sh hook-audit.sh; do
  # shellcheck disable=SC1090
  [[ -f "$_lib_dir/$_lib" ]] && source "$_lib_dir/$_lib"
done
# shellcheck source=hooks/agent-delegation-progress-surface.sh
[[ -f "$(dirname "${BASH_SOURCE[0]}")/agent-delegation-progress-surface.sh" ]] && \
  source "$(dirname "${BASH_SOURCE[0]}")/agent-delegation-progress-surface.sh"

_sb_adg_have_jq=false
command -v jq >/dev/null 2>&1 && _sb_adg_have_jq=true

sb_adg_hook_field() {
  local json="$1" field="$2" default="${3:-}"
  if [[ "$_sb_adg_have_jq" == true ]]; then
    printf '%s' "$json" | jq -r ".$field // \"$default\"" 2>/dev/null || printf '%s' "$default"
    return 0
  fi
  case "$field" in
    hook_event_name) grep -q '"hook_event_name"[[:space:]]*:[[:space:]]*"PreToolUse"' <<<"$json" && printf 'PreToolUse' || printf '%s' "$default" ;;
    tool_name) printf '%s' "$json" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$//' || printf '%s' "$default" ;;
    *) printf '%s' "$default" ;;
  esac
}

_workspace_config=""
if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
  _workspace_config="$(sb_find_project_config_walk_only 2>/dev/null || true)"
fi
[[ -n "$_workspace_config" ]] || exit 0

sb_agent_delegation_v2_enabled || exit 0
sb_agent_delegation_is_active || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

hook_event="$(sb_adg_hook_field "$input" 'hook_event_name' 'PreToolUse')"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_adg_hook_field "$input" 'tool_name' '')"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  *) exit 0 ;;
esac

repo_root="$(dirname "$_workspace_config")"
target_path=""
if [[ "$_sb_adg_have_jq" == true ]]; then
  target_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
fi
[[ -n "$target_path" ]] || exit 0

sb_agent_delegation_path_in_scope "$target_path" "$repo_root" || exit 0

tier="$(sb_agent_delegation_parent_host_tier)"
progress="$(sb_agent_delegation_progress_surface 2>/dev/null || true)"
reason="Active external-agent delegation — parent must supervise, not edit scoped ownership paths. See AF-AGENT-DELEGATE."

if [[ "$tier" == "block" ]]; then
  if command -v jq >/dev/null 2>&1; then
    json_reason=$(printf '%s' "$reason" | jq -Rs '.')
    if declare -f sb_hook_audit_record >/dev/null 2>&1; then
      sb_hook_audit_record "agent-delegation-guard" "PreToolUse" "deny" "$reason" ""
    fi
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    exit 0
  fi
  printf '%s\n' "$reason" >&2
  exit 2
fi

# Cursor: advise via additional_context
if command -v jq >/dev/null 2>&1; then
  ctx=$(printf '%s\n%s' "$reason" "$progress" | jq -Rs '.')
  if declare -f sb_hook_audit_record >/dev/null 2>&1; then
    sb_hook_audit_record "agent-delegation-guard" "PreToolUse" "advise" "$reason" ""
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":%s}}' "$ctx"
fi
exit 0
