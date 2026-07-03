#!/usr/bin/env bash
# Round Cursor-3 REAL phased driver: Phase A ladder → T2 rows 3,7,8 → batch 2 rows 2,4,5,9,10.
# Usage:
#   tmux new-session -d -s cursor3-pipeline \
#     "bash .planning/enterprise-e2e/cursor3-real-pipeline-driver.sh 2>&1 | tee -a .e2e-cursor3-pipeline-live.log"
set -euo pipefail

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
cd "$SB_ROOT"
LOG="${SB_ROOT}/.e2e-cursor3-pipeline-live.log"
PIPELINE_MARKER="${SB_ROOT}/.planning/enterprise-e2e/cursor3-real-pipeline.state"
LADDER_LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor3-ladder-live.log"

export SB_ROOT SB_E2E_BRANCH=enterprise-e2e/cursor
export SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app-cursor
export SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_SKIP_CURSOR_INSTALL=1
export SB_E2E_SURFACE_SKIP=0 SB_LIVE_CURSOR_FORCE_HEADLESS=1
export SB_E2E_MATRIX_FORCE_ALL=1 SB_E2E_MATRIX_FORCE=1
export SB_E2E_TEST_APP_ROUND=3
export RTK_DISABLED=1 CLAUDE_INTERACTIVE_TIMEOUT=1800 CURSOR_AGENT_TIMEOUT=1800
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5

# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT" || true

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"; }

phase_done() { grep -q "^${1}:DONE" "$PIPELINE_MARKER" 2>/dev/null; }
mark_done() { echo "${1}:DONE $(date -u +%Y-%m-%dT%H:%M:%SZ) @ $(git rev-parse --short HEAD)" >>"$PIPELINE_MARKER"; }

touch "$PIPELINE_MARKER"

# --- Phase A: review-fix-ladder 8/8 (live, not resolver-only) ---
if ! phase_done PHASE_A; then
  log "=== PHASE A ladder start @ $(git rev-parse --short HEAD) ==="
  {
    echo ""
    echo "=== Round Cursor-3 REAL Phase A ladder start $(date -u +%Y-%m-%dT%H:%M:%SZ) @ $(git rev-parse --short HEAD) ==="
    export SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1
    export SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0
    bash tests/live/test-live-review-fix-ladder-full-ladder.sh
    echo "=== Round Cursor-3 REAL Phase A ladder end $(date -u +%Y-%m-%dT%H:%M:%SZ) exit:$? ==="
  } 2>&1 | tee -a "$LADDER_LOG" | tee -a "$LOG"
  if tail -30 "$LADDER_LOG" | grep -qE "Results: (8|9) passed, 0 failed"; then
    mark_done PHASE_A
    log "PHASE A PASS"
  else
    log "PHASE A FAIL — see cursor3-ladder-live.log"
    exit 1
  fi
fi

# --- T2 smoke expansion: rows 3, 7, 8 ---
for ROW in 3 7 8; do
  PHASE_KEY="ROW_${ROW}"
  if phase_done "$PHASE_KEY"; then
    log "ROW ${ROW} already done — skip"
    continue
  fi
  log "=== ROW ${ROW} start ==="
  if bash .planning/enterprise-e2e/cursor3-real-driver.sh "$ROW" 2>&1 | tee -a "$LOG"; then
    ATTEMPT_LOG="${SB_ROOT}/.e2e-row${ROW}-cursor-attempt.log"
    LIVE_LOG="${SB_ROOT}/.e2e-cursor3-row${ROW}-live.log"
  if [[ -f "$ATTEMPT_LOG" ]]; then
      BYTES=$(wc -c <"$ATTEMPT_LOG" | tr -d ' ')
      log "ROW ${ROW} attempt log: ${BYTES} B"
      if [[ "$BYTES" -lt 2048 ]]; then
        log "ROW ${ROW} FAIL — §5b log floor (${BYTES} B < 2048)"
        exit 1
      fi
    fi
    mark_done "$PHASE_KEY"
    log "ROW ${ROW} driver exit 0"
  else
    log "ROW ${ROW} driver exit non-zero"
    exit 1
  fi
done

# --- T2 smoke expansion batch 2: rows 2, 4, 5, 9, 10 ---
for ROW in 2 4 5 9 10; do
  PHASE_KEY="ROW_${ROW}"
  if phase_done "$PHASE_KEY"; then
    log "ROW ${ROW} already done — skip"
    continue
  fi
  log "=== ROW ${ROW} start ==="
  if bash .planning/enterprise-e2e/cursor3-real-driver.sh "$ROW" 2>&1 | tee -a "$LOG"; then
    ATTEMPT_LOG="${SB_ROOT}/.e2e-row${ROW}-cursor-attempt.log"
    if [[ -f "$ATTEMPT_LOG" ]]; then
      BYTES=$(wc -c <"$ATTEMPT_LOG" | tr -d ' ')
      log "ROW ${ROW} attempt log: ${BYTES} B"
      if [[ "$BYTES" -lt 2048 ]]; then
        log "ROW ${ROW} FAIL — §5b log floor (${BYTES} B < 2048)"
        exit 1
      fi
    fi
    mark_done "$PHASE_KEY"
    log "ROW ${ROW} driver exit 0"
  else
    log "ROW ${ROW} driver exit non-zero"
    exit 1
  fi
