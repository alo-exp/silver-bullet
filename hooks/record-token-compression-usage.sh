#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse/Bash — record RTK usage for the token-compression gate: a command whose first
# program is rtk and that visibly succeeded.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin record-token-compression-usage rtk
case "$tool_name" in
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac
# shellcheck source=lib/token-compression-tools-gate.sh
source "$_lib_dir/token-compression-tools-gate.sh"

sb_token_tool_enforced "$config_file" rtk || exit 0
sb_token_tool_command_matches "$(sb_opt_in_command_string)" rtk rtk || exit 0
sb_opt_in_shell_succeeded || exit 0

if sb_token_tool_record_usage "$config_file" rtk; then
  printf '{"hookSpecificOutput":{"message":"✅ %s usage recorded"}}' "$(sb_recommended_tool_display_name rtk)"
fi
exit 0
