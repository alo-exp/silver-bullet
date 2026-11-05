#!/usr/bin/env bash
# Behaviour tests for the delivery-oriented criterion scorers of
# scripts/lib/enterprise-e2e-outcome-assessment.sh: plan, skill, review, blast, hook, complete,
# handoff, codeint, flow, measure and decide.
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

# --- plan / decide / complete / flow ----------------------------------------
newcase
score "plan: none" fail score_plan "$W"
mkdir -p "$W/.planning"; : >"$W/.planning/PLAN-1.md"
score "plan: PLAN file" pass score_plan "$W"

score "decide: no clarify doc" n/a score_decide "$W"
echo "notes" >"$W/.planning/CLARIFY.md"
score "decide: clarify doc without locked decisions" n/a score_decide "$W"
echo "LOCKED decisions" >"$W/.planning/CLARIFY.md"
score "decide: locked decisions" pass score_decide "$W"

newcase
for r in 1 3 13 17 "" abc; do
  score "complete: row '$r' not applicable" n/a score_complete "$W" "$r"
done
score "complete/14: nothing" fail score_complete "$W" 14
score "complete/15: nothing" fail score_complete "$W" 15
: >"$W/CHANGELOG.md"
score "complete/14: changelog" pass score_complete "$W" 14
score "complete/16: changelog is not enough" fail score_complete "$W" 16
mkdir -p "$W/.planning/ship-readiness"
score "complete/16: ship-readiness" pass score_complete "$W" 16

newcase
score "flow: nothing" partial score_flow "$W"
mkdir -p "$W/.planning/workflows/.archive"
score "flow: archive dir" pass score_flow "$W"
echo "no log" >"$W/.planning/workflows/2026-01-01-a.md"
score "flow: dated note without a Flow Log" partial score_flow "$W"
echo "## Flow Log" >"$W/.planning/workflows/2026-01-02-b.md"
score "flow: dated note with a Flow Log" pass score_flow "$W"

# --- score_skill ------------------------------------------------------------
newcase
oa_log "$L" "SILVER BULLET ► ROUTING"
score "skill/routing: banner" pass score_skill "$S" "$L" 1 "$W"
for m in "Routing to: silver-feature" "routing validation only" "routing completes"; do
  oa_log "$L" "$m"
  score "skill/routing: '$m'" pass score_skill "$S" "$L" 1 "$W"
