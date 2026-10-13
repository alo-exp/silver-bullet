#!/usr/bin/env bash
# Quota / rate-limit detection for enterprise E2E matrix interactive sessions.

is_quota_failure() {
  local output="$1"
  local log_file="${2:-}"
  if printf '%s\n' "$output" | grep -qiE '429|token[[:space:]]+plan|usage[[:space:]]+limit|rate[[:space:]]+limit'; then
    return 0
  fi
  if [[ -n "$log_file" && -f "$log_file" ]] \
    && grep -qiE '429|token[[:space:]]+plan|usage[[:space:]]+limit|rate[[:space:]]+limit' "$log_file" 2>/dev/null; then
    return 0
  fi
  return 1
}
