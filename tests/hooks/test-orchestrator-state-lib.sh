#!/usr/bin/env bash
# Unit tests for hooks/lib/orchestrator-state.sh (queues, seeding, composer start,
# interruption handling, composer chains and atom advance).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
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
EVENTS="$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"
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

echo "=== composer start ==="
# shellcheck source=../../hooks/lib/orchestrator-scheduler.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"
CAT="$TL_TMP/catalog.json"
orch_fixture_catalog "$CAT"
export SB_APO_CATALOG_FILE="$CAT"
PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
mkdir -p "$PROJ/scripts"
WFLOG="$TL_TMP/wf.log"
cat >"$PROJ/scripts/workflows.sh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$WFLOG"
case "\$1" in
  start) echo WF-TEST-1 ;;
  complete-flow) [[ -n "\${WF_FAIL_LABEL:-}" && "\$3" == "\$WF_FAIL_LABEL" ]] && exit 1; exit 0 ;;
esac
STUB
chmod +x "$PROJ/scripts/workflows.sh"
rm -f "$STATE" "$DIRF" "$EVENTS" "$WFLOG"
sb_orchestrator_on_composer_start "" "i" "$PROJ" >/dev/null
assert_file_absent "empty composer: nothing happens" "$STATE"
( PATH="$NOJQ"; sb_orchestrator_on_composer_start silver-test "i" "$PROJ" ) >/dev/null
assert_file_absent "no jq: nothing happens" "$STATE"
out="$(sb_orchestrator_on_composer_start silver-test "ship the thing" "$PROJ")"
assert_eq "workflow id returned" WF-TEST-1 "$out"
assert_eq "workflow id stored" WF-TEST-1 "$(orch_state_get .workflow_id)"
assert_contains "workflow started with the composer and intent" "$(cat "$WFLOG")" "start /sb:test ship the thing PLAN,VALIDATE,EXECUTE,VERIFY"
clog="$PROJ/.planning/orchestrator-composition-log.jsonl"
assert_eq "composition log first entry" silver-test "$(head -1 "$clog" | jq -r .composer)"
assert_eq "composition log workflow" WF-TEST-1 "$(head -1 "$clog" | jq -r .workflow_id)"
assert_eq "composition log catalog workflow" WF-SILVER-TEST "$(head -1 "$clog" | jq -r .selected_workflow)"
assert_eq "scheduler plan appended to the log" runtime-scheduler "$(tail -1 "$clog" | jq -r .mode)"
assert_eq "scheduler plan persisted" 0 "$(orch_state_get .scheduler.active_batch_index)"
assert_eq "composer_start event logged" silver-test "$(jq -r 'select(.type=="composer_start")|.payload.composer' "$EVENTS")"
# Doc-only intent is tailored through the scheduler.
rm -f "$STATE" "$clog" "$WFLOG"
sb_orchestrator_on_composer_start silver-fast "add a README badge" "$PROJ" >/dev/null
assert_contains "doc-only tailoring recorded" "$(cat "$clog")" "DR-SUBSTITUTE-LEANER-WORKFLOW"
# Scheduler disabled: no scheduler plan.
rm -f "$STATE" "$clog"
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_on_composer_start silver-test "x" "$PROJ" >/dev/null
assert_eq "scheduler disabled: only the composition entry" 1 "$(wc -l <"$clog" | tr -d ' ')"
assert_eq "scheduler disabled: no scheduler state" null "$(orch_state_get .scheduler)"
# No workflows.sh: no workflow id, state keeps empty id.
P2="$TL_TMP/p2"
orch_make_project "$P2"
rm -f "$STATE"
out="$(sb_orchestrator_on_composer_start silver-test "x" "$P2")"
assert_eq "no workflows.sh: no id" "" "$out"
assert_eq "no workflows.sh: empty workflow id" "" "$(orch_state_get .workflow_id)"
# Relative scripts/workflows.sh from the cwd when no repo root is given.
rm -f "$STATE" "$WFLOG"
out="$(cd "$PROJ" && sb_orchestrator_on_composer_start silver-test "x" "")"
assert_eq "relative workflows.sh used" WF-TEST-1 "$out"
# No .planning: no composition log.
P3="$TL_TMP/p3"
mkdir -p "$P3"
rm -f "$STATE"
sb_orchestrator_on_composer_start silver-test "x" "$P3" >/dev/null
assert_file_absent "no .planning: no log" "$P3/.planning"
# Unwritable state update: id returned even when the state update document fails.
rm -f "$STATE"
stub_jq_failing_on workflow_id
out="$(sb_orchestrator_on_composer_start silver-test "x" "$PROJ" 2>/dev/null)"
unstub_jq
assert_eq "id still returned when the state update fails" WF-TEST-1 "$out"
# Event-log lib missing: still completes.
rm -f "$STATE" "$EVENTS"
out="$(bash -c 'source "$1"; export SB_APO_CATALOG_FILE="$3"; sb_orchestrator_on_composer_start silver-test x "$2"' _ "$stg/orchestrator-state.sh" "$PROJ" "$CAT")"
assert_eq "composer start without the scheduler/event libs" WF-TEST-1 "$out"
assert_file_absent "no event log without the event lib" "$EVENTS"

