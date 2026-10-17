#!/usr/bin/env bash
# matrix.sh routing row 1, fixture/product gates, tolerated collaborator failures and degraded
# environments, against a staged SB root with a fake agent.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

queue_file="$SB_RUNTIME_STATE_DIR/orchestrator.json"
marker_file="$SB_RUNTIME_STATE_DIR/e2e-matrix-routing-row"
EVID1="$APP/.planning/workflows/router-session.md"
row1_prompt_expected() {
  printf '%s %s' "$(matrix_router_workflow_prompt silver-router 'I need to add order validation to the API — route me.' .planning/workflows/router-session.md /sb)" "$(matrix_row1_evidence_clause)"
}

# ------------------------------------------------------------ row 1 (routing-only)
reset
echo '{"current_flow":"FLOW-EXECUTE"}' >"$queue_file"
agent <<'EOS'
echo silver-feature >>"$(enterprise_e2e_runtime_state_dir)/state"
EOS
run env SB_E2E_TEST_APP_BRANCH=row1-branch bash "$MATRIX" 1
assert_eq "row 1 passes on routing state delta" "0" "$TL_STATUS"
assert_contains "row 1 evidence written by the harness" "$(cat "$EVID1")" "# Router session evidence (matrix row 1 — routing-only)"
assert_contains "row 1 evidence lists recorded skills" "$(cat "$EVID1")" "- silver-feature"
assert_contains "row 1 pass message" "$TL_OUT" "  PASS: evidence at .planning/workflows/router-session.md"
assert_file_absent "routing row marker cleared after pass" "$marker_file"
assert_file_absent "orchestrator queue quiesced after pass" "$queue_file"
assert_eq "row 1 prompt is the router prompt plus evidence clause" "prompt#1 $(SB_E2E_TEST_APP_BRANCH=row1-branch row1_prompt_expected)" "$(grep '^prompt#1 ' <<<"$CALLS")"

# marker visible to the agent while the row runs; routing marker in the output
reset
agent <<'EOS'
[[ -f "$(enterprise_e2e_runtime_state_dir)/e2e-matrix-routing-row" ]] && echo "MARKER-PRESENT-DURING-ROW" >>"$F2_CALLS"
echo "SILVER BULLET ▸ ROUTING silver-feature"
EOS
run bash "$MATRIX" 1
assert_eq "row 1 passes on routing output marker" "0" "$TL_STATUS"
assert_contains "routing marker file exists during the row" "$CALLS" "MARKER-PRESENT-DURING-ROW"
assert_file_exists "evidence written after output-marker pass" "$EVID1"
assert_file_absent "marker cleared after pass" "$marker_file"

# state already holds a routing skill before the row: the delta is empty but the state counts (FORCE skips the pre-check)
reset
mkdir -p "$SB_RUNTIME_STATE_DIR"
echo silver-quality-gates >"$STATE"
agent <<'EOS'
echo "no markers here"
EOS
run env SB_E2E_MATRIX_FORCE=1 bash "$MATRIX" 1
assert_eq "row 1 passes when state already has routing skills" "0" "$TL_STATUS"
assert_contains "pass via present state" "$TL_OUT" "  PASS: evidence at .planning/workflows/router-session.md"

# routing marker only in the attempt log (agent printed nothing)
reset
agent <<'EOS'
echo "Skill(silver-bullet:silver-fast) invoked" >>"$CLAUDE_INTERACTIVE_LOG_FILE"
EOS
run env SB_E2E_MATRIX_FORCE=1 bash "$MATRIX" 1
assert_eq "row 1 passes on routing marker in the attempt log" "0" "$TL_STATUS"
assert_file_exists "evidence written for log-only marker" "$EVID1"

# pre-existing routing state skips the row without FORCE
reset
echo silver-feature >"$STATE"
run bash "$MATRIX" 1
assert_contains "row 1 skipped when routing state already present" "$TL_OUT" "  SKIP: evidence already present"
assert_not_contains "agent not started for skipped row 1" "$CALLS" "prompt#"

# nothing recorded: the row fails and the harness cleans up
reset
echo '{"current_flow":"FLOW-EXECUTE"}' >"$queue_file"
agent <<'EOS'
echo "nothing useful"
EOS
run bash "$MATRIX" 1
assert_eq "row 1 without routing fails" "1" "$TL_STATUS"
assert_contains "row 1 missing evidence" "$TL_OUT" "  FAIL: missing evidence at .planning/workflows/router-session.md"
assert_contains "row 1 routing failure message" "$TL_OUT" "  FAIL: no routing markers in session output or $STATE"
assert_file_absent "marker cleared after failure" "$marker_file"
assert_file_absent "queue quiesced after failure" "$queue_file"
assert_file_absent "no evidence written on failure" "$EVID1"

# comm failing is tolerated and counts as no new skills
reset
agent <<'EOS'
echo "nothing useful"
EOS
tl_stub comm 'exit 2'
run bash "$MATRIX" 1
/bin/rm -f "$TL_BIN/comm"
assert_eq "row 1 with failing comm fails cleanly" "1" "$TL_STATUS"

# evidence given as a directory counts as present
reset
agent <<'EOS'
mkdir -p "$WORK_DIR/docs/ADR-001-runtime.md"
EOS
run bash "$MATRIX" 2
assert_eq "directory evidence accepted" "0" "$TL_STATUS"

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

# ------------------------------------------------------------ optional collaborators
reset
evidence_agent
tl_stub graphify 'printf "graphify %s cwd=%s\n" "$*" "$PWD" >>"$F2_CALLS"; exit 1'
run bash "$MATRIX" 2
/bin/rm -f "$TL_BIN/graphify"
assert_eq "failing graphify query tolerated" "0" "$TL_STATUS"
assert_contains "graphify queried from the SB root" "$CALLS" "graphify query silver-deep-research routes hooks skills orchestrator cwd=$R"

reset
evidence_agent
run env F2_CHECKLIST_FAIL=1 bash "$MATRIX" 2
assert_eq "failing checklist writer tolerated" "0" "$TL_STATUS"

reset
evidence_agent
mkdir -p "$SB_RUNTIME_STATE_DIR/state"
run bash "$MATRIX" 2
assert_eq "unwritable routing state file tolerated" "0" "$TL_STATUS"
rmdir "$SB_RUNTIME_STATE_DIR/state"

reset
evidence_agent
: >"$TL_TMP/blocker"
run env SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/state" bash "$MATRIX" 2
assert_eq "uncreatable routing state dir tolerated" "0" "$TL_STATUS"

# codex adapter failing before a row is tolerated
reset
evidence_agent
run env SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex F2_ENSURE_FAIL_AT=3 bash "$MATRIX" 2
assert_eq "codex adapter failure tolerated" "0" "$TL_STATUS"
assert_contains "agent still launched" "$CALLS" "prompt#1"

# unavailable agent CLI is reported, not fatal
reset
evidence_agent
run env F2_AGENT_MISSING=1 bash "$MATRIX" 2
assert_contains "missing agent shown" "$TL_OUT" "Agent:      missing"

# skips with failing telemetry
reset
evidence_agent
bash "$MATRIX" 2 >/dev/null 2>&1 || true
run env F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_contains "install-pass skip with failing telemetry" "$TL_OUT" "ROW_ALREADY_PASSED_SAME_INSTALL"
rm -f "$REG"
run env F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_contains "evidence skip with failing telemetry" "$TL_OUT" "SKIP: evidence already present"

tl_results
