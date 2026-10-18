#!/usr/bin/env bash
# Behaviour tests for the artifact-oriented criterion scorers of
# scripts/lib/enterprise-e2e-outcome-assessment.sh: world/row verdict aggregation, tailor, vloop,
# gates, trace, intent, km (knowledge management) and orch.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f3-helpers.sh"

c=0
newcase() {
  c=$((c + 1))
  W="$TL_TMP/c$c/work"
  S="$TL_TMP/c$c/state"
  L="$TL_TMP/c$c/row.log"
  mkdir -p "$W" "$S"
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
MATRIX="SB_E2E_ENTERPRISE_MATRIX=1"

# --- world / row_passes / row_failures -------------------------------------
REG="$TL_TMP/registry.json"
oa_registry "$REG" '{"criteria":[],"workflow_row_map":{"3":["OUT-PLAN-01"],"4":["OUT-PLAN-01","OUT-VLOOP-01"]},"session_criteria":["OUT-DECIDE-01"]}'
REGENV="SB_E2E_OUTCOME_REGISTRY=$REG"
newcase
mkdir -p "$W/.planning"; : >"$W/.planning/PLAN-1.md"
score "world: row criterion passes, session criterion n/a" pass score_world 3 "$W" "$S" "" "" "" -- "$REGENV"
oa "$REGENV" -- enterprise_e2e_outcome_row_failures 3 "$W" "$S" "" "" ""
assert_eq "row_failures: no output when everything passes" "" "$TL_OUT"
oa "$REGENV" -- enterprise_e2e_outcome_row_passes 3 "$W" "$S" "" "" ""
assert_eq "row_passes (registry): passes" 0 "$TL_STATUS"
# row criterion that is only partial
score "world: a partial row criterion fails the world" fail score_world 4 "$W" "$S" "" "" "" -- "$REGENV"
oa "$REGENV" -- enterprise_e2e_outcome_row_passes 4 "$W" "$S" "" "" ""
assert_eq "row_passes: failing row criterion" 1 "$TL_STATUS"
oa "$REGENV" -- enterprise_e2e_outcome_row_failures 4 "$W" "$S" "" "" ""
assert_eq "row_failures: failing criterion + world listed" "OUT-VLOOP-01 fail
OUT-WORLD-01 fail" "$TL_OUT"
# session criterion failing
newcase
mkdir -p "$W/.planning"; : >"$W/.planning/PLAN-1.md"
oa_registry "$REG" '{"criteria":[],"workflow_row_map":{"3":["OUT-PLAN-01"]},"session_criteria":["OUT-VLOOP-01"]}'
score "world: failing session criterion" fail score_world 3 "$W" "$S" "" "" "" -- "$REGENV"
oa "$REGENV" -- enterprise_e2e_outcome_row_passes 3 "$W" "$S" "" "" ""
assert_eq "row_passes: failing session criterion" 1 "$TL_STATUS"
oa "$REGENV" -- enterprise_e2e_outcome_row_failures 3 "$W" "$S" "" "" ""
assert_eq "row_failures: session failure + world" "OUT-VLOOP-01 fail
OUT-WORLD-01 fail" "$TL_OUT"
# blank ids in the registry are ignored; n/a and pass are both fine
oa_registry "$REG" '{"criteria":[],"workflow_row_map":{"3":["","OUT-PLAN-01","OUT-BLAST-01"]},"session_criteria":["","OUT-DECIDE-01"]}'
score "world: blank ids skipped; n/a scores ignored" pass score_world 3 "$W" "$S" "" "" "" -- "$REGENV"
oa "$REGENV" -- enterprise_e2e_outcome_row_passes 3 "$W" "$S" "" "" ""
assert_eq "row_passes: blank ids skipped" 0 "$TL_STATUS"
oa "$REGENV" -- enterprise_e2e_outcome_row_failures 3 "$W" "$S" "" "" ""
assert_eq "row_failures: blank ids skipped" "" "$TL_OUT"
# world fails although each listed criterion passes? (world re-scores identically, so only via inconsistent state)

# --- score_tailor -----------------------------------------------------------
newcase
score "tailor/6: nothing" n/a score_tailor "$W" "$S" "$L" 6
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/fast-readme.md"
score "tailor/6: fast-readme.md" pass score_tailor "$W" "$S" "$L" 6
rm "$W/.planning/workflows/fast-readme.md"
: >"$W/.planning/orchestrator-composition-log.jsonl"
score "tailor/6: composition log" pass score_tailor "$W" "$S" "$L" 6
rm "$W/.planning/orchestrator-composition-log.jsonl"
for m in '/sb:fast' silver-fast fast-readme 'catalog workflow'; do
  oa_log "$L" "ran $m"
  score "tailor/6: log mentions $m" pass score_tailor "$W" "$S" "$L" 6
done
oa_log "$L" "nothing"
score "tailor/6: unrelated log" n/a score_tailor "$W" "$S" "$L" 6
newcase
for m in silver-context silver-router silver-feature; do
  echo "$m" >"$S/state"
  score "tailor: state lists $m" pass score_tailor "$W" "$S" "$L" 3
done
newcase
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/router-session.md"
score "tailor: router-session.md" pass score_tailor "$W" "$S" "$L" 3
newcase
oa_log "$L" "SILVER BULLET routing summary"
score "tailor/1: routing banner in the log" pass score_tailor "$W" "$S" "$L" 1
score "tailor/other: routing banner only partial" partial score_tailor "$W" "$S" "$L" 3
oa_log "$L" "silver-context loaded"
score "tailor/other: silver-context in log" partial score_tailor "$W" "$S" "$L" 8
oa_log "$L" "routing validation only"
score "tailor/1: routing validation only" pass score_tailor "$W" "$S" "$L" 1
oa_log "$L" "nothing"
score "tailor/1: nothing -> fail" fail score_tailor "$W" "$S" "$L" 1
score "tailor/other: nothing -> n/a" n/a score_tailor "$W" "$S" "$L" 3
score "tailor/other: no log" n/a score_tailor "$W" "$S" "" 3

# --- score_vloop ------------------------------------------------------------
newcase
score "vloop: nothing" fail score_vloop "$W"
mkdir -p "$W/.planning/workflows"
echo "notes" >"$W/.planning/workflows/a.md"
score "vloop: workflow notes without validation" fail score_vloop "$W"
for m in VALIDATE validate-evidence V-loop; do
  echo "step: $m" >"$W/.planning/workflows/a.md"
  score "vloop: workflow note mentions $m" partial score_vloop "$W"
done
: >"$W/.planning/VALIDATION-1.md"
score "vloop: VALIDATION file" pass score_vloop "$W"

# --- score_gates ------------------------------------------------------------
newcase
score "gates/6" pass score_gates "$W" 6
score "gates: row 3 without evidence" fail score_gates "$W" 3
for r in 5 15 16 21; do
  score "gates: row $r without evidence" fail score_gates "$W" "$r"
done
score "gates: other row without evidence" n/a score_gates "$W" 8
score "gates: no row" n/a score_gates "$W"
mkdir -p "$W/.planning/workflows"
echo "nothing" >"$W/.planning/workflows/feature-currency.md"
score "gates: feature-currency without post-exec-gates" fail score_gates "$W" 3
echo "post-exec-gates ran" >"$W/.planning/workflows/feature-currency.md"
score "gates: feature-currency mentions post-exec-gates" pass score_gates "$W" 3
rm "$W/.planning/workflows/feature-currency.md"
mkdir -p "$W/.planning/ship-readiness"
score "gates: ship-readiness dir" pass score_gates "$W" 3
rmdir "$W/.planning/ship-readiness"
: >"$W/.planning/QUALITY-GATES-1.md"
score "gates: QUALITY-GATES file" pass score_gates "$W" 3

# --- score_trace ------------------------------------------------------------
newcase
score "trace: nothing" fail score_trace "$W"
mkdir -p "$W/.planning" "$W/docs"
: >"$W/.planning/FEATURE-SPEC.md"
score "trace: SPEC without PLAN" fail score_trace "$W"
: >"$W/.planning/PLAN-1.md"
score "trace: SPEC and PLAN" pass score_trace "$W"
rm "$W/.planning/FEATURE-SPEC.md"
score "trace: PLAN only" partial score_trace "$W"
rm "$W/.planning/PLAN-1.md"
: >"$W/docs/instruction-ledger.jsonl"
score "trace: instruction ledger only" partial score_trace "$W"

# --- score_intent -----------------------------------------------------------
newcase
score "intent: nothing to look at" fail score_intent "$W"
mkdir -p "$W/.planning"; : >"$W/.planning/any.md"
score "intent: planning files but no evidence/row" partial score_intent "$W"
score "intent: evidence path given, missing" fail score_intent "$W" "docs/e.md"
mkdir -p "$W/docs"; : >"$W/docs/e.md"
score "intent: evidence path present" pass score_intent "$W" "docs/e.md"
score "intent: row alone resolves via the evidence table" fail score_intent "$W" "" 2
: >"$W/docs/ADR-001-runtime.md"
score "intent: row alone resolves via the evidence table (present)" pass score_intent "$W" "" 2
newcase
score "intent/1: routing row without routing evidence" fail score_intent "$W" "" 1 "$S"
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/router-session.md"
score "intent/1: routing row with router-session.md (via the table)" pass score_intent "$W" "" 1 "$S"
rm "$W/.planning/workflows/router-session.md"
echo silver-router >"$S/state"
score "intent/1: routing evidence from the state file" pass score_intent "$W" "" 1 "$S"
score "intent/3: non-routing row ignores the state file" fail score_intent "$W" "" 3 "$S"
score "intent: evidence arg but no state dir" fail score_intent "$W" "nope.md" 1

# --- score_km ---------------------------------------------------------------
kmledger() { # FILE ROW STATUS GREF AREF
  printf '| %s | `silver-x` | wf | note | %s | a | b | c | %s | %s |\n' "$2" "$3" "$4" "$5" >"$1"
}
newcase
KL="$TL_TMP/c$c/km-ledger.md"
score "km: routing row" n/a score_km "" 1 "" "$W"
score "km: nothing, no work-dir config" n/a score_km "" 3 "" "$W"
score "km: fixture mode" n/a score_km "" 3 "" "$W" -- SB_E2E_OUTCOME_ASSESS_FIXTURE=1
echo '{"graphify": {}}' >"$W/.silver-bullet.json"
score "km: project configures graphify but no evidence" partial score_km "" 3 "" "$W"
score "km: fixture mode beats the config hint" n/a score_km "" 3 "" "$W" -- SB_E2E_OUTCOME_ASSESS_FIXTURE=1
echo '{}' >"$W/.silver-bullet.json"
score "km: config without graphify" n/a score_km "" 3 "" "$W"
score "km: work dir defaults to SB_TEST_ENTERPRISE_APP_ROOT" n/a score_km "" 3 "" "" -- "SB_TEST_ENTERPRISE_APP_ROOT=$W"
echo '{"graphify": {}}' >"$W/.silver-bullet.json"
score "km: default work dir feeds the config check" partial score_km "" 3 "" "" -- "SB_TEST_ENTERPRISE_APP_ROOT=$W"
rm "$W/.silver-bullet.json"
# ledger-driven
kmledger "$KL" 3 Pass gq am
score "km: ledger pass with both refs" pass score_km "$KL" 3 "" "$W"
kmledger "$KL" 3 Pass gq ""
score "km: ledger pass, graphify ref only" partial score_km "$KL" 3 "" "$W"
oa_log "$L" "agentmemory is not available"
score "km: ledger pass, graphify ref only, agentmemory unavailable" n/a score_km "$KL" 3 "$L" "$W"
kmledger "$KL" 3 Pass "" am
score "km: ledger pass, agentmemory ref only" partial score_km "$KL" 3 "" "$W"
kmledger "$KL" 3 Pass "" ""
score "km: ledger pass with no refs" fail score_km "$KL" 3 "" "$W"
kmledger "$KL" 3 Fail gq am
score "km: ledger not pass, both refs" pass score_km "$KL" 3 "" "$W"
kmledger "$KL" 3 Fail gq ""
score "km: ledger not pass, graphify ref only" partial score_km "$KL" 3 "" "$W"
score "km: ledger not pass, graphify ref only, agentmemory unavailable" n/a score_km "$KL" 3 "$L" "$W"
kmledger "$KL" 3 Fail "" am
score "km: ledger not pass, agentmemory ref only" n/a score_km "$KL" 3 "" "$W"
kmledger "$KL" 4 Pass gq am
score "km: ledger without this row" n/a score_km "$KL" 3 "" "$W"
score "km: non-numeric row ignores the ledger" n/a score_km "$KL" abc "" "$W"
score "km: ledger file missing" n/a score_km "$TL_TMP/absent.md" 3 "" "$W"
# env graphify ref replaces a missing ledger ref
score "km: SB_E2E_MATRIX_GRAPHIFY_REF acts as the graphify ref" partial score_km "" 3 "" "$W" -- SB_E2E_MATRIX_GRAPHIFY_REF=ref1
score "km: matrix graphify ref counts as pass in matrix mode" pass score_km "" 3 "" "$W" -- SB_E2E_MATRIX_GRAPHIFY_REF=ref1 "$MATRIX"
score "km: ... and with the score-matrix switch" pass score_km "" 3 "" "$W" -- SB_E2E_MATRIX_GRAPHIFY_REF=ref1 SB_E2E_OUTCOME_SCORE_MATRIX=1
# log-driven
oa_log "$L" "graphify query foo" "agentmemory memory_save done"
score "km: agentmemory MCP + graphify activity" pass score_km "" 3 "$L" "$W"
oa_log "$L" "persisted to agentmemory" "graphify query foo"
score "km: agentmemory capture + graphify activity" pass score_km "" 3 "$L" "$W"
oa_log "$L" "graphify query foo"
score "km: graphify activity alone, no refs" n/a score_km "" 3 "$L" "$W"
oa_log "$L" "memory_save only"
score "km: agentmemory only" n/a score_km "" 3 "$L" "$W"
# matrix mode with graphify activity
oa_log "$L" "graphify query foo" "agentmemory memory_save"
score "km/matrix: graphify + agentmemory" pass score_km "" 3 "$L" "$W" -- "$MATRIX"
oa_log "$L" "HARNESS graphify: scope" "graphify query x"
score "km/matrix: harness graphify line" pass score_km "" 3 "$L" "$W" -- "$MATRIX"
oa_log "$L" "matrix MCP env: disabled" "graphify query x"
score "km/matrix: MCP env disabled" pass score_km "" 3 "$L" "$W" -- "$MATRIX"
oa_log "$L" "HARNESS x" '{"type":"readToolCall","text":"matrix MCP env: disabled"}' "graphify query x"
score "km/matrix: hidden MCP-disabled marker found in the raw log" pass score_km "" 3 "$L" "$W" -- "$MATRIX"
oa_log "$L" "graphify query x"
score "km/matrix: graphify only, no MCP evidence" n/a score_km "" 3 "$L" "$W" -- "$MATRIX"
oa_log "$L" "WROTE: x .planning/workflows/a.md"
score "km/matrix: workflow evidence written" pass score_km "" 3 "$L" "$W" -- "$MATRIX"
oa_log "$L" "nothing"
score "km/matrix: nothing" n/a score_km "" 3 "$L" "$W" -- "$MATRIX"
# worker completion + graphify ref
kmledger "$KL" 3 Fail gq ""
oa_log "$L" "worker completed"
score "km: graphify ref + worker completion" pass score_km "$KL" 3 "$L" "$W"
# graphify ref + activity + graph.json + evidence written
oa_log "$L" "graphify query x" "WROTE: x .planning/workflows/a.md"
score "km: ref + activity but no graph.json" partial score_km "$KL" 3 "$L" "$W"
mkdir -p "$W/graphify-out"; : >"$W/graphify-out/graph.json"
score "km: ref + activity + graph.json + evidence written" pass score_km "$KL" 3 "$L" "$W"
oa_log "$L" "graphify query x"
score "km: ref + activity + graph.json but no evidence written" partial score_km "$KL" 3 "$L" "$W"

# --- score_orch -------------------------------------------------------------
newcase
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/fast-readme.md"
score "orch/6: evidence resolved" n/a score_orch "$S" "$L" 6 "$W" ""
newcase
echo silver-fast >"$S/state"
score "orch/6: state is exactly silver-fast" n/a score_orch "$S" "$L" 6 "$W" ""
echo "x silver-fast" >"$S/state"
score "orch/6: state line is not exactly silver-fast" fail score_orch "$S" "$L" 6 "$W" ""
newcase
mkdir -p "$W/docs"; : >"$W/docs/ADR-001-runtime.md"
oa_log "$L" "worker completed"
score "orch/matrix: worker completion" pass score_orch "$S" "$L" 2 "$W" "" -- "$MATRIX"
oa_log "$L" "Silver Bullet orchestrator ran"
score "orch/matrix: evidence + orchestrator mention" pass score_orch "$S" "$L" 2 "$W" "" -- "$MATRIX"
oa_log "$L" "quiet"
score "orch/matrix: evidence but no mention" fail score_orch "$S" "$L" 2 "$W" "" -- "$MATRIX"
newcase
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/router-session.md"
score "orch/routing: routing evidence" pass score_orch "$S" "$L" 1 "$W" ""
newcase
for m in "SILVER BULLET" "routing validation only" "/sb:feature" "silver-feature"; do
  oa_log "$L" "log: $m"
  score "orch/routing: log mentions '$m'" pass score_orch "$S" "$L" 1 "$W" ""
done
oa_log "$L" "nothing"
score "orch/routing: nothing" fail score_orch "$S" "$L" 1 "$W" ""
newcase
echo '{"next_skill":"x"}' >"$S/orchestrator-directive.json"
score "orch: directive with next_skill" pass score_orch "$S" "$L" 3 "$W" ""
echo '{"template":"next_worker_template"}' >"$S/orchestrator-directive.json"
score "orch: directive with next_worker_template" pass score_orch "$S" "$L" 3 "$W" ""
echo '{}' >"$S/orchestrator-directive.json"
score "orch: directive without next-step keys" fail score_orch "$S" "$L" 3 "$W" ""
echo '{}' >"$S/orchestrator-worker-active.json"
score "orch: worker-active file" pass score_orch "$S" "$L" 3 "$W" ""
newcase
mkdir -p "$W/docs"; : >"$W/docs/e.md"
oa_log "$L" "Booting MCP server"
score "orch: evidence file + Booting MCP in the log" pass score_orch "$S" "$L" 3 "$W" "docs/e.md"
oa_log "$L" 'ran $silver feature'
score "orch: evidence file + \$silver in the log" pass score_orch "$S" "$L" 3 "$W" "docs/e.md"
oa_log "$L" "unrelated"
score "orch: evidence file but nothing orchestrator-like" fail score_orch "$S" "$L" 3 "$W" "docs/e.md"
newcase
oa_log "$L" "a Task was started"
score "orch: Task mention without completion or evidence" partial score_orch "$S" "$L" 3 "$W" ""
oa_log "$L" "worker spawned" "worker completed"
score "orch: worker mention with completion" pass score_orch "$S" "$L" 3 "$W" ""
oa_log "$L" "orchestrator noted"
mkdir -p "$W/docs"; : >"$W/docs/ADR-001-runtime.md"
score "orch: orchestrator mention with resolved evidence" pass score_orch "$S" "$L" 2 "$W" ""
score "orch: no log at all" fail score_orch "$S" "" 3 "$TL_TMP/empty-work" ""

tl_results
