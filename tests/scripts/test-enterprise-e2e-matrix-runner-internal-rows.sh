#!/usr/bin/env bash
# matrix.sh internal rows 21/22 verdicts and marker fallbacks, against a staged SB root.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

WF="$APP/.planning/workflows"
# ----------------------------------------------------- internal rows 21 and 22
WF="$APP/.planning/workflows"
reset
run bash "$MATRIX" 21 22
assert_eq "internal rows pass" "0" "$TL_STATUS"
assert_contains "row 21 pass" "$TL_OUT" "=== Row 21: post-exec-gates (internal) PASS ==="
assert_contains "row 22 pass" "$TL_OUT" "=== Row 22: validate-substep (internal) PASS ==="
assert_eq "internal pass recorded in registry (row 21)" "true" "$(jq -r '.installs | to_entries[0].value.rows["21"].outcome_pass' "$REG")"
assert_eq "internal pass recorded in registry (row 22)" "true" "$(jq -r '.installs | to_entries[0].value.rows["22"].outcome_pass' "$REG")"
assert_contains "feature marker" "$(cat "$WF/feature-currency.md")" "post-exec-gates"
assert_contains "bugfix marker" "$(cat "$WF/bugfix-health.md")" "validate-substep"

# registry pass on the same install lets a broken marker slip to SKIP
break_markers() { touch "$F2_CTL/find-fail-post-exec-gates" "$F2_CTL/find-fail-validate-substep"; }
break_markers
run bash "$MATRIX" 21 22
assert_eq "registry-skipped internal rows pass" "0" "$TL_STATUS"
assert_contains "row 21 skipped" "$TL_OUT" "=== Row 21: post-exec-gates (internal) SKIP: ROW_ALREADY_PASSED_SAME_INSTALL ==="
assert_contains "row 22 skipped" "$TL_OUT" "=== Row 22: validate-substep (internal) SKIP: ROW_ALREADY_PASSED_SAME_INSTALL ==="
assert_contains "internal skips counted" "$TL_OUT" "Skip:  2 (install-pass: 2)"

# no registry pass and unusable markers: FAIL (and nothing else rescues it)
rm -f "$REG"
break_markers
run bash "$MATRIX" 21 22
assert_eq "broken markers fail the internal rows" "1" "$TL_STATUS"
assert_contains "row 21 fail" "$TL_OUT" "=== Row 21: post-exec-gates (internal) FAIL ==="
assert_contains "row 22 fail" "$TL_OUT" "=== Row 22: validate-substep (internal) FAIL ==="
assert_contains "internal fail summary" "$TL_OUT" "Fail:  2"

# parent attempt log that mentions the marker rescues the row
break_markers
echo "post-exec-gates reached" >"$R/.e2e-row3-attempt.log"
echo "validate-substep reached" >"$R/.e2e-row4-attempt.log"
run bash "$MATRIX" 21 22
assert_eq "parent attempt logs rescue the internal rows" "0" "$TL_STATUS"
assert_contains "row 21 rescued by log" "$TL_OUT" "=== Row 21: post-exec-gates (internal) PASS ==="
rm -f "$REG"

# parent log without the marker: the outcome scorer decides; a passing scorer re-seeds (heal) and passes
break_markers
echo "unrelated" >"$R/.e2e-row3-attempt.log"
echo "unrelated" >"$R/.e2e-row4-attempt.log"
touch "$F2_CTL/heal"
run bash "$MATRIX" 21 22
assert_eq "scorer-approved parent rows pass after reseeding" "0" "$TL_STATUS"
assert_contains "scorer consulted for parent row 3" "$CALLS" "outcome-row-passes row=3 work=$APP log=$R/.e2e-row3-attempt.log"
assert_contains "scorer consulted for parent row 4" "$CALLS" "outcome-row-passes row=4 work=$APP log=$R/.e2e-row4-attempt.log"
assert_contains "scorer given the evidence path" "$CALLS" "evidence=evidence-for-3"
rm -f "$F2_CTL/heal" "$REG"

# scorer failing and no usable ledger: FAIL
break_markers
touch "$F2_CTL/outcome-fail-3" "$F2_CTL/outcome-fail-4"
run bash "$MATRIX" 21 22
assert_eq "scorer rejection fails internal rows" "1" "$TL_STATUS"
assert_not_contains "no ledger consulted without a ledger file" "$TL_OUT" "Row 21: post-exec-gates (internal) PASS"
rm -f "$F2_CTL"/outcome-fail-*

