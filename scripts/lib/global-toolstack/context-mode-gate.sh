#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR
umask 0077
_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "$_LIB/common.sh"
command -v jq >/dev/null 2>&1 || exit 0
ts_sb_defer_to_bridge && exit 0
ts_config >/dev/null 2>&1 || exit 0
ts_enforcement_active || exit 0
ts_tool_required context_mode || exit 0
input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
project_root="$(ts_git_root 2>/dev/null || true)"
[[ -n "$project_root" ]] || exit 0
tool_name="$(ts_tool_name "$input")"
file_path="$(ts_tool_file_path "$input")"
command_str="$(ts_tool_command_string "$input")"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac
if [[ -n "$file_path" ]]; then
  case "$file_path" in */.cursor/*|*/hooks/*) exit 0 ;; esac
elif [[ -n "$command_str" ]]; then
  if printf '%s' "$command_str" | grep -qE '(^|[[:space:]])(context-mode|ctx_)(\s|$)'; then exit 0; fi
  ts_is_substantive_shell "$command_str" || exit 0
else exit 0; fi
if ! ts_context_mode_cli_available; then
  ts_emit_deny "🚫 CONTEXT MODE REQUIRED — npm install -g context-mode (sb_grep/sb_slice/sb_webfetch owner)" "$hook_event"
  exit 0
fi
if ! ts_context_mode_mcp_wired; then
  ts_emit_deny "🚫 CONTEXT MODE MCP NOT WIRED — run bash scripts/optimize-rtk-context-mode.sh --host cursor" "$hook_event"
  exit 0
fi
exit 0
