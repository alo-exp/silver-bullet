#!/usr/bin/env bash
# Purge stale row 3 artifacts, pin fixture @ row-6 commit, relaunch force3+6 in tmux-stable poll.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FIXTURE="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
ROW6_COMMIT="${SB_E2E_ROW6_FROZEN_COMMIT:-b22b730}"
BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-codex}"
LAUNCH_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-launch.log"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-poll.log"
RESCORE_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-rescore.log"

printf '\n=== codex-r3-force3-launch %s @ %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD)"

tmux kill-session -t codex-r3-force36 2>/dev/null || true
tmux kill-session -t codex-r3-force3 2>/dev/null || true
tmux kill-session -t codex-r3-real-tierb 2>/dev/null || true
rm -f "${ROOT}/.e2e-matrix-codex-batch.pid" "${ROOT}/.e2e-live-test.lock" 2>/dev/null || true

rm -f "${ROOT}/.e2e-row3-codex-attempt.log" "${ROOT}/.e2e-row3-codex-attempt"[0-9]*.log
rm -f "${ROOT}/.e2e-row6-codex-attempt.log" "${ROOT}/.e2e-row6-codex-attempt"[0-9]*.log
: >"$POLL_LOG"
: >"$RESCORE_LOG"

if [[ -d "${FIXTURE}/.git" ]]; then
  git -C "$FIXTURE" checkout "$BRANCH" 2>/dev/null || true
  git -C "$FIXTURE" reset --hard "$ROW6_COMMIT" 2>/dev/null || true
  rm -f \
    "${FIXTURE}/.planning/workflows/feature-currency.md" \
    "${FIXTURE}/.planning/enterprise-e2e/outcomes/row-3-outcomes.md" \
    2>/dev/null || true
  if [[ -f "${FIXTURE}/.silver-bullet.json" ]]; then
    jq '.recommended_tools.graphify.enabled_by_user = true | .recommended_tools.agentmemory.enabled_by_user = true' \
      "${FIXTURE}/.silver-bullet.json" >"${FIXTURE}/.silver-bullet.json.tmp" && \
      mv "${FIXTURE}/.silver-bullet.json.tmp" "${FIXTURE}/.silver-bullet.json"
    printf 'fixture Session0 opt-in: graphify+agentmemory enabled_by_user=true\n'
  fi
  if command -v graphify >/dev/null 2>&1; then
    (cd "$FIXTURE" && graphify update . --no-cluster >/dev/null 2>&1) && \
      printf 'fixture graphify update: graphify-out/graph.json present\n' || \
      printf 'WARN: fixture graphify update failed (continuing)\n'
  fi
  printf 'fixture pinned %s@%s (row6 README preserved)\n' "$BRANCH" "$(git -C "$FIXTURE" rev-parse --short HEAD)"
fi

if [[ ! -s "${ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-rescore.log" ]]; then
  printf 'row 1 PASS (frozen@4412bb01)\nrow 3 FAIL: prior attempt\nrow 6 FAIL: prior attempt\nTIERB_RESCORE pass=1/3 fail_rows=3 6\n' \
    >"${ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-rescore.log"
fi

chmod +x "${ROOT}/.planning/enterprise-e2e/codex-r3-force3-driver.sh"
chmod +x "${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-poll-exit.sh"

tmux new-session -d -s codex-r3-force3 -n driver -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_ROW6_FROZEN_COMMIT=$ROW6_COMMIT && exec bash .planning/enterprise-e2e/codex-r3-force3-driver.sh 2>&1 | tee -a \"$LAUNCH_LOG\"'"

sleep 2
DRIVER_PID="$(tmux list-panes -t codex-r3-force3:driver -F '#{pane_pid}' | head -1)"
printf '%s\n' "$DRIVER_PID" >"${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-driver.pid"

tmux new-window -t codex-r3-force3 -n poll -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_ROW6_FROZEN_COMMIT=$ROW6_COMMIT && exec bash .planning/enterprise-e2e/.codex-r3-force3-poll-exit.sh ${DRIVER_PID} 75'"

tmux new-window -t codex-r3-force3 -n chain -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/.codex-r3-chain-monitor.sh ${DRIVER_PID} 80'"

mon_pid="$(bash "${ROOT}/.planning/enterprise-e2e/tui-monitor-batch-continuation-launch.sh" | awk '{print $NF}')"

printf 'tmux=codex-r3-force3 driver=%s poll=tmux:poll chain=tmux:chain friction=%s\n' "$DRIVER_PID" "$mon_pid"
