#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: .*, async: false)
# Checks for /tmp/.silver-bullet-timeout flag set by session-log-init.sh sentinel.
# Emits a non-blocking warning in autonomous mode when the flag is current.
# Supports macOS (stat -f %m) and Linux (stat --format=%Y).

# Consume stdin (required to avoid broken pipe)
cat > /dev/null

# Mode gate: only act in autonomous mode
mode_file_content=$(cat /tmp/.silver-bullet-mode 2>/dev/null || echo "interactive")
[[ "$mode_file_content" != "autonomous" ]] && exit 0

# Check for timeout flag (allow override for testing)
flag_file="${TIMEOUT_FLAG_OVERRIDE:-/tmp/.silver-bullet-timeout}"
[[ -f "$flag_file" ]] || exit 0

# Platform-aware stat helper: returns file mtime as epoch seconds
_mtime() {
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f %m "$1" 2>/dev/null
  else
    stat --format=%Y "$1" 2>/dev/null
  fi
}

# Stale-flag check
session_start=$(cat /tmp/.silver-bullet-session-start-time 2>/dev/null || echo "")
[[ -z "$session_start" ]] && exit 0
flag_mtime=$(_mtime "$flag_file") || exit 0
[[ "$flag_mtime" -lt "$session_start" ]] && exit 0

# Rate-limiting
count_file="/tmp/.silver-bullet-timeout-warn-count"
count=0
if [[ -f "$count_file" ]]; then
  count_mtime=$(_mtime "$count_file") || count_mtime=0
  if [[ "$count_mtime" -lt "$session_start" ]]; then
    # Stale count from prior session — reset
    count=0
  else
    count=$(cat "$count_file" 2>/dev/null || echo "0")
  fi
fi
count=$((count + 1))
echo "$count" > "$count_file"
# Emit only on 1st, 6th, 11th... call (count mod 5 == 1)
[[ $((count % 5)) -ne 1 ]] && exit 0

printf '{"hookSpecificOutput":{"message":"⚠️ Autonomous session running 10+ min. Check for stalls or log a blocker under Needs human review."}}'
