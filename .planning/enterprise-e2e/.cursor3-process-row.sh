#!/usr/bin/env bash
# Process one completed Cursor-3 REAL row: score, fixture commit, ledger line.
set -euo pipefail
ROW="${1:?row number}"
SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
FIXTURE="/Users/shafqat/projects/enterprise-grade-test-app-cursor"
LEDGER="$SB_ROOT/.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md"

export SB_ROOT SB_E2E_LEDGER_FILE="$LEDGER" SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE"
export SB_E2E_ENTERPRISE_MATRIX=1

source "$SB_ROOT/scripts/lib/enterprise-e2e-outcome-assessment.sh"
slug="$(enterprise_e2e_outcome_matrix_workflow_slug "$ROW")"
export SB_E2E_MATRIX_GRAPHIFY_REF="graphify query ${slug} routes hooks skills orchestrator"

ATTEMPT="$SB_ROOT/.e2e-row${ROW}-cursor-attempt.log"
STATE="$FIXTURE/.planning/enterprise-e2e/state"
mkdir -p "$STATE"

bytes=$(wc -c <"$ATTEMPT" | tr -d ' ')
[[ "$bytes" -ge 2048 ]] || { echo "FAIL row $ROW log floor $bytes"; exit 1 }
enterprise_e2e_outcome_row_passes "$ROW" "$FIXTURE" "$STATE" "$ATTEMPT" "$LEDGER" "" || {
  echo "FAIL row $ROW outcome"; enterprise_e2e_outcome_assess_session "$ATTEMPT" "$STATE" "$FIXTURE" "$LEDGER" "$ROW"; exit 1
}

cd "$FIXTURE"
if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  git add -A
  git commit -m "enterprise-e2e: cursor-3 row ${ROW} (${slug})

Round Cursor-3 REAL live matrix evidence." >/dev/null
fi
sha=$(git rev-parse --short HEAD)
echo "PASS row $ROW bytes=$bytes sha=$sha slug=$slug"