done
oa_log "$L" "nothing"
score "skill/routing: nothing" fail score_skill "$S" "$L" 1 "$W"
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/router-session.md"
score "skill/routing: router-session.md in the work dir" pass score_skill "$S" "$L" 1 "$W"
rm "$W/.planning/workflows/router-session.md"
mkdir -p "$TL_TMP/c$c/envapp/.planning/workflows"; : >"$TL_TMP/c$c/envapp/.planning/workflows/router-session.md"
score "skill/routing: work dir defaults to SB_TEST_ENTERPRISE_APP_ROOT" pass score_skill "$S" "$L" 1 "" -- "SB_TEST_ENTERPRISE_APP_ROOT=$TL_TMP/c$c/envapp"
newcase
oa_log "$L" "worker completed"
score "skill/matrix: worker completion" pass score_skill "$S" "$L" 3 "$W" -- "$MATRIX"
score "skill: worker completion outside matrix mode is not enough" fail score_skill "$S" "$L" 3 "$W"
oa_log "$L" "wrote Feature-Currency today"
score "skill: log names the row's evidence file" pass score_skill "$S" "$L" 3 "$W"
oa_log "$L" "nothing"
printf 'x\nsilver-bugfix\n' >"$S/state"
score "skill: state lists a silver- skill" pass score_skill "$S" "$L" 3 "$W"
printf 'silver\n' >"$S/state"
score "skill: bare 'silver' state line" pass score_skill "$S" "$L" 3 "$W"
rm "$S/state"
printf 'silver-fast\n' >"$S/state.requested"
score "skill: requested-skill file" pass score_skill "$S" "$L" 3 "$W"
rm "$S/state.requested"
printf 'review-triad\n' >"$S/state"
score "skill: state holds the row's slug exactly" pass score_skill "$S" "$L" 15 "$W"
score "skill: state holds a different non-silver entry" partial score_skill "$S" "$L" 3 "$W"
rm "$S/state"
printf 'review-triad\n' >"$S/state.requested"
score "skill: slug in the requested file" pass score_skill "$S" "$L" 15 "$W"
score "skill: other non-silver entry in the requested file only" fail score_skill "$S" "$L" 3 "$W"
rm "$S/state.requested"
: >"$S/state"
score "skill: empty state file is ignored" fail score_skill "$S" "$L" 3 "$W"
rm "$S/state"
oa_log "$L" "ran silver-feature skill"
score "skill: log names the slug" pass score_skill "$S" "$L" 3 "$W"
oa_log "$L" "invoked /sb:feature"
score "skill: log names /sb:<slug without prefix>" pass score_skill "$S" "$L" 3 "$W"
oa_log "$L" "invoked silver-other"
score "skill: log names some other silver skill" partial score_skill "$S" "$L" 3 "$W"
oa_log "$L" "invoked /sb:other"
score "skill: log names some other /sb: command" partial score_skill "$S" "$L" 99 "$W"
oa_log "$L" "nothing"
score "skill: nothing" fail score_skill "$S" "$L" 3 "$W"
score "skill: no log, no state" fail score_skill "$S" "" 99 "$W"

# --- score_review -----------------------------------------------------------
newcase
mkdir -p "$W/.planning/reviews"; : >"$W/.planning/reviews/triad-currency.md"
score "review/15: triad-currency.md" pass score_review "$TL_TMP/absent-ledger.md" 15 "" "$W"
rm "$W/.planning/reviews/triad-currency.md"
for m in "review triad complete" "review-triad workflow is complete" "0 BLOCK findings" "REVIEW-TRIAGE done"; do
  oa_log "$L" "$m"
  score "review/15: log '$m'" pass score_review "$TL_TMP/absent-ledger.md" 15 "$L" "$W"
done
oa_log "$L" "nothing"
score "review/15: nothing, no ledger" fail score_review "$TL_TMP/absent-ledger.md" 15 "$L" "$W"
mkdir -p "$TL_TMP/envw/.planning/reviews"; : >"$TL_TMP/envw/.planning/reviews/triad-currency.md"
score "review/15: work dir defaults to SB_TEST_ENTERPRISE_APP_ROOT" pass score_review "$TL_TMP/absent-ledger.md" 15 "" "" -- "SB_TEST_ENTERPRISE_APP_ROOT=$TL_TMP/envw"
score "review: no ledger" fail score_review "$TL_TMP/absent-ledger.md" 3 "" "$W"
RL="$TL_TMP/review-ledger.md"
ladder() { # FILE: eight rows, marker line from $2, pass flags from remaining args
  local f="$1" marker="$2" i
  shift 2
  {
    echo "$marker"
    for i in 1 2 3 4 5 6 7 8; do
      echo "| $i | rung | $1 |"
      shift
    done
  } >"$f"
}
ladder "$RL" "review-fix-ladder" Pass Pass Pass Pass Pass Pass Pass Pass
score "review: ladder, all rungs Pass" pass score_review "$RL" 3 "" "$W"
ladder "$RL" "review-fix-ladder" '**Pass**' '**Pass**' '**Pass**' '**Pass**' '**Pass**' '**Pass**' '**Pass**' '**Pass**'
score "review: ladder, bold Pass" pass score_review "$RL" 3 "" "$W"
ladder "$RL" "review-fix-ladder" Pass Pass Pass Fail Pass Pass Pass Pass
score "review: ladder with a failing rung" partial score_review "$RL" 3 "" "$W"
ladder "$RL" "something else" Pass Pass Pass Pass Pass Pass Pass Pass
score "review: no ladder marker" fail score_review "$RL" 3 "" "$W"
printf 'review-fix-ladder\n| 1 | rung | Pass |\n' >"$RL"
score "review: ladder with fewer than eight rungs" fail score_review "$RL" 3 "" "$W"
ladder "$RL" "review-fix-ladder" Pass Pass Pass Pass Pass Pass Pass Pass
score "review/15 with nothing but a complete ladder ledger" pass score_review "$RL" 15 "" "$W"

