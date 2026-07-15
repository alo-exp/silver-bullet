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
mcp_server="$(ts_mcp_server_name "$input")"
mcp_tool="$(ts_mcp_tool_name "$input")"
command_str="$(ts_tool_command_string "$input")"
# Block double shell compression: lean-ctx rewrite must not be primary when RTK owns sb_shell
if [[ "$tool_name" == "Shell" || "$tool_name" == "Bash" || "$tool_name" == "shell" ]]; then
  if [[ "$(ts_shell_compression_primary)" == "rtk" ]] && command -v rtk >/dev/null 2>&1; then
    if printf '%s' "$command_str" | grep -qE 'lean-ctx hook rewrite'; then
      ts_emit_deny "🚫 DOUBLE SHELL COMPRESSION — RTK owns sb_shell; remove lean-ctx hook rewrite from preToolUse" "$hook_event"
      exit 0
    fi
  fi
fi
# Block wrong-owner lctx_* sandbox/fetch/shell when CM present
if [[ "$tool_name" == "CallMcpTool" || "$tool_name" == "MCP" ]]; then
  case "$mcp_server" in *leanctx*|user-leanctx) ;;
  *) exit 0 ;; esac
  case "$mcp_tool" in
    lctx_shell|lctx_execute|lctx_batch_execute|lctx_fetch|lctx_fetch_and_index)
      if ts_context_mode_mcp_wired; then
        ts_emit_deny "🚫 WRONG OWNER — ${mcp_tool} disabled; use context-mode ctx_* or RTK shell (five_tool_routed)" "$hook_event"
        exit 0
      fi
      ;;
  esac
  case "$mcp_tool" in
    ctx_execute|ctx_execute_file|ctx_batch_execute|ctx_search|ctx_index|ctx_fetch_and_index)
      ts_emit_deny "🚫 WRONG OWNER — use context-mode MCP server for ctx_* tools, not leanctx" "$hook_event"
      exit 0
      ;;
  esac
fi
# Source SB coordinator lib when available for extended checks
sb_cache="$(ts_sb_plugin_cache 2>/dev/null || true)"
if [[ -n "$sb_cache" && -f "${sb_cache}/hooks/lib/stack-compression-coordinator.sh" ]]; then
  # shellcheck source=/dev/null
  source "${sb_cache}/hooks/lib/stack-compression-coordinator.sh" 2>/dev/null || true
fi
exit 0