done

# --- T2 batch 3: rows 11-14 ---
for ROW in 11 12 13 14; do
  PHASE_KEY="ROW_${ROW}"
  if phase_done "$PHASE_KEY"; then
    log "ROW ${ROW} already done — skip"
    continue
  fi
  log "=== ROW ${ROW} start ==="
  if bash .planning/enterprise-e2e/cursor3-real-driver.sh "$ROW" 2>&1 | tee -a "$LOG"; then
    ATTEMPT_LOG="${SB_ROOT}/.e2e-row${ROW}-cursor-attempt.log"
    if [[ -f "$ATTEMPT_LOG" ]]; then
      BYTES=$(wc -c <"$ATTEMPT_LOG" | tr -d ' ')
      log "ROW ${ROW} attempt log: ${BYTES} B"
      if [[ "$BYTES" -lt 2048 ]]; then
        log "ROW ${ROW} FAIL — §5b log floor (${BYTES} B < 2048)"
        exit 1
      fi
    fi
    mark_done "$PHASE_KEY"
    log "ROW ${ROW} driver exit 0"
  else
    log "ROW ${ROW} driver exit non-zero"
    exit 1
  fi
done

# --- T2 batch 4: rows 15-18 ---
for ROW in 15 16 17 18; do
  PHASE_KEY="ROW_${ROW}"
  if phase_done "$PHASE_KEY"; then
    log "ROW ${ROW} already done — skip"
    continue
  fi
  log "=== ROW ${ROW} start ==="
  if bash .planning/enterprise-e2e/cursor3-real-driver.sh "$ROW" 2>&1 | tee -a "$LOG"; then
    ATTEMPT_LOG="${SB_ROOT}/.e2e-row${ROW}-cursor-attempt.log"
    if [[ -f "$ATTEMPT_LOG" ]]; then
      BYTES=$(wc -c <"$ATTEMPT_LOG" | tr -d ' ')
      log "ROW ${ROW} attempt log: ${BYTES} B"
      if [[ "$BYTES" -lt 2048 ]]; then
        log "ROW ${ROW} FAIL — §5b log floor (${BYTES} B < 2048)"
        exit 1
      fi
    fi
    mark_done "$PHASE_KEY"
    log "ROW ${ROW} driver exit 0"
  else
    log "ROW ${ROW} driver exit non-zero"
    exit 1
  fi
done

# --- T2 batch 5: rows 19-20 ---
for ROW in 19 20; do
  PHASE_KEY="ROW_${ROW}"
  if phase_done "$PHASE_KEY"; then
    log "ROW ${ROW} already done — skip"
    continue
  fi
  log "=== ROW ${ROW} start ==="
  if bash .planning/enterprise-e2e/cursor3-real-driver.sh "$ROW" 2>&1 | tee -a "$LOG"; then
    ATTEMPT_LOG="${SB_ROOT}/.e2e-row${ROW}-cursor-attempt.log"
    if [[ -f "$ATTEMPT_LOG" ]]; then
      BYTES=$(wc -c <"$ATTEMPT_LOG" | tr -d ' ')
      log "ROW ${ROW} attempt log: ${BYTES} B"
      if [[ "$BYTES" -lt 2048 ]]; then
        log "ROW ${ROW} FAIL — §5b log floor (${BYTES} B < 2048)"
        exit 1
      fi
    fi
    mark_done "$PHASE_KEY"
    log "ROW ${ROW} driver exit 0"
  else
    log "ROW ${ROW} driver exit non-zero"
    exit 1
  fi
done

# --- T2 batch 6: rows 21-22 (internal gate rows) ---
for ROW in 21 22; do
  PHASE_KEY="ROW_${ROW}"
  if phase_done "$PHASE_KEY"; then
    log "ROW ${ROW} already done — skip"
    continue
  fi
  log "=== ROW ${ROW} start ==="
  if bash .planning/enterprise-e2e/cursor3-real-driver.sh "$ROW" 2>&1 | tee -a "$LOG"; then
    ATTEMPT_LOG="${SB_ROOT}/.e2e-row${ROW}-cursor-attempt.log"
    if [[ -f "$ATTEMPT_LOG" ]]; then
      BYTES=$(wc -c <"$ATTEMPT_LOG" | tr -d ' ')
      log "ROW ${ROW} attempt log: ${BYTES} B"
      if [[ "$BYTES" -lt 2048 ]]; then
        log "ROW ${ROW} FAIL — §5b log floor (${BYTES} B < 2048)"
        exit 1
      fi
    fi
    mark_done "$PHASE_KEY"
    log "ROW ${ROW} driver exit 0"
  else
    log "ROW ${ROW} driver exit non-zero"
    exit 1
  fi
done

log "=== Round Cursor-3 REAL pipeline (Phase A + rows 2-22) finished ==="