# --- score_blast ------------------------------------------------------------
newcase
score "blast: other rows" n/a score_blast "$W" 3
score "blast: no row" n/a score_blast "$W"
score "blast/11: nothing" fail score_blast "$W" 11
mkdir -p "$W/.planning" "$W/infra/terraform"
: >"$W/infra/terraform/main.tf"
score "blast/11: terraform only" partial score_blast "$W" 11
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/devops-terraform-validation.md"
score "blast/11: validation note + terraform" pass score_blast "$W" 11
rm "$W/.planning/workflows/devops-terraform-validation.md" "$W/infra/terraform/main.tf"
echo "other" >"$W/.planning/workflows/devops-notes.md"
score "blast/11: devops note without blast terms" fail score_blast "$W" 11
echo "environment variable handling" >"$W/.planning/workflows/devops-notes.md"
score "blast/11: devops note with terms" pass score_blast "$W" 11
echo "other" >"$W/.planning/workflows/devops-notes.md"
: >"$W/infra/terraform/main.tf"
score "blast/11: devops note + terraform" pass score_blast "$W" 11
rm "$W/.planning/workflows/devops-notes.md" "$W/infra/terraform/main.tf"
: >"$W/.planning/SECURITY-REVIEW.md"
score "blast/11: security review" pass score_blast "$W" 11

# --- score_handoff ----------------------------------------------------------
newcase
score "handoff: routing row" n/a score_handoff "$S" 1 "$L" "$W"
for r in 2 6 99 ""; do
  score "handoff: row '$r' not applicable" n/a score_handoff "$S" "$r" "$L" "$W"
done
score "handoff: nothing" fail score_handoff "$S" 3 "$L" "$W"
echo '{}' >"$S/orchestrator-directive.json"
score "handoff: directive only" partial score_handoff "$S" 3 "$L" "$W"
oa_log "$L" "worker completed"
score "handoff: worker completion in the log" pass score_handoff "$S" 4 "$L" "$W"
oa_log "$L" "quiet"
mkdir -p "$W/.planning"; echo '{}' >"$W/.planning/orchestrator-composition-log.jsonl"
score "handoff: composition log in the work dir" pass score_handoff "$S" 5 "$L" "$W"
rm "$W/.planning/orchestrator-composition-log.jsonl" "$S/orchestrator-directive.json"
echo '{}' >"$S/orchestrator-worker-active.json"
score "handoff: worker-active file" pass score_handoff "$S" 3 "$L" "$W"

