#!/usr/bin/env bash
# matrix.sh routing row 1 verdicts, against a staged SB root with a fake agent.
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

# a failing tail is tolerated when scanning the attempt log for routing markers
reset
agent <<'EOS'
:
EOS
tl_stub tail 'exit 1'
run bash "$MATRIX" 1
/bin/rm -f "$TL_BIN/tail"
assert_eq "row 1 with failing tail fails cleanly" "1" "$TL_STATUS"
assert_contains "row 1 reported as missing routing" "$TL_OUT" "FAIL: no routing markers in session output"

# evidence given as a directory counts as present
reset
agent <<'EOS'
mkdir -p "$WORK_DIR/docs/ADR-001-runtime.md"
EOS
run bash "$MATRIX" 2
assert_eq "directory evidence accepted" "0" "$TL_STATUS"

tl_results
