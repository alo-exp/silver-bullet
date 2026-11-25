#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — RTK install/wiring gate before substantive work (opt-in enforced).
# Active only with the user's own consent (hooks/lib/user-consent.sh) inside an SB project
# whose .silver-bullet.json does not turn RTK off.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin rtk-gate rtk
# shellcheck source=lib/rtk-gate.sh
source "$_lib_dir/rtk-gate.sh"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

sb_rtk_required "$config_file" || exit 0

if ! sb_rtk_cli_available; then
  if sb_rtk_cli_path >/dev/null 2>&1; then
    reason="$(sb_rtk_block_message_wrong_binary)"
  else
    reason="$(sb_rtk_block_message_no_cli "$config_file")"
  fi
elif ! sb_rtk_version_ok "$config_file"; then
  reason="$(sb_rtk_block_message_old_version "$config_file")"
elif ! sb_rtk_platform_hook_present "$project_root"; then
  reason="$(sb_rtk_block_message_no_hook "$config_file")"
else
  exit 0
fi

if sb_tool_is_shell_like "$tool_name"; then
  command_str="$(sb_opt_in_command_string)"
  [[ -n "$command_str" ]] || exit 0
  sb_opt_in_shell_needs_gate rtk "$command_str" || exit 0
else
  sb_opt_in_edit_targets_exempt sb_rtk_edit_path_is_exempt && exit 0
fi

sb_opt_in_emit_block "$reason"
exit 0