echo "=== clear queue ==="
orch_write_state '{"current_flow":"x"}'
printf '{"next_skill":"x"}' >"$DIRF"
sb_orchestrator_mark_worker_spawn silver-plan
sb_orchestrator_clear_queue
assert_file_absent "queue state removed" "$STATE"
assert_file_absent "directive removed" "$DIRF"
assert_file_absent "worker marker removed" "$(sb_orchestrator_worker_marker_file)"
orch_write_state '{"current_flow":"x"}'
printf '{"next_skill":"x"}' >"$DIRF"
(
  unset -f sb_orchestrator_directive_clear sb_orchestrator_clear_worker_marker
  sb_orchestrator_clear_queue
)
assert_file_absent "fallback removes the directive file directly" "$DIRF"

echo "=== clear on interrupt ==="
# shellcheck source=../../hooks/lib/prompt-classifier.sh
source "$TL_REPO_ROOT/hooks/lib/prompt-classifier.sh"
interrupt() { sb_orchestrator_clear_queue_on_interrupt "$@" && echo cleared || echo kept; }
mkpending() { orch_write_state '{"current_flow":"silver-plan","flow_queue":["silver-plan"]}'; printf '{}' >"$DIRF"; }
mkpending
assert_eq "empty prompt" kept "$(interrupt "")"
rm -f "$STATE"
assert_eq "no pending queue" kept "$(interrupt "what is the status?")"
mkpending
assert_eq "follow-up answers keep the queue" kept "$(interrupt "yes")"
assert_file_exists "queue survives a follow-up" "$STATE"
assert_eq "informational query clears" cleared "$(interrupt "what are the remaining deliverables?")"
assert_file_absent "queue gone after the informational query" "$STATE"
mkpending
assert_eq "bare work request clears" cleared "$(interrupt "please build the login page")"
mkpending
assert_eq "other prompts keep the queue" kept "$(interrupt "hmm")"
mkpending
assert_eq "without classifiers nothing clears" kept "$( unset -f sb_prompt_is_orchestrator_followup sb_prompt_is_informational_query sb_prompt_is_bare_work_request; interrupt "what are the remaining deliverables?")"
assert_eq "without the informational classifier: bare work still clears" cleared "$( unset -f sb_prompt_is_informational_query; interrupt "please build the login page")"

echo "=== composer chain ==="
rm -f "$STATE" "$DIRF" "$EVENTS"
assert_eq "chain: no state" 1 "$(rc_of sb_orchestrator_try_advance_composer_chain "$PROJ")"
assert_eq "chain: no jq" 1 "$(PATH="$NOJQ" rc_of sb_orchestrator_try_advance_composer_chain "$PROJ")"
orch_write_state '{"composer":"silver-feature","flow_queue":[],"active_intent":"go"}'
assert_eq "chain: nothing queued" 1 "$(rc_of sb_orchestrator_try_advance_composer_chain "$PROJ")"
orch_write_state '{"composer":"silver-feature","composer_chain":[],"flow_queue":[]}'
assert_eq "chain: empty chain" 1 "$(rc_of sb_orchestrator_try_advance_composer_chain "$PROJ")"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test","silver-release"],"active_intent":"go on"}'
out="$(sb_orchestrator_try_advance_composer_chain "$PROJ")"
assert_contains "chain message" "$out" "Composer chain advanced to silver-test"
assert_eq "next composer seeded" silver-test "$(orch_state_get .composer)"
assert_eq "remaining chain restored after the restart" '["silver-release"]' "$(orch_state_get '.composer_chain|tojson')"
assert_eq "intent carried over" "go on" "$(orch_state_get .active_intent)"
assert_eq "advance event logged for the chain" silver-feature "$(jq -r 'select(.type=="advance")|.payload.completed_skill' "$EVENTS" | head -1)"
# The restarted composer leaves no state behind: the chain tail is not re-applied.
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"]}'
( sb_orchestrator_on_composer_start() { rm -f "$STATE"; }; out="$(sb_orchestrator_try_advance_composer_chain "$PROJ")"; [[ -z "$out" ]] ) && rc=0 || rc=$?
assert_eq "state vanishing during restart returns quietly" 0 "$rc"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"]}'
( unset -f sb_orchestrator_event_record_advance; out="$(sb_orchestrator_try_advance_composer_chain "$PROJ")"; [[ "$out" == *silver-test* ]] ) && rc=0 || rc=$?
assert_eq "chain works without the event recorder" 0 "$rc"

