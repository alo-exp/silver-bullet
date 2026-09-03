#!/usr/bin/env bash
# Purge stale row 3/6 artifacts, reset fixture, relaunch force36 in tmux-stable poll.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FIXTURE="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
BASELINE="${SB_E2E_TEST_APP_BASELINE_SHA:-09f8d1a}"
BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-codex}"
LAUNCH_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force36-launch.log"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force36-poll.log"

printf '\n=== codex-r3-force36-launch %s @ %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD)"

# Stop prior Tier B / force36 sessions (driver already exited; poll 68831 died early)
tmux kill-session -t codex-r3-real-tierb 2>/dev/null || true
tmux kill-session -t codex-r3-force36 2>/dev/null || true
if [[ -f "${ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-poll.pid" ]]; then
  old_poll="$(tr -d '[:space:]' <"${ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-poll.pid" || true)"
  [[ -n "$old_poll" ]] && kill "$old_poll" 2>/dev/null || true
fi
rm -f "${ROOT}/.e2e-matrix-codex-batch.pid" "${ROOT}/.e2e-live-test.lock" 2>/dev/null || true

# Purge stale row 3/6 attempt logs (keep row 1 frozen log)
rm -f "${ROOT}/.e2e-row3-codex-attempt.log" "${ROOT}/.e2e-row3-codex-attempt"[0-9]*.log
rm -f "${ROOT}/.e2e-row6-codex-attempt.log" "${ROOT}/.e2e-row6-codex-attempt"[0-9]*.log
: >"$POLL_LOG"
: >"${ROOT}/.planning/enterprise-e2e/.codex-r3-force36-rescore.log"

# Purge stale workflow evidence in fixture (row 1 routing state may remain uncommitted)
if [[ -d "${FIXTURE}/.git" ]]; then
  git -C "$FIXTURE" checkout "$BRANCH" 2>/dev/null || true
  git -C "$FIXTURE" reset --hard "$BASELINE" 2>/dev/null || true
  rm -f \
    "${FIXTURE}/.planning/workflows/feature-currency.md" \
    "${FIXTURE}/.planning/workflows/fast-readme.md" \
    "${FIXTURE}/.planning/enterprise-e2e/outcomes/row-3-outcomes.md" \
    "${FIXTURE}/.planning/enterprise-e2e/outcomes/row-6-outcomes.md" \
    2>/dev/null || true
  printf 'fixture reset %s@%s\n' "$BRANCH" "$(git -C "$FIXTURE" rev-parse --short HEAD)"
fi

# Seed frozen row 1 rescore if tierb log empty (prior poll 68831 died before rescore)
if [[ ! -s "${ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-rescore.log" ]]; then
  export SB_ROOT="$ROOT"
  export SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE"
  export SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex
  export SB_E2E_LEDGER_FILE="${ROOT}/.planning/enterprise-e2e/ROUND-CODEX-3-LEDGER.md"
  export SB_E2E_ENTERPRISE_MATRIX=1 SB_E2E_PRODUCT_WORK_GATE=1
  # shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
  source "${ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
  # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
  source "${ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"
  row1_log="${ROOT}/.e2e-row1-codex-attempt.log"
  STATE_DIR="$(enterprise_e2e_runtime_state_dir)"
  if [[ -f "$row1_log" ]] && enterprise_e2e_outcome_row_passes 1 "$FIXTURE" "$STATE_DIR" \
    "$row1_log" "$SB_E2E_LEDGER_FILE" ".planning/workflows/router-session.md"; then
    printf 'row 1 PASS\nrow 3 FAIL: prior attempt\nrow 6 FAIL: prior attempt\nTIERB_RESCORE pass=1/3 fail_rows=3 6\n' \
      >"${ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-rescore.log"
    printf 'seeded frozen row1 PASS from %s\n' "$row1_log"
  fi
fi

chmod +x "${ROOT}/.planning/enterprise-e2e/codex-r3-force36-driver.sh"
chmod +x "${ROOT}/.planning/enterprise-e2e/.codex-r3-force36-poll-exit.sh"

tmux new-session -d -s codex-r3-force36 -n driver -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/codex-r3-force36-driver.sh 2>&1 | tee -a \"$LAUNCH_LOG\"'"

sleep 2
DRIVER_PID="$(tmux list-panes -t codex-r3-force36:driver -F '#{pane_pid}' | head -1)"
printf '%s\n' "$DRIVER_PID" >"${ROOT}/.planning/enterprise-e2e/.codex-r3-force36-driver.pid"

tmux new-window -t codex-r3-force36 -n poll -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/.codex-r3-force36-poll-exit.sh ${DRIVER_PID} 75'"

tmux new-window -t codex-r3-force36 -n chain -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/.codex-r3-chain-monitor.sh ${DRIVER_PID} 80'"

mon_pid="$(bash "${ROOT}/.planning/enterprise-e2e/tui-monitor-batch-continuation-launch.sh" | awk '{print $NF}')"

printf 'tmux=codex-r3-force36 driver=%s poll=tmux:poll chain=tmux:chain friction=%s\n' "$DRIVER_PID" "$mon_pid"
