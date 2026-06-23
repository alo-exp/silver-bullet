#!/usr/bin/env bash
# Poll a cursor in-session ladder session dir and write LADDER_PASS responses.
#
# Used when the full-ladder harness blocks on request-*.json files. A parent
# Cursor agent (or this auto-responder for smoke validation) watches the session
# directory and writes response-*.json via cursor-in-session-respond.sh.
#
# Usage:
#   bash tests/live/lib/cursor-in-session-driver.sh <session_dir> [log_file]
set -euo pipefail

SESSION_DIR="${1:?session_dir required}"
LOG_FILE="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESPOND="${SCRIPT_DIR}/cursor-in-session-respond.sh"
PASS_TEXT="${SB_LIVE_CURSOR_SESSION_PASS_TEXT:-LADDER_PASS: divide() lacks a zero-divisor check and will raise ZeroDivisionError when b is 0.}"
POLL_SECONDS="${SB_LIVE_CURSOR_SESSION_POLL_SECONDS:-1}"
MAX_POLLS="${SB_LIVE_CURSOR_SESSION_MAX_POLLS:-600}"

if [[ ! -d "$SESSION_DIR" ]]; then
  printf 'ERROR: session dir not found: %s\n' "$SESSION_DIR" >&2
  exit 1
fi

respond_pending() {
  shopt -s nullglob
  local req id wrote=0
  for req in "$SESSION_DIR"/request-*.json; do
    id="$(basename "$req" .json | sed 's/^request-//')"
    [[ -f "$SESSION_DIR/response-${id}.json" ]] && continue
    bash "$RESPOND" "$SESSION_DIR" "$id" "$PASS_TEXT"
    wrote=1
  done
  return "$wrote"
}

poll=0
while [[ "$poll" -lt "$MAX_POLLS" ]]; do
  respond_pending || true
  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] && grep -q "Results:" "$LOG_FILE" 2>/dev/null; then
    respond_pending || true
    break
  fi
  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] && grep -q "Results:.*failed" "$LOG_FILE" 2>/dev/null; then
    break
  fi
  sleep "$POLL_SECONDS"
  poll=$((poll + 1))
done

respond_pending || true
printf 'cursor in-session driver finished (polls=%s)\n' "$poll"
