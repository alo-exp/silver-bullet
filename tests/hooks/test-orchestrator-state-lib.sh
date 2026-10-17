#!/usr/bin/env bash
# Unit tests for hooks/lib/orchestrator-state.sh (queues, seeding, composer start,
# interruption handling, composer chains and atom advance).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init claude
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_RUNTIME_SCHEDULER SB_APO_CATALOG_FILE SB_ORCHESTRATOR_PARALLEL_DISPATCH SILVER_BULLET_TEST_HOOK_ENFORCED _lib_dir
export SILVER_BULLET_RUNTIME=claude
tl_stub sleep 'exit 0'
# Run from a scratch directory: some helpers fall back to ./scripts/workflows.sh.
mkdir -p "$TL_TMP/cwd"
cd "$TL_TMP/cwd"
# shellcheck source=../../hooks/lib/orchestrator-state.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-state.sh"

NOJQ="$(tl_path_without jq)"
REAL_JQ="$(command -v jq)"
STATE="$(orch_state_file)"
DIRF="$(orch_directive_file)"
rc_of() { "$@" >/dev/null 2>&1 && echo 0 || echo $?; }
stub_jq_failing_on() {
  tl_stub jq "for a in \"\$@\"; do [[ \"\$a\" == *'$1'* ]] && exit 1; done; exec $REAL_JQ \"\$@\""
  hash -r
}
unstub_jq() { rm -f "$TL_BIN/jq"; hash -r; }


echo "=== paths and classifiers ==="
assert_eq "state file" "$SB_RUNTIME_STATE_DIR/orchestrator.json" "$(sb_orchestrator_state_file)"
assert_eq "composition log under root" "/r/.planning/orchestrator-composition-log.jsonl" "$(sb_orchestrator_composition_log /r)"
assert_eq "composition log defaults to PWD" "$PWD/.planning/orchestrator-composition-log.jsonl" "$(sb_orchestrator_composition_log)"
for c in silver silver-feature silver-ui silver-devops silver-bugfix silver-deep-research silver-release silver-fast silver-new-workflow silver-benchmark silver-canary silver-content silver-deploy silver-forensics silver-incident silver-refactor silver-retro silver-test; do
  assert_eq "$c is a composer" 0 "$(rc_of sb_orchestrator_is_composer_skill "$c")"
done
assert_eq "atom is not a composer" 1 "$(rc_of sb_orchestrator_is_composer_skill silver-plan)"
assert_eq "silver-plan is a flow atom" 0 "$(rc_of sb_orchestrator_is_flow_atom silver-plan)"
assert_eq "security is a flow atom" 0 "$(rc_of sb_orchestrator_is_flow_atom security)"
assert_eq "composer is not a flow atom" 1 "$(rc_of sb_orchestrator_is_flow_atom silver-feature)"

echo "=== default queues ==="
assert_eq "post-exec queue default" "silver-review-request,silver-review,silver-review-triage,silver-verify,security,silver-secure,silver-validate,FLOW-QUALITY-GATE-PRESHIP,silver-branch-finish,silver-completion-audit,silver-ship" "$(sb_orchestrator_post_exec_queue)"
assert_contains "post-exec queue custom gate" "$(sb_orchestrator_post_exec_queue MY-GATE)" "silver-validate,MY-GATE,silver-branch-finish"
q() { sb_orchestrator_default_queue_for_composer "$1"; }
PX="$(sb_orchestrator_post_exec_queue FLOW-QUALITY-GATE-PRESHIP)"
assert_eq "silver-feature" "FLOW-QUALITY-GATE,silver-context,silver-plan,silver-validate,silver-execute,$PX" "$(q silver-feature)"
assert_eq "silver-ui" "FLOW-QUALITY-GATE,silver-context,silver-plan,silver-ui-contract,silver-validate,silver-execute,silver-ui-review,$PX" "$(q silver-ui)"
assert_eq "silver-devops" "silver-blast-radius,devops-skill-router,devops-quality-gates,security,silver-context,silver-plan,silver-validate,silver-execute,$PX" "$(q silver-devops)"
assert_eq "silver-bugfix" "silver-debug,silver-plan,silver-execute,$PX" "$(q silver-bugfix)"
assert_eq "silver-deep-research" "silver-clarify,silver-deep-research,silver-ensure-docs,silver-validate" "$(q silver-deep-research)"
assert_eq "silver-new-workflow" "silver-clarify,silver-scan,silver-deep-research,silver-plan,silver-review-fix-ladder,silver-execute,silver-verify,silver-validate,silver-ensure-docs" "$(q silver-new-workflow)"
assert_eq "silver-fast" "FLOW-QUALITY-GATE,silver-plan,silver-validate,silver-execute,silver-verify" "$(q silver-fast)"
assert_eq "silver-release" "FLOW-QUALITY-GATE,silver-review-request,silver-review,silver-review-triage,silver-verify,security,silver-secure,silver-validate,silver-branch-finish,silver-completion-audit,silver-ship,silver-create-release" "$(q silver-release)"
assert_eq "silver" "silver-context" "$(q silver)"
assert_eq "silver-benchmark" "silver-context,silver-plan,silver-execute,silver-verify,silver-ensure-docs" "$(q silver-benchmark)"
assert_eq "silver-canary" "silver-blast-radius,silver-plan,silver-execute,silver-verify,silver-ship" "$(q silver-canary)"
assert_eq "silver-content" "silver-clarify,silver-plan,silver-execute,silver-verify,silver-ensure-docs" "$(q silver-content)"
assert_eq "silver-deploy" "silver-blast-radius,devops-quality-gates,silver-plan,silver-execute,silver-verify,security,silver-secure,silver-ship" "$(q silver-deploy)"
assert_eq "silver-forensics" "silver-debug,silver-execute,silver-ensure-docs,silver-validate" "$(q silver-forensics)"
assert_eq "silver-incident" "silver-blast-radius,silver-debug,silver-plan,silver-execute,security,silver-secure,silver-verify,silver-ensure-docs" "$(q silver-incident)"
assert_eq "silver-refactor" "silver-plan,silver-validate,silver-execute,$PX" "$(q silver-refactor)"
assert_eq "silver-retro" "silver-context,silver-execute,silver-ensure-docs" "$(q silver-retro)"
assert_eq "silver-test" "silver-plan,silver-validate,silver-execute,silver-verify" "$(q silver-test)"
assert_eq "unknown composer" "silver-context,silver-plan,silver-execute,$PX" "$(q mystery)"

