#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — ensure local site preview is healthy before site/** edits (Wave 3).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

config_file=""
repo_root=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    repo_root="$search_dir"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

if [[ -f "$_lib_dir/orchestrator-parent.sh" ]]; then
  source "$_lib_dir/orchestrator-parent.sh"
  sb_orchestrator_is_parent_session 2>/dev/null && exit 0
fi

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
sb_site_session_path_is_site "$file_path" || exit 0

if sb_site_preview_healthy; then
  exit 0
fi

serve_script="${repo_root}/site/serve.sh"
reason="Site preview preflight — local preview server is not healthy on :8765.

Before editing site/** run:
  bash site/serve.sh start
  bash site/serve.sh status

Then retry the edit. Durable preview: site/install-preview-launchagent.sh"
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
[[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]] && { printf '%s\n' "$reason" >&2; exit 2; }
exit 0
