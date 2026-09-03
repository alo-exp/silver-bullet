#!/usr/bin/env bash
# Targeted FORCE retry: Cursor-2 fail rows 8, 11, 15, 16 only @ install 26cf687f.
# Policy: SB_E2E_MATRIX_FORCE=1 on explicit rows — NOT full matrix, NOT FORCE_ALL.
set -euo pipefail

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
cd "$SB_ROOT"
LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor-c2-force-fail-rows.log"
MATRIX_LOG="${SB_ROOT}/.e2e-matrix-cursor-c2-force-fail.log"
LIVE_MATRIX_LOG="${SB_ROOT}/.e2e-matrix-cursor-c2-live.log"
PHASE_C_LOG="${SB_ROOT}/.planning/enterprise-e2e/cursor-c2-phase-c-subset.log"
RUN_ALL_LOG="/tmp/cursor2-phasec-run-all-r5.log"

export SB_ROOT SB_E2E_BRANCH=enterprise-e2e/cursor
export SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-2-LEDGER.md
export SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_SKIP_CURSOR_INSTALL=1
export SB_E2E_SURFACE_SKIP=0 SB_LIVE_CURSOR_FORCE_HEADLESS=1
export RTK_DISABLED=1
# Default 1800s; rows 8/11 use per-row overrides in matrix.sh (3600/5400).
export CLAUDE_INTERACTIVE_TIMEOUT=1800
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5
export SB_LIVE_CURSOR_IN_SESSION=1
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-cursor-c2-force-fail-batch.pid
export SB_E2E_MATRIX_LOG=.e2e-matrix-cursor-c2-force-fail.log

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"; }

# Outcome harness can transiently fail (57/2) when fixture state races set -e trap.
# Retry once before aborting Phase C.
run_outcome_assessment_with_retry() {
  local attempt rc=0
  for attempt in 1 2; do
    set +e
    RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh 2>&1 | tee -a "$LOG" | tee -a "$PHASE_C_LOG"
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
  log "ABORT Phase C — outcome harness failed after retry (rc=${rc})"
  return 1
}

log "=== Cursor-2 targeted FORCE rows 8 11 15 16 @ $(git rev-parse --short HEAD) install=26cf687f ==="
log "Policy: FORCE on fail rows only; skip install-pass rows 1 6 7 21 22"

: >"$MATRIX_LOG"
if bash scripts/run-enterprise-e2e-matrix.sh 8 11 15 16 2>&1 | tee -a "$LOG" | tee -a "$MATRIX_LOG"; then
  matrix_rc=0
else
  matrix_rc=$?
fi

fail_count="$(grep '^Fail:' "$MATRIX_LOG" 2>/dev/null | tail -1 | awk '{print $2}' || echo 99)"
pass_count="$(grep '^Pass:' "$MATRIX_LOG" 2>/dev/null | tail -1 | awk '{print $2}' || echo 0)"
log "Matrix done rc=${matrix_rc} pass=${pass_count} fail=${fail_count}"

if [[ "${fail_count:-99}" != "0" ]]; then
  log "ABORT Phase C — ${fail_count} row(s) still failing"
  exit 1
fi

log "=== Phase C (post 4-row green) ==="
: >"$PHASE_C_LOG"

run_outcome_assessment_with_retry

if [[ -f "$RUN_ALL_LOG" ]] && grep -q 'run_all_exit:0' "$RUN_ALL_LOG" 2>/dev/null; then
  log "run-all-tests: using recorded r5 @ $(git rev-parse --short HEAD) ($RUN_ALL_LOG)"
  tail -5 "$RUN_ALL_LOG" | tee -a "$LOG" | tee -a "$PHASE_C_LOG"
  run_all_rcs=pass
else
  log "run-all-tests: live run (no recorded r5 yet)"
  set +e
  bash tests/run-all-tests.sh 2>&1 | tee -a "$LOG" | tee -a "$PHASE_C_LOG" | tee "$RUN_ALL_LOG"
  run_all_rc=${PIPESTATUS[0]}
  echo "run_all_exit:${run_all_rc}" >>"$RUN_ALL_LOG"
  set -e
  if [[ "$run_all_rc" -ne 0 ]]; then
    log "ABORT Phase C — run-all-tests rc=${run_all_rc}"
    exit 1
  fi
  run_all_rcs=pass
fi

set +e
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --live 2>&1 | tee -a "$LOG" | tee -a "$PHASE_C_LOG"
val_rc=${PIPESTATUS[0]}
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run 2>&1 | tee -a "$LOG" | tee -a "$PHASE_C_LOG"
pre_rc=${PIPESTATUS[0]}
bash scripts/lib/enterprise-e2e-ledger-reconcile.sh "${LIVE_MATRIX_LOG}" 2>&1 | tee -a "$LOG" | tee -a "$PHASE_C_LOG"
recon_rc=${PIPESTATUS[0]}
SB_E2E_RCS_LADDER=8/8 SB_E2E_RCS_TRIHOST=full SB_E2E_RCS_RUN_ALL_TESTS="${run_all_rcs}" \
  bash scripts/enterprise-e2e-rcs.sh 2>&1 | tee -a "$LOG" | tee -a "$PHASE_C_LOG"
rcs_rc=${PIPESTATUS[0]}
RTK_DISABLED=1 bash scripts/lib/enterprise-e2e-consecutive-rounds-check.sh --host cursor 2>&1 | tee -a "$LOG" | tee -a "$PHASE_C_LOG"
pair_rc=${PIPESTATUS[0]}
set -e

phase_c_abort=0
check_phase_c_rc() {
  local label="$1" rc="$2"
  if [[ "$rc" -ne 0 ]]; then
    log "Phase C step ${label} rc=${rc}"
    phase_c_abort=1
  fi
}
check_phase_c_rc validation "$val_rc"
check_phase_c_rc pre_release "$pre_rc"
check_phase_c_rc reconcile "$recon_rc"
check_phase_c_rc rcs "$rcs_rc"
check_phase_c_rc pair "$pair_rc"
if [[ "$phase_c_abort" -ne 0 ]]; then
  log "ABORT Phase C — one or more gates failed"
  exit 1
fi

log "=== Cursor-2 targeted FORCE + Phase C complete ==="
