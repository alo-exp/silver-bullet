#!/usr/bin/env bash
# Enterprise E2E — cursor triage ladder scenario (review → triage → file → fix → verify).
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor-triage-ladder-live.log"
cd "$SB_ROOT"

export SB_ROOT SILVER_BULLET_RUNTIME=cursor SB_LIVE_RUNTIME=cursor
export RTK_DISABLED=1
export SB_LIVE_REVIEW_FIX_LADDER_LIVE=1
export SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO=1
export SB_LIVE_REVIEW_FIX_LADDER_LITE_PROMPT=0
# Real GitHub PM filing when gh auth or GITHUB_TOKEN is available
if command -v gh >/dev/null 2>&1 && { [[ -n "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]] || gh auth status >/dev/null 2>&1; }; then
  export SB_RFL_GITHUB_E2E=1
fi
export CURSOR_AGENT=1 SB_LIVE_CURSOR_IN_SESSION=1
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5

if [[ -z "${SB_TEST_ENTERPRISE_APP_ROOT:-}" ]]; then
  SB_TEST_ENTERPRISE_APP_ROOT="/Users/shafqat/projects/enterprise-grade-test-app-cursor"
fi
export SB_TEST_ENTERPRISE_APP_ROOT

_in_session_driver() {
  local session_dir="$1"
  local log_file="$2"
  SB_LIVE_CURSOR_SESSION_MAX_POLLS="${SB_LIVE_CURSOR_SESSION_MAX_POLLS:-7200}" \
    bash "${SB_ROOT}/tests/live/lib/cursor-in-session-driver.sh" "$session_dir" "$log_file"
}

{
  echo "=== Triage ladder scenario start $(date -u +%Y-%m-%dT%H:%M:%SZ) @ $(git rev-parse --short HEAD) ==="
  (
    for _ in $(seq 1 120); do
      for d in /var/folders/*/*/T/tmp.*/.cursor-live-session "${TMPDIR:-/tmp}"/tmp.*/.cursor-live-session; do
        [[ -d "$d" ]] || continue
        _in_session_driver "$d" "$LOG"
        exit 0
      done
      sleep 1
    done
  ) >> /tmp/cursor-triage-ladder-in-session-driver.log 2>&1 &
  echo "in-session driver pid $! (log /tmp/cursor-triage-ladder-in-session-driver.log)"
  bash tests/enterprise-e2e-live/test-enterprise-e2e-triage-ladder-scenario.sh
  echo "=== Triage ladder scenario end $(date -u +%Y-%m-%dT%H:%M:%SZ) exit:$? ==="
} 2>&1 | tee -a "$LOG"
