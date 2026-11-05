#!/usr/bin/env bash
# matrix.sh fixture-branch and product-commit gates around a row, against a staged SB root.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"


# ------------------------------------------------------------ fixture gates around a row
reset
evidence_agent
run env F2_ENSURE_FAIL_AT=2 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "row-level branch pin failure fails the row" "1" "$TL_STATUS"
assert_contains "row-level pin message" "$TL_ERR" "  FAIL: cannot pin fixture branch before row 2"
assert_not_contains "agent not launched after pin failure" "$CALLS" "prompt#"
assert_contains "pin failure telemetry" "$CALLS" "telemetry matrix_row row=2 slug=silver-deep-research result=fail log="

reset
evidence_agent
run env F2_LOCK_FAIL_AT=2 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "pre-invoke branch lock failure fails the row" "1" "$TL_STATUS"
assert_contains "pre-invoke label" "$CALLS" "branch-lock#2 pre-invoke fixture branch (row 2)"
assert_not_contains "agent not launched after lock failure" "$CALLS" "prompt#"

reset
evidence_agent
run env F2_LOCK_FAIL_AT=3 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "post-invoke branch lock failure fails the row" "1" "$TL_STATUS"
assert_contains "post-invoke label" "$CALLS" "branch-lock#3 post-invoke fixture branch (row 2)"
assert_contains "agent ran before post-invoke failure" "$CALLS" "prompt#1"
assert_file_absent "no registry record after post-invoke failure" "$REG"

reset
evidence_agent
run env F2_BASELINE_FAIL_AT=2 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "late baseline gate failure fails the row" "1" "$TL_STATUS"
assert_file_absent "no registry record after late baseline failure" "$REG"
reset
evidence_agent
run env F2_DELTA_FAIL_AT=2 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "late product delta failure fails the row" "1" "$TL_STATUS"
assert_file_absent "no registry record after late delta failure" "$REG"

# row 1 does not require a product commit, so the late gates are the first calls
reset
agent <<'EOS'
echo "SILVER BULLET ▸ ROUTING"
EOS
run env F2_BASELINE_FAIL_AT=1 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 1
assert_eq "row 1 late baseline failure" "1" "$TL_STATUS"
reset
agent <<'EOS'
echo "SILVER BULLET ▸ ROUTING"
EOS
run env F2_DELTA_FAIL_AT=1 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 1
assert_eq "row 1 late delta failure" "1" "$TL_STATUS"

# early §5b gates (real implementations, product-work gate on)
reset
evidence_agent
run env SB_E2E_PRODUCT_WORK_GATE=1 SB_E2E_TEST_APP_BASELINE_SHA="$BASE" F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "evidence without a fixture commit fails (early delta gate)" "1" "$TL_STATUS"
assert_contains "early delta message" "$TL_OUT" "  FAIL: §5b product delta (early gate — evidence without fixture commit)"
assert_not_contains "outcomes not scored after early gate failure" "$TL_OUT" "OUTCOMES:"

reset
agent <<'EOS'
mkdir -p "$WORK_DIR/docs"; echo ok >"$WORK_DIR/docs/ADR-001-runtime.md"
git -C "$WORK_DIR" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m "product work"
EOS
run env SB_E2E_PRODUCT_WORK_GATE=1 SB_E2E_TEST_APP_BASELINE_SHA="$BASE" bash "$MATRIX" 2
assert_eq "evidence with a fixture commit passes" "0" "$TL_STATUS"
assert_contains "product delta reported" "$TL_OUT" "§5b product delta: "

reset
agent <<'EOS'
mkdir -p "$WORK_DIR/.planning/workflows"; echo ok >"$WORK_DIR/.planning/workflows/fast-readme.md"
EOS
run env SB_E2E_PRODUCT_WORK_GATE=1 SB_E2E_TEST_APP_BASELINE_SHA="$BASE" F2_TELEMETRY_FAIL=1 bash "$MATRIX" 6
assert_eq "row 6 evidence without a commit fails the baseline rev gate" "1" "$TL_STATUS"
assert_contains "row 6 start line" "$TL_OUT" "  §5b row 6 start: baseline ${BASE} rev-count="
assert_contains "row 6 early baseline gate message" "$TL_OUT" "  FAIL: §5b matrix baseline rev gate (early — no commit since row start)"

tl_results
