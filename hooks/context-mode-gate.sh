#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — Context Mode install/wiring gate (opt-in enforced).
# Active only with the user's own consent (hooks/lib/user-consent.sh) inside an SB project
# whose .silver-bullet.json does not turn Context Mode off.
# Usage (ctx_* vs Read) is instructional in silver-bullet.md §2g-ii; large reads are handled
# by context-mode-read-deny.sh.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin context-mode-gate context_mode
# shellcheck source=lib/context-mode-gate.sh
source "$_lib_dir/context-mode-gate.sh"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

sb_context_mode_required "$config_file" || exit 0

if ! sb_context_mode_node_ok "$config_file"; then
  reason="$(sb_context_mode_block_message_node "$config_file")"
elif ! sb_context_mode_cli_available; then
  reason="$(sb_context_mode_block_message_no_cli "$config_file")"
elif ! sb_context_mode_platform_artifact_present "$project_root"; then
  reason="$(sb_context_mode_block_message_no_platform "$config_file")"
elif ! sb_context_mode_instruction_fragment_present "$project_root"; then
  reason="$(sb_context_mode_block_message_no_fragment)"
else
  exit 0
fi

if sb_tool_is_shell_like "$tool_name"; then
  command_str="$(sb_opt_in_command_string)"
  [[ -n "$command_str" ]] || exit 0
  sb_opt_in_shell_needs_gate context_mode "$command_str" || exit 0
else
  sb_opt_in_edit_targets_exempt sb_context_mode_edit_path_is_exempt && exit 0
fi

sb_opt_in_emit_block "$reason"
exit 0
