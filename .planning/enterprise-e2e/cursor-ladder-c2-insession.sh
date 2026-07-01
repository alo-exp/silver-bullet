#!/usr/bin/env bash
# Persistent in-session responder for Cursor-2 Phase A ladder.
set -euo pipefail
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOG="/tmp/cursor-ladder-c2-in-session-driver.log"
LADDER_LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor-ladder-live.log"
export SB_LIVE_CURSOR_SESSION_MAX_POLLS="${SB_LIVE_CURSOR_SESSION_MAX_POLLS:-7200}"

echo "=== cursor-ladder-c2-insession start $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" | tee -a "$LOG"
MARKER="Round Cursor-2 Phase A ladder end"
while true; do
  if [[ -f "$LADDER_LOG" ]] && grep -q "$MARKER" "$LADDER_LOG" 2>/dev/null; then
    break
  fi
  shopt -s nullglob
  for d in /var/folders/*/*/T/tmp.*/.cursor-live-session; do
    [[ -d "$d" ]] || continue
    bash "${SB_ROOT}/tests/live/lib/cursor-in-session-driver.sh" "$d" "$LADDER_LOG" >>"$LOG" 2>&1 || true
  done
  sleep 2
done
echo "=== cursor-ladder-c2-insession end $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" | tee -a "$LOG"
