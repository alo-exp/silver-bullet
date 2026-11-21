#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse — record browser screenshot paths for site visual evidence V-loop.
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

tool_name="$(sb_tool_name "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_name // ""')"
case "$tool_name" in
  browser_take_screenshot|MCP) ;;
  *) exit 0 ;;
esac

# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
search_dir="${config_file:+${config_file%/*}}"
search_dir="${search_dir:-$PWD}"
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

path=""
if [[ "$tool_name" == "browser_take_screenshot" ]]; then
  path="$(printf '%s' "$input" | jq -r '.tool_response.path // .tool_response.filename // ""' 2>/dev/null || true)"
else
  mcp_tool="$(printf '%s' "$input" | jq -r '.tool_input.toolName // .tool_input.name // ""' 2>/dev/null || true)"
  case "$mcp_tool" in
    browser_take_screenshot|take_screenshot|screenshot) ;;
    *) exit 0 ;;
  esac
  path="$(printf '%s' "$input" | jq -r '.tool_response.path // .tool_response.result.path // ""' 2>/dev/null || true)"
fi
[[ -n "$path" ]] || exit 0

sb_site_session_mark_visual_evidence "$path" 2>/dev/null || true
printf '{"hookSpecificOutput":{"message":"✅ site visual evidence recorded"}}'
exit 0
