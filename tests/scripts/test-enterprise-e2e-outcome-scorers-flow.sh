#!/usr/bin/env bash
# Behaviour tests for the flow-oriented criterion scorers of
# scripts/lib/enterprise-e2e-outcome-assessment.sh: auto, clarify, noop, drift, super, heal, release
# and the orchestrator-state helpers they use. Every case builds its own work/state dirs under $TL_TMP.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f3-helpers.sh"

# case dirs: fresh $W (work dir), $S (state dir), $L (log path, not created)
c=0
newcase() {
  c=$((c + 1))
  W="$TL_TMP/c$c/work"
  S="$TL_TMP/c$c/state"
  L="$TL_TMP/c$c/row.log"
  mkdir -p "$W" "$S"
}
# score NAME EXPECTED FUNCTION ARGS... [-- ENV...]: run a scorer, compare its output.
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

# --- score_auto: routing row -----------------------------------------------
newcase
oa_log "$L" "waiting for your input"
score "auto/routing: babysitting fails even with evidence" fail score_auto "$W" "$S" "$L" "" 1
newcase
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/router-session.md"
score "auto/routing: routing evidence passes" pass score_auto "$W" "$S" "" "" 1
newcase
oa_log "$L" "routing completes cleanly"
score "auto/routing: log says routing completes" pass score_auto "$W" "$S" "$L" "" 1
oa_log "$L" "composed workflow skill ran"
score "auto/routing: composed workflow skill" pass score_auto "$W" "$S" "$L" "" 1
oa_log "$L" "nothing useful"
score "auto/routing: nothing -> fail" fail score_auto "$W" "$S" "$L" "" 1

# --- score_auto: other rows -------------------------------------------------
newcase
oa_log "$L" "needed babysitting"
score "auto: babysitting and no evidence" fail score_auto "$W" "$S" "$L" "docs/e.md" 3
mkdir -p "$W/docs"; : >"$W/docs/e.md"
score "auto: babysitting but evidence file present" partial score_auto "$W" "$S" "$L" "docs/e.md" 3
mkdir -p "$W/docs/edir"
score "auto: babysitting but evidence directory present" partial score_auto "$W" "$S" "$L" "docs/edir" 3
newcase
mkdir -p "$W/docs"; : >"$W/docs/e.md"
oa_log "$L" "autonomous mode on"
score "auto: evidence + autonomous log" pass score_auto "$W" "$S" "$L" "docs/e.md" 3
oa_log "$L" "plain"
score "auto: evidence + enterprise matrix" pass score_auto "$W" "$S" "$L" "docs/e.md" 3 -- "$MATRIX"
score "auto: evidence only -> partial" partial score_auto "$W" "$S" "$L" "docs/e.md" 3
echo '{}' >"$S/orchestrator-directive.json"
score "auto: evidence + directive file" pass score_auto "$W" "$S" "$L" "docs/e.md" 3
rm "$S/orchestrator-directive.json"
echo silver-feature >"$S/state"
score "auto: evidence + state file" pass score_auto "$W" "$S" "$L" "docs/e.md" 3
newcase
score "auto: no evidence at all" fail score_auto "$W" "$S" "$L" "docs/missing.md" 3
score "auto: no evidence, matrix mode" fail score_auto "$W" "$S" "$L" "docs/missing.md" 3 -- "$MATRIX"

# --- score_auto: tri-criteria rows ------------------------------------------
newcase
TAPP="$TL_TMP/c$c/app"
e2e_git_app "$TAPP"
git -C "$TAPP" branch feature/tc01-waitlist-saas
oa_log "$L" "built the waitlist"
score "auto/tri: session evidence + product evidence" pass score_auto "$TAPP" "$S" "$L" "" TC-01
oa_log "$L" "unrelated"
score "auto/tri: product exists but session log has no marker -> generic evidence path, no autonomy" partial score_auto "$TAPP" "$S" "$L" "" TC-01
oa_log "$L" "unrelated autonomous run" "worker completed"
score "auto/tri: matrix mode autonomous + worker completion" pass score_auto "$W" "$S" "$L" "" TC-03 -- "$MATRIX"
oa_log "$L" "unrelated autonomous run"
score "auto/tri: matrix mode needs worker completion too" fail score_auto "$W" "$S" "$L" "" TC-03 -- "$MATRIX"
oa_log "$L" "unrelated" "worker completed"
score "auto/tri: matrix mode needs the autonomous marker too" pass score_auto "$W" "$S" "$L" "" TC-03 -- "$MATRIX"

