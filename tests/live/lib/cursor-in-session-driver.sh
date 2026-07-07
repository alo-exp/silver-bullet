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
DEFAULT_PASS_TEXT="LADDER_PASS: divide() lacks a zero-divisor check and will raise ZeroDivisionError when b is 0."
PASS_TEXT="${SB_LIVE_CURSOR_SESSION_PASS_TEXT:-$DEFAULT_PASS_TEXT}"
SCRIPT_DIR_FOR_TRIAGE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/live/lib/review-fix-ladder-triage-scenario.sh
source "${SCRIPT_DIR_FOR_TRIAGE}/review-fix-ladder-triage-scenario.sh" 2>/dev/null || true
POLL_SECONDS="${SB_LIVE_CURSOR_SESSION_POLL_SECONDS:-1}"
MAX_POLLS="${SB_LIVE_CURSOR_SESSION_MAX_POLLS:-600}"

if [[ ! -d "$SESSION_DIR" ]]; then
  printf 'ERROR: session dir not found: %s\n' "$SESSION_DIR" >&2
  exit 1
fi

cursor_in_session_response_for_request() {
  local req_file="$1"
  local prompt phase text
  prompt="$(jq -r '.prompt // ""' "$req_file" 2>/dev/null || true)"
  if review_fix_ladder_triage_scenario_enabled 2>/dev/null && [[ -n "$prompt" ]]; then
    phase="$(review_fix_ladder_phase_from_prompt "$prompt")"
    if [[ "$phase" != "unknown" ]]; then
      text="$(review_fix_ladder_cursor_phase_response "$phase")"
      printf '%s' "$text"
      return 0
    fi
  fi
  printf '%s' "$PASS_TEXT"
}

respond_pending() {
  shopt -s nullglob
  local req id wrote=0 response_text
  for req in "$SESSION_DIR"/request-*.json; do
    id="$(basename "$req" .json | sed 's/^request-//')"
    [[ -f "$SESSION_DIR/response-${id}.json" ]] && continue
    response_text="$(cursor_in_session_response_for_request "$req")"
    bash "$RESPOND" "$SESSION_DIR" "$id" "$response_text"
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
