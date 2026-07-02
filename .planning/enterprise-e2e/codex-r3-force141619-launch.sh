#!/usr/bin/env bash
# Purge stale row 14/15/16/19 artifacts, preserve fixture @ 3ca685f, launch force141619 in tmux.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FIXTURE="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-codex}"
FROZEN_SHA="${SB_E2E_FROZEN_BASELINE_SHA:-e4e8f814}"
LAUNCH_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-launch.log"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-poll.log"

printf '\n=== codex-r3-force141619-launch %s @ %s frozen@%s ===\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD)" "$FROZEN_SHA"

tmux kill-session -t codex-r3-force141619 2>/dev/null || true
tmux kill-session -t codex-r3-matrix 2>/dev/null || true
rm -f "${ROOT}/.e2e-matrix-codex-batch.pid" "${ROOT}/.e2e-live-test.lock" 2>/dev/null || true

for row in 14 15 16 19; do
  rm -f "${ROOT}/.e2e-row${row}-codex-attempt.log" "${ROOT}/.e2e-row${row}-codex-attempt"[0-9]*.log
done
: >"$POLL_LOG"
: >"${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-rescore.log"

if [[ -d "${FIXTURE}/.git" ]]; then
  git -C "$FIXTURE" checkout "$BRANCH" 2>/dev/null || true
  printf 'fixture preserved @ %s (%s commits since 09f8d1a)\n' \
    "$(git -C "$FIXTURE" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
    "$(git -C "$FIXTURE" rev-list --count 09f8d1a..HEAD 2>/dev/null || echo 0)"
fi

if [[ ! -f "${ROOT}/.planning/enterprise-e2e/.codex-r3-matrix-rescore.log" ]]; then
  echo "ERROR: missing frozen rescore baseline .codex-r3-matrix-rescore.log" >&2
  exit 1
fi
if ! grep -q 'RESCORE_TOTAL pass=18/22' "${ROOT}/.planning/enterprise-e2e/.codex-r3-matrix-rescore.log"; then
  echo "WARN: matrix rescore not 18/22 — proceeding with available frozen log" >&2
fi

chmod +x "${ROOT}/.planning/enterprise-e2e/codex-r3-force141619-driver.sh"
chmod +x "${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-poll-exit.sh"

tmux new-session -d -s codex-r3-force141619 -n driver -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_FROZEN_BASELINE_SHA=${FROZEN_SHA} && exec bash .planning/enterprise-e2e/codex-r3-force141619-driver.sh 2>&1 | tee -a \"$LAUNCH_LOG\"'"

sleep 2
DRIVER_PID="$(tmux list-panes -t codex-r3-force141619:driver -F '#{pane_pid}' | head -1)"
printf '%s\n' "$DRIVER_PID" >"${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-driver.pid"

tmux new-window -t codex-r3-force141619 -n poll -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_FROZEN_BASELINE_SHA=${FROZEN_SHA} && exec bash .planning/enterprise-e2e/.codex-r3-force141619-poll-exit.sh ${DRIVER_PID} 75'"

tmux new-window -t codex-r3-force141619 -n chain -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/.codex-r3-chain-monitor.sh ${DRIVER_PID} 80'"

mon_pid="$(bash "${ROOT}/.planning/enterprise-e2e/tui-monitor-batch-continuation-launch.sh" | awk '{print $NF}')"

printf 'tmux=codex-r3-force141619 driver=%s poll=tmux:poll chain=tmux:chain friction=%s\n' "$DRIVER_PID" "$mon_pid"
