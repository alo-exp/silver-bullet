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
input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"' 2>/dev/null || echo PreToolUse)"
tool_name="$(ts_tool_name "$input")"
command_str="$(ts_tool_command_string "$input")"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac
[[ -n "$command_str" ]] || exit 0
if ! printf '%s' "$command_str" | grep -qE '\bgit commit\b|\bgh pr create\b|\bgh release create\b'; then
  exit 0
fi
if ts_tool_required rtk && ! ts_rtk_cli_available; then
  ts_emit_deny "🚫 RTK USAGE REQUIRED before commit — install RTK and run a compressed shell command first" "$hook_event"
  exit 0
fi
if ts_tool_required rtk && ! ts_token_usage_is_fresh rtk; then
  ts_emit_deny "🚫 RTK USAGE STALE — run an allow-listed shell command (RTK compresses via rtk hook cursor) before git commit" "$hook_event"
  exit 0
fi
exit 0
