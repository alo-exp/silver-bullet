#!/usr/bin/env bash
# Opt-in enterprise E2E live test entrypoint (interactive agent TUI + dual-role monitoring).
# Operator prompt: scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md
# Shared harness: scripts/enterprise-e2e/ — see .planning/enterprise-e2e/SHARED-HARNESS.md
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

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "${SB_ROOT}/hooks/lib/rtk-compat.sh"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"

PREFLIGHT_ONLY=0
RESUME=0
SKIP_CODE_INTEL_PREFLIGHT=0
MATRIX_HOST_ARG=""
REQUESTED_ROWS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [--host claude|codex|cursor] [--preflight-only] [--resume] [--skip-code-intel-preflight] [row_numbers...]

Enterprise E2E live test — interactive agent TUI against enterprise-grade-test-app.

Constraints (from Round 1/2 learnings):
  - API key auth via ~/.codex/settings.json — NO login/logout
  - SB_E2E_MATRIX_CLEAN_ENV=0 (inherit shell auth; default)
  - NO SB_E2E_MATRIX_DRY_RUN for live runs
  - 429 / Token Plan → retry every 60s (SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL)
  - Network blips → 120-300s backoff (monitor handles)
  - Resume skips ledger Pass rows; includes all ledger-incomplete rows
  - Re-run bash scripts/install-claude.sh after every SB hook fix
  - Code-intel preflight: Graphify, agentmemory, RTK, Context Mode when opted in
  - Round gates: 22/22 matrix, review-fix-ladder, run-all-tests, graphify, 2 clean rounds

Environment:
  SB_ENTERPRISE_E2E_LIVE=1     Required opt-in (unless --preflight-only)
  SB_TEST_ENTERPRISE_APP_ROOT  Test app path (default: enterprise-grade-test-app)
  SB_E2E_TEST_APP_BRANCH       Expected isolated test-app branch (e.g. enterprise-e2e/round-8-claude)
  SB_E2E_TEST_APP_ROUND        Round number for auto branch name (with host → round-N-host)
  SB_E2E_TEST_APP_BASELINE_SHA Baseline SHA when creating branch (default: 8482e60; 09f8d1a when SB_E2E_PRODUCT_WORK_GATE=1 or codex hosts.json)
  SB_E2E_TEST_APP_BRANCH_ENFORCE  0 to skip branch preflight (default: 1)
  SB_E2E_LEDGER_FILE           Ledger path (default: host-specific ROUND-*-LEDGER.md)
  SB_E2E_MATRIX_LOG            Matrix batch log (default: host-isolated)
  SB_E2E_LIVE_RUNTIME          claude | codex | cursor (see --host)
  SB_E2E_VALIDATION_OVERLAY    Pre-matrix validation gate (default: 1 on live runs; 0 to skip)
  SB_E2E_VALIDATION_PRE_GATE   Force validation overlay dry-run before matrix (=1)

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
    --host)
      MATRIX_HOST_ARG="$2"
      shift 2
      ;;
    *)
      REQUESTED_ROWS+=("$1")
      shift
      ;;
  esac
done

export SB_ROOT
if [[ -n "$MATRIX_HOST_ARG" ]]; then
  export SB_E2E_LIVE_RUNTIME="$MATRIX_HOST_ARG"
  export SILVER_BULLET_RUNTIME="$MATRIX_HOST_ARG"
fi
enterprise_e2e_apply_matrix_host_defaults
MATRIX_HOST="$(enterprise_e2e_matrix_host)"
enterprise_e2e_assert_host_git_branch || exit 1
FIXTURE_DIR="$(enterprise_e2e_fixture_dir)"
LEDGER_FILE="$(enterprise_e2e_ledger_file)"
MATRIX_LOG="$(enterprise_e2e_matrix_log)"
MONITOR_PID_FILE="${SB_E2E_MATRIX_MONITOR_PID_FILE:-${SB_ROOT}/.e2e-matrix-monitor.pid}"
WATCH_PID_FILE="${SB_E2E_TUI_WATCH_PID:-${SB_ROOT}/.e2e-tui-watch.pid}"
# shellcheck disable=SC2034  # documented batch pid path for dual-shell runbook
BATCH_PID_FILE="${SB_E2E_MATRIX_BATCH_PID_FILE:-${SB_ROOT}/.e2e-matrix-batch.pid}"

if [[ "$PREFLIGHT_ONLY" != "1" && "${SB_ENTERPRISE_E2E_LIVE:-}" != "1" ]]; then
  echo "ERROR: set SB_ENTERPRISE_E2E_LIVE=1 to run live enterprise E2E (or use --preflight-only)" >&2
  exit 2
fi

if [[ "$PREFLIGHT_ONLY" != "1" ]]; then
  enterprise_e2e_acquire_live_test_lock || exit 1
  trap enterprise_e2e_release_live_test_lock EXIT
fi

