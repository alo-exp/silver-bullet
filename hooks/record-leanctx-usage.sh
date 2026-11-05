#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse — record LeanCTX usage for the opt-in gate: one lean-ctx CLI command run on its
# own that visibly succeeded, or an lctx_* tool call on the LeanCTX MCP server.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin record-leanctx-usage leanctx
# shellcheck source=lib/leanctx-gate.sh
source "$_lib_dir/leanctx-gate.sh"

sb_leanctx_required "$config_file" || exit 0

case "$tool_name" in
  Bash|Shell|shell|exec_command)
    sb_leanctx_command_is_usage "$(sb_opt_in_command_string)" || exit 0
    sb_opt_in_shell_succeeded || exit 0
    ;;
  *)
    sb_opt_in_mcp_call || exit 0
    sb_leanctx_mcp_server_matches "$mcp_server" || exit 0
    sb_leanctx_mcp_tool_is_usage "$mcp_tool" || exit 0
    sb_opt_in_mcp_succeeded || exit 0
    ;;
esac

if sb_leanctx_record_usage "$config_file"; then
  printf '{"hookSpecificOutput":{"message":"✅ LeanCTX usage recorded"}}'
fi
exit 0
