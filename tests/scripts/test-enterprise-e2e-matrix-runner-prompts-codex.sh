#!/usr/bin/env bash
# matrix.sh prompt composition for the codex host, against a staged SB root with a fake agent.
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

# codex: route is translated; the generic product clause appears for qualifying rows
CODEX=(SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex)
p="$(prompt_of 7 "${CODEX[@]}" SB_E2E_PRODUCT_WORK_GATE=1)"
assert_contains "codex row 7 uses the dollar route" "$p" 'prompt#1 /sb '
assert_contains "codex row 7 generic product clause" "$p" "$CLAUSE_P"
p="$(prompt_of 7 "${CODEX[@]}")"
assert_not_contains "codex row 7 without gate has no clause" "$p" "§5b product gate"
p="$(prompt_of 14 "${CODEX[@]}" SB_E2E_PRODUCT_WORK_GATE=1)"
assert_contains "codex row 14 generic product clause" "$p" "$CLAUSE_P"
p="$(prompt_of 14 "${CODEX[@]}" SB_E2E_PRODUCT_WORK_GATE=1 SB_E2E_OUTCOME_ONLY_ROWS=14)"
assert_not_contains "codex outcome-only row 14 has no generic clause" "$p" "$CLAUSE_P"
p="$(prompt_of 16 "${CODEX[@]}" SB_E2E_PRODUCT_WORK_GATE=1)"
assert_contains "codex row 16 generic product clause" "$p" "$CLAUSE_P"
p="$(prompt_of 16 "${CODEX[@]}" SB_E2E_PRODUCT_WORK_GATE=1 SB_E2E_OUTCOME_ONLY_ROWS=16)"
assert_not_contains "codex outcome-only row 16 has no generic clause" "$p" "$CLAUSE_P"
p="$(prompt_of 1 "${CODEX[@]}")"
assert_contains "codex row 1 prompt carries the evidence clause" "$p" "§5b row 1 gate"
assert_contains "codex router prompt keeps the slash route in the card" "$p" "prompt#1 /sb I need to add order validation"

tl_results