# --- score_codeint ----------------------------------------------------------
newcase
score "codeint: project without code-intel config" n/a score_codeint "$W" "$L" 3 ""
echo '{"name":"x"}' >"$W/.silver-bullet.json"
score "codeint: config without graphify/agentmemory" n/a score_codeint "$W" "$L" 3 ""
echo '{"agentmemory": {}}' >"$W/.silver-bullet.json"
oa_log "$L" "ran graphify query foo"
score "codeint: agentmemory configured, graphify query in log" pass score_codeint "$W" "$L" 3 ""
oa_log "$L" "nothing"
score "codeint: configured, nothing else" partial score_codeint "$W" "$L" 3 ""
score "codeint: configured, no log" partial score_codeint "$W" "" 3 ""
echo '{"graphify": {}}' >"$W/.silver-bullet.json"
score "codeint: routing row is satisfied by configuration" pass score_codeint "$W" "$L" 1 ""
mkdir -p "$W/graphify-out"; : >"$W/graphify-out/graph.json"
score "codeint: graph.json present" pass score_codeint "$W" "$L" 3 ""
rm -r "$W/graphify-out"
KL="$TL_TMP/c$c/ledger.md"
printf '| 3 | `silver-feature` | wf | note | Pass | a | b | c | gq | am |\n' >"$KL"
score "codeint: ledger graphify ref" pass score_codeint "$W" "$L" 3 "$KL"
printf '| 3 | `silver-feature` | wf | note | Pass | a | b | c |  | am |\n' >"$KL"
score "codeint: ledger without graphify ref" partial score_codeint "$W" "$L" 3 "$KL"
printf '| 4 | `silver-feature` | wf | note | Pass | a | b | c | gq | am |\n' >"$KL"
score "codeint: ledger without this row" partial score_codeint "$W" "$L" 3 "$KL"
score "codeint: ledger path missing" partial score_codeint "$W" "$L" 3 "$TL_TMP/absent.md"
score "codeint: non-numeric row ignores the ledger" partial score_codeint "$W" "$L" abc "$KL"

# --- score_hook -------------------------------------------------------------
newcase
HROOT="$TL_TMP/c$c/sbroot"
mkdir -p "$HROOT"
HWATCH="$HROOT/.e2e-tui-watch-findings.jsonl"
BLOCKER='{"severity":"blocker","category":"hook","row":3,"message":"completion-audit","excerpt":"denied"}'
oa_log "$L" "fine"
score "hook/routing: clean log" pass score_hook "$HROOT" 1 "$L"
oa_log "$L" "FAIL: outcome assessment of row 1"
score "hook/routing: harness outcome failure" fail score_hook "$HROOT" 1 "$L"
score "hook/routing: no log" pass score_hook "$HROOT" 1 ""
oa_log "$L" "quiet"
score "hook: no ledger, no watch" partial score_hook "$HROOT" 3 "$L"
echo "$BLOCKER" >"$HWATCH"
score "hook: watch blocker" fail score_hook "$HROOT" 3 "$L"
score "hook: fixture mode ignores the watch file" partial score_hook "$HROOT" 3 "$L" -- SB_E2E_OUTCOME_ASSESS_FIXTURE=1
HL="$TL_TMP/c$c/hook-ledger.md"
echo "hook-delivery 3/3" >"$HL"
score "hook: ledger delivery 3/3 but watch blocker" fail score_hook "$HROOT" 3 "$L" -- "SB_E2E_LEDGER_FILE=$HL"
score "hook: ledger delivery 3/3, fixture mode" pass score_hook "$HROOT" 3 "$L" -- "SB_E2E_LEDGER_FILE=$HL" SB_E2E_OUTCOME_ASSESS_FIXTURE=1
rm "$HWATCH"
score "hook: ledger delivery 3/3, clean" pass score_hook "$HROOT" 3 "$L" -- "SB_E2E_LEDGER_FILE=$HL"
echo "no delivery" >"$HL"
score "hook: ledger without delivery marker" partial score_hook "$HROOT" 3 "$L" -- "SB_E2E_LEDGER_FILE=$HL"
mkdir -p "$HROOT/.planning/enterprise-e2e"
echo "hook-delivery 3/3" >"$HROOT/.planning/enterprise-e2e/ROUND-6-LEDGER.md"
score "hook: default ledger location under the SB root" pass score_hook "$HROOT" 3 "$L"
# matrix mode
rm "$HROOT/.planning/enterprise-e2e/ROUND-6-LEDGER.md"
score "hook/matrix: quiet" pass score_hook "$HROOT" 3 "$L" -- "$MATRIX"
oa_log "$L" "Stop hook blocks completion"
score "hook/matrix: stop-hook block" fail score_hook "$HROOT" 3 "$L" -- "$MATRIX"
oa_log "$L" "session ended on hook block"
score "hook/matrix: session ended on hook block" fail score_hook "$HROOT" 3 "$L" -- "$MATRIX"
oa_log "$L" "worker completed"
score "hook/matrix: worker completion" pass score_hook "$HROOT" 3 "$L" -- "$MATRIX"
oa_log "$L" "quiet"
echo "$BLOCKER" >"$HWATCH"
score "hook/matrix: watch blocker" fail score_hook "$HROOT" 3 "$L" -- "$MATRIX"
score "hook/matrix: fixture mode ignores the watch" pass score_hook "$HROOT" 3 "$L" -- "$MATRIX" SB_E2E_OUTCOME_ASSESS_FIXTURE=1
mkdir -p "$W/docs"; : >"$W/docs/ADR-001-runtime.md"
score "hook/matrix: evidence in the app root beats the watch blocker" pass score_hook "$HROOT" 2 "$L" -- "$MATRIX" "SB_TEST_ENTERPRISE_APP_ROOT=$W"