# --- score_clarify ----------------------------------------------------------
newcase
mkdir -p "$W/.planning"
echo "decisions locked" >"$W/.planning/CLARIFY.md"
score "clarify: doc with locked decisions" pass score_clarify "$W" "$S" "" 3
echo "just notes" >"$W/.planning/CLARIFY.md"
score "clarify: doc without decisions" partial score_clarify "$W" "$S" "" 3
echo "decision_class: A" >"$W/.planning/plan-CLARIFY-260101-20260101T000000Z.md"
touch -d '2030-01-01' "$W/.planning/plan-CLARIFY-260101-20260101T000000Z.md"
score "clarify: newest dated doc wins (decision_class)" pass score_clarify "$W" "$S" "" 3
newcase
echo "ran silver-clarify" >"$S/state"
score "clarify: state mentions silver-clarify" pass score_clarify "$W" "$S" "" 3
newcase
for m in '/sb:clarify' 'sb:clarify' '$sb:clarify' 'silver-clarify'; do
  oa_log "$L" "invoked $m now"
  score "clarify: log mentions $m" pass score_clarify "$W" "$S" "$L" 3
done
oa_log "$L" "nothing"
score "clarify: unrelated log, row 3" fail score_clarify "$W" "$S" "$L" 3
score "clarify: unrelated log, row 2" fail score_clarify "$W" "$S" "$L" 2
score "clarify: unrelated log, other row" n/a score_clarify "$W" "$S" "$L" 8
score "clarify: no log at all, other row" n/a score_clarify "$W" "$S" "" 8
# routing row 1
newcase
mkdir -p "$W/.planning/workflows"; : >"$W/.planning/workflows/router-session.md"
score "clarify/routing: routing evidence -> n/a" n/a score_clarify "$W" "$S" "" 1
newcase
for m in "routing validation only" "routing completes" "composed workflow skill" "SILVER BULLET ROUTING" "/sb:feature"; do
  oa_log "$L" "log: $m"
  score "clarify/routing: '$m' -> n/a" n/a score_clarify "$W" "$S" "$L" 1
done
oa_log "$L" "nothing"
score "clarify/routing: nothing -> fail" fail score_clarify "$W" "$S" "$L" 1
score "clarify/routing: no log -> fail" fail score_clarify "$W" "$S" "" 1

# --- score_noop -------------------------------------------------------------
newcase
oa_log "$L" "needed babysitting" "SB OVERRIDE: because"
score "noop: babysitting with an audited override" partial score_noop "$W" "$L"
oa_log "$L" "needed babysitting"
score "noop: babysitting" fail score_noop "$W" "$L"
oa_log "$L" "fine"
mkdir -p "$W/.planning"; echo "locked in" >"$W/.planning/CLARIFY.md"
score "noop: locked clarify doc" pass score_noop "$W" "$L"
rm "$W/.planning/CLARIFY.md"
score "noop: a row log exists" pass score_noop "$W" "$L"
score "noop: no log" partial score_noop "$W" "$TL_TMP/absent.log"
score "noop: empty log arg" partial score_noop "$W" ""