echo "=== queue for composer (SPEC awareness) ==="
R="$TL_TMP/specroot"
mkdir -p "$R/.planning"
assert_contains "no SPEC.md: clarify + spec inserted before context" "$(sb_orchestrator_queue_for_composer silver-feature "$R")" "silver-clarify,silver-spec,silver-context"
assert_contains "no SPEC.md also applies to silver-ui" "$(sb_orchestrator_queue_for_composer silver-ui "$R")" "silver-clarify,silver-spec,silver-context"
: >"$R/.planning/SPEC.md"
assert_eq "SPEC.md present: default queue" "$(q silver-feature)" "$(sb_orchestrator_queue_for_composer silver-feature "$R")"
assert_eq "no repo root: default queue" "$(q silver-feature)" "$(sb_orchestrator_queue_for_composer silver-feature)"
assert_eq "other composers ignore SPEC.md" "$(q silver-bugfix)" "$(sb_orchestrator_queue_for_composer silver-bugfix "$TL_TMP/nospec")"

echo "=== flow labels and CSV ==="
while IFS='=' read -r tok want; do
  assert_eq "label for $tok" "$want" "$(sb_orchestrator_flow_label_for_token "$tok")"
done <<'MAP'
FLOW-QUALITY-GATE=QUALITY GATE
FLOW-QUALITY-GATE-PRESHIP=QUALITY GATE
FLOW-DEVOPS-QUALITY-GATE-PRESHIP=QUALITY GATE
devops-skill-router=DEVOPS SKILL ROUTER
silver-blast-radius=BLAST RADIUS
silver-branch-finish=BRANCH FINISH
silver-completion-audit=COMPLETION AUDIT
silver-validate=VALIDATE
silver-quality-gates=QUALITY GATE
devops-quality-gates=QUALITY GATE
silver-create-release=CREATE RELEASE
silver-deep-research=RESEARCH
security=SECURITY
FLOW-DESIGN-HANDOFF=DESIGN HANDOFF
DESIGN-HANDOFF=DESIGN HANDOFF
silver-handoff=DESIGN HANDOFF
FLOW-DOCUMENT=DOCUMENT
silver-ensure-docs=DOCUMENT
silver-plan=PLAN
silver-review-request=REVIEW-REQUEST
other-token=other-token
MAP
assert_eq "csv of silver-test" "PLAN,VALIDATE,EXECUTE,VERIFY" "$(sb_orchestrator_flow_csv_for_workflows silver-test)"
assert_contains "csv collapses quality-gate tokens" "$(sb_orchestrator_flow_csv_for_workflows silver-fast)" "QUALITY GATE,PLAN"

