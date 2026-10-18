#!/usr/bin/env bash
# matrix.sh prompt composition per row and host, against a staged SB root with a fake agent.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

export SB_E2E_TEST_APP_BRANCH=prompt-branch

# prompt_of ROW [env assignments...]: the prompt the agent receives for one live row
prompt_of() {
  local row="$1"
  shift
  reset
  agent <<'EOS'
echo noop
EOS
  run env "$@" bash "$MATRIX" "$row"
  grep '^prompt#1 ' <<<"$CALLS" || true
}

CLAUSE_P="$(SB_E2E_PRODUCT_WORK_GATE=1 matrix_product_commit_clause)"
R3_OUT="$(matrix_row3_outcome_clause)"
R3_ONLY="$(matrix_row3_outcome_only_clause)"
R3_PRODUCT="$(SB_E2E_PRODUCT_WORK_GATE=1 matrix_row3_product_commit_clause)"
R6_PRODUCT="$(SB_E2E_PRODUCT_WORK_GATE=1 matrix_row6_product_commit_clause)"
R11_OUT="$(matrix_row11_outcome_clause)"
R11_PRODUCT="$(SB_E2E_PRODUCT_WORK_GATE=1 matrix_row11_product_commit_clause)"
R14_OUT="$(matrix_row14_outcome_clause)"
R14_ONLY="$(matrix_row14_outcome_only_clause)"
R15_OUT="$(matrix_row15_outcome_clause)"
R16_OUT="$(matrix_row16_outcome_clause)"
R16_ONLY="$(matrix_row16_outcome_only_clause)"
BASE_PROMPT_2="$(matrix_router_workflow_prompt silver-deep-research 'Should we use Postgres or SQLite for orders?' docs/ADR-001-runtime.md /sb)"

# claude, gate off: plain workflow prompt
p="$(prompt_of 2)"
assert_eq "row 2 claude prompt is the plain workflow prompt" "prompt#1 $BASE_PROMPT_2" "$p"

# claude, gate on: product commit clauses only for the rows that define one
p="$(prompt_of 3 SB_E2E_PRODUCT_WORK_GATE=1)"
assert_contains "row 3 outcome clause" "$p" "$R3_OUT"
assert_contains "row 3 product commit clause under the gate" "$p" "$R3_PRODUCT"
assert_not_contains "row 3 outcome-only clause absent by default" "$p" "$R3_ONLY"
p="$(prompt_of 3)"
assert_contains "row 3 outcome clause without the gate" "$p" "$R3_OUT"
assert_not_contains "row 3 commit clause absent without the gate" "$p" "§5b row 3 gate"
p="$(prompt_of 3 SB_E2E_PRODUCT_WORK_GATE=1 "SB_E2E_OUTCOME_ONLY_ROWS=3 14")"
assert_contains "row 3 outcome-only clause" "$p" "$R3_ONLY"
assert_not_contains "outcome-only row 3 drops the commit clause" "$p" "$R3_PRODUCT"

p="$(prompt_of 6 SB_E2E_PRODUCT_WORK_GATE=1)"
assert_contains "row 6 product commit clause" "$p" "$R6_PRODUCT"
p="$(prompt_of 6)"
assert_not_contains "row 6 plain without gate" "$p" "§5b row 6 gate"

p="$(prompt_of 11 SB_E2E_PRODUCT_WORK_GATE=1)"
assert_contains "row 11 outcome clause" "$p" "$R11_OUT"
assert_contains "row 11 product commit clause" "$p" "$R11_PRODUCT"
p="$(prompt_of 11)"
assert_contains "row 11 outcome clause without gate" "$p" "$R11_OUT"
assert_not_contains "row 11 commit clause absent without gate" "$p" "§5b row 11 gate"

p="$(prompt_of 14)"
assert_contains "row 14 outcome clause" "$p" "$R14_OUT"
assert_not_contains "row 14 claude never gets the generic commit clause" "$p" "§5b product gate"
p="$(prompt_of 14 SB_E2E_PRODUCT_WORK_GATE=1)"
assert_not_contains "row 14 claude with gate has no generic clause" "$p" "$CLAUSE_P"
p="$(prompt_of 14 "SB_E2E_OUTCOME_ONLY_ROWS=14")"
assert_contains "row 14 outcome-only clause" "$p" "$R14_ONLY"

p="$(prompt_of 15)"
assert_contains "row 15 outcome clause" "$p" "$R15_OUT"
p="$(prompt_of 16)"
assert_contains "row 16 outcome clause" "$p" "$R16_OUT"
p="$(prompt_of 16 SB_E2E_OUTCOME_ONLY_ROWS=16)"
assert_contains "row 16 outcome-only clause" "$p" "$R16_ONLY"

# other rows: plain on claude even with the gate
p="$(prompt_of 7 SB_E2E_PRODUCT_WORK_GATE=1)"
assert_not_contains "row 7 claude gate has no commit clause" "$p" "§5b product gate"

tl_results