# --- runtime state dirs / orchestrator files -------------------------------
HOME_DIR="$TL_TMP/home"
mkdir -p "$HOME_DIR/.cursor/.silver-bullet" "$HOME_DIR/.claude/.silver-bullet"
oa -- enterprise_e2e_outcome_runtime_state_dirs ""
assert_eq "state dirs: sibling hosts that exist, in fixed order" "$HOME_DIR/.cursor/.silver-bullet
$HOME_DIR/.claude/.silver-bullet" "$TL_OUT"
oa -- enterprise_e2e_outcome_runtime_state_dirs "$TL_TMP/primary"
assert_eq "state dirs: primary first, then siblings" "$TL_TMP/primary
$HOME_DIR/.cursor/.silver-bullet
$HOME_DIR/.claude/.silver-bullet" "$TL_OUT"
oa -- enterprise_e2e_outcome_runtime_state_dirs "$HOME_DIR/.cursor/.silver-bullet"
assert_eq "state dirs: a sibling equal to the primary is not repeated" "$HOME_DIR/.cursor/.silver-bullet
$HOME_DIR/.claude/.silver-bullet" "$TL_OUT"
oa -- enterprise_e2e_outcome_runtime_state_dirs
assert_eq "state dirs: no primary argument" "$HOME_DIR/.cursor/.silver-bullet
$HOME_DIR/.claude/.silver-bullet" "$TL_OUT"

echo '{}' >"$HOME_DIR/.claude/.silver-bullet/orchestrator-directive.json"
oa -- enterprise_e2e_outcome_find_orchestrator_file orchestrator-directive.json "$TL_TMP/primary"
assert_eq "find orchestrator file: sibling host dir" "$HOME_DIR/.claude/.silver-bullet/orchestrator-directive.json" "$TL_OUT"
mkdir -p "$TL_TMP/primary"
echo '{}' >"$TL_TMP/primary/orchestrator-directive.json"
oa -- enterprise_e2e_outcome_find_orchestrator_file orchestrator-directive.json "$TL_TMP/primary"
assert_eq "find orchestrator file: primary wins" "$TL_TMP/primary/orchestrator-directive.json" "$TL_OUT"
oa -- enterprise_e2e_outcome_find_orchestrator_file orchestrator-worker-active.json "$TL_TMP/primary"
assert_eq "find orchestrator file: absent everywhere" 1 "$TL_STATUS"
oa_sh "enterprise_e2e_outcome_runtime_state_dirs() { printf '\n%s\n' '$TL_TMP/primary'; }
enterprise_e2e_outcome_find_orchestrator_file orchestrator-directive.json"
assert_eq "find orchestrator file: blank directory entries are skipped" "$TL_TMP/primary/orchestrator-directive.json" "$TL_OUT"

dd_() { oa -- enterprise_e2e_outcome_directive_drained "$1"; }
dd_ "$TL_TMP/absent.json"; assert_eq "drained: missing file" 1 "$TL_STATUS"
echo '{"blocking": false, "next_skill": null}' >"$TL_TMP/d1.json"
dd_ "$TL_TMP/d1.json"; assert_eq "drained: not blocking, no next skill" 0 "$TL_STATUS"
echo '{"blocking":false,"verdict":"COMPLETE","next_skill":"x"}' >"$TL_TMP/d2.json"
dd_ "$TL_TMP/d2.json"; assert_eq "drained: not blocking, verdict COMPLETE" 0 "$TL_STATUS"
echo '{"blocking":true,"next_skill":null}' >"$TL_TMP/d3.json"
dd_ "$TL_TMP/d3.json"; assert_eq "drained: still blocking" 1 "$TL_STATUS"
echo '{"blocking":false,"next_skill":"silver-x"}' >"$TL_TMP/d4.json"
dd_ "$TL_TMP/d4.json"; assert_eq "drained: not blocking but next skill queued" 1 "$TL_STATUS"

# --- score_drift ------------------------------------------------------------
newcase
for r in 1 2 6 18 20 99 ""; do
  score "drift: row '$r' not applicable" n/a score_drift "$W" "$L" "$r"
done
score "drift: no evidence" partial score_drift "$W" "$L" 3
mkdir -p "$W/.planning/workflows"
echo "plain" >"$W/.planning/workflows/a.md"
score "drift: workflow notes without drift" partial score_drift "$W" "$L" 4
echo "we saw deviation from plan" >"$W/.planning/workflows/a.md"
score "drift: deviation recorded in a workflow note" pass score_drift "$W" "$L" 5
newcase
oa_log "$L" "the agent will course correct"
score "drift: log says course correct" pass score_drift "$W" "$L" 17
oa_log "$L" "implementation drift detected"
score "drift: log says implementation drift" pass score_drift "$W" "$L" 19
oa_log "$L" "REALIGN now"
score "drift: log says realign" pass score_drift "$W" "$L" 3

