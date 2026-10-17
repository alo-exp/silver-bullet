#!/usr/bin/env bash
# matrix.sh prompt composition per row/host/gate, host environment defaults seen by the agent, and
# the internal rows 21/22 verdicts, against a staged SB root with a fake agent.
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

# ----------------------------------------------------- host environment seen by the agent
reset
agent <<'EOS'
printf 'hostenv headless=%s cursor_id=%s cursor_agent=%s vscode=%s cred=%s anthropic=%s openai=%s\n' \
  "${SB_LIVE_CURSOR_FORCE_HEADLESS-unset}" "${CURSOR_CONVERSATION_ID-unset}" "${CURSOR_AGENT-unset}" \
  "${VSCODE_IPC_HOOK-unset}" "${AGENT_CLI_CREDENTIAL_STORE-unset}" "${ANTHROPIC_API_KEY-unset}" "${OPENAI_API_KEY-unset}" >>"$F2_CALLS"
EOS
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 \
  CURSOR_CONVERSATION_ID=c1 CURSOR_AGENT=a1 VSCODE_IPC_HOOK=h1 AGENT_CLI_CREDENTIAL_STORE=s1 bash "$MATRIX" 2
assert_contains "cursor strips host session variables and forces headless" "$CALLS" "hostenv headless=1 cursor_id=unset cursor_agent=unset vscode=unset cred=unset"
assert_contains "cursor raises the interactive timeout floor" "$CALLS" "timeout=1800 cursor_timeout=1800"
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 CLAUDE_INTERACTIVE_TIMEOUT=900 bash "$MATRIX" 2
assert_contains "cursor lifts a legacy 900s timeout" "$CALLS" "timeout=1800 cursor_timeout=1800"
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 CLAUDE_INTERACTIVE_TIMEOUT=3600 CURSOR_AGENT_TIMEOUT=4000 bash "$MATRIX" 2
assert_contains "cursor keeps a larger interactive timeout" "$CALLS" "timeout=3600 cursor_timeout=3600"
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 CLAUDE_INTERACTIVE_TIMEOUT=3600 CURSOR_AGENT_TIMEOUT=1000 bash "$MATRIX" 2
assert_contains "cursor lifts a short agent timeout to the interactive timeout" "$CALLS" "timeout=3600 cursor_timeout=3600"

run env SB_E2E_MATRIX_CLEAN_ENV=1 ANTHROPIC_API_KEY=a OPENAI_API_KEY=o bash "$MATRIX" 2
assert_contains "clean-env mode strips conflicting API keys" "$CALLS" "anthropic=unset openai=unset"
run env ANTHROPIC_API_KEY=a OPENAI_API_KEY=o bash "$MATRIX" 2
assert_contains "default mode inherits the shell keys" "$CALLS" "anthropic=a openai=o"

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

tl_results