enterprise_e2e_export_live_defaults
enterprise_e2e_assert_no_auth_mutations "${SB_ROOT}/scripts/run-enterprise-e2e-matrix.sh"
enterprise_e2e_assert_no_auth_mutations "${SB_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh"

echo "=== Enterprise E2E Live Test ==="
echo "SB_ROOT:     ${SB_ROOT}"
echo "Fixture:     ${FIXTURE_DIR}"
echo "Ledger:      ${LEDGER_FILE}"
echo "Matrix log:  ${MATRIX_LOG}"
echo "Host:        ${MATRIX_HOST}"
echo "CLEAN_ENV:   ${SB_E2E_MATRIX_CLEAN_ENV}"
echo "DRY_RUN:     unset (live)"
echo ""

if [[ ! -d "$FIXTURE_DIR" ]]; then
  echo "ERROR: fixture not found at ${FIXTURE_DIR}" >&2
  exit 1
fi

enterprise_e2e_assert_test_app_branch "$FIXTURE_DIR"

# --- Preflight ---
echo "--- Preflight ---"
cd "$SB_ROOT"
enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT"
if [[ "$SKIP_CODE_INTEL_PREFLIGHT" == "1" ]]; then
  echo "WARN: skipping code-intel preflight (--skip-code-intel-preflight; debug only)"
else
  enterprise_e2e_code_intel_preflight "$SB_ROOT" "$FIXTURE_DIR" 0
fi
# install-claude.sh runs below; avoid duplicate bootstrap during hook-delivery prepare_workspace.
export SB_E2E_HOOK_DELIVERY_SKIP_BOOTSTRAP=1
_hook_delivery_rc=1
for _hook_attempt in 1 2 3; do
  if bash tests/e2e-live/hook-delivery-preflight.sh; then
    _hook_delivery_rc=0
    break
  fi
  echo "WARN: hook-delivery preflight attempt ${_hook_attempt}/3 failed; retrying..." >&2
  sleep 2
done
if ((_hook_delivery_rc)); then
  exit 1
fi
(cd "$FIXTURE_DIR" && git status --short && npm test)

# Session-start from test app (cursor-hook-bridge / branch scope — cursor runtime only).
if [[ -f "${SB_ROOT}/tests/e2e-live/lib/session-start-preflight.sh" ]]; then
  (
    export SILVER_BULLET_RUNTIME=cursor
    # shellcheck source=tests/e2e-live/lib/session-start-preflight.sh
    source "${SB_ROOT}/tests/e2e-live/lib/session-start-preflight.sh" || true
  )
fi

enterprise_e2e_run_install_host "$SB_ROOT"
enterprise_e2e_preflight_host "$SB_ROOT"

if [[ "$PREFLIGHT_ONLY" == "1" ]]; then
  echo "Preflight complete (--preflight-only)."
  exit 0
fi

# Session 0 gate before interactive matrix (TUI init or programmatic opt-in).
enterprise_e2e_assert_session0_or_skip "$FIXTURE_DIR" "$LEDGER_FILE"

