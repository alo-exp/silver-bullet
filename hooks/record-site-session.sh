#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse — record site/** edits and site-intent prompts for session gates.
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

config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
[[ -n "$config_file" ]] || exit 0
sb_project_gate_or_exit 2>/dev/null || exit 0

if [[ "$hook_event" == "UserPromptSubmit" ]]; then
  prompt="$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null || true)"
  if sb_site_prompt_is_site_intent "$prompt"; then
    sb_site_session_mark_site_intent
    if printf '%s' "$prompt" | grep -qiE '\blive\b|publish|pushed to main|go live'; then
      sb_site_session_mark_live_claim_pending
    fi
  fi
  exit 0
fi

[[ "$hook_event" == "PostToolUse" ]] || exit 0
tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
file_path="$(sb_tool_file_path "$input" 2>/dev/null || printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)"

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch)
    if sb_site_session_path_is_site "$file_path"; then
      sb_site_session_touch "edit:${file_path}"
    fi
    ;;
  Bash|Shell|shell|exec_command)
    cmd="$(sb_tool_command_string "$input" 2>/dev/null || true)"
    if printf '%s' "$cmd" | grep -qE '\bgit push\b'; then
      sb_site_session_mark_push_intent
    fi
    ;;
esac

exit 0
