#!/usr/bin/env bash
# Round 9 Claude Gate 3 — one-command full matrix driver (22/22 strict-clean target).
#
# Prerequisites (operator):
#   - Claude CLI installed; token gateway (cc-switch / MiniMax) per CLAUDE-TUI-PROTOCOL.md
#   - agentmemory on :3111; graphify on PATH
#   - Fixture: /Users/shafqat/projects/enterprise-grade-test-app-round9-claude @ enterprise-e2e/round-9-claude
#   - tmux recommended for detached runs (TTY honest)
#
# Usage:
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh --preflight-only
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh 2 4 5 7
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh --tmux
#
# Environment:
#   SB_E2E_MAIN_REPO          Ledger/registry repo (default: repo containing this script)
#   SB_ROOT                   Harness checkout (default: same as MAIN — no /private/tmp worktree)
#   SB_E2E_REGISTRY_MIGRATE_FROM  Optional prior install_fp to copy smoke rows before matrix
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_MAIN="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MAIN="${SB_E2E_MAIN_REPO:-$DEFAULT_MAIN}"
export SB_E2E_MAIN_REPO="$MAIN"

# shellcheck source=scripts/lib/enterprise-e2e-sb-root-resolve.sh
source "${MAIN}/scripts/lib/enterprise-e2e-sb-root-resolve.sh"
SB_ROOT="$(enterprise_e2e_resolve_sb_root)"
export SB_ROOT

PREFLIGHT_ONLY=0
USE_TMUX=0
ROWS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preflight-only) PREFLIGHT_ONLY=1; shift ;;
    --tmux) USE_TMUX=1; shift ;;
    -h|--help)
      sed -n '1,25p' "$0"
      exit 0
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        ROWS+=("$1")
        shift
      else
        echo "Unknown arg: $1" >&2
        exit 2
      fi
      ;;
  esac
done

export SILVER_BULLET_RUNTIME=claude SB_E2E_LIVE_RUNTIME=claude SB_LIVE_RUNTIME=claude
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_SURFACE_SKIP=0
export SB_E2E_PRODUCT_WORK_CUMULATIVE=1
export SB_E2E_LEDGER_NO_UX_APPEND=1
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow
export SB_E2E_MONITOR_AUTO_RESTART=0
export RTK_DISABLED=1
export SB_E2E_ISOLATED_CLAUDE_CONFIG="${SB_E2E_ISOLATED_CLAUDE_CONFIG:-1}"

export SB_E2E_LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${MAIN}/.planning/enterprise-e2e/ROUND-9-LEDGER.md}"
export SB_E2E_ROW_PASS_REGISTRY="${SB_E2E_ROW_PASS_REGISTRY:-${MAIN}/.planning/enterprise-e2e/.row-pass-registry.json}"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app-round9-claude}"
export SB_E2E_TEST_APP_ROUND=9
export SB_E2E_TEST_APP_BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-claude}"
export SB_E2E_TEST_APP_BASELINE_SHA="${SB_E2E_TEST_APP_BASELINE_SHA:-8482e60}"
export SB_E2E_MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-r9-gate3-matrix-live.log}"
export SB_E2E_HOST_GIT_BRANCH_ENFORCE="${SB_E2E_HOST_GIT_BRANCH_ENFORCE:-0}"

# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"
sb_prepend_harness_path

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

echo "=== Round 9 Gate 3 driver $(utc_now) ==="
echo "  MAIN=${MAIN}"
echo "  SB_ROOT=${SB_ROOT} @ $(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
echo "  install_fp=$(enterprise_e2e_install_fingerprint 2>/dev/null || echo unknown)"
echo "  fixture=${SB_TEST_ENTERPRISE_APP_ROOT}"
echo "  ledger=${SB_E2E_LEDGER_FILE}"

preflight_fail() {
  echo "PREFLIGHT FAIL: $*" >&2
  exit 1
}

[[ -f "$SB_E2E_LEDGER_FILE" ]] || preflight_fail "ledger missing: $SB_E2E_LEDGER_FILE"
[[ -d "$SB_TEST_ENTERPRISE_APP_ROOT" ]] || preflight_fail "fixture missing: $SB_TEST_ENTERPRISE_APP_ROOT — clone enterprise-grade-test-app-round9-claude"
command -v claude >/dev/null 2>&1 || preflight_fail "claude CLI not on PATH"
command -v jq >/dev/null 2>&1 || preflight_fail "jq required"