# --- score_measure ----------------------------------------------------------
newcase
score "measure: ledger missing" fail score_measure "$TL_TMP/absent-ledger.md" "$OA_ROOT"
ML="$TL_TMP/c$c/measure-ledger.md"
mapfile -t SPECS < <(e2e_all_pass_specs 22)
e2e_mk_ledger "$ML" "${SPECS[@]}"
score "measure: no reconcile lib under the root" partial score_measure "$ML" "$TL_TMP/c$c/empty-root"
mkdir -p "$OA_ROOT/scripts/lib"
ln -sf "$TL_REPO_ROOT/scripts/lib/enterprise-e2e-ledger-reconcile.sh" "$OA_ROOT/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
score "measure: 22/22 pass" pass score_measure "$ML" "$OA_ROOT"
mapfile -t SPECS21 < <(e2e_all_pass_specs 21)
e2e_mk_ledger "$ML" "${SPECS21[@]}"
score "measure: 21 rows is stale (partial outside matrix mode)" partial score_measure "$ML" "$OA_ROOT"
score "measure: stale ledger passes in matrix mode" pass score_measure "$ML" "$OA_ROOT" -- "$MATRIX"
mapfile -t SPECS21 < <(e2e_all_pass_specs 21)
e2e_mk_ledger "$ML" "${SPECS21[@]}" 22:Fail
score "measure: a failing row is a mismatch (partial outside matrix mode)" partial score_measure "$ML" "$OA_ROOT"
score "measure: mismatch passes in matrix mode" pass score_measure "$ML" "$OA_ROOT" -- "$MATRIX"
# unknown reconcile status -> fail (stubbed library in a scratch root)
mkdir -p "$TL_TMP/c$c/stub-root/scripts/lib"
echo 'enterprise_e2e_ledger_reconcile_status() { echo UNREADABLE; }' >"$TL_TMP/c$c/stub-root/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
score "measure: any other reconcile status fails" fail score_measure "$ML" "$TL_TMP/c$c/stub-root"
echo 'enterprise_e2e_ledger_reconcile_status() { echo COMPLETE; }
echo "leaked-output-should-not-matter" >/dev/null' >"$TL_TMP/c$c/stub-root/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
score "measure: COMPLETE from the library" pass score_measure "$ML" "$TL_TMP/c$c/stub-root"
# the reconcile library reads the ledger passed in, not an ambient SB_E2E_LEDGER_FILE
mapfile -t SPECS < <(e2e_all_pass_specs 22)
e2e_mk_ledger "$ML" "${SPECS[@]}"
e2e_mk_ledger "$TL_TMP/c$c/other-ledger.md" 1:Fail
score "measure: scores the ledger argument, not the ambient SB_E2E_LEDGER_FILE" pass score_measure "$ML" "$OA_ROOT" -- "SB_E2E_LEDGER_FILE=$TL_TMP/c$c/other-ledger.md"

tl_results
