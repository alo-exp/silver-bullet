#!/usr/bin/env bash
# Opt-in enterprise E2E live test entrypoint (interactive Claude TUI + dual-role monitoring).
# Operator prompt: scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md
#
# Usage:
#   SB_ENTERPRISE_E2E_LIVE=1 bash scripts/run-enterprise-e2e-live-test.sh [row_numbers...]
#   bash scripts/run-enterprise-e2e-live-test.sh --preflight-only
#   bash scripts/run-enterprise-e2e-live-test.sh --resume
#   bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight  # debug only
#
# Operator model: dual-role in two persistent shells —
#   Shell A (drive): this script or run-enterprise-e2e-matrix.sh
#   Shell B (monitor): bash scripts/monitor-enterprise-e2e-matrix.sh &
#   Shell C (watch):   bash scripts/watch-enterprise-e2e-tui.sh &
#
# See docs/ENTERPRISE-E2E-LIVE-TEST.md for the full runbook and fresh-session prompt.
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "${SB_ROOT}/hooks/lib/rtk-compat.sh"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"

export SB_ROOT
FIXTURE_DIR="$(enterprise_e2e_fixture_dir)"
LEDGER_FILE="$(enterprise_e2e_ledger_file)"
MATRIX_LOG="$(enterprise_e2e_matrix_log)"
MONITOR_PID_FILE="${SB_E2E_MATRIX_MONITOR_PID_FILE:-${SB_ROOT}/.e2e-matrix-monitor.pid}"
WATCH_PID_FILE="${SB_E2E_TUI_WATCH_PID:-${SB_ROOT}/.e2e-tui-watch.pid}"
# shellcheck disable=SC2034  # documented batch pid path for dual-shell runbook
BATCH_PID_FILE="${SB_E2E_MATRIX_BATCH_PID_FILE:-${SB_ROOT}/.e2e-matrix-batch.pid}"

PREFLIGHT_ONLY=0
RESUME=0
SKIP_CODE_INTEL_PREFLIGHT=0
REQUESTED_ROWS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [--preflight-only] [--resume] [--skip-code-intel-preflight] [row_numbers...]

Enterprise E2E live test — interactive Claude TUI against enterprise-grade-test-app.

Constraints (from Round 1/2 learnings):
  - API key auth via ~/.claude/settings.json — NO login/logout
  - SB_E2E_MATRIX_CLEAN_ENV=0 (inherit shell auth; default)
  - NO SB_E2E_MATRIX_DRY_RUN for live runs
  - 429 / Token Plan → retry every 600s (SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL)
  - Network blips → 120-300s backoff (monitor handles)
  - Resume skips rows with PASS/SKIP in matrix log (not from row 1)
  - Re-run bash scripts/install-claude.sh after every SB hook fix
  - Code-intel preflight: Graphify, agentmemory, RTK, Context Mode when opted in
  - Round gates: 22/22 matrix, review-fix-ladder, run-all-tests, graphify, 2 clean rounds

Environment:
  SB_ENTERPRISE_E2E_LIVE=1     Required opt-in (unless --preflight-only)
  SB_TEST_ENTERPRISE_APP_ROOT  Test app path (default: enterprise-grade-test-app)
  SB_E2E_LEDGER_FILE           Ledger path (default: ROUND-1-LEDGER.md)
  SB_E2E_MATRIX_LOG            Matrix batch log (default: .e2e-matrix-live.log)

Docs: docs/ENTERPRISE-E2E-LIVE-TEST.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --preflight-only)
      PREFLIGHT_ONLY=1
      shift
      ;;
    --resume)
      RESUME=1
      shift
      ;;
    --skip-code-intel-preflight)
      SKIP_CODE_INTEL_PREFLIGHT=1
      shift
      ;;
    *)
      REQUESTED_ROWS+=("$1")
      shift
      ;;
  esac
done

if [[ "$PREFLIGHT_ONLY" != "1" && "${SB_ENTERPRISE_E2E_LIVE:-}" != "1" ]]; then
  echo "ERROR: set SB_ENTERPRISE_E2E_LIVE=1 to run live enterprise E2E (or use --preflight-only)" >&2
  exit 2
fi

enterprise_e2e_export_live_defaults
enterprise_e2e_assert_no_auth_mutations "${SB_ROOT}/scripts/run-enterprise-e2e-matrix.sh"
enterprise_e2e_assert_no_auth_mutations "${SB_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh"

echo "=== Enterprise E2E Live Test ==="
echo "SB_ROOT:     ${SB_ROOT}"
echo "Fixture:     ${FIXTURE_DIR}"
echo "Ledger:      ${LEDGER_FILE}"
echo "Matrix log:  ${MATRIX_LOG}"
echo "CLEAN_ENV:   ${SB_E2E_MATRIX_CLEAN_ENV}"
echo "DRY_RUN:     unset (live)"
echo ""

if [[ ! -d "$FIXTURE_DIR" ]]; then
  echo "ERROR: fixture not found at ${FIXTURE_DIR}" >&2
  exit 1
