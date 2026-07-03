#!/usr/bin/env bash
# Round Codex-3 force3+6 — FORCE rows 3,6; frozen row 1 PASS; preserve row 6 commit @ b22b730.
# Row 3: full product rerun (api/currency commits required after row-6 anchor).
# Row 6: outcome-only rerun (§5b satisfied by frozen README commit).
set -euo pipefail

SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SB_ROOT
export SB_E2E_BRANCH="${SB_E2E_BRANCH:-main}"
export SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex SB_LIVE_RUNTIME=codex
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CODEX-3-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
export SB_E2E_TEST_APP_BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-codex}"
export SB_E2E_TEST_APP_BASELINE_SHA="${SB_E2E_TEST_APP_BASELINE_SHA:-09f8d1a}"
export SB_E2E_TEST_APP_ROUND=9
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_MATRIX_FORCE_ALL=1
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_PRODUCT_WORK_GATE=1
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_SURFACE_SKIP=0
# Session 0: opt in graphify + agentmemory on fixture (row 6 OUT-KM-01).
export SB_E2E_SESSION0_SKIP=0
export SB_E2E_SESSION0_SKIP_REASON=""
export SB_E2E_OUTCOME_ONLY_ROWS="6"
export SB_E2E_ROW6_FROZEN_COMMIT="${SB_E2E_ROW6_FROZEN_COMMIT:-b22b730}"
export SB_E2E_ROW3_PRODUCT_ANCHOR_SHA="${SB_E2E_ROW6_FROZEN_COMMIT}"
export SB_E2E_FROZEN_BASELINE_SHA="${SB_E2E_FROZEN_BASELINE_SHA:-4412bb01}"
export SB_E2E_SKIP_CODEX_INSTALL=1
export RTK_DISABLED=1
export SB_E2E_MATRIX_LOG="${SB_ROOT}/.e2e-matrix-codex-live.log"
export SB_E2E_MATRIX_BATCH_PID_FILE="${SB_ROOT}/.e2e-matrix-codex-batch.pid"
export SB_E2E_FROZEN_TIERB_RESCORE_LOG="${SB_ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-rescore.log"
export CODEX_INTERACTIVE_IDLE_TIMEOUT="${CODEX_INTERACTIVE_IDLE_TIMEOUT:-1800}"

ROWS=(3 6)

# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"

cd "$SB_ROOT"
if declare -f enterprise_e2e_matrix_batch_running >/dev/null 2>&1 && enterprise_e2e_matrix_batch_running; then
  batch_pid="$(enterprise_e2e_matrix_batch_pid 2>/dev/null || true)"
  echo "ERROR: matrix batch already running (pid ${batch_pid:-unknown}) — refuse duplicate force3 launch" >&2
  exit 1
fi

current_branch="$(git branch --show-current 2>/dev/null || true)"
if [[ "$current_branch" != "$SB_E2E_BRANCH" ]]; then
  git checkout "$SB_E2E_BRANCH" >/dev/null 2>&1 || true
fi

fixture_dir="$SB_TEST_ENTERPRISE_APP_ROOT"
if [[ -d "${fixture_dir}/.git" ]]; then
  git -C "$fixture_dir" checkout "$SB_E2E_TEST_APP_BRANCH" 2>/dev/null || true
  frozen_head="$(git -C "$fixture_dir" rev-parse --short "$SB_E2E_ROW6_FROZEN_COMMIT" 2>/dev/null || true)"
  if [[ -n "$frozen_head" ]]; then
    git -C "$fixture_dir" reset --hard "$SB_E2E_ROW6_FROZEN_COMMIT" 2>/dev/null || true
    echo "  fixture pinned @ row-6 commit ${frozen_head} (row 1 frozen + row 6 README preserved)"
  fi
  if [[ -f "${fixture_dir}/.silver-bullet.json" ]]; then
    jq '.recommended_tools.graphify.enabled_by_user = true | .recommended_tools.agentmemory.enabled_by_user = true' \
      "${fixture_dir}/.silver-bullet.json" >"${fixture_dir}/.silver-bullet.json.tmp" && \
      mv "${fixture_dir}/.silver-bullet.json.tmp" "${fixture_dir}/.silver-bullet.json"
    echo "  fixture Session0: graphify+agentmemory opted in"
  fi
  if command -v graphify >/dev/null 2>&1; then
    (cd "$fixture_dir" && graphify update . --no-cluster >/dev/null 2>&1) || true
  fi
  rm -f \
    "${fixture_dir}/.planning/workflows/feature-currency.md" \
    "${fixture_dir}/.planning/enterprise-e2e/outcomes/row-3-outcomes.md" \
    2>/dev/null || true
fi

printf '\n=== codex-r3-force3 FORCE %s rows %s @ SB %s fixture %s@%s ===\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${ROWS[*]}" "$(git rev-parse --short HEAD)" \
  "${SB_E2E_TEST_APP_BRANCH}" "$(git -C "$fixture_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "  SB_SHA=$(git rev-parse --short HEAD) fixture=$(git -C "$fixture_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "  policy=frozen row1 PASS; FORCE rows 3+6; row6 outcome-only @ ${SB_E2E_ROW6_FROZEN_COMMIT:0:12}"
echo "  §5b product gate=ON early-fail; exempt rows 1,15,21,22; row6 outcome-only"

exec env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight "${ROWS[@]}" \
  2>&1 | tee -a "$SB_E2E_MATRIX_LOG"
