#!/usr/bin/env bash
# Purge stale row 14/15/16 artifacts, preserve fixture @ 3ca685f, launch force1416 in tmux.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FIXTURE="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-codex}"
FROZEN_SHA="${SB_E2E_FROZEN_BASELINE_SHA:-dead1460}"
LAUNCH_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force1416-launch.log"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force1416-poll.log"
FROZEN_RESCORE="${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-rescore.log"

printf '\n=== codex-r3-force1416-launch %s @ %s frozen@%s ===\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD)" "$FROZEN_SHA"

export SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_MATRIX_BATCH_PID_FILE="${ROOT}/.e2e-matrix-codex-batch.pid"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
if declare -f enterprise_e2e_matrix_batch_running >/dev/null 2>&1 && enterprise_e2e_matrix_batch_running; then
  batch_pid="$(enterprise_e2e_matrix_batch_pid 2>/dev/null || true)"
  if [[ "${SB_E2E_LAUNCH_FORCE:-}" != "1" ]]; then
    echo "ERROR: codex matrix batch still running (pid ${batch_pid:-unknown}) — refuse tmux kill; set SB_E2E_LAUNCH_FORCE=1 to override" >&2
    exit 1
  fi
  echo "WARN: SB_E2E_LAUNCH_FORCE=1 — killing running codex batch pid ${batch_pid:-unknown}" >&2
fi
for stale_pid_file in \
  "${ROOT}/.planning/enterprise-e2e/.codex-r3-force1416-driver.pid" \
  "${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-driver.pid"; do
  if [[ -f "$stale_pid_file" ]]; then
    stale_pid="$(tr -d '[:space:]' <"$stale_pid_file" 2>/dev/null || true)"
    if [[ -n "$stale_pid" ]] && ! kill -0 "$stale_pid" 2>/dev/null; then
      rm -f "$stale_pid_file"
    fi
  fi
done

tmux kill-session -t codex-r3-force1416 2>/dev/null || true
tmux kill-session -t codex-r3-force141619 2>/dev/null || true
rm -f "${ROOT}/.e2e-matrix-codex-batch.pid" "${ROOT}/.e2e-live-test.lock" 2>/dev/null || true

for row in 14 15 16; do
  rm -f "${ROOT}/.e2e-row${row}-codex-attempt.log" "${ROOT}/.e2e-row${row}-codex-attempt"[0-9]*.log
done
: >"$POLL_LOG"
: >"${ROOT}/.planning/enterprise-e2e/.codex-r3-force1416-rescore.log"

if [[ -d "${FIXTURE}/.git" ]]; then
  git -C "$FIXTURE" checkout "$BRANCH" 2>/dev/null || true
  printf 'fixture preserved @ %s (%s commits since 09f8d1a)\n' \
    "$(git -C "$FIXTURE" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
    "$(git -C "$FIXTURE" rev-list --count 09f8d1a..HEAD 2>/dev/null || echo 0)"
fi

if [[ ! -f "$FROZEN_RESCORE" ]]; then
  echo "ERROR: missing frozen rescore baseline .codex-r3-force141619-rescore.log" >&2
  exit 1
fi
if ! grep -q 'RESCORE_TOTAL pass=19/22' "$FROZEN_RESCORE"; then
  echo "WARN: force141619 rescore not 19/22 — proceeding with available frozen log" >&2
fi

chmod +x "${ROOT}/.planning/enterprise-e2e/codex-r3-force1416-driver.sh"
chmod +x "${ROOT}/.planning/enterprise-e2e/.codex-r3-force1416-poll-exit.sh"

tmux new-session -d -s codex-r3-force1416 -n driver -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_FROZEN_BASELINE_SHA=${FROZEN_SHA} SB_E2E_REVIEW_LADDER_LEDGER=$ROOT/.planning/enterprise-e2e/ROUND-3-LEDGER.md && exec bash .planning/enterprise-e2e/codex-r3-force1416-driver.sh 2>&1 | tee -a \"$LAUNCH_LOG\"'"

sleep 2
DRIVER_PID="$(tmux list-panes -t codex-r3-force1416:driver -F '#{pane_pid}' | head -1)"
printf '%s\n' "$DRIVER_PID" >"${ROOT}/.planning/enterprise-e2e/.codex-r3-force1416-driver.pid"

tmux new-window -t codex-r3-force1416 -n poll -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_FROZEN_BASELINE_SHA=${FROZEN_SHA} SB_E2E_REVIEW_LADDER_LEDGER=$ROOT/.planning/enterprise-e2e/ROUND-3-LEDGER.md && exec bash .planning/enterprise-e2e/.codex-r3-force1416-poll-exit.sh ${DRIVER_PID} 75'"

tmux new-window -t codex-r3-force1416 -n chain -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/.codex-r3-chain-monitor.sh ${DRIVER_PID} 80'"

mon_pid="$(bash "${ROOT}/.planning/enterprise-e2e/tui-monitor-batch-continuation-launch.sh" | awk '{print $NF}')"

printf 'tmux=codex-r3-force1416 driver=%s poll=tmux:poll chain=tmux:chain friction=%s\n' "$DRIVER_PID" "$mon_pid"
