#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034  # input, tool_name, config_file, project_root, mcp_* are set by sb_opt_in_hook_begin (hooks/lib/opt-in-gate.sh)
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook — Alumnium MCP wiring gate for browser/visual work (opt-in enforced).
# Active only with the user's own consent (hooks/lib/user-consent.sh) inside an SB project
# whose .silver-bullet.json does not turn Alumnium off.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || exit 0
[[ -f "$_lib_dir/opt-in-gate.sh" ]] || exit 0
# shellcheck source=lib/opt-in-gate.sh
source "$_lib_dir/opt-in-gate.sh"
sb_opt_in_hook_begin alumnium-gate alumnium
# shellcheck source=lib/alumnium-gate.sh
source "$_lib_dir/alumnium-gate.sh"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|Shell|shell|exec_command) ;;
  *) exit 0 ;;
esac

sb_alumnium_required "$config_file" || exit 0

if ! sb_alumnium_npx_available; then
  reason="$(sb_alumnium_block_message_no_npx)"
elif ! sb_alumnium_platform_artifact_present "$project_root"; then
  reason="$(sb_alumnium_block_message_no_mcp "$config_file")"
else
  exit 0
fi

if sb_tool_is_shell_like "$tool_name"; then
  command_str="$(sb_opt_in_command_string)"
  [[ -n "$command_str" ]] || exit 0
  sb_alumnium_command_requires_browser "$command_str" || exit 0
else
  browser=0
  while IFS= read -r path; do
    file_path="${file_path:-$path}"
    if ! sb_alumnium_edit_path_is_exempt "$path" "$config_file" && sb_alumnium_edit_path_requires_browser "$path"; then
      browser=1
    fi
  done < <(sb_opt_in_target_paths)
  [[ "$browser" == 1 ]] || exit 0
fi

sb_opt_in_emit_block "$reason"
exit 0