echo "=== advance on atom ==="
mkq() {
  orch_write_state "$(jq -n --arg r "$PROJ" --arg w "${1:-}" '{repo_root:$r, workflow_id:$w, active_intent:"intent",
    flow_queue:["FLOW-QUALITY-GATE","silver-plan","silver-validate","silver-execute"], current_flow:"FLOW-QUALITY-GATE"}')"
  rm -f "$DIRF" "$EVENTS" "$WFLOG"
}
adv() { sb_orchestrator_advance_on_atom "$@"; }
mkq
assert_eq "non-atom is ignored" "" "$(adv silver-feature "$PROJ")"
assert_eq "non-atom leaves state" FLOW-QUALITY-GATE "$(orch_state_get .current_flow)"
assert_eq "no jq: nothing" "" "$(PATH="$NOJQ" adv silver-plan "$PROJ")"
rm -f "$STATE"
assert_eq "no state: nothing" "" "$(adv silver-plan "$PROJ")"
mkq
out="$(adv silver-quality-gates "$PROJ")"
assert_contains "advance message" "$out" "Next flow: silver-plan (auto-chained"
assert_eq "current flow advanced" silver-plan "$(orch_state_get .current_flow)"
assert_eq "last completed" silver-quality-gates "$(orch_state_get .last_completed)"
assert_eq "last completed index" 0 "$(orch_state_get .last_completed_index)"
assert_eq "directive for the next flow (no lib dir context)" silver-plan "$(orch_directive_get .next_skill)"
assert_contains "directive reason" "$(orch_directive_get .reason)" "Flow silver-quality-gates complete"
assert_eq "advance event" silver-plan "$(jq -r 'select(.type=="advance")|.payload.next_flow' "$EVENTS")"
mkq
_lib_dir="$TL_REPO_ROOT/hooks/lib" adv silver-quality-gates "$PROJ" >/dev/null
assert_eq "directive written via the lib-dir context" silver-plan "$(orch_directive_get .next_skill)"
mkq
out="$(adv silver-ship "$PROJ")"
assert_eq "atom not in the queue: ignored" "" "$out"
assert_eq "stale completion leaves current flow" FLOW-QUALITY-GATE "$(orch_state_get .current_flow)"
mkq
adv silver-quality-gates "$PROJ" >/dev/null
adv silver-quality-gates "$PROJ" >/dev/null
assert_eq "re-completing a finished atom does not rewind" silver-plan "$(orch_state_get .current_flow)"
# Workflow bookkeeping via scripts/workflows.sh.
mkq WF-TEST-1
adv silver-quality-gates "$PROJ" >/dev/null
assert_eq "complete-flow called with the flow label" "complete-flow WF-TEST-1 QUALITY GATE" "$(head -1 "$WFLOG")"
mkq WF-TEST-1
WF_FAIL_LABEL="QUALITY GATE" adv silver-quality-gates "$PROJ" >/dev/null
assert_eq "complete-flow retried with the raw skill name" "complete-flow WF-TEST-1 silver-quality-gates" "$(sed -n 2p "$WFLOG")"
mkq WF-TEST-1
adv silver-quality-gates "" >/dev/null
assert_file_absent "no repo root: workflow script not called" "$WFLOG"
rm -f "$PROJ/scripts/workflows.sh.off"
mv "$PROJ/scripts/workflows.sh" "$PROJ/scripts/workflows.sh.off"
mkq WF-TEST-1
adv silver-quality-gates "$PROJ" >/dev/null
mv "$PROJ/scripts/workflows.sh.off" "$PROJ/scripts/workflows.sh"
assert_file_absent "no workflows.sh: nothing called" "$WFLOG"
# End of queue.
mkq
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, flow_queue:["silver-plan"], current_flow:"silver-plan"}')"
printf '{"next_skill":"x"}' >"$DIRF"
out="$(adv silver-plan "$PROJ")"
assert_eq "queue drained: no message" "" "$out"
assert_eq "queue drained: current flow empty" "" "$(orch_state_get .current_flow)"
assert_file_absent "queue drained: directive cleared" "$DIRF"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, flow_queue:["silver-plan"], current_flow:"silver-plan"}')"
printf '{"next_skill":"x"}' >"$DIRF"
_lib_dir="$TL_REPO_ROOT/hooks/lib" adv silver-plan "$PROJ" >/dev/null
assert_file_absent "queue drained: directive cleared via lib-dir context" "$DIRF"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, flow_queue:["silver-plan"], current_flow:"silver-plan", composer_chain:["silver-test"], active_intent:"i"}')"
out="$(adv silver-plan "$PROJ")"
assert_contains "queue drained with a chain: next composer starts" "$out" "Composer chain advanced to silver-test"
# A directive lib that cannot be found: advance still moves the state.
mkq
out="$(bash -c 'source "$1"; sb_orchestrator_advance_on_atom silver-plan ""' _ "$stg/orchestrator-state.sh")"
assert_contains "advance without directive/scheduler libs still messages" "$out" "Next flow: silver-validate"
assert_file_absent "no directive lib: no directive written" "$DIRF"
orch_write_state '{"flow_queue":["silver-execute"],"current_flow":"silver-execute"}'
bash -c 'source "$1"; sb_orchestrator_advance_on_atom silver-execute ""' _ "$stg/orchestrator-state.sh" >/dev/null
assert_eq "drain without directive lib" "" "$(orch_state_get .current_flow)"