fi

# --- Preflight ---
echo "--- Preflight ---"
cd "$SB_ROOT"
if [[ "$SKIP_CODE_INTEL_PREFLIGHT" == "1" ]]; then
  echo "WARN: skipping code-intel preflight (--skip-code-intel-preflight; debug only)"
else
  enterprise_e2e_code_intel_preflight "$SB_ROOT" "$FIXTURE_DIR" 0
fi
bash tests/e2e-live/hook-delivery-preflight.sh
export SILVER_BULLET_RUNTIME=cursor
(cd "$FIXTURE_DIR" && git status --short && npm test)

# Session-start from test app (cursor-hook-bridge / branch scope)
if [[ -f "${SB_ROOT}/tests/e2e-live/lib/session-start-preflight.sh" ]]; then
  # shellcheck source=tests/e2e-live/lib/session-start-preflight.sh
  source "${SB_ROOT}/tests/e2e-live/lib/session-start-preflight.sh" || true
fi

echo "Plugin install (latest SB checkout):"
bash scripts/install-claude.sh

if [[ "$PREFLIGHT_ONLY" == "1" ]]; then
  echo "Preflight complete (--preflight-only)."
  exit 0
fi

# --- Dual-role monitor + watch (persistent shells recommended) ---
start_background_if_missing() {
  local name="$1" pattern="$2" script="$3" pid_file="$4"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    echo "${name}: already running"
    pgrep -f "$pattern" | head -1 >"$pid_file" 2>/dev/null || true
    return 0
  fi
  echo "${name}: starting in background..."
  bash "$script" &
  echo $! >"$pid_file"
  echo "${name}: pid $(cat "$pid_file")"
}

export SB_E2E_MATRIX_LOG="$MATRIX_LOG"
start_background_if_missing \
  "matrix-monitor" \
  "monitor-enterprise-e2e-matrix.sh" \
  "${SB_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh" \
  "$MONITOR_PID_FILE"
start_background_if_missing \
  "tui-watch" \
  "watch-enterprise-e2e-tui.sh" \
  "${SB_ROOT}/scripts/watch-enterprise-e2e-tui.sh" \
  "$WATCH_PID_FILE"

# --- Resume logic (default: skip PASS/SKIP rows when log exists) ---
MATRIX_ARGS=()
if ((${#REQUESTED_ROWS[@]} > 0)); then
  MATRIX_ARGS=("${REQUESTED_ROWS[@]}")
else
  touch "$MATRIX_LOG"
  if [[ "$RESUME" == "1" ]] || enterprise_e2e_incomplete_rows "$MATRIX_LOG" | grep -q .; then
    enterprise_e2e_read_lines_to_array inc enterprise_e2e_incomplete_rows "$MATRIX_LOG"
    if ((${#inc[@]} == 0)); then
      echo "All rows PASS/SKIP in ${MATRIX_LOG} — nothing to resume."
      echo "Set SB_E2E_MATRIX_FORCE=1 or pass explicit row numbers to re-run."
      exit 0
    fi
    echo "Resume rows (skip last PASS/SKIP): ${inc[*]}"
    MATRIX_ARGS=("${inc[@]}")
  fi
fi

echo ""
echo "--- Launching interactive matrix (live) ---"
echo "Log: ${MATRIX_LOG}"
echo "Tail: tail -f ${MATRIX_LOG}"
echo "Monitor: tail -f ${SB_ROOT}/.e2e-matrix-monitor-status.txt"
echo "Watch findings: tail -f ${SB_ROOT}/.e2e-tui-watch-findings.jsonl"
echo ""

MATRIX_LAUNCH_CMD=(bash scripts/run-enterprise-e2e-matrix.sh)
if ((${#MATRIX_ARGS[@]} > 0)); then
  MATRIX_LAUNCH_CMD=(bash scripts/run-enterprise-e2e-matrix.sh "${MATRIX_ARGS[@]}")
fi

(
  cd "$SB_ROOT"
  env -u SB_E2E_MATRIX_DRY_RUN     SB_E2E_MATRIX_CLEAN_ENV=0     SB_E2E_MATRIX_FORCE="${SB_E2E_MATRIX_FORCE:-}"     SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE_DIR"     SB_E2E_LEDGER_FILE="$LEDGER_FILE"     SB_E2E_MATRIX_LOG="$MATRIX_LOG"     "${MATRIX_LAUNCH_CMD[@]}"
) 2>&1 | tee -a "$MATRIX_LOG"

echo ""
echo "--- Round gate checklist (manual before release) ---"
cat <<'GATES'
  [ ] 22/22 PASS in ledger with graphify + agentmemory refs
  [ ] /silver:review-fix-ladder — 8 rungs × 2 consecutive clean verify passes
  [ ] bash tests/run-all-tests.sh → 0 failures
  [ ] graphify update . in SB repo post-fixes
  [ ] 2 consecutive clean rounds before release tag
  [ ] After SB hook fixes: bash scripts/install-claude.sh then re-run failed rows only
GATES
