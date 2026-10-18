#!/usr/bin/env bash
# Behaviour tests for the tri-criteria scorers (multiwf, dynamic, newwf), forensics, the criterion
# dispatcher, the workflow/session/round assessors, the checklist writer and the structural wiring
# check of scripts/lib/enterprise-e2e-outcome-assessment.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f3-helpers.sh"

NOJQ="$(tl_path_without jq)"
c=0
newcase() {
  c=$((c + 1))
  W="$TL_TMP/c$c/work"
  S="$TL_TMP/c$c/state"
  L="$TL_TMP/c$c/row.log"
  mkdir -p "$W/.planning" "$S"
}
score() {
  local name="$1" want="$2" fn="$3"
  shift 3
  local args=() envs=()
  while (($#)) && [[ "$1" != "--" ]]; do
    args+=("$1")
    shift
  done
  [[ "${1:-}" != "--" ]] || shift
  envs=("$@")
  oa ${envs[@]+"${envs[@]}"} -- "enterprise_e2e_outcome_$fn" ${args[@]+"${args[@]}"}
  assert_eq "$name" "$want" "$TL_OUT"
}

# --- event log path ---------------------------------------------------------
newcase
RUN="$TL_TMP/c$c/run"
mkdir -p "$RUN"
score "event log: state dir" "$S/orchestrator-events.jsonl" event_log_path "$S"
score "event log: run dir without an events file" "$S/orchestrator-events.jsonl" event_log_path "$S" -- "SB_TRI_CRITERIA_RUN_DIR=$RUN"
echo '{}' >"$RUN/orchestrator-events.jsonl"
score "event log: run dir events file wins" "$RUN/orchestrator-events.jsonl" event_log_path "$S" -- "SB_TRI_CRITERIA_RUN_DIR=$RUN"
score "event log: default state dir is SB_RUNTIME_STATE_DIR" "$TL_TMP/rt/orchestrator-events.jsonl" event_log_path -- "SB_RUNTIME_STATE_DIR=$TL_TMP/rt"
score "event log: default state dir falls back to /tmp" "/tmp/orchestrator-events.jsonl" event_log_path

# --- distinct workflow ids --------------------------------------------------
newcase
RUN="$TL_TMP/c$c/run"
mkdir -p "$RUN"
cat >"$W/.planning/orchestrator-composition-log.jsonl" <<'JL'
{"selected_workflow":"WF-A","composer":"silver-feature"}
{"workflow_id":"run-1-silver-bugfix"}
{"composer":"silver-research"}
{"composer":"silver-foo-bar"}
{"composer":"sb:feature"}
{"composer":"other"}
{"composer":""}
{"composer":5}
{"operations":[{"target_ref":"WF-OPS"},{"target_ref":"x"},{}]}
{"payload":{"workflow_id":"WF-PAY","selected_workflow":"WF-PAY2","next_flow":"WF-PAY3","instance_workflow_id":"x-silver-ui"}}
{"workflow_id":5,"selected_workflow":" "}
{"payload":{"instance_workflow_id":5}}
not json at all

JL
cat >"$S/orchestrator.json" <<'JS'
{"workflow_id":"WF-S1","selected_workflow":"WF-S2","completed_flows":["WF-S3","bad",7],"flow_queue":["WF-S4"]}
JS
printf '%s\n' '{"payload":{"workflow_id":"WF-E1"}}' 'oops' '' >"$S/orchestrator-events.jsonl"
echo '{"selected_workflow":"WF-X1"}' >"$RUN/composition_log.jsonl"
count() { oa "$@" -- enterprise_e2e_outcome_count_distinct_workflow_ids "$W" "$S"; }
count
# A, FEATURE(dup via composer), BUGFIX, DEEP-RESEARCH, FOO-BAR, OPS, PAY, PAY2, PAY3, UI, S1..S4, E1 = 15 (sb:feature adds nothing new)
assert_eq "distinct ids: composition log + state + events" "15" "$TL_OUT"
count "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "distinct ids: run-dir composition log adds one" "16" "$TL_OUT"
echo 'not json' >"$S/orchestrator.json"
count
assert_eq "distinct ids: unparsable state file is ignored" "11" "$TL_OUT"
rm "$S/orchestrator.json"
count
assert_eq "distinct ids: no state file" "11" "$TL_OUT"
echo '{"completed_flows":"WF-STR","flow_queue":{"a":"WF-OBJ"}}' >"$S/orchestrator.json"
count
assert_eq "distinct ids: non-list flow keys ignored" "11" "$TL_OUT"
count "PATH=$NOJQ"
assert_eq "distinct ids: no jq reports zero" "0" "$TL_OUT"
newcase
count
assert_eq "distinct ids: nothing recorded" "0" "$TL_OUT"
mkdir -p "$W/.planning"
echo '{"composer":"silver-ship"}' >"$W/.planning/orchestrator-composition-log.jsonl"
count
assert_eq "distinct ids: composer silver-ship" "1" "$TL_OUT"
oa -- enterprise_e2e_outcome_count_distinct_workflow_ids "$W"
assert_eq "distinct ids: state dir defaults when omitted" "1" "$TL_OUT"

# --- score_multiwf ----------------------------------------------------------
newcase
mw() { oa "$@" -- enterprise_e2e_outcome_score_multiwf "$W" "$S" "$L"; }
mw
assert_eq "multiwf: nothing" "fail" "$TL_OUT"
printf '%s\n' '{"selected_workflow":"WF-1"}' '{"selected_workflow":"WF-2"}' >"$W/.planning/orchestrator-composition-log.jsonl"
mw
assert_eq "multiwf: two ids, no advances" "fail" "$TL_OUT"
printf '%s\n' '{"type":"advance"}' '{"type":"advance"}' '{"type":"dispatch"}' >"$S/orchestrator-events.jsonl"
mw
assert_eq "multiwf: two ids + advances, but nothing in the log marks a chain" "fail" "$TL_OUT"
oa_log "$L" "ran a multi-workflow chain"
mw
assert_eq "multiwf: two ids + two advances + chain wording" "partial" "$TL_OUT"
printf '%s\n' '{"type":"advance"}' >"$S/orchestrator-events.jsonl"
mw
assert_eq "multiwf: one advance is not enough" "fail" "$TL_OUT"
printf '%s\n' '{"selected_workflow":"WF-1"}' '{"selected_workflow":"WF-2"}' '{"selected_workflow":"WF-3"}' >"$W/.planning/orchestrator-composition-log.jsonl"
mw
assert_eq "multiwf: three ids" "pass" "$TL_OUT"
mw "SB_TRI_CRITERIA_MIN_WORKFLOW_IDS=4"
assert_eq "multiwf: minimum raised to four" "fail" "$TL_OUT"
mw "SB_TRI_CRITERIA_MIN_WORKFLOW_IDS=2"
assert_eq "multiwf: minimum lowered to two" "pass" "$TL_OUT"
mw "PATH=$NOJQ"
assert_eq "multiwf: without jq the count is zero" "fail" "$TL_OUT"
rm "$S/orchestrator-events.jsonl"
oa_log "$L" "WF-SILVER-FEATURE multi workflow"
printf '%s\n' '{"selected_workflow":"WF-1"}' '{"selected_workflow":"WF-2"}' >"$W/.planning/orchestrator-composition-log.jsonl"
mw
assert_eq "multiwf: no events file" "fail" "$TL_OUT"

# --- score_dynamic ----------------------------------------------------------
newcase
APO="$OA_ROOT/docs/apo-catalog.json"
mkdir -p "$OA_ROOT/docs"
echo '{"dynamic_rules":[{"id":"DR-1"},{"id":"DR-2"}]}' >"$APO"
dyn() { oa "$@" -- enterprise_e2e_outcome_score_dynamic "$W" "$S" "${DYN_LOG-$L}"; }
CL="$W/.planning/orchestrator-composition-log.jsonl"
DYN_LOG="" dyn
assert_eq "dynamic: no composition log" "fail" "$TL_OUT"
printf '%s\n' '{"operations":[{"op":"insert","catalog_rule_ref":"DR-1","rationale":"why"},{"op":"prune","catalog_rule_ref":"DR-2","rationale":"why"}]}' >"$CL"
dyn
assert_eq "dynamic: two valid distinct ops with known rules" "pass" "$TL_OUT"
printf '%s\n' '{"operations":[{"op":"insert","catalog_rule_ref":"DR-1","rationale":"why"},{"op":"insert","catalog_rule_ref":"DR-2","rationale":"why"}]}' >"$CL"
dyn
assert_eq "dynamic: ops all the same kind" "partial" "$TL_OUT"
printf '%s\n' '{"operations":[{"op":"insert","catalog_rule_ref":"DR-1","rationale":"why"},{"op":"prune","catalog_rule_ref":"DR-9","rationale":"why"}]}' >"$CL"
dyn
assert_eq "dynamic: an op references a rule that is not in the catalog" "partial" "$TL_OUT"
printf '%s\n' '{"operations":[{"op":"insert","catalog_rule_ref":"DR-1","rationale":""},{"op":"prune","catalog_rule_ref":"DR-2"}]}' >"$CL"
dyn
assert_eq "dynamic: ops without rationale are not valid" "fail" "$TL_OUT"
oa_log "$L" "applied DR-PRUNE"
dyn
assert_eq "dynamic: no valid ops but the log mentions a dynamic rule" "partial" "$TL_OUT"
oa_log "$L" "dynamic composition happened"
dyn
assert_eq "dynamic: log says dynamic composition" "partial" "$TL_OUT"
oa_log "$L" "nothing"
dyn
assert_eq "dynamic: no valid ops, nothing in the log" "fail" "$TL_OUT"
DYN_LOG="" dyn
assert_eq "dynamic: invalid ops, no log" "fail" "$TL_OUT"
printf '%s\n' '{"operations":[{"op":"insert","catalog_rule_ref":"DR-1","rationale":"why"},{"op":"prune","catalog_rule_ref":"DR-2","rationale":"why"}]}' >"$CL"
echo 'not json' >"$APO"
dyn
assert_eq "dynamic: unreadable catalog counts as bad references" "partial" "$TL_OUT"
rm "$APO"
dyn
assert_eq "dynamic: no catalog file means references are not checked" "pass" "$TL_OUT"
echo '{"dynamic_rules":[{"id":"DR-1"},{"id":"DR-2"}]}' >"$APO"
echo 'not json' >"$CL"
dyn
assert_eq "dynamic: unparsable composition log" "fail" "$TL_OUT"
printf '%s\n' '{"operations":[{"op":"insert","catalog_rule_ref":"DR-1","rationale":"why"},{"op":"prune","catalog_rule_ref":"DR-2","rationale":"why"}]}' >"$CL"
oa_log "$L" "DR-INSERT mentioned"
dyn "PATH=$NOJQ"
assert_eq "dynamic: without jq only the log wording counts" "partial" "$TL_OUT"
oa_log "$L" "nothing"
dyn "PATH=$NOJQ"
assert_eq "dynamic: without jq and without wording" "fail" "$TL_OUT"
# run-dir composition logs are used when present
RUN="$TL_TMP/c$c/run"
mkdir -p "$RUN"
rm "$CL"
printf '%s\n' '{"operations":[{"op":"insert","catalog_rule_ref":"DR-1","rationale":"why"},{"op":"prune","catalog_rule_ref":"DR-2","rationale":"why"}]}' >"$RUN/orchestrator-composition-log.jsonl"
dyn "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "dynamic: composition log from the run dir" "pass" "$TL_OUT"
rm "$APO"

# --- score_newwf ------------------------------------------------------------
newcase
nw() { oa "$@" -- enterprise_e2e_outcome_score_newwf "$W" "$S" "${NW_LOG-$L}"; }
NW_LOG="" nw
assert_eq "newwf: nothing" "fail" "$TL_OUT"
oa_log "$L" "ran silver-new-workflow"
nw
assert_eq "newwf: worker via the log, no artifact" "partial" "$TL_OUT"
for m in "NEW-WORKFLOW" "net new workflow" "net-new-workflow"; do
  oa_log "$L" "worker: $m"
  nw
  assert_eq "newwf: log wording '$m'" "partial" "$TL_OUT"
done
oa_log "$L" "unrelated"
NW_LOG="$L" nw
assert_eq "newwf: unrelated log" "fail" "$TL_OUT"
echo '{"workflow":"NEW-WORKFLOW"}' >"$S/orchestrator.json"
nw
assert_eq "newwf: worker via orchestrator.json" "partial" "$TL_OUT"
rm "$S/orchestrator.json"
echo '{"workflow":"silver-new-workflow"}' >"$S/orchestrator.json"
nw
assert_eq "newwf: worker via orchestrator.json (skill name)" "partial" "$TL_OUT"
rm "$S/orchestrator.json"
# JSONL event stream
printf '%s\n' '{"type":"advance"}' '{"type":"dispatch","payload":{"worker_template":"NEW-WORKFLOW"}}' >"$S/orchestrator-events.jsonl"
nw
assert_eq "newwf: dispatch event (worker_template) in a JSONL event stream" "partial" "$TL_OUT"
printf '%s\n' '{"type":"dispatch","payload":{"skill":"silver-new-workflow"}}' >"$S/orchestrator-events.jsonl"
nw
assert_eq "newwf: dispatch event (skill) in a JSONL event stream" "partial" "$TL_OUT"
printf '%s\n' '{"type":"dispatch","payload":{"skill":"silver-feature"}}' '{"type":"advance"}' >"$S/orchestrator-events.jsonl"
nw
assert_eq "newwf: dispatch of another skill is not the new-workflow worker" "fail" "$TL_OUT"
printf '%s\n' '{"type":"dispatch","payload":{"worker_template":"NEW-WORKFLOW"}}' >"$S/orchestrator-events.jsonl"
nw "PATH=$NOJQ"
assert_eq "newwf: without jq events cannot be read" "fail" "$TL_OUT"
rm "$S/orchestrator-events.jsonl"
# artifacts
mkdir -p "$W/.planning/workflows"
echo "plain" >"$W/.planning/workflows/a.md"
nw
assert_eq "newwf: workflow notes without markers" "fail" "$TL_OUT"
echo "a compliance snapshot" >"$W/.planning/workflows/a.md"
nw
assert_eq "newwf: artifact only (compliance snapshot note)" "partial" "$TL_OUT"
echo "Flow Log" >"$W/.planning/workflows/a.md"
nw
assert_eq "newwf: artifact only (Flow Log)" "partial" "$TL_OUT"
oa_log "$L" "ran silver-new-workflow"
nw
assert_eq "newwf: worker + artifact" "pass" "$TL_OUT"
rm "$W/.planning/workflows/a.md"
mkdir -p "$W/docs/apo-catalog.d"
nw
assert_eq "newwf: empty catalog fragment dir is no artifact" "partial" "$TL_OUT"
echo '{}' >"$W/docs/apo-catalog.d/new.json"
nw
assert_eq "newwf: catalog fragment + worker" "pass" "$TL_OUT"
rm "$W/docs/apo-catalog.d/new.json"
mkdir -p "$W/.planning/compliance" "$W/scripts"
: >"$W/.planning/compliance/c.md"
nw
assert_eq "newwf: compliance doc without script" "partial" "$TL_OUT"
: >"$W/scripts/run-compliance.sh"
nw
assert_eq "newwf: compliance doc + script + worker" "pass" "$TL_OUT"
oa -- enterprise_e2e_outcome_score_newwf "$W"
assert_eq "newwf: defaults for the state dir and log" "partial" "$TL_OUT"

# --- score_forens -----------------------------------------------------------
newcase
for r in 1 3 18 20 "" abc; do
  score "forens: row '$r' not applicable" n/a score_forens "$W" "$r"
done
score "forens/19: nothing" fail score_forens "$W" 19
mkdir -p "$W/docs/forensics"
echo "notes" >"$W/docs/forensics/CI-001.md"
score "forens/19: report without root cause" partial score_forens "$W" 19
echo "Root Cause: flaky" >"$W/docs/forensics/CI-001.md"
score "forens/19: root cause" pass score_forens "$W" 19
echo "Timeline" >"$W/docs/forensics/CI-001.md"
score "forens/19: timeline" pass score_forens "$W" 19

# --- criterion dispatcher (scorers stubbed to echo their arguments) ----------
STUBS=""
for fn in tailor vloop gates trace intent km orch plan skill review blast hook complete handoff codeint flow measure decide forens auto clarify noop world drift super heal release multiwf dynamic newwf; do
  STUBS+="enterprise_e2e_outcome_score_$fn() { echo \"$fn|\$*\"; }; "
done
disp() { # CID ; expected output
  oa_sh "$STUBS enterprise_e2e_outcome_score_criterion $1 WORK STATE LOG ROW LEDGER EVID" "${@:3}"
  assert_eq "dispatch: $1" "$2" "$TL_OUT"
}
disp OUT-TAILOR-01 "tailor|WORK STATE LOG ROW"
disp OUT-VLOOP-01 "vloop|WORK"
disp OUT-GATES-01 "gates|WORK ROW"
disp OUT-TRACE-01 "trace|WORK"
disp OUT-INTENT-01 "intent|WORK EVID ROW STATE"
disp OUT-KM-01 "km|LEDGER ROW LOG WORK"
disp OUT-ORCH-01 "orch|STATE LOG ROW WORK EVID"
disp OUT-PLAN-01 "plan|WORK"
disp OUT-SKILL-01 "skill|STATE LOG ROW WORK EVID"
disp OUT-REVIEW-01 "review|LEDGER ROW LOG WORK"
disp OUT-REVIEW-01 "review|OTHERLEDGER ROW LOG WORK" "SB_E2E_REVIEW_LADDER_LEDGER=OTHERLEDGER"
disp OUT-BLAST-01 "blast|WORK ROW"
disp OUT-HOOK-01 "hook|$OA_ROOT ROW LOG"
disp OUT-COMPLETE-01 "complete|WORK ROW"
disp OUT-HANDOFF-01 "handoff|STATE ROW LOG WORK"
disp OUT-CODEINT-01 "codeint|WORK LOG ROW LEDGER"
disp OUT-FLOW-01 "flow|WORK"
disp OUT-MEASURE-01 "measure|LEDGER $OA_ROOT"
disp OUT-DECIDE-01 "decide|WORK"
disp OUT-FORENS-01 "forens|WORK ROW"
disp OUT-AUTO-01 "auto|WORK STATE LOG EVID ROW"
disp OUT-CLARIFY-01 "clarify|WORK STATE LOG ROW"
disp OUT-NOOP-01 "noop|WORK LOG"
disp OUT-WORLD-01 "world|ROW WORK STATE LOG LEDGER EVID"
disp OUT-DRIFT-01 "drift|WORK LOG ROW"
disp OUT-SUPER-01 "super|STATE LOG ROW"
disp OUT-HEAL-01 "heal|$OA_ROOT LOG ROW"
disp OUT-RELEASE-01 "release|WORK ROW LEDGER"
disp OUT-MULTIWF-01 "multiwf|WORK STATE LOG"
disp OUT-DYNAMIC-01 "dynamic|WORK STATE LOG"
disp OUT-NEWWF-01 "newwf|WORK STATE LOG"
disp OUT-UNKNOWN-99 "n/a"
oa -- enterprise_e2e_outcome_score_criterion OUT-PLAN-01 "$TL_TMP/nowork" "$S"
assert_eq "dispatch: real scorer with only the required args" "fail" "$TL_OUT"

# --- assess workflow row / session / round ---------------------------------
REG="$TL_TMP/registry-assess.json"
oa_registry "$REG" '{"criteria":[],"workflow_row_map":{"3":["OUT-PLAN-01","","OUT-VLOOP-01"]},"session_criteria":["OUT-DECIDE-01","","OUT-PLAN-01"]}'
RENV="SB_E2E_OUTCOME_REGISTRY=$REG"
newcase
: >"$W/.planning/PLAN-1.md"
oa "$RENV" -- enterprise_e2e_outcome_assess_workflow_row 3 "$W" "$S" "" "" ""
assert_eq "assess row: one line per criterion, blanks skipped" "OUT-PLAN-01 pass
OUT-VLOOP-01 fail" "$TL_OUT"
oa "$RENV" -- enterprise_e2e_outcome_assess_workflow_row 99 "$W" "$S"
assert_eq "assess row: unmapped row prints nothing" "" "$TL_OUT"
oa "$RENV" -- enterprise_e2e_outcome_assess_session "$L" "$S" "$W" "" 3
assert_eq "assess session: session criteria only" "OUT-DECIDE-01 n/a
OUT-PLAN-01 pass" "$TL_OUT"
oa "$RENV" -- enterprise_e2e_outcome_assess_session "$L" "$S"
assert_eq "assess session: optional args default" "OUT-DECIDE-01 n/a
OUT-PLAN-01 fail" "$TL_OUT"

RL="$TL_TMP/round-ledger.md"
{
  echo "review-fix-ladder"
  for i in 1 2 3 4 5 6 7 8; do echo "| $i | rung | Pass |"; done
} >"$RL"
oa "SB_TEST_ENTERPRISE_APP_ROOT=$W" -- enterprise_e2e_outcome_assess_round "$RL"
assert_eq "assess round: review ladder, measure, km" "pass
OUT-MEASURE-01 partial
OUT-KM-01 n/a" "$TL_OUT"
oa "SB_TEST_ENTERPRISE_APP_ROOT=$W" -- enterprise_e2e_outcome_assess_round "$TL_TMP/absent-round.md"
assert_eq "assess round: missing ledger" "fail
OUT-MEASURE-01 fail
OUT-KM-01 n/a" "$TL_OUT"
oa -- enterprise_e2e_outcome_assess_round "$RL"
assert_eq "assess round: default work dir (no app root) still scores" "pass
OUT-MEASURE-01 partial
OUT-KM-01 n/a" "$TL_OUT"

# --- checklist writer -------------------------------------------------------
newcase
: >"$W/.planning/PLAN-1.md"
oa_registry "$REG" '{"criteria":[],"workflow_row_map":{"3":["OUT-PLAN-01"]},"session_criteria":["OUT-PLAN-01","","OUT-DECIDE-01"]}'
OUTF="$TL_TMP/c$c/nested/dir/row-3.md"
oa "$RENV" -- enterprise_e2e_outcome_write_workflow_checklist 3 "$OUTF" "$W" "$S" "$L" "" ""
assert_eq "checklist: status" 0 "$TL_STATUS"
assert_eq "checklist: full document" "# Row 3 outcome checklist

| Criterion | Score | Scope |
|-----------|-------|-------|
| OUT-PLAN-01 | pass | workflow |
| OUT-WORLD-01 | pass | composite |

**Row outcome verdict:** PASS (all applicable criteria must pass; partial = fail)

## Session criteria (same session)

| Criterion | Score | Scope |
|-----------|-------|-------|
| OUT-PLAN-01 | pass | session |
| OUT-DECIDE-01 | n/a | session |" "$(cat "$OUTF")"
rm "$W/.planning/PLAN-1.md"
oa "$RENV" -- enterprise_e2e_outcome_write_workflow_checklist 3 "$OUTF" "$W" "$S" "$L" "" ""
assert_contains "checklist: failing criterion" "$(cat "$OUTF")" "| OUT-PLAN-01 | fail | workflow |"
assert_contains "checklist: failing world" "$(cat "$OUTF")" "| OUT-WORLD-01 | fail | composite |"
assert_contains "checklist: FAIL verdict" "$(cat "$OUTF")" "**Row outcome verdict:** FAIL"
# defaults: work dir from SB_TEST_ENTERPRISE_APP_ROOT, state dir from SB_RUNTIME_STATE_DIR
: >"$W/.planning/PLAN-1.md"
OUTF2="$TL_TMP/c$c/default.md"
oa "$RENV" "SB_TEST_ENTERPRISE_APP_ROOT=$W" "SB_RUNTIME_STATE_DIR=$S" -- enterprise_e2e_outcome_write_workflow_checklist 3 "$OUTF2"
assert_contains "checklist: defaulted work dir is used" "$(cat "$OUTF2")" "**Row outcome verdict:** PASS"
oa "$RENV" "SB_TEST_ENTERPRISE_APP_ROOT=$W" -- enterprise_e2e_outcome_write_workflow_checklist 3 "$OUTF2" "" "" "" "" ""
assert_contains "checklist: empty state dir falls back" "$(cat "$OUTF2")" "| OUT-PLAN-01 | pass | workflow |"

# --- structural wiring ------------------------------------------------------
FRESH="$TL_TMP/wiring-root"
mkdir -p "$FRESH"
oa_sh_wiring() { e2e_script "source '$OA_LIB'; if enterprise_e2e_outcome_assess_structural_wiring; then echo WIRING_OK; else echo WIRING_FAIL; fi" "${OA_BASE_ENV[@]}" "$@"; }
oa_sh_wiring "SB_ROOT=$FRESH" "PATH=$NOJQ"
assert_contains "wiring: empty root reports a missing rubric" "$TL_OUT" "MISSING: $FRESH/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md"
assert_contains "wiring: empty root reports a missing registry" "$TL_OUT" "MISSING: $FRESH/docs/testing/outcome-criteria-registry.json"
assert_contains "wiring: empty root reports the missing lib" "$TL_OUT" "MISSING: $FRESH/scripts/lib/enterprise-e2e-outcome-assessment.sh"
assert_contains "wiring: empty root reports the missing test" "$TL_OUT" "MISSING: $FRESH/tests/scripts/test-outcome-assessment.sh"
assert_contains "wiring: empty root reports the missing outcomes doc" "$TL_OUT" "MISSING: $FRESH/.planning/enterprise-e2e/ROUND-N-OUTCOMES.md"
assert_contains "wiring: failure verdict" "$TL_OUT" "WIRING_FAIL"
GOOD="$TL_TMP/wiring-good"
mkdir -p "$GOOD/.planning/enterprise-e2e" "$GOOD/docs/testing" "$GOOD/scripts/lib" "$GOOD/tests/scripts"
: >"$GOOD/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md"
: >"$GOOD/.planning/enterprise-e2e/ROUND-N-OUTCOMES.md"
: >"$GOOD/scripts/lib/enterprise-e2e-outcome-assessment.sh"
: >"$GOOD/tests/scripts/test-outcome-assessment.sh"
jq -n '{criteria: [range(27) | {id: "C\(.)"}]}' >"$GOOD/docs/testing/outcome-criteria-registry.json"
oa_sh_wiring "SB_ROOT=$GOOD"
assert_eq "wiring: complete root" "WIRING_OK" "$TL_OUT"
jq -n '{criteria: [range(26) | {id: "C\(.)"}]}' >"$GOOD/docs/testing/outcome-criteria-registry.json"
oa_sh_wiring "SB_ROOT=$GOOD"
assert_contains "wiring: 26 criteria is too few" "$TL_OUT" "CRITERIA_COUNT: expected >=27 got 26"
assert_contains "wiring: too few criteria fails" "$TL_OUT" "WIRING_FAIL"
oa_sh_wiring "SB_ROOT=$GOOD" "PATH=$NOJQ"
assert_eq "wiring: without jq the count is not checked" "WIRING_OK" "$TL_OUT"

# --- executing the library directly ----------------------------------------
tl_run bash "$OA_LIB"
assert_eq "direct execution: refused with status 2" 2 "$TL_STATUS"
assert_contains "direct execution: explains how to use it" "$TL_ERR" "Source this library"
assert_eq "direct execution: no stdout" "" "$TL_OUT"

tl_results