echo "=== scheduler helpers without their library file ==="
# Helpers that happen to be declared must not be used when the scheduler lib is not beside this lib.
stg2="$(orch_stage_libs orchestrator-state.sh orchestrator-directive.sh)"
flag="$TL_TMP/sched-flag"
mkq
FLAG="$flag" bash -c 'source "$1"; sb_scheduler_runtime_enabled() { return 0; }; sb_scheduler_mark_handoff_joined() { touch "$FLAG"; }
  sb_scheduler_catalog_file() { return 1; }; sb_scheduler_active_batch_has_pending_joins() { return 1; }
  sb_orchestrator_advance_on_atom silver-plan ""' _ "$stg2/orchestrator-state.sh" >/dev/null
assert_file_absent "scheduler helpers not used without the lib file" "$flag"
assert_eq "advance still happened" silver-validate "$(orch_state_get .current_flow)"

echo "=== advance with an active scheduler batch ==="
mkbatch() {
  orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, active_intent:"i", flow_queue:["silver-fixture-read-a","silver-fixture-read-b","security"], current_flow:"silver-fixture-read-a",
    scheduler:{batches:[["AF-READ-A","AF-READ-B"],["AF-SECURE"]],active_batch_index:0,
     batch_dispatch:{batch_index:0,dispatch_mode:"parallel",handoffs:[
       {atomic_flow_id:"AF-READ-A",next_skill:"silver-fixture-read-a",next_worker_template:"FIXTURE-READ-A",dispatch_status:"dispatched",join_status:"pending"},
       {atomic_flow_id:"AF-READ-B",next_skill:"silver-fixture-read-b",next_worker_template:"FIXTURE-READ-B",dispatch_status:"pending",join_status:"pending"}]}}}')"
  rm -f "$DIRF" "$EVENTS"
}
mkbatch
out="$(adv silver-fixture-read-a "$PROJ")"
assert_eq "batch still has pending joins: no chain message" "" "$out"
assert_eq "held: current flow unchanged" silver-fixture-read-a "$(orch_state_get .current_flow)"
assert_eq "held: completion recorded" silver-fixture-read-a "$(orch_state_get .last_completed)"
assert_eq "held: handoff joined" joined "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
assert_eq "held: advance event flagged" true "$(jq -r 'select(.type=="advance")|.payload.held_for_batch' "$EVENTS")"
assert_eq "held: directive points at the remaining handoff" silver-fixture-read-b "$(orch_directive_get .next_skill)"
out="$(adv silver-fixture-read-b "$PROJ")"
assert_eq "joined batch hands over to the next batch: still held" "" "$out"
assert_eq "join gates evaluated for the completed atom" open "$(orch_state_get '.scheduler.join_gates["AF-READ-B"]')"
assert_eq "second batch became active" 1 "$(orch_state_get .scheduler.active_batch_index)"
assert_eq "second batch handoff awaits dispatch" AF-SECURE "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].atomic_flow_id')"
adv security "$PROJ" >/dev/null
assert_eq "final batch joined: queue drained" "" "$(orch_state_get .current_flow)"
assert_eq "final batch joined: status" joined "$(orch_state_get .scheduler.batch_dispatch.status)"
mkbatch
( unset -f sb_orchestrator_event_record_advance; adv silver-fixture-read-a "$PROJ" >/dev/null )
assert_eq "held without the event recorder" silver-fixture-read-a "$(orch_state_get .last_completed)"
mkbatch
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 adv silver-fixture-read-a "$PROJ" >/dev/null
assert_eq "scheduler disabled: plain advance" silver-fixture-read-b "$(orch_state_get .current_flow)"
mkbatch
SB_APO_CATALOG_FILE=/no/such/catalog adv silver-fixture-read-a "$PROJ" >/dev/null
assert_eq "no catalog: still joins and holds" silver-fixture-read-a "$(orch_state_get .last_completed)"

tl_results