fixture_branch="$(git -C "$SB_TEST_ENTERPRISE_APP_ROOT" branch --show-current 2>/dev/null || true)"
if [[ "$fixture_branch" != "$SB_E2E_TEST_APP_BRANCH" ]]; then
  echo "WARN: fixture on '${fixture_branch:-detached}' — want ${SB_E2E_TEST_APP_BRANCH}"
fi

if [[ -n "${SB_E2E_REGISTRY_MIGRATE_FROM:-}" ]]; then
  to_fp="$(enterprise_e2e_install_fingerprint)"
  echo "Registry migrate: ${SB_E2E_REGISTRY_MIGRATE_FROM} -> ${to_fp}"
  RTK_DISABLED=1 bash "${MAIN}/scripts/enterprise-e2e/registry-migrate-install.sh" \
    --from "${SB_E2E_REGISTRY_MIGRATE_FROM}" \
    --to "${to_fp}" \
    --rows "1,3,6,11,21,22" \
    --source-note "gate3-driver" || preflight_fail "registry migrate failed"
fi

reg_count="$(enterprise_e2e_row_pass_registry_pass_count 2>/dev/null || echo 0)"
echo "  registry_pass_count=${reg_count}/22 @ current install_fp"

if [[ ${#ROWS[@]} -eq 0 ]]; then
  # Default: all rows not yet passed on current install_fp
  for r in $(seq 1 22); do
    if enterprise_e2e_row_pass_registry_should_skip "$r" 2>/dev/null; then
      echo "  skip row $r (registry pass on current install_fp)"
      continue
    fi
    ROWS+=("$r")
  done
  if [[ ${#ROWS[@]} -eq 0 ]]; then
    echo "All 22 rows already in registry @ $(enterprise_e2e_install_fingerprint) — run strict-clean-check"
    if RTK_DISABLED=1 bash "${SB_ROOT}/scripts/enterprise-e2e/strict-clean-check.sh" --ledger "$SB_E2E_LEDGER_FILE"; then
      echo "STRICT-CLEAN: PASS"
      exit 0
    fi
    echo "Registry complete but strict-clean FAIL — update ledger matrix table + outcome rescoring" >&2
    exit 1
  fi
fi

echo "  rows_to_run: ${ROWS[*]}"
echo ""

echo "--- offline harness preflight ---"
RTK_DISABLED=1 bash "${SB_ROOT}/scripts/run-enterprise-e2e-live-test.sh" --preflight-only \
  || preflight_fail "live-test --preflight-only"

if [[ "$PREFLIGHT_ONLY" -eq 1 ]]; then
  echo ""
  echo "PREFLIGHT OK — launch full matrix without --preflight-only"
  echo "  tmux: RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh --tmux"
  exit 0
fi

enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT" 2>/dev/null || true
enterprise_e2e_quiesce_orchestrator_queue "$SB_ROOT" 2>/dev/null || true

unset SB_E2E_SKIP_INSTALL_CLAUDE

run_matrix() {
  cd "$SB_ROOT"
  # shellcheck source=tests/live/lib/detach-background.sh
  source "${SB_ROOT}/tests/live/lib/detach-background.sh"
  printf '\n=== R9 Gate3 matrix %s rows=%s ===\n' "$(utc_now)" "${ROWS[*]}"
  if sb_detach_has_controlling_tty; then
    exec env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh "${ROWS[@]}" \
      2>&1 | tee -a "$SB_E2E_MATRIX_LOG"
  fi
  driver_log="${SB_ROOT}/.e2e-r9-gate3-driver.log"
  driver_pid="$(sb_run_detached_pty --log "$driver_log" -- \
    env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh "${ROWS[@]}")"
  printf '%s\n' "$driver_pid" >"${MAIN}/.e2e-r9-gate3-driver.pid"
  echo "Gate3 driver detached pid ${driver_pid} (log ${driver_log})"
  echo "Monitor: tail -f ${SB_E2E_MATRIX_LOG}"
}

if [[ "$USE_TMUX" -eq 1 ]]; then
  command -v tmux >/dev/null 2>&1 || preflight_fail "tmux required for --tmux"
  session="r9-gate3"
  tmux kill-session -t "$session" 2>/dev/null || true
  tmux new-session -d -s "$session" \
    "cd '${SB_ROOT}' && RTK_DISABLED=1 bash '${MAIN}/scripts/enterprise-e2e/round9-gate3-driver.sh' ${ROWS[*]} 2>&1 | tee -a '${SB_E2E_MATRIX_LOG}'"
  echo "tmux session ${session} started — attach: tmux attach -t ${session}"
  exit 0
fi

run_matrix
