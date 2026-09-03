#!/usr/bin/env bash
# Round Cursor-2 phased driver: Phase A ladder → T2 smoke (1,3,6) → full matrix → Phase C.
set -euo pipefail

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
cd "$SB_ROOT"
LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor-c2-pipeline.log"
PIPELINE_MARKER="${SB_ROOT}/.planning/enterprise-e2e/cursor-c2-pipeline.state"

export SB_ROOT SB_E2E_BRANCH=enterprise-e2e/cursor
export SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-2-LEDGER.md
export SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_SKIP_CURSOR_INSTALL=1
# Single-pass-at-install-version: do not blanket FORCE; per-row skip in matrix.sh
unset SB_E2E_MATRIX_FORCE
export SB_E2E_SURFACE_SKIP=0 SB_LIVE_CURSOR_FORCE_HEADLESS=1
export RTK_DISABLED=1 CLAUDE_INTERACTIVE_TIMEOUT=1800
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5
export SB_LIVE_CURSOR_IN_SESSION=1

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"; }

# Outcome harness can transiently fail inside set -e; retry once before abort.
run_outcome_assessment_with_retry() {
  local attempt rc=0
  for attempt in 1 2; do
    set +e
    RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh 2>&1 | tee -a "$LOG"
    rc=${PIPESTATUS[0]}
    set -e
    if [[ "$rc" -eq 0 ]]; then
      log "Outcome harness PASS (attempt ${attempt})"
      return 0
    fi
    if [[ "$attempt" -eq 1 ]]; then
      log "Outcome harness rc=${rc} — retry once (transient fixture)"
    fi
  done
  log "PHASE C abort — outcome harness failed after retry (rc=${rc})"
  return 1
}

phase_done() { grep -q "^${1}:DONE" "$PIPELINE_MARKER" 2>/dev/null; }
mark_done() { echo "${1}:DONE $(date -u +%Y-%m-%dT%H:%M:%SZ) @ $(git rev-parse --short HEAD)" >>"$PIPELINE_MARKER"; }

: >"$PIPELINE_MARKER"

# --- Phase A: review-fix-ladder 8/8 ---
if ! phase_done PHASE_A; then
  log "=== PHASE A ladder start @ $(git rev-parse --short HEAD) ==="
  {
    echo ""
    echo "=== Round Cursor-2 Phase A ladder start $(date -u +%Y-%m-%dT%H:%M:%SZ) @ $(git rev-parse --short HEAD) ==="
    export SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1
    export SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0
    bash tests/live/test-live-review-fix-ladder-full-ladder.sh
    echo "=== Round Cursor-2 Phase A ladder end $(date -u +%Y-%m-%dT%H:%M:%SZ) exit:$? ===" | tee -a "${SB_ROOT}/.planning/enterprise-e2e/cursor-ladder-live.log"
  } 2>&1 | tee -a "$LOG"
  if tail -30 "${SB_ROOT}/.planning/enterprise-e2e/cursor-ladder-live.log" | grep -q "Results: 9 passed, 0 failed"; then
    mark_done PHASE_A
    log "PHASE A PASS"
  else
    log "PHASE A FAIL — see cursor-ladder-live.log"
    exit 1
  fi
fi

# --- Tier B smoke: rows 1, 3, 6 ---
if ! phase_done T2_SMOKE; then
  log "=== T2 smoke rows 1 3 6 start ==="
  export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-cursor-t2-smoke-batch.pid
  export SB_E2E_MATRIX_LOG=.e2e-matrix-cursor-t2-smoke.log
  T2_LOG="${SB_ROOT}/.e2e-matrix-cursor-t2-smoke.log"
  if bash scripts/run-enterprise-e2e-matrix.sh 1 3 6 2>&1 | tee -a "$LOG" | tee -a "$T2_LOG"; then
    if grep -q "Fail:  0" "$T2_LOG" 2>/dev/null; then
      mark_done T2_SMOKE
      log "T2 smoke PASS"
    else
      log "T2 smoke FAIL"
      exit 1
    fi
  else
    log "T2 smoke matrix exit non-zero"
    exit 1
  fi
fi

# --- Full matrix 1-22 ---
if ! phase_done FULL_MATRIX; then
  log "=== Full matrix 1-22 start ==="
  export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-cursor-c2-batch.pid
  export SB_E2E_MATRIX_LOG=.e2e-matrix-cursor-c2-live.log
  MATRIX_LOG="${SB_ROOT}/.e2e-matrix-cursor-c2-live.log"
  if bash scripts/run-enterprise-e2e-matrix.sh 2>&1 | tee -a "$LOG" | tee -a "$MATRIX_LOG"; then
  mark_done FULL_MATRIX
  log "Full matrix driver exit 0"
  else
    log "Full matrix exit non-zero"
    exit 1
  fi
fi

# --- Phase C ---
if ! phase_done PHASE_C; then
  log "=== Phase C start ==="
  run_outcome_assessment_with_retry
  RUN_ALL_LOG="/tmp/cursor2-phasec-run-all-r5.log"
  if [[ -f "$RUN_ALL_LOG" ]] && grep -q 'run_all_exit:0' "$RUN_ALL_LOG" 2>/dev/null; then
    log "run-all-tests: using recorded r5 ($RUN_ALL_LOG)"
    tail -5 "$RUN_ALL_LOG" | tee -a "$LOG"
  else
    set +e
    bash tests/run-all-tests.sh 2>&1 | tee -a "$LOG" | tee "$RUN_ALL_LOG"
    run_all_rc=${PIPESTATUS[0]}
    echo "run_all_exit:${run_all_rc}" >>"$RUN_ALL_LOG"
    set -e
    [[ "$run_all_rc" -eq 0 ]] || exit 1
  fi
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --live 2>&1 | tee -a "$LOG" || exit 1
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run 2>&1 | tee -a "$LOG" || exit 1
  bash scripts/lib/enterprise-e2e-ledger-reconcile.sh "${SB_ROOT}/.e2e-matrix-cursor-c2-live.log" 2>&1 | tee -a "$LOG" || exit 1
  SB_E2E_RCS_LADDER=8/8 SB_E2E_RCS_TRIHOST=full SB_E2E_RCS_RUN_ALL_TESTS=pass \
    bash scripts/enterprise-e2e-rcs.sh 2>&1 | tee -a "$LOG" || exit 1
  RTK_DISABLED=1 bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --host cursor 2>&1 | tee -a "$LOG" || exit 1
  mark_done PHASE_C
  log "PHASE C complete"
fi

log "=== Round Cursor-2 pipeline finished ==="
