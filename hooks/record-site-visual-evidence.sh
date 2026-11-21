#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse — record the screenshot file a host browser tool took, as site visual evidence. This hook is the
# only writer of site-visual-evidence.json (the state directory is protected from the agent), so what it records
# is a file that exists, taken by a browser tool the host ran after the latest site edit (R9-03).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/site-session.sh" ]] && source "$_lib_dir/site-session.sh"
[[ -f "$_lib_dir/tool-input.sh" ]] && source "$_lib_dir/tool-input.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0
hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null || echo PostToolUse)"
[[ "$hook_event" == "PostToolUse" ]] || exit 0

# Claude names MCP tools mcp__<server>__<tool> (Playwright: mcp__playwright__browser_take_screenshot); Codex
# reports an MCP call as tool_name MCP with the tool in tool_input. Match on the screenshot suffix.
tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
case "$tool_name" in
  mcp__*screenshot* | browser_take_screenshot) ;;
  MCP)
    mcp_tool="$(printf '%s' "$input" | jq -r '.tool_input.toolName // .tool_input.name // ""')"
    case "$mcp_tool" in
      *screenshot*) ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0
sb_site_profile_load || exit 0
# Only a session with site edits has anything to prove.
sb_site_session_gates_apply || exit 0

# The file path: the tool's own result fields, the filename the agent asked for, or an image path in the
# result text. Relative paths are the browser tool's output directory: the project, then the working directory.
candidates="$(printf '%s' "$input" | jq -r '
  [ (.tool_response | objects | (.path, .filename, .result.path)?),
    (.tool_input | objects | .filename?),
    ([.tool_response | .. | strings | scan("[^\\s()\"`<>]+\\.(?:png|jpe?g|webp)")] | reverse | .[]) ]
  | .[] | strings | select(length > 0)')"
path=""
while IFS= read -r candidate; do
  [[ -n "$candidate" ]] || continue
  for resolved in "$candidate" "$SB_SITE_ROOT/$candidate" "$PWD/$candidate"; do
    if [[ "$resolved" == /* && -f "$resolved" && ! -L "$resolved" ]]; then
      path="$resolved"
      break 2
    fi
  done
done <<<"$candidates"
[[ -n "$path" ]] || exit 0

sb_site_session_mark_visual_evidence "$path" 2>/dev/null || true
jq -cn '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"site visual evidence recorded"}}'
exit 0
