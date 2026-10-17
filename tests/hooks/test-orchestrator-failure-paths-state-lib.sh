#!/usr/bin/env bash
# Failure-path tests for the orchestrator libs: every degrade-gracefully fallback
# (`cmd || true`, `cmd || echo default`) is driven by injecting the failure it guards against
# and asserting the observable result (fallback value used, state untouched, status code).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init claude
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_RUNTIME_SCHEDULER SB_APO_CATALOG_FILE SB_ORCHESTRATOR_PARALLEL_DISPATCH SILVER_BULLET_TEST_HOOK_ENFORCED \
  SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT _lib_dir
export SILVER_BULLET_RUNTIME=claude
tl_stub sleep 'exit 0'
GARB="$TL_TMP/garbage-catalog.json"
printf garbage >"$GARB"
mkdir -p "$TL_TMP/cwd"
cd "$TL_TMP/cwd"
# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh"
# shellcheck source=../../hooks/lib/orchestrator-scheduler.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"

CAT="$TL_TMP/catalog.json"
orch_fixture_catalog "$CAT"
export SB_APO_CATALOG_FILE="$CAT"
PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
STATE="$(orch_state_file)"
DIRF="$(orch_directive_file)"
EVENTS="$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"
MARKER="$(sb_orchestrator_worker_marker_file)"
NOTADIR="$TL_TMP/regular-file"
: >"$NOTADIR"
dirize() { rm -rf "$1"; mkdir -p "$1"; }
rc_of() { "$@" >/dev/null 2>&1 && echo 0 || echo $?; }
# Reset per-case files.
reset() { rm -rf "$STATE" "$DIRF" "$EVENTS" "$MARKER" "$SB_RUNTIME_STATE_DIR/orchestrator-saga.json"; }

# ---------------------------------------------------------------------------------------

echo "=== state lib ==="
reset
( sb_orchestrator_queue_for_composer() { printf 'silver-plan,,silver-ship'; }; sb_orchestrator_flow_csv_for_workflows silver-test ) >"$TL_TMP/csv.out"
assert_eq "empty queue tokens are skipped in the workflow CSV" "PLAN,SHIP" "$(cat "$TL_TMP/csv.out")"
orch_write_state '{"flow_queue":["silver-plan","silver-ship"]}'
orch_stub_failing jq '.flow_queue[$i]'
sb_orchestrator_queue_index_for_atom silver-ship "$STATE" >/dev/null && rc=0 || rc=$?
orch_unstub jq
assert_eq "jq failing per token: no index" 1 "$rc"
rm -f "$STATE"
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_write_json '{"a":1}' ) 2>/dev/null && rc=0 || rc=$?
assert_eq "write_json with an uncreatable dir fails" 1 "$((rc != 0))"
# clear_queue with an unusable state helper and undeletable files.
orch_write_state '{"a":1}'
( sb_orchestrator_state_file() { return 1; }; sb_orchestrator_clear_queue )
assert_file_absent "clear_queue falls back to the default state path" "$STATE"
rm -f "$STATE"; mkdir -p "$STATE"
sb_orchestrator_clear_queue && rc=0 || rc=$?
assert_eq "clear_queue tolerates an undeletable state path" 0 "$rc"
rmdir "$STATE"
mkdir -p "$DIRF"
( unset -f sb_orchestrator_directive_clear; sb_orchestrator_clear_queue ) && rc=0 || rc=$?
assert_eq "clear_queue tolerates an undeletable directive path" 0 "$rc"
rmdir "$DIRF"

