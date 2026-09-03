#!/usr/bin/env bash
# Emit Claude Code hook JSON with required hookEventName field (CLI 2.1+).
# Usage:
#   sb_emit_hook_message "PostToolUse" "✅ Skill recorded"
#   sb_emit_hook_message_json "PreToolUse" "$json_message_string"

sb_emit_hook_message() {
  local event="${1:-PostToolUse}"
  local message="${2:-}"
  [[ -n "$message" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg e "$event" --arg m "$message" \
      '{"hookSpecificOutput":{"hookEventName":$e,"message":$m}}'
    return 0
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"%s","message":%s}}' \
    "$event" "$(printf '%s' "$message" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$message")"
}

# message_json: already jq-escaped string (e.g. from jq -Rs '.')
sb_emit_hook_message_json() {
  local event="${1:-PostToolUse}"
  local message_json="${2:-}"
  [[ -n "$message_json" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg e "$event" --argjson m "$message_json" \
      '{"hookSpecificOutput":{"hookEventName":$e,"message":$m}}'
    return 0
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"%s","message":%s}}' "$event" "$message_json"
}