echo "=== queue index for atom ==="
orch_write_state '{"flow_queue":["FLOW-QUALITY-GATE","","silver-plan","FLOW-EXECUTE","silver-plan"]}'
ix() { sb_orchestrator_queue_index_for_atom "$@"; }
assert_eq "raw token match" 2 "$(ix silver-plan "$STATE")"
assert_eq "alias match through flow_to_skill" 0 "$(ix silver-quality-gates "$STATE")"
assert_eq "alias match later in the queue" 3 "$(ix silver-execute "$STATE")"
assert_eq "search starts at the given index" 4 "$(ix silver-plan "$STATE" 3)"
assert_eq "no match" 1 "$(rc_of ix silver-ship "$STATE")"
assert_eq "start past the end" 1 "$(rc_of ix silver-plan "$STATE" 99)"
assert_eq "unreadable state: empty queue" 1 "$(rc_of ix silver-plan /no/such/file)"

echo "=== full-software intent ==="
for t in "build a full app" "build the entire software" "start from scratch" "a greenfield project" "new product launch" "build a platform"; do
  assert_eq "full-software: $t" 0 "$(rc_of sb_orchestrator_detect_full_software_intent "$t")"
done
assert_eq "not full-software" 1 "$(rc_of sb_orchestrator_detect_full_software_intent "fix the typo")"
assert_eq "full-software queue" "silver-clarify,silver-spec,silver-feature,silver-ship,silver-release" "$(sb_orchestrator_full_software_queue)"

echo "=== read / write ==="
rm -f "$STATE"
assert_eq "read without state" 1 "$(rc_of sb_orchestrator_read)"
sb_orchestrator_write_json "" && rc=0 || rc=$?
assert_eq "write rejects empty JSON" 1 "$rc"
sb_orchestrator_write_json '{"a":1}'
assert_eq "write then read" '{"a":1}' "$(sb_orchestrator_read)"
rm -rf "$SB_RUNTIME_STATE_DIR"
sb_orchestrator_write_json '{"b":2}'
assert_eq "write creates the state dir" 2 "$(orch_state_get .b)"

echo "=== seed intent ==="
rm -f "$STATE" "$DIRF"
( PATH="$NOJQ"; sb_orchestrator_seed_intent "x" silver-test ) && rc=0 || rc=$?
assert_eq "no jq: nothing seeded" 0 "$rc"
assert_file_absent "no jq: no state" "$STATE"
sb_orchestrator_seed_intent "do something" silver-test ""
assert_eq "composer queue seeded" '["silver-plan","silver-validate","silver-execute","silver-verify"]' "$(orch_state_get '.flow_queue|tojson')"
assert_eq "current flow is the head" silver-plan "$(orch_state_get .current_flow)"
assert_eq "single workflow scope" single-workflow "$(orch_state_get .intent_graph.scope)"
assert_eq "no repo root recorded" "" "$(orch_state_get .repo_root)"
assert_eq "directive for the first flow" silver-plan "$(orch_directive_get .next_skill)"
assert_contains "directive reason" "$(orch_directive_get .reason)" "Composer silver-test started"
sb_orchestrator_seed_intent "build a full app" silver-test ""
assert_eq "full-software intent overrides the composer queue" silver-clarify "$(orch_state_get .current_flow)"
assert_eq "full-software scope" full-software "$(orch_state_get .intent_graph.scope)"
sb_orchestrator_seed_intent "plain request" "" ""
assert_eq "no composer: default queue" silver-context "$(orch_state_get .current_flow)"
assert_eq "no composer: five flows" 5 "$(orch_state_get '.flow_queue|length')"
mkdir -p "$TL_TMP/real"
ln -sfn "$TL_TMP/real" "$TL_TMP/lnk"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"
sb_orchestrator_seed_intent "i" silver-test "$TL_TMP/lnk"
assert_eq "repo root normalised via realpath" "$TL_TMP/real" "$(orch_state_get .repo_root)"
unset -f sb_orchestrator_normalize_repo_root
sb_orchestrator_seed_intent "i" silver-test "$TL_TMP/lnk"
assert_eq "repo root normalised via cd/pwd (no symlink resolution)" "$TL_TMP/lnk" "$(orch_state_get .repo_root)"
sb_orchestrator_seed_intent "i" silver-test "/no/such/root"
assert_eq "missing repo root kept verbatim" "/no/such/root" "$(orch_state_get .repo_root)"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"
rm -f "$STATE" "$DIRF"
stub_jq_failing_on active_intent
sb_orchestrator_seed_intent "i" silver-test ""
unstub_jq
assert_file_absent "state document build failure writes no state" "$STATE"
# A lib directory without the directive lib: state is written, no directive.
stg="$(orch_stage_libs orchestrator-state.sh)"
rm -f "$STATE" "$DIRF"
bash -c 'source "$1"; sb_orchestrator_seed_intent i silver-test ""' _ "$stg/orchestrator-state.sh"
assert_eq "state written without the directive lib" silver-plan "$(orch_state_get .current_flow)"
assert_file_absent "no directive without the directive lib" "$DIRF"


tl_results