# --- Resume logic (default: skip PASS/SKIP rows when log exists) ---
MATRIX_ARGS=()
if ((${#REQUESTED_ROWS[@]} > 0)); then
  MATRIX_ARGS=("${REQUESTED_ROWS[@]}")
else
  enterprise_e2e_ensure_matrix_log "$MATRIX_LOG"
  if [[ "$RESUME" == "1" ]] || enterprise_e2e_incomplete_rows "$MATRIX_LOG" "$LEDGER_FILE" | grep -q .; then
    inc=()
    enterprise_e2e_read_lines_to_array inc enterprise_e2e_incomplete_rows "$MATRIX_LOG" "$LEDGER_FILE"
    if ((${#inc[@]} == 0)); then
      echo "All rows Pass in ledger — nothing to resume."
      echo "Set SB_E2E_MATRIX_FORCE=1 or pass explicit row numbers to re-run."
      exit 0
    fi
    echo "Resume rows (ledger-incomplete): ${inc[*]}"
    MATRIX_ARGS=("${inc[@]}")
  fi
fi

# --- Validation overlay pre-matrix gate (dry-run; fail fast) ---
# Default ON for live runs (SB_E2E_VALIDATION_OVERLAY=1). Skip with =0 unless PRE_GATE=1.
if [[ "${SB_E2E_VALIDATION_OVERLAY:-1}" == "1" || "${SB_E2E_VALIDATION_PRE_GATE:-0}" == "1" ]]; then
  echo "--- Validation overlay pre-matrix gate (dry-run) ---"
  export SB_E2E_VALIDATION_OVERLAY=1
  if ! RTK_DISABLED=1 bash "${SB_ROOT}/scripts/run-enterprise-e2e-validation-overlay.sh" --dry-run; then
    echo "ERROR: validation overlay pre-matrix gate failed — fix before launching matrix" >&2
    echo "       (skip: SB_E2E_VALIDATION_OVERLAY=0; force: SB_E2E_VALIDATION_PRE_GATE=1)" >&2
    exit 1
  fi
  echo "Validation overlay pre-matrix gate: PASS"
  echo ""
fi

# --- Dual-role monitor + watch (driver-owned; replace stale harness children) ---
start_harness_background() {
  local name="$1" pattern="$2" script="$3" pid_file="$4"
  local pid
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    echo "${name}: replacing existing instance (driver-owned harness)"
    pkill -f "$pattern" 2>/dev/null || true
    sleep 1
  fi
  echo "${name}: starting in background..."
  pid="$(sb_run_detached -- bash "$script")"
  printf '%s\n' "$pid" >"$pid_file"
  echo "${name}: pid ${pid}"
}

export SB_E2E_MATRIX_LOG="$MATRIX_LOG"
if ((${#MATRIX_ARGS[@]} > 0)); then
  export SB_E2E_MATRIX_ROWS="${MATRIX_ARGS[*]}"
fi
if [[ "${SB_E2E_MATRIX_MONITOR:-1}" != "0" ]]; then
  start_harness_background \
    "matrix-monitor" \
    "monitor-enterprise-e2e-matrix.sh" \
    "${SB_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh" \
    "$MONITOR_PID_FILE"
  start_harness_background \
    "tui-watch" \
    "watch-enterprise-e2e-tui.sh" \
    "${SB_ROOT}/scripts/watch-enterprise-e2e-tui.sh" \
    "$WATCH_PID_FILE"
else
  echo "matrix-monitor: skipped (SB_E2E_MATRIX_MONITOR=0)"
fi

echo ""
enterprise_e2e_ensure_matrix_log "$MATRIX_LOG"
if [[ "$(enterprise_e2e_matrix_host)" == "claude" ]] && declare -f enterprise_e2e_prepare_matrix_mcp_env >/dev/null 2>&1; then
  enterprise_e2e_prepare_matrix_mcp_env "$FIXTURE_DIR"
fi

echo "--- Launching interactive matrix (live) ---"
echo "Log: ${MATRIX_LOG}"
echo "Tail: tail -f ${MATRIX_LOG}"
MONITOR_STATUS_FILE="${SB_E2E_MATRIX_MONITOR_STATUS_FILE:-${SB_ROOT}/.e2e-matrix-monitor-status.txt}"
TUI_FINDINGS_FILE="${SB_E2E_TUI_FINDINGS:-${SB_ROOT}/.e2e-tui-watch-findings.jsonl}"
echo "Monitor: tail -f ${MONITOR_STATUS_FILE}"
echo "Watch findings: tail -f ${TUI_FINDINGS_FILE}"
echo ""

MATRIX_LAUNCH_CMD=(bash scripts/enterprise-e2e/matrix.sh)
if ((${#MATRIX_ARGS[@]} > 0)); then
  MATRIX_LAUNCH_CMD=(bash scripts/enterprise-e2e/matrix.sh "${MATRIX_ARGS[@]}")
fi

(
  trap - EXIT INT TERM
  cd "$SB_ROOT"
  env -u SB_E2E_MATRIX_DRY_RUN \
    SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0 \
    SB_E2E_MATRIX_CLEAN_ENV=0 \
    CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow \
    SB_E2E_MATRIX_FORCE="${SB_E2E_MATRIX_FORCE:-}" \
    SB_E2E_MATRIX_FORCE_ALL="${SB_E2E_MATRIX_FORCE_ALL:-}" \
    SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE_DIR" \
    SB_E2E_LEDGER_FILE="$LEDGER_FILE" \
    SB_E2E_MATRIX_LOG="$MATRIX_LOG" \
    "${MATRIX_LAUNCH_CMD[@]}"
) 2>&1 | tee -a "$MATRIX_LOG"


if [[ "${SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS:-}" == "1" ]]; then
  echo ""
  echo "--- Consecutive strict-clean round pair (P2 harness) ---"
  if ! RTK_DISABLED=1 bash "${SB_ROOT}/scripts/enterprise-e2e/lib/deterministic/consecutive-rounds.sh" --host "${MATRIX_HOST}"; then
    echo "ERROR: consecutive strict-clean round pair check failed (SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1)" >&2
    exit 1
  fi
fi

echo ""
echo "--- Round gate checklist (manual before release) ---"
cat <<'GATES'
  [ ] 22/22 PASS in ledger with graphify + agentmemory refs
  [ ] /sb:review-fix-ladder — 8 rungs × 2 consecutive clean verify passes
  [ ] bash tests/run-all-tests.sh → 0 failures
  [ ] graphify update . in SB repo post-fixes
  [ ] 2 consecutive clean rounds before release tag
  [ ] After SB hook fixes: re-run host install (install-claude.sh | install-codex.sh | install-cursor.sh) then re-run failed rows only
GATES
