#!/usr/bin/env bash
# Resume R9 pilot row 3 after operator clears /mcp (USER_MCP_GATE=REQUIRED).
# See .r9-mcp-operator-runbook.md — do not run until manual /mcp gate is done.
set -euo pipefail

MAIN="${SB_E2E_MAIN_REPO:-/Users/shafqat/projects/silver-bullet/repo}"
# shellcheck source=scripts/lib/enterprise-e2e-sb-root-resolve.sh
source "${MAIN}/scripts/lib/enterprise-e2e-sb-root-resolve.sh"
SB_ROOT="${SB_ROOT:-$(enterprise_e2e_resolve_sb_root)}"
WT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app-round9-claude}"
export SB_TEST_ENTERPRISE_APP_ROOT="$WT"
BASELINE_SHA="${SB_E2E_TEST_APP_BASELINE_SHA:-8482e60}"
PILOT_LOG="${SB_E2E_MATRIX_LOG:-${MAIN}/.e2e-r9-pilot-row3-resume-after-mcp-live.log}"

commit_count() {
  git -C "$WT" rev-list --count "${BASELINE_SHA}..HEAD" 2>/dev/null || echo 0
}

print_env() {
  cat <<EOF
--- Honest env (documented) ---
  SB_E2E_MAIN_REPO=$MAIN
  SB_ROOT=$SB_ROOT
  SB_TEST_ENTERPRISE_APP_ROOT=$WT
  SB_E2E_TEST_APP_BRANCH=${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-claude}
  SB_E2E_TEST_APP_BASELINE_SHA=$BASELINE_SHA
  SB_ENTERPRISE_E2E_LIVE=1
  SB_E2E_LIVE_RUNTIME=claude
  SILVER_BULLET_RUNTIME=claude
  SB_E2E_SURFACE_SKIP=0
  SB_E2E_MATRIX_FORCE=1
  SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
  SB_E2E_ISOLATED_CLAUDE_CONFIG=${SB_E2E_ISOLATED_CLAUDE_CONFIG:-1}
  CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow
  CLAUDE_MODEL=${CLAUDE_MODEL:-sonnet}
  SB_E2E_WORKFLOW_QUIET_TIMEOUT=${SB_E2E_WORKFLOW_QUIET_TIMEOUT:-1200}
  CLAUDE_INTERACTIVE_TIMEOUT=${CLAUDE_INTERACTIVE_TIMEOUT:-2400}
  RTK_DISABLED=1
  SB_E2E_MONITOR_AUTO_RESTART=0
  SB_E2E_LEDGER_FILE=${SB_E2E_LEDGER_FILE:-${MAIN}/.planning/enterprise-e2e/ROUND-9-LEDGER.md}
  SB_E2E_MATRIX_LOG=$PILOT_LOG
EOF
}

echo "=== R9 resume after /mcp gate ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo
echo "Preflight checklist (operator — runbook step 2–4):"
echo "  [ ] /mcp banner cleared in round-9 worktree (no blocking 「N MCP servers need authentication」)"
echo "  [ ] Manual Claude session: tokens advance past the ❯ prompt (not a 0-token stall)"
echo "  [ ] agentmemory shows Connected (claude mcp list; do not disable agentmemory)"
echo
print_env
echo

if [[ ! -d "$SB_ROOT" ]]; then
  echo "RESULT: FAIL — SB_ROOT missing: $SB_ROOT"
  echo "§5b commits (${BASELINE_SHA}..HEAD): $(commit_count)"
  exit 2
fi
if [[ ! -d "$WT" ]]; then
  echo "RESULT: FAIL — worktree missing: $WT"
  echo "§5b commits (${BASELINE_SHA}..HEAD): $(commit_count)"
  exit 2
fi

# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${MAIN}/scripts/lib/enterprise-e2e-live-common.sh"
export SB_ROOT SB_TEST_ENTERPRISE_APP_ROOT
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_LIVE_RUNTIME=claude
export SILVER_BULLET_RUNTIME=claude
export SB_E2E_ISOLATED_CLAUDE_CONFIG="${SB_E2E_ISOLATED_CLAUDE_CONFIG:-1}"

echo "--- matrix MCP prepare + verify (worktree) ---"
enterprise_e2e_prepare_matrix_mcp_env "$WT"
if ! enterprise_e2e_verify_matrix_mcp_env "$WT"; then
  echo
  echo "RESULT: FAIL — enterprise_e2e_verify_matrix_mcp_env (fix runbook step 2–4, then re-run)"
  echo "§5b commits (${BASELINE_SHA}..HEAD): $(commit_count)"
  exit 3
fi
echo

export SB_E2E_TEST_APP_BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-claude}"
export SB_E2E_TEST_APP_BASELINE_SHA="$BASELINE_SHA"
export SB_E2E_SURFACE_SKIP=0
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow
export CLAUDE_MODEL="${CLAUDE_MODEL:-sonnet}"
export SB_E2E_WORKFLOW_QUIET_TIMEOUT="${SB_E2E_WORKFLOW_QUIET_TIMEOUT:-1200}"
export CLAUDE_INTERACTIVE_TIMEOUT="${CLAUDE_INTERACTIVE_TIMEOUT:-2400}"
export RTK_DISABLED=1
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${MAIN}/.planning/enterprise-e2e/ROUND-9-LEDGER.md}"
export SB_E2E_MATRIX_LOG="$PILOT_LOG"

echo "--- pilot row 3 only (silver-feature) ---"
cd "$SB_ROOT"
set +e
bash scripts/run-enterprise-e2e-live-test.sh 3 2>&1 | tee -a "$PILOT_LOG"
pilot_rc=${PIPESTATUS[0]}
set -e

commits="$(commit_count)"
echo
if [[ "$pilot_rc" -eq 0 ]]; then
  echo "RESULT: PASS — pilot row 3 exit 0"
else
  echo "RESULT: FAIL — pilot row 3 exit $pilot_rc (log: $PILOT_LOG)"
fi
echo "§5b commits (${BASELINE_SHA}..HEAD): $commits"
exit "$pilot_rc"
