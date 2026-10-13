#!/usr/bin/env bash
# Row 3 outcome-only — product commit frozen @ 0fcd73e; rerun for PLAN/GATES/TRACE outcomes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FIXTURE="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-codex}"
ROW3_PRODUCT_SHA="${SB_E2E_ROW3_FROZEN_COMMIT:-345917a}"
ROW6_FROZEN="${SB_E2E_ROW6_FROZEN_COMMIT:-5072735}"
LAUNCH_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-row3-outcome-only-launch.log"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-row3-outcome-only-poll.log"
RESCORE_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-only-rescore.log"

printf '\n=== codex-r3-row3-outcome-only %s @ %s product=%s ===\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD)" "$ROW3_PRODUCT_SHA"

tmux kill-session -t codex-r3-row3-outcome 2>/dev/null || true
rm -f "${ROOT}/.e2e-matrix-codex-batch.pid" "${ROOT}/.e2e-live-test.lock" 2>/dev/null || true

# Archive prior row 3 log for comparison; fresh log for outcome-only attempt.
if [[ -f "${ROOT}/.e2e-row3-codex-attempt.log" ]]; then
  mv "${ROOT}/.e2e-row3-codex-attempt.log" \
    "${ROOT}/.e2e-row3-codex-attempt-product-only.log" 2>/dev/null || true
fi
rm -f "${ROOT}/.e2e-row3-codex-attempt"[0-9]*.log 2>/dev/null || true
: >"$POLL_LOG"

if [[ -d "${FIXTURE}/.git" ]]; then
  git -C "$FIXTURE" checkout "$BRANCH" 2>/dev/null || true
  git -C "$FIXTURE" reset --hard "$ROW3_PRODUCT_SHA" 2>/dev/null || true
  if [[ -f "${FIXTURE}/.silver-bullet.json" ]]; then
    jq '.recommended_tools.graphify.enabled_by_user = true | .recommended_tools.agentmemory.enabled_by_user = true' \
      "${FIXTURE}/.silver-bullet.json" >"${FIXTURE}/.silver-bullet.json.tmp" && \
      mv "${FIXTURE}/.silver-bullet.json.tmp" "${FIXTURE}/.silver-bullet.json"
  fi
  if command -v graphify >/dev/null 2>&1; then
    (cd "$FIXTURE" && graphify update . --no-cluster >/dev/null 2>&1) || true
  fi
  printf 'fixture pinned %s@%s (row 3 product frozen; outcome-only rerun)\n' \
    "$BRANCH" "$(git -C "$FIXTURE" rev-parse --short HEAD)"
fi

chmod +x "${ROOT}/.planning/enterprise-e2e/codex-r3-force3-only-driver.sh"
chmod +x "${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-only-poll-exit.sh"

tmux new-session -d -s codex-r3-row3-outcome -n driver -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_OUTCOME_ONLY_ROWS=3 SB_E2E_ROW6_FROZEN_COMMIT=$ROW6_FROZEN SB_E2E_ROW3_PRODUCT_ANCHOR_SHA=$ROW6_FROZEN SB_E2E_ROW3_FROZEN_COMMIT=$ROW3_PRODUCT_SHA && exec bash .planning/enterprise-e2e/codex-r3-force3-only-driver.sh 2>&1 | tee -a \"$LAUNCH_LOG\"'"

sleep 2
DRIVER_PID="$(tmux list-panes -t codex-r3-row3-outcome:driver -F '#{pane_pid}' | head -1)"
printf '%s\n' "$DRIVER_PID" >"${ROOT}/.planning/enterprise-e2e/.codex-r3-row3-outcome-only-driver.pid"

tmux new-window -t codex-r3-row3-outcome -n poll -c "$ROOT" \
  "bash -lc 'cd \"$ROOT\" && export SB_E2E_ROW6_FROZEN_COMMIT=$ROW6_FROZEN SB_E2E_ROW3_PRODUCT_ANCHOR_SHA=$ROW6_FROZEN SB_E2E_ROW3_FROZEN_COMMIT=$ROW3_PRODUCT_SHA && exec bash .planning/enterprise-e2e/.codex-r3-force3-only-poll-exit.sh ${DRIVER_PID} 75'"

mon_pid="$(bash "${ROOT}/.planning/enterprise-e2e/tui-monitor-batch-continuation-launch.sh" | awk '{print $NF}')"
printf 'tmux=codex-r3-row3-outcome driver=%s poll=tmux:poll friction=%s\n' "$DRIVER_PID" "$mon_pid"