# Composer start with failure injection.
WF="$PROJ/scripts"
mkdir -p "$WF"
cat >"$WF/workflows.sh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$WF/workflows.sh"
reset
out="$(sb_orchestrator_on_composer_start plain "x" "$PROJ")"
assert_eq "workflows.sh failing: no workflow id" "" "$out"
assert_eq "non-silver composer has no catalog workflow" null "$(jq -r '.selected_workflow' "$PROJ/.planning/orchestrator-composition-log.jsonl" | head -1)"
rm -f "$PROJ/.planning/orchestrator-composition-log.jsonl"
orch_stub_failing mkdir '.planning'
reset
sb_orchestrator_on_composer_start silver-test "x" "$PROJ" >/dev/null
orch_unstub mkdir
assert_file_exists "composer start survives a failing mkdir" "$STATE"
rm -f "$PROJ/.planning/orchestrator-composition-log.jsonl"
# Scheduler plan append/refresh failures.
cat >"$WF/workflows.sh" <<'STUB'
#!/usr/bin/env bash
case "$1" in start) echo WF-FP-1 ;; esac
STUB
reset
mkdir -p "$PROJ/.planning/orchestrator-composition-log.jsonl"
out="$(sb_orchestrator_on_composer_start silver-test "x" "$PROJ")"
rm -rf "$PROJ/.planning/orchestrator-composition-log.jsonl"
assert_eq "composition log unwritable: workflow id still returned" WF-FP-1 "$out"
reset
orch_stub_failing jq 'host_parallel_capable'
out="$(sb_orchestrator_on_composer_start silver-test "x" "$PROJ")"
orch_unstub jq
assert_eq "batch refresh failing: composer start still returns the id" WF-FP-1 "$out"
assert_eq "batch refresh failing: no batch dispatch recorded" null "$(orch_state_get .scheduler.batch_dispatch)"
# The event jq failing.
reset
orch_stub_failing jq 'selected_workflow: (if'
out="$(sb_orchestrator_on_composer_start silver-test "x" "$PROJ")"
orch_unstub jq
assert_eq "event payload jq failing: composer start still returns the id" WF-FP-1 "$out"
# Event-less variants via override of the scheduler helper that fails to resolve a workflow.
reset
( sb_scheduler_composer_catalog_workflow_id() { return 1; }; sb_orchestrator_on_composer_start silver-test "x" "$PROJ" >/dev/null )
assert_file_exists "no catalog workflow id: state still seeded" "$STATE"
rm -f "$PROJ/.planning/orchestrator-composition-log.jsonl"

# Composer chain failure injection.
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"],"active_intent":"go"}'
orch_stub_failing jq '.composer_chain[0] // empty'
sb_orchestrator_try_advance_composer_chain "$PROJ" >/dev/null && rc=0 || rc=$?
orch_unstub jq
assert_eq "jq failing on next composer: no advance" 1 "$rc"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"],"active_intent":"go"}'
orch_stub_failing jq '.composer // ""'
out="$(sb_orchestrator_try_advance_composer_chain "$PROJ")"
orch_unstub jq
assert_contains "jq failing on the completed composer: chain still advances" "$out" "Composer chain advanced to silver-test"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test","silver-release"],"active_intent":"go"}'
orch_stub_failing jq '.composer_chain[1:]'
out="$(sb_orchestrator_try_advance_composer_chain "$PROJ")"
orch_unstub jq
assert_contains "jq failing on the saved chain: falls back to an empty chain" "$out" "Composer chain advanced"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"],"active_intent":"go"}'
orch_stub_failing jq '.active_intent'
out="$(sb_orchestrator_try_advance_composer_chain "$PROJ")"
orch_unstub jq
assert_contains "jq failing on the intent: chain still advances" "$out" "Composer chain advanced"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"],"active_intent":"go"}'
orch_stub_failing jq '.composer_chain = $chain'
out="$(sb_orchestrator_try_advance_composer_chain "$PROJ")"
orch_unstub jq
assert_contains "jq failing on the chain rewrite: chain still advances" "$out" "Composer chain advanced"
dirize "$EVENTS"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"],"active_intent":"go"}'
out="$(sb_orchestrator_try_advance_composer_chain "$PROJ" 2>/dev/null)"
rm -rf "$EVENTS"
assert_contains "event log unwritable: chain still advances" "$out" "Composer chain advanced"
orch_write_state '{"composer":"silver-feature","composer_chain":["silver-test"],"active_intent":"go"}'
out="$( sb_orchestrator_on_composer_start() { return 1; }; sb_orchestrator_try_advance_composer_chain "$PROJ")"
assert_contains "restart failing: the chain message is still produced" "$out" "Composer chain advanced to silver-test"

# advance_on_atom failure injection.
mkq() {
  orch_write_state "$(jq -n --arg r "$PROJ" --arg w "${1:-}" '{repo_root:$r, workflow_id:$w, active_intent:"i",
    flow_queue:["silver-plan","silver-validate","silver-execute"], current_flow:"silver-plan"}')"
  rm -f "$DIRF" "$EVENTS"
}
cat >"$WF/workflows.sh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
mkq WF1
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ" >/dev/null
assert_eq "both complete-flow attempts failing: advance continues" silver-validate "$(orch_state_get .current_flow)"
for pat in '.workflow_id' '// -1'; do
  mkq WF1
  orch_stub_failing jq "$pat"
  SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ" >/dev/null
  orch_unstub jq
  assert_eq "jq failing on '$pat': advance still works" silver-validate "$(orch_state_get .current_flow)"
