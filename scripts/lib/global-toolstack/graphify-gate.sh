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
ts_tool_required graphify || exit 0
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
  ts_graphify_edit_path_is_exempt "$file_path" && exit 0
elif [[ -n "$command_str" ]]; then
  ts_graphify_command_is_exempt "$command_str" && exit 0
  ts_is_substantive_shell "$command_str" || exit 0
else exit 0; fi
graph_rel="$(ts_effective_graph_path)"
ttl="$(ts_effective_query_ttl)"
budget="$(ts_effective_query_budget)"
if ! ts_graphify_cli_available; then
  ts_emit_deny "🚫 GRAPHIFY REQUIRED — CLI not installed (uv tool install graphifyy). Config: ~/.cursor/toolstack.json" "$hook_event"
  exit 0
fi
if ! ts_graphify_index_exists "$project_root"; then
  ts_emit_deny "🚫 GRAPHIFY INDEX MISSING — run: graphify update . --no-cluster (expected ${graph_rel})" "$hook_event"
  exit 0
fi
ts_graphify_query_is_fresh && exit 0
ts_emit_deny "$(ts_graphify_block_message_stale_query)" "$hook_event"
exit 0
