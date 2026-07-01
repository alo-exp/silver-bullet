#!/usr/bin/env bash
# T1 row 1 silver-router FORCE×2 — isolated from retry4 driver.
set -euo pipefail

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
export SB_ROOT
export SB_E2E_BRANCH=enterprise-e2e/cursor
export SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md
export SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_MATRIX_FORCE=1 SB_E2E_SKIP_CURSOR_INSTALL=1
export SB_E2E_SURFACE_SKIP=0 SB_LIVE_CURSOR_FORCE_HEADLESS=1
export RTK_DISABLED=1 CLAUDE_INTERACTIVE_TIMEOUT=1800
export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-cursor-t1-batch.pid
export SB_E2E_MATRIX_LOG=.e2e-matrix-cursor-t1.log
export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5

LOG="${SB_ROOT}/.e2e-matrix-cursor-t1.log"
CHECKPOINT_LEDGER="${SB_ROOT}/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md"

wait_pid="${SB_E2E_T1_WAIT_PID:-}"
if [[ -n "$wait_pid" ]] && kill -0 "$wait_pid" 2>/dev/null; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) T1 driver waiting for busy matrix pid ${wait_pid}" | tee -a "$LOG"
  while kill -0 "$wait_pid" 2>/dev/null; do
    sleep 90
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) poll: pid ${wait_pid} still alive" >>"$LOG"
  done
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) busy driver exited — starting T1×2" | tee -a "$LOG"
fi

cd "$SB_ROOT"
current_branch="$(git branch --show-current 2>/dev/null || true)"
if [[ "$current_branch" != "$SB_E2E_BRANCH" ]]; then
  git checkout "$SB_E2E_BRANCH" >/dev/null 2>&1 || true
fi

run_ok=0
t1_env() {
  unset SB_TEST_ENTERPRISE_APP_ROOT
  export SB_ROOT SB_E2E_BRANCH SILVER_BULLET_RUNTIME SB_E2E_LIVE_RUNTIME
  export SB_E2E_LEDGER_FILE SB_ENTERPRISE_E2E_LIVE SB_E2E_MATRIX_FORCE SB_E2E_SKIP_CURSOR_INSTALL
  export SB_E2E_SURFACE_SKIP SB_LIVE_CURSOR_FORCE_HEADLESS RTK_DISABLED CLAUDE_INTERACTIVE_TIMEOUT
  export SB_E2E_MATRIX_BATCH_PID_FILE SB_E2E_MATRIX_LOG CURSOR_AGENT_MODEL CURSOR_MODEL
}
for run in 1 2; do
  echo "" | tee -a "$LOG"
  echo "=== T1 FORCE run ${run}/2 $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" | tee -a "$LOG"
  t1_env
  if bash scripts/run-enterprise-e2e-matrix.sh 1 2>&1 | tee -a "$LOG"; then
    run_ok=$((run_ok + 1))
  else
    echo "T1 run ${run} FAIL" | tee -a "$LOG"
  fi
done

export SB_E2E_CHECKPOINT_EXIT_REASON="t1_x2_complete"
export SB_E2E_CHECKPOINT_LAST_ROW=1
bash scripts/enterprise-e2e/enterprise-e2e-checkpoint.sh --append "$CHECKPOINT_LEDGER" | tee -a "$LOG"

echo "T1×2 finished: ${run_ok}/2 pass" | tee -a "$LOG"