done
mkq
orch_stub_failing jq '.flow_queue | length'
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ" >/dev/null
orch_unstub jq
assert_eq "queue length unreadable: nothing is searched, nothing advances" silver-plan "$(orch_state_get .current_flow)"
mkq
orch_stub_failing jq '.flow_queue[$i] // ""'
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ" >/dev/null
orch_unstub jq
assert_eq "jq failing on every token read: nothing matches, nothing advances" silver-plan "$(orch_state_get .current_flow)"
mkq
orch_stub_failing_nth jq '.flow_queue[$i] // ""' 2
out="$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ")"
orch_unstub jq
assert_eq "next flow unreadable: no chaining message" "" "$out"
assert_eq "next flow unreadable: current flow cleared" "" "$(orch_state_get .current_flow)"
mkq
orch_stub_failing jq '.current_flow = $next'
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ" >/dev/null
orch_unstub jq
assert_eq "jq failing on the state update: state untouched" silver-plan "$(orch_state_get .current_flow)"
mkq
orch_stub_failing jq '.active_intent'
out="$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ")"
orch_unstub jq
assert_contains "jq failing on the intent: message still produced" "$out" "Next flow: silver-validate"
mkq
dirize "$EVENTS"
out="$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ" 2>/dev/null)"
rm -rf "$EVENTS"
assert_contains "event log unwritable: message still produced" "$out" "Next flow: silver-validate"
# The directive-lib present via the lib-dir context: intent read failing.
mkq
orch_stub_failing jq '.active_intent'
_lib_dir="$TL_REPO_ROOT/hooks/lib" SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_orchestrator_advance_on_atom silver-plan "$PROJ" >/dev/null
orch_unstub jq
assert_eq "lib-dir context: intent read failing, directive still written" silver-validate "$(orch_directive_get .next_skill)"
# Scheduler-enabled hold path.
mkbatch() {
  orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, active_intent:"i", flow_queue:["silver-fixture-read-a","silver-fixture-read-b"], current_flow:"silver-fixture-read-a",
    scheduler:{batches:[["AF-READ-A","AF-READ-B"]],active_batch_index:0,
     batch_dispatch:{batch_index:0,dispatch_mode:"parallel",handoffs:[
       {atomic_flow_id:"AF-READ-A",next_skill:"silver-fixture-read-a",next_worker_template:"FIXTURE-READ-A",dispatch_status:"dispatched",join_status:"pending"},
       {atomic_flow_id:"AF-READ-B",next_skill:"silver-fixture-read-b",next_worker_template:"FIXTURE-READ-B",dispatch_status:"pending",join_status:"pending"}]}}}')"
  rm -f "$DIRF" "$EVENTS"
}
mkbatch
orch_stub_failing jq 'join_gates'
sb_orchestrator_advance_on_atom silver-fixture-read-a "$PROJ" >/dev/null
orch_unstub jq
assert_eq "join gate refresh failing: handoff still joined" joined "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
mkbatch
orch_stub_failing jq '.last_completed_index = $idx | .updated_at'
sb_orchestrator_advance_on_atom silver-fixture-read-a "$PROJ" >/dev/null
orch_unstub jq
assert_eq "hold update failing: queue state untouched" silver-fixture-read-a "$(orch_state_get .current_flow)"
mkbatch
dirize "$EVENTS"
sb_orchestrator_advance_on_atom silver-fixture-read-a "$PROJ" >/dev/null 2>&1
rm -rf "$EVENTS"
assert_eq "hold with an unwritable event log: completion recorded" silver-fixture-read-a "$(orch_state_get .last_completed)"
# A pending handoff without a skill: the batch directive cannot be written but the hold stands.
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, flow_queue:["silver-fixture-read-a","silver-fixture-read-b"], current_flow:"silver-fixture-read-a",
  scheduler:{batch_dispatch:{batch_index:0,handoffs:[{atomic_flow_id:"AF-X",join_status:"pending"},{atomic_flow_id:"AF-READ-A",next_skill:"silver-fixture-read-a",join_status:"pending"}]}}}')"
rm -f "$DIRF"
sb_orchestrator_advance_on_atom silver-fixture-read-a "$PROJ" >/dev/null
assert_file_absent "unusable handoff: no directive written" "$DIRF"
assert_eq "unusable handoff: still held" silver-fixture-read-a "$(orch_state_get .current_flow)"
# Scheduler enabled but no catalog is reachable from this lib location.
tree="$(orch_stage_libs orchestrator-state.sh orchestrator-scheduler.sh orchestrator-skill-atom.sh orchestrator-event-log.sh orchestrator-directive.sh orchestrator-parent.sh)"
mkq
bash -c 'unset SB_APO_CATALOG_FILE; source "$1"; sb_orchestrator_advance_on_atom silver-plan ""' _ "$tree/orchestrator-scheduler.sh" >/dev/null
assert_eq "no catalog reachable: plain advance" silver-validate "$(orch_state_get .current_flow)"

# ---------------------------------------------------------------------------------------

tl_results
