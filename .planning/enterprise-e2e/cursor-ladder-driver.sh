#!/usr/bin/env bash
# Phase A live review-fix-ladder 8/8 — Cursor host.
set -euo pipefail

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor-ladder-live.log"
cd "$SB_ROOT"

export SB_ROOT SILVER_BULLET_RUNTIME=cursor SB_LIVE_RUNTIME=cursor
export RTK_DISABLED=1
export SB_LIVE_REVIEW_FIX_LADDER_LIVE=1
export SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1
export SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5

# When IDE in-session mode blocks on request-*.json, auto-respond in background.
_in_session_driver() {
  local session_dir="$1"
  local log_file="$2"
  SB_LIVE_CURSOR_SESSION_MAX_POLLS="${SB_LIVE_CURSOR_SESSION_MAX_POLLS:-7200}" \
    bash "${SB_ROOT}/tests/live/lib/cursor-in-session-driver.sh" "$session_dir" "$log_file"
}

{
  echo "=== Phase A ladder start $(date -u +%Y-%m-%dT%H:%M:%SZ) @ $(git rev-parse --short HEAD) ==="
  if [[ "${CURSOR_AGENT:-}" == "1" || "${SB_LIVE_CURSOR_IN_SESSION:-}" == "1" ]]; then
    export SB_LIVE_CURSOR_IN_SESSION=1
    # Session dir is created by agent on first invoke; driver polls once it exists.
    (
      for _ in $(seq 1 120); do
        for d in /var/folders/*/*/T/tmp.*/.cursor-live-session; do
          [[ -d "$d" ]] || continue
          _in_session_driver "$d" "$LOG"
          exit 0
        done
        sleep 1
      done
    ) >> /tmp/cursor-ladder-in-session-driver.log 2>&1 &
    echo "in-session driver pid $! (log /tmp/cursor-ladder-in-session-driver.log)"
  fi
  bash tests/live/test-live-review-fix-ladder-full-ladder.sh
  echo "=== Phase A ladder end $(date -u +%Y-%m-%dT%H:%M:%SZ) exit:$? ==="
} 2>&1 | tee -a "$LOG"