# scorer failing but ledger says the parent row passed: reseed (heal) and pass
printf '| 3 | silver-feature | wf | Pass | g | a |\n| 4 | silver-bugfix | wf | Fail | g | a |\n' >"$SB_E2E_LEDGER_FILE"
break_markers
touch "$F2_CTL/outcome-fail-3" "$F2_CTL/outcome-fail-4" "$F2_CTL/heal"
echo 4 >"$F2_CTL/heal-ledger-after"
run bash "$MATRIX" 21 22
assert_eq "ledger Pass for parent 3 rescues row 21 only" "1" "$TL_STATUS"
assert_contains "row 21 rescued by ledger" "$TL_OUT" "=== Row 21: post-exec-gates (internal) PASS ==="
assert_contains "row 22 not rescued by a Fail ledger row" "$TL_OUT" "=== Row 22: validate-substep (internal) FAIL ==="
rm -f "$F2_CTL"/outcome-fail-* "$F2_CTL/heal" "$F2_CTL/heal-ledger-after" "$F2_CTL/parse-count" "$SB_E2E_LEDGER_FILE" "$R"/.e2e-row3-attempt.log "$R"/.e2e-row4-attempt.log

# ledger row line missing entirely
printf '| 9 | other | wf | Pass | g | a |\n' >"$SB_E2E_LEDGER_FILE"
break_markers
rm -f "$REG"
run bash "$MATRIX" 21
assert_eq "ledger without the parent row cannot rescue" "1" "$TL_STATUS"

# unusable runtime state dir / evidence-path lookups / attempt-log lookups do not abort the verdict
break_markers
echo "unrelated" >"$R/.e2e-row3-attempt.log"
touch "$F2_CTL/outcome-fail-3"
run env F2_RUNTIME_STATE_FAIL=1 F2_EVPATH_FAIL=1 bash "$MATRIX" 21
assert_eq "scorer still consulted with fallback state dir and no evidence path" "1" "$TL_STATUS"
assert_contains "scorer called without an evidence path" "$CALLS" "outcome-row-passes row=3 work=$APP log=$R/.e2e-row3-attempt.log ledger=$SB_E2E_LEDGER_FILE evidence="
rm -f "$F2_CTL"/outcome-fail-3 "$R/.e2e-row3-attempt.log"
break_markers
run env F2_ATTEMPT_LOG_FAIL_FIRST=5 bash "$MATRIX" 21
assert_eq "failing parent attempt-log lookup falls through to FAIL" "1" "$TL_STATUS"
assert_contains "row 21 fail verdict" "$TL_OUT" "=== Row 21: post-exec-gates (internal) FAIL ==="
rm -f "$F2_CTL"/find-fail-*

# ensure_internal_gate_markers consults the ledger and parent logs up front
rm -f "$F2_CTL"/find-fail-*
printf '| 3 | silver-feature | wf | Pass | g | a |\n| 4 | silver-bugfix | wf | pass | g | a |\n' >"$SB_E2E_LEDGER_FILE"
echo "log" >"$R/.e2e-row3-attempt.log"
echo "log" >"$R/.e2e-row4-attempt.log"
rm -rf "$WF"
run env SB_E2E_MATRIX_DRY_RUN=1 bash "$MATRIX" 21
assert_contains "dry-run seeds from ledger and logs" "$(cat "$WF/feature-currency.md")" "post-exec-gates"
# attempt-log lookups failing during the pre-seed are tolerated
rm -rf "$WF"
run env SB_E2E_MATRIX_DRY_RUN=1 F2_ATTEMPT_LOG_FAIL_FIRST=2 bash "$MATRIX" 21
assert_eq "failing attempt-log lookup tolerated" "0" "$TL_STATUS"
rm -f "$SB_E2E_LEDGER_FILE"

# blank row argument is ignored
reset
run env SB_E2E_MATRIX_DRY_RUN=1 bash "$MATRIX" "" 99
assert_eq "blank row argument ignored" "0" "$TL_STATUS"
assert_not_contains "blank row runs nothing" "$TL_OUT" "=== Row"

# several matching marker files, listed slowly: the verdict must not depend on grep -q closing the pipe early
reset
touch "$F2_CTL/find-slow"
run bash "$MATRIX" 21 22
assert_eq "slow multi-file marker listing passes" "0" "$TL_STATUS"
assert_contains "row 21 pass with slow listing" "$TL_OUT" "=== Row 21: post-exec-gates (internal) PASS ==="
assert_contains "row 22 pass with slow listing" "$TL_OUT" "=== Row 22: validate-substep (internal) PASS ==="
rm -f "$F2_CTL/find-slow"

tl_results