# --- score_super ------------------------------------------------------------
newcase
score "super: routing row" n/a score_super "$S" "$L" 1
for r in 2 6 99 ""; do
  score "super: row '$r' not applicable" n/a score_super "$S" "$L" "$r"
done
score "super: nothing" fail score_super "$S" "$L" 3
oa_log "$L" "WBS Supervisor started"
score "super: log mentions the supervisor" pass score_super "$S" "$L" 4
oa_log "$L" "wbs stub"
score "super: WBS stub" pass score_super "$S" "$L" 5
newcase
echo '{}' >"$S/orchestrator-worker-active.json"
score "super: worker-active file" pass score_super "$S" "$L" 3
newcase
echo '{"blocking":false,"next_skill":null}' >"$S/orchestrator-directive.json"
score "super: drained directive" pass score_super "$S" "$L" 3
echo '{"blocking":true,"next_skill":"silver-x"}' >"$S/orchestrator-directive.json"
score "super: queued directive without worker completion" partial score_super "$S" "$L" 3
oa_log "$L" "worker completed"
score "super: queued directive with worker completion" pass score_super "$S" "$L" 3
echo '{"blocking":true}' >"$S/orchestrator-directive.json"
oa_log "$L" "still going"
score "super: directive without next-step keys and no completion" fail score_super "$S" "$L" 3
oa_log "$L" "worker completed"
score "super: directive without next-step keys but worker completion" pass score_super "$S" "$L" 3
newcase
EAPP="$TL_TMP/c$c/enterprise-app"
mkdir -p "$EAPP/docs"; : >"$EAPP/docs/ADR-001-runtime.md"
mkdir -p "$EAPP/.planning/workflows"; : >"$EAPP/.planning/workflows/feature-currency.md"
score "super: matrix mode, evidence in the enterprise app" pass score_super "$S" "$L" 3 -- "$MATRIX" "SB_TEST_ENTERPRISE_APP_ROOT=$EAPP"
score "super: matrix mode without an app root falls through" fail score_super "$S" "$L" 3 -- "$MATRIX"
score "super: matrix mode with an app root but no evidence for the row" fail score_super "$S" "$L" 4 -- "$MATRIX" "SB_TEST_ENTERPRISE_APP_ROOT=$EAPP"

# --- score_heal -------------------------------------------------------------
newcase
HEALROOT="$TL_TMP/c$c/sbroot"
mkdir -p "$HEALROOT"
WATCHF="$HEALROOT/.e2e-tui-watch-findings.jsonl"
score "heal: routing row" n/a score_heal "$HEALROOT" "$L" 1
score "heal: clean, no log" n/a score_heal "$HEALROOT" "$L" 3
oa_log "$L" "Stop hook blocks completion" "then a retry succeeded"
score "heal: hook block followed by retry" pass score_heal "$HEALROOT" "$L" 3
oa_log "$L" "session ended on hook block"
score "heal: hook block without recovery" fail score_heal "$HEALROOT" "$L" 3
oa_log "$L" "[WARN] some hook gate warning"
score "heal: hook warning" partial score_heal "$HEALROOT" "$L" 3
oa_log "$L" "[WARN] hook gate warning" "[harness] ignoring non-blocking hook"
score "heal: hook warning that the harness ignored" n/a score_heal "$HEALROOT" "$L" 3
oa_log "$L" "[WARN] hook gate warning" "warning: Spec session record skipped"
score "heal: spec-session warning is noise" n/a score_heal "$HEALROOT" "$L" 3
oa_log "$L" "unrelated"
echo '{"severity":"blocker","category":"hook","row":3,"message":"completion-audit","excerpt":"denied"}' >"$WATCHF"
score "heal: TUI watch hook blocker" fail score_heal "$HEALROOT" "$L" 3
score "heal: watch blocker ignored in fixture mode" n/a score_heal "$HEALROOT" "$L" 3 -- SB_E2E_OUTCOME_ASSESS_FIXTURE=1
score "heal: watch blocker for another row" n/a score_heal "$HEALROOT" "$L" 4
# enterprise matrix mode
score "heal/matrix: watch hook blocker" fail score_heal "$HEALROOT" "$L" 3 -- "$MATRIX"
score "heal/matrix: fixture mode ignores the watch file" n/a score_heal "$HEALROOT" "$L" 3 -- "$MATRIX" SB_E2E_OUTCOME_ASSESS_FIXTURE=1
oa_log "$L" "session ended on hook block"
score "heal/matrix: stop-hook block fails first" fail score_heal "$HEALROOT" "$L" 3 -- "$MATRIX" SB_E2E_OUTCOME_ASSESS_FIXTURE=1
oa_log "$L" "worker completed"
score "heal/matrix: worker completion means nothing to heal" n/a score_heal "$HEALROOT" "$L" 3 -- "$MATRIX"
oa_log "$L" "quiet"
rm -f "$WATCHF"
score "heal/matrix: evidence in the app root means nothing to heal" n/a score_heal "$HEALROOT" "$L" 3 -- "$MATRIX" "SB_TEST_ENTERPRISE_APP_ROOT=$EAPP"
score "heal/matrix: quiet run" n/a score_heal "$HEALROOT" "$L" 3 -- "$MATRIX"

