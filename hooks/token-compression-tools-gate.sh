#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — RTK usage freshness before delivery commands (git commit, gh pr create,
# gh release create), and the stack mutex for them. Shell tools only: edits are not gated.
# Active only with the user's own consent (hooks/lib/user-consent.sh).

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin token-compression-tools-gate rtk context_mode leanctx
case "$tool_name" in
  Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac
# shellcheck source=lib/token-compression-tools-gate.sh
source "$_lib_dir/token-compression-tools-gate.sh"

command_str="$(sb_opt_in_command_string)"
[[ -n "$command_str" ]] || exit 0
sb_token_tool_command_is_delivery "$command_str" || exit 0

declare -f sb_stack_set_session >/dev/null 2>&1 && sb_stack_set_session "$input"
if sb_token_tool_mutex_dirty "$config_file"; then
  sb_opt_in_emit_block "$(sb_token_compression_mutual_exclusion_block_message)"
  exit 0
fi

if sb_token_tool_enforced "$config_file" rtk; then
  if ! sb_token_tool_cli_available "$config_file" rtk || ! sb_token_tool_usage_is_fresh "$config_file" rtk; then
    sb_opt_in_emit_block "$(sb_token_tool_block_message "$config_file" rtk)"
    exit 0
  fi
fi

exit 0