# --- score_release ----------------------------------------------------------
newcase
for r in 1 3 13 17 "" abc; do
  score "release: row '$r' not applicable" n/a score_release "$W" "$r" ""
done
score "release/14: nothing" fail score_release "$W" 14 ""
: >"$W/CHANGELOG.md"
score "release/14: changelog only" partial score_release "$W" 14 ""
rm "$W/CHANGELOG.md"
mkdir -p "$W/docs"; : >"$W/docs/instruction-ledger.jsonl"
score "release/14: instruction ledger only" partial score_release "$W" 14 ""
: >"$W/CHANGELOG.md"
score "release/14: changelog + instruction ledger" pass score_release "$W" 14 ""
LEDGER="$TL_TMP/rel-ledger.md"
echo "hand-edited row" >"$LEDGER"
score "release/14: hand-edited ledger downgrades to partial" partial score_release "$W" 14 "$LEDGER"
echo "operator patch applied" >"$LEDGER"
score "release/14: operator patch downgrades to partial" partial score_release "$W" 14 "$LEDGER"
echo "all machine generated" >"$LEDGER"
score "release/14: clean ledger file" pass score_release "$W" 14 "$LEDGER"
score "release/14: ledger path that does not exist" pass score_release "$W" 14 "$TL_TMP/absent-ledger.md"
rm "$W/docs/instruction-ledger.jsonl"
mkdir -p "$W/.planning/phases/p1"
: >"$W/.planning/phases/p1/SHIP.md"
score "release/14: SHIP.md not under a release phase" partial score_release "$W" 14 ""
mkdir -p "$W/.planning/phases/release-1"
: >"$W/.planning/phases/release-1/SHIP.md"
score "release/14: changelog + release-phase SHIP.md" pass score_release "$W" 14 ""
newcase
score "release/15: nothing" partial score_release "$W" 15 ""
mkdir -p "$W/.planning/reviews"; : >"$W/.planning/reviews/triad-extra.md"
score "release/15: any triad review file" pass score_release "$W" 15 ""
: >"$W/.planning/reviews/triad-currency.md"
score "release/15: triad-currency.md" pass score_release "$W" 15 ""
newcase
score "release/16: nothing" fail score_release "$W" 16 ""
mkdir -p "$W/.planning/ship-readiness"
score "release/16: ship-readiness only" partial score_release "$W" 16 ""
mkdir -p "$W/docs"; : >"$W/docs/instruction-ledger.jsonl"
score "release/16: ledger + ship-readiness" pass score_release "$W" 16 ""
echo "operator patch" >"$LEDGER"
score "release/16: operator patch downgrades to partial" partial score_release "$W" 16 "$LEDGER"
echo "manual edits: *manual*" >"$LEDGER"
score "release/16: *manual* downgrades to partial" partial score_release "$W" 16 "$LEDGER"
rm -rf "$W/.planning/ship-readiness"
score "release/16: instruction ledger only" partial score_release "$W" 16 ""

tl_results
