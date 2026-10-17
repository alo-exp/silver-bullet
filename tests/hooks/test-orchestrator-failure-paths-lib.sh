#!/usr/bin/env bash
# Failure-path tests for the orchestrator libs: every degrade-gracefully fallback
# (`cmd || true`, `cmd || echo default`) is driven by injecting the failure it guards against
# and asserting the observable result (fallback value used, state untouched, status code).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_RUNTIME_SCHEDULER SB_APO_CATALOG_FILE SB_ORCHESTRATOR_PARALLEL_DISPATCH SILVER_BULLET_TEST_HOOK_ENFORCED \
  SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT _lib_dir
export SILVER_BULLET_RUNTIME=claude
tl_stub sleep 'exit 0'
mkdir -p "$TL_TMP/cwd"
cd "$TL_TMP/cwd"
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
echo "=== directive lib ==="
reset
# The flow->skill table: mixed-case FLOW tokens fall through to the slug table.
assert_eq "FLOW-Quality-Gate slug" silver-quality-gates "$(sb_orchestrator_flow_to_skill FLOW-Quality-Gate)"
assert_eq "FLOW-Quality-Gate-Preship slug" silver-quality-gates "$(sb_orchestrator_flow_to_skill FLOW-Quality-Gate-Preship)"
assert_eq "FLOW-Devops-Quality-Gate-Preship slug" devops-quality-gates "$(sb_orchestrator_flow_to_skill FLOW-Devops-Quality-Gate-Preship)"
assert_eq "FLOW-Design-Handoff slug" silver-handoff "$(sb_orchestrator_flow_to_skill FLOW-Design-Handoff)"
assert_eq "FLOW-Secure slug" security "$(sb_orchestrator_flow_to_skill FLOW-Secure)"
assert_eq "FLOW-Novel slug" silver-novel "$(sb_orchestrator_flow_to_skill FLOW-Novel)"
assert_eq "bare lower-case name" silver-shout "$(sb_orchestrator_flow_to_skill SHOUT)"
# The worker-template mapper loads lazily; a lib whose directory vanished cannot load it.
gone="$(orch_stage_libs orchestrator-directive.sh)"
(
  unset -f sb_orchestrator_worker_template_for_skill
  # shellcheck disable=SC1091
  source "$gone/orchestrator-directive.sh"
  rm -rf "$gone"
  sb_orchestrator_directive_write silver-verify "" "" true
  [[ "$(jq -r .next_worker_template "$DIRF")" == null ]]
) && rc=0 || rc=$?
assert_eq "mapper dir gone: directive written without a template" 0 "$rc"
# The state directory cannot be created: nothing is written, the writers report failure.
rm -f "$DIRF"
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_directive_write silver-plan ) 2>/dev/null && rc=0 || rc=$?
assert_eq "directive_write with an uncreatable state dir fails" 1 "$((rc != 0))"
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_directive_write_batch silver-plan "" "" true "" '{"handoffs":[]}' ) 2>/dev/null && rc=0 || rc=$?
assert_eq "directive_write_batch with an uncreatable state dir fails" 1 "$((rc != 0))"
# jq cannot build the batch document.
orch_stub_failing jq 'batch_dispatch: $batch_dispatch'
sb_orchestrator_directive_write_batch silver-plan "" "" true TPL '{"handoffs":[]}' && rc=0 || rc=$?
assert_eq "batch document build failure" 1 "$rc"
assert_file_absent "no batch directive left behind" "$DIRF"
orch_unstub jq
# Override log: an unusable .planning/ directory is tolerated.
mkdir -p "$PROJ/.planning"
orch_stub_failing mkdir '.planning'
sb_orchestrator_log_override "$PROJ" "why" silver-plan && rc=0 || rc=$?
assert_eq "override log tolerates mkdir failure" 0 "$rc"
assert_eq "override entry still appended when the dir exists" 1 "$(wc -l <"$PROJ/.planning/orchestrator-override-log.jsonl" | tr -d ' ')"
orch_unstub mkdir
rm -f "$PROJ/.planning/orchestrator-override-log.jsonl"
mkdir -p "$PROJ/.planning/orchestrator-override-log.jsonl"
sb_orchestrator_log_override "$PROJ" "why" silver-plan && rc=0 || rc=$?
assert_eq "override log tolerates an unwritable log file" 0 "$rc"
rm -rf "$PROJ/.planning/orchestrator-override-log.jsonl"
# State sync: state file helper missing or jq failing degrade quietly.
orch_write_state '{"current_flow":"FLOW-PLAN","active_intent":"go"}'
sb_orchestrator_state_file() { return 1; }
sb_orchestrator_sync_directive_from_state
assert_eq "state_file helper failing: default path used" silver-plan "$(orch_directive_get .next_skill)"
rm -f "$DIRF"
sb_outcomes_session_file() { return 1; }
printf '%s' '{"outcomes":[{"id":"route","status":"pending"}]}' >"$SB_RUNTIME_STATE_DIR/outcomes-session.json"
sb_orchestrator_directive_from_pending_outcome
assert_eq "outcomes helper failing: default path used" silver "$(orch_directive_get .next_skill)"
unset -f sb_outcomes_session_file
source "$TL_REPO_ROOT/hooks/lib/orchestrator-state.sh"
rm -f "$DIRF"
orch_stub_failing jq '.current_flow // ""'
sb_orchestrator_sync_directive_from_state
orch_unstub jq
assert_file_absent "jq failing on current_flow: no directive" "$DIRF"
tl_stub head "exit 1"
hash -r
sb_orchestrator_sync_directive_from_state
orch_unstub head
assert_eq "head failing while trimming the intent: directive still written" silver-plan "$(orch_directive_get .next_skill)"

# ---------------------------------------------------------------------------------------
echo "=== event log lib ==="
reset
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_event_append t '{}' ) 2>/dev/null && rc=0 || rc=$?
assert_eq "append with an uncreatable log dir fails" 1 "$rc"
dirize "$EVENTS"
sb_orchestrator_event_record_dispatch AF-A silver-a T 1 2>/dev/null && rc=0 || rc=$?
assert_eq "dispatch recorder swallows an append failure" 0 "$rc"
rm -rf "$EVENTS"
orch_write_state '{"flow_queue":["a"]}'
( sb_orchestrator_state_file() { return 1; }; sb_orchestrator_event_resume_hints_json ) >"$TL_TMP/hints.out" && rc=0 || rc=$?
assert_eq "resume hints with a failing state helper" '{"resumable":false,"reason":"no orchestrator.json"}' "$(cat "$TL_TMP/hints.out")"
( sb_orchestrator_state_file() { return 1; }; sb_orchestrator_event_apply_resume_checkpoint ) && rc=0 || rc=$?
assert_eq "resume checkpoint with a failing state helper" 1 "$rc"

# ---------------------------------------------------------------------------------------
echo "=== parent lib ==="
reset
# Marker file with unparsable JSON and no usable spawned_at.
printf 'garbage' >"$MARKER"
sb_orchestrator_is_worker_session && rc=0 || rc=$?
assert_eq "garbage marker is not a worker" 1 "$rc"
# grep -o failing after grep -q matched (no jq available for the first read).
printf '{"spawned_at":"%s"}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$MARKER"
NOJQ="$(tl_path_without jq)"
orch_stub_failing grep '-oE'
nojq_dir="$TL_TMP/nojq-bin"
mkdir -p "$nojq_dir"
for b in "$NOJQ"/*; do n="${b##*/}"; [[ "$n" == grep ]] || ln -sf "$(readlink -f "$b")" "$nojq_dir/$n" 2>/dev/null || true; done
cp "$TL_BIN/grep" "$nojq_dir/grep"
PATH="$nojq_dir" sb_orchestrator_is_worker_session && rc=0 || rc=$?
assert_eq "grep -o failing: no spawn time, not a worker" 1 "$rc"
orch_unstub grep
# grep -o succeeding with nothing: spawned_at stays empty.
tl_stub grep 'if [[ "$1" == "-oE" ]]; then exit 0; fi; exec '"$(PATH="$NOJQ" command -v grep)"' "$@"'
cp "$TL_BIN/grep" "$nojq_dir/grep"
PATH="$nojq_dir" sb_orchestrator_is_worker_session && rc=0 || rc=$?
assert_eq "empty grep -o output: not a worker" 1 "$rc"
orch_unstub grep
# BSD date flavours where the first probe succeeds but the real conversion then fails.
real_date="$(command -v date)"
printf '{"spawned_at":"2024-01-01T00:00:00Z"}' >"$MARKER"
cnt="$TL_TMP/date-count"
for flag in -ju -j; do
  rm -f "$cnt"
  cat >"$TL_BIN/date" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"$flag -f"*)
    n=\$(cat "$cnt" 2>/dev/null || echo 0); echo \$((n+1)) >"$cnt"
    [[ \$n -eq 0 ]] && { echo 5; exit 0; }
    exit 1 ;;
  *"-ju -f"*|*"-j -f"*) exit 1 ;;
  "+%s") echo 100000 ;;
  *) exec "$real_date" "\$@" ;;
esac
STUB
  chmod +x "$TL_BIN/date"
  hash -r
  sb_orchestrator_is_worker_session && rc=0 || rc=$?
  assert_eq "date $flag probe ok, conversion fails: epoch 0 means not a worker" 1 "$rc"
done
orch_unstub date
rm -f "$MARKER"
# guard_applies: root resolver failing.
orch_make_project "$TL_TMP/gp"
( sb_find_project_root_walk_only() { return 1; }; cd "$TL_TMP/gp" && sb_orchestrator_guard_applies_to_workspace ) && rc=0 || rc=$?
assert_eq "root resolver failing: guard does not apply" 1 "$rc"
# mark / clear worker marker failure modes.
mkdir -p "$MARKER.tmp"
sb_orchestrator_mark_worker_spawn silver-plan 2>/dev/null && rc=0 || rc=$?
assert_eq "marker temp path blocked: spawn marking fails" 1 "$((rc != 0))"
rmdir "$MARKER.tmp"
( SB_RUNTIME_STATE_DIR="$NOTADIR/state"; sb_orchestrator_mark_worker_spawn silver-plan ) 2>/dev/null && rc=0 || rc=$?
assert_eq "uncreatable state dir: spawn marking fails" 1 "$((rc != 0))"
mkdir -p "$MARKER"
sb_orchestrator_clear_worker_marker && rc=0 || rc=$?
assert_eq "clearing a marker that is a directory is tolerated" 0 "$rc"
rmdir "$MARKER"
# state_applies_to_project fallbacks.
orch_write_state "$(jq -n --arg r "$PROJ" '{current_flow:"a",repo_root:$r}')"
( sb_orchestrator_state_file() { return 1; }; sb_orchestrator_state_applies_to_project "$PROJ" ) && rc=0 || rc=$?
assert_eq "state helper failing after the pending check" 1 "$rc"
orch_stub_failing jq '.repo_root'
sb_orchestrator_state_applies_to_project "$PROJ" && rc=0 || rc=$?
orch_unstub jq
assert_eq "jq failing on repo_root: unprovable" 1 "$rc"
orch_write_state '{"current_flow":"a","workflow_id":"WF1"}'
orch_stub_failing jq '.workflow_id'
sb_orchestrator_state_applies_to_project "$PROJ" && rc=0 || rc=$?
orch_unstub jq
assert_eq "jq failing on workflow_id: unprovable" 1 "$rc"
# jq disappears between the queue-pending check and the follow-up read.
orch_write_state "$(jq -n --arg r "$PROJ" '{current_flow:"a",repo_root:$r}')"
real_jq="$(command -v jq)"
vanish="$TL_TMP/vanish-bin"
mkdir -p "$vanish"
cat >"$vanish/jq" <<STUB
#!/usr/bin/env bash
rm -f "\$0"
exec "$real_jq" "\$@"
STUB
chmod +x "$vanish/jq"
( PATH="$vanish:$NOJQ"; hash -r; sb_orchestrator_state_applies_to_project "$PROJ" ) && rc=0 || rc=$?
hash -r
assert_eq "jq vanishing mid-check: unprovable" 1 "$rc"
# Bash classification without python.
assert_eq "no python3: unknown commands are not allowed" 1 "$((($(PATH="$(tl_path_without python3)" rc_of sb_orchestrator_parent_bash_allowed "ls")) != 0))"
# Without the classifier lib there is no read-only allowance.
nl="$(orch_stage_libs orchestrator-parent.sh)"
assert_eq "no classifier: refused" 1 "$(bash -c 'source "$1"; sb_orchestrator_parent_bash_allowed "git status" >/dev/null; echo $?' _ "$nl/orchestrator-parent.sh")"

# ---------------------------------------------------------------------------------------
echo "=== skill-atom lib ==="
GARB="$TL_TMP/garbage-catalog.json"
printf 'garbage' >"$GARB"
sb_scheduler_resolve_atom_id "$GARB" silver-thing >/dev/null && rc=0 || rc=$?
assert_eq "unreadable catalog resolves nothing" 1 "$rc"
( sb_orchestrator_flow_to_skill() { return 1; }; sb_scheduler_resolve_atom_id "$GARB" FLOW-THING ) >/dev/null && rc=0 || rc=$?
assert_eq "failing normaliser: nothing resolved" 1 "$rc"
( sb_orchestrator_flow_to_skill() { return 1; }; sb_scheduler_resolve_atom_id "$CAT" FLOW-PLAN ) >/dev/null && rc=0 || rc=$?
assert_eq "failing normaliser: only direct matches resolve" 1 "$rc"
# A reverse lookup can only ever return an AF id for AF tokens, which resolve earlier.
assert_eq "AF tokens never reach the reverse lookup" AF-PLAN "$(sb_scheduler_resolve_atom_id "$CAT" AF-PLAN)"

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
( sb_scheduler_refresh_active_batch_dispatch() { return 1; }; sb_orchestrator_on_composer_start silver-test "x" "$PROJ" >/dev/null )
assert_file_exists "batch refresh failing: composer start still completes" "$STATE"
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
bash -c 'unset SB_APO_CATALOG_FILE; source "$1"; sb_orchestrator_advance_on_atom silver-plan ""' _ "$tree/orchestrator-state.sh" >/dev/null
assert_eq "no catalog reachable: plain advance" silver-validate "$(orch_state_get .current_flow)"

# ---------------------------------------------------------------------------------------
echo "=== scheduler lib ==="
reset
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r}')"
orch_stub_failing jq '.repo_root'
sb_scheduler_write_plan_to_state '{"batches":[]}' && rc=0 || rc=$?
orch_unstub jq
assert_eq "repo_root read failing: plan still stored" 0 "$rc"
assert_eq "plan stored despite the failing root read" "[]" "$(orch_state_get '.scheduler.batches|tojson')"
sb_scheduler_write_plan_to_state '{"batches":[]}' && rc=0 || rc=$?
assert_eq "plan with no batches: refresh failing is tolerated" 0 "$rc"
printf 'garbage' >"$STATE"
sb_scheduler_plan_queue_from_state "$PROJ" >/dev/null && rc=0 || rc=$?
assert_eq "corrupt state: no queue to plan" 1 "$rc"
orch_write_state '{"flow_queue":5}'
sb_scheduler_plan_queue_from_state "$PROJ" >/dev/null && rc=0 || rc=$?
assert_eq "non-array queue: nothing planned" 1 "$rc"
# Composition log: mkdir failing is tolerated.
orch_stub_failing mkdir 'planning'
sb_scheduler_append_composition_log "$PROJ" '{"x":1}' && rc=0 || rc=$?
orch_unstub mkdir
assert_eq "log append with a failing mkdir (dir exists)" 0 "$rc"
# Tailoring with an unwritable composition log / failing workflow-id lookup.
bad="$NOTADIR/proj"
sb_scheduler_apply_doc_only_tailoring "$bad" silver-fast "README badge only" && rc=0 || rc=$?
assert_eq "doc-only (fast) with an unwritable log" 0 "$rc"
sb_scheduler_apply_doc_only_tailoring "$bad" silver-feature "README badge only" && rc=0 || rc=$?
assert_eq "doc-only (feature) with an unwritable log" 0 "$rc"
obs="structured logging runbook with zero API and no UI"
sb_scheduler_apply_observability_tailoring "$bad" silver-fast "$obs" && rc=0 || rc=$?
assert_eq "observability (fast) with an unwritable log" 0 "$rc"
sb_scheduler_apply_observability_tailoring "$bad" silver-feature "$obs" && rc=0 || rc=$?
assert_eq "observability (feature) with an unwritable log" 0 "$rc"
multi="greenfield waitlist micro-SaaS with an API, docker packaging, and ship readiness"
rm -f "$STATE"
sb_scheduler_apply_multi_workflow_chain "$bad" silver-feature "$multi" && rc=0 || rc=$?
assert_eq "multi-chain with an unwritable log" 0 "$rc"
sb_scheduler_apply_net_new_workflow_route "$bad" silver-new-workflow "posture audit" && rc=0 || rc=$?
assert_eq "net-new composer with an unwritable log" 0 "$rc"
sb_scheduler_apply_net_new_workflow_route "$bad" silver-feature "posture audit" && rc=0 || rc=$?
assert_eq "net-new routing with an unwritable log" 0 "$rc"
(
  sb_scheduler_composer_catalog_workflow_id() { return 1; }
  sb_scheduler_apply_doc_only_tailoring "$PROJ" silver-fast "README badge only"
  sb_scheduler_apply_observability_tailoring "$PROJ" silver-fast "$obs"
  sb_scheduler_apply_multi_workflow_chain "$PROJ" silver-feature "$multi"
  sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-feature "posture audit"
)
log="$PROJ/.planning/orchestrator-composition-log.jsonl"
assert_contains "fallback workflow ids used when the lookup fails" "$(cat "$log")" "WF-SILVER-FEATURE"
assert_contains "fallback fast workflow id" "$(cat "$log")" "WF-SILVER-FAST"
assert_contains "fallback devops workflow id" "$(cat "$log")" "WF-SILVER-DEVOPS"
assert_contains "fallback release workflow id" "$(cat "$log")" "WF-SILVER-RELEASE"
assert_contains "fallback new-workflow id" "$(cat "$log")" "WF-SILVER-NEW-WORKFLOW"
rm -f "$log"
# State helper / jq failures while recording the chain.
( sb_orchestrator_state_file() { return 1; }
  sb_scheduler_apply_multi_workflow_chain "$PROJ" silver-feature "$multi"
  sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-feature "posture audit" ) && rc=0 || rc=$?
assert_eq "state helper failing: chain recording skipped" 0 "$rc"
orch_write_state '{"flow_queue":["a"]}'
orch_stub_failing jq '.composer_chain = $chain'
sb_scheduler_apply_multi_workflow_chain "$PROJ" silver-feature "$multi" || true
sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-feature "posture audit" || true
orch_unstub jq
assert_eq "jq failing on the chain: no chain stored" null "$(orch_state_get .composer_chain)"
rm -f "$log"
# Join-gate evaluation with an unreadable catalog.
orch_write_state '{"flow_queue":["a"]}'
SB_APO_CATALOG_FILE="$GARB" sb_scheduler_eval_join_gate "$PROJ" AF-PLAN >"$TL_TMP/gate.out" || true
assert_eq "unreadable catalog: no owned steps, gate opens" open "$(cat "$TL_TMP/gate.out")"
printf 'garbage' >"$STATE"
SB_APO_CATALOG_FILE="$CAT" sb_scheduler_workflow_completion_blocked "$PROJ" && rc=0 || rc=$?
assert_eq "corrupt state: completion not blocked" 1 "$rc"
( sb_orchestrator_state_file() { return 1; }; sb_scheduler_active_batch_has_pending_joins ) && rc=0 || rc=$?
assert_eq "pending joins with a failing state helper" 1 "$rc"
# Tier probe failing.
stage="$(orch_stage_libs orchestrator-scheduler.sh orchestrator-state.sh orchestrator-skill-atom.sh orchestrator-event-log.sh orchestrator-directive.sh orchestrator-parent.sh capability-tier.sh)"
printf '%s\n' 'sb_capability_tier_number() { return 1; }' >"$stage/capability-tier.sh"
assert_eq "tier probe failing: sequential" 1 "$(bash -c 'source "$1"; sb_scheduler_host_supports_parallel_dispatch; echo $?' _ "$stage/orchestrator-scheduler.sh" 2>/dev/null | tail -1)"
# Catalog parsing failures.
sb_scheduler_worker_template_for_atom "$GARB" AF-PLAN >/dev/null && rc=0 || rc=$?
assert_eq "unreadable catalog: no worker template" 1 "$rc"
( sb_orchestrator_flow_to_skill() { return 1; }
  [[ "$(sb_scheduler_skill_for_atom "$CAT" AF-DEP)" == silver-dep ]] ) && rc=0 || rc=$?
assert_eq "failing flow_to_skill: slug-derived skill" 0 "$rc"
( sb_orchestrator_flow_to_skill() { return 1; }
  [[ "$(sb_scheduler_skill_for_atom "$GARB" AF-DEP 2>/dev/null)" == AF-DEP ]] ) 2>/dev/null && rc=0 || rc=$?
assert_eq "failing flow_to_skill and unreadable slug: token returned" 0 "$rc"
# Refresh/dispatch/join failure injection.
mkbd() {
  orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, active_intent:"i", scheduler:{batches:[["AF-READ-A","AF-READ-B"],["AF-PLAN"]],active_batch_index:0}}')"
  rm -f "$DIRF" "$EVENTS"
}
mkbd
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_scheduler_refresh_active_batch_dispatch "$PROJ" && rc=0 || rc=$?
assert_eq "scheduler disabled: no dispatch refresh" 1 "$rc"
mkbd
( sb_scheduler_write_batch_directive() { return 1; }; sb_scheduler_refresh_active_batch_dispatch "$PROJ" ) && rc=0 || rc=$?
assert_eq "directive writer failing: refresh still succeeds" 0 "$rc"
printf 'garbage' >"$STATE"
sb_scheduler_write_batch_directive "$PROJ" && rc=0 || rc=$?
assert_eq "corrupt state: no batch directive" 1 "$rc"
orch_write_state '{"active_intent":"x","scheduler":{"batch_dispatch":{"handoffs":[{"next_skill":"silver-a","dispatch_status":"pending"}]}}}'
orch_stub_failing jq '.active_intent'
sb_scheduler_write_batch_directive "$PROJ"
orch_unstub jq
assert_eq "intent read failing: directive still written" silver-a "$(orch_directive_get .next_skill)"
# mark dispatched / joined.
mkbatch2() {
  orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,scheduler:{batch_dispatch:{batch_index:1,status:"pending_dispatch",handoffs:[
    {atomic_flow_id:"AF-PLAN",next_skill:"silver-plan",next_worker_template:"PLAN",dispatch_status:"pending",join_status:"pending"}]}}}')"
  rm -f "$EVENTS" "$DIRF"
}
mkbatch2
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_scheduler_mark_handoff_dispatched "" silver-plan
assert_eq "scheduler disabled: skill-only dispatch matches by next_skill" dispatched "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].dispatch_status')"
mkbatch2
orch_stub_failing jq '.scheduler.batch_dispatch.batch_index'
sb_scheduler_mark_handoff_dispatched AF-PLAN silver-plan
orch_unstub jq
assert_eq "batch index read failing: dispatch still recorded" dispatched "$(orch_state_get .scheduler.batch_dispatch.status)"
mkbatch2
orch_stub_failing jq 'next_worker_template // ""'
sb_scheduler_mark_handoff_dispatched AF-PLAN silver-plan
orch_unstub jq
assert_eq "template read failing: dispatch still recorded" dispatched "$(orch_state_get .scheduler.batch_dispatch.status)"
mkbatch2
( sb_orchestrator_event_record_dispatch() { return 1; }; sb_scheduler_mark_handoff_dispatched AF-PLAN silver-plan ) && rc=0 || rc=$?
assert_eq "event recorder failing: dispatch marking succeeds" 0 "$rc"
mkbatch2
dirize "$EVENTS"
sb_scheduler_mark_handoff_joined AF-PLAN "" 2>/dev/null && rc=0 || rc=$?
rm -rf "$EVENTS"
assert_eq "event log unwritable: join marking succeeds" 0 "$rc"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,scheduler:{batches:[["AF-PLAN"],[]],active_batch_index:0,batch_dispatch:{handoffs:[{atomic_flow_id:"AF-PLAN",next_skill:"silver-plan",join_status:"pending"}]}}}')"
sb_scheduler_mark_handoff_joined AF-PLAN ""
assert_eq "next batch empty: refresh failure tolerated, index advanced" 1 "$(orch_state_get .scheduler.active_batch_index)"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,scheduler:{batch_dispatch:{handoffs:[{atomic_flow_id:"AF-PLAN",next_skill:"silver-plan",join_status:"pending"},{atomic_flow_id:"AF-X",join_status:"pending"}]}}}')"
sb_scheduler_mark_handoff_joined AF-PLAN ""
assert_eq "pending handoff without a skill: join still recorded" joined "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
# project scoping / stop-block helpers with broken state.
( sb_orchestrator_state_file() { return 1; }
  sb_scheduler_state_applies_to_project "$PROJ" ) && rc=0 || rc=$?
assert_eq "state_applies with a failing state helper" 1 "$rc"
printf 'garbage' >"$STATE"
sb_scheduler_state_applies_to_project "$PROJ" && rc=0 || rc=$?
assert_eq "state_applies with a corrupt state" 1 "$rc"
( sb_orchestrator_state_file() { return 1; }
  sb_scheduler_parent_stop_blocked "$PROJ" ) && rc=0 || rc=$?
assert_eq "stop_blocked with a failing state helper" 1 "$rc"
sb_scheduler_parent_stop_blocked && rc=0 || rc=$?
assert_eq "stop_blocked with a corrupt state" 1 "$rc"
assert_eq "stop-block reason with a corrupt state falls back" "Orchestrator scheduler: pending dispatch or join work remains." "$(sb_scheduler_parent_stop_block_reason)"
( sb_orchestrator_state_file() { return 1; }
  sb_scheduler_parent_stop_block_reason ) >"$TL_TMP/reason.out"
assert_eq "stop-block reason with a failing state helper" "Orchestrator scheduler: pending batch dispatch." "$(cat "$TL_TMP/reason.out")"
orch_write_state '{"scheduler":{"batch_dispatch":{"status":"joined","handoffs":[{"atomic_flow_id":"AF-A","join_status":"joined"}]}}}'
orch_stub_failing jq '.scheduler.batch_dispatch.status'
sb_scheduler_parent_stop_blocked && rc=0 || rc=$?
orch_unstub jq
assert_eq "batch status read failing: falls through to the handoff check" 1 "$rc"
orch_write_state '{"scheduler":{"batch_dispatch":{"status":"joined","handoffs":[{"atomic_flow_id":"AF-A","join_status":"pending"}]}}}'
orch_stub_failing jq 'atomic_flow_id'
sb_scheduler_parent_stop_blocked && rc=0 || rc=$?
orch_unstub jq
assert_eq "handoff read failing: not blocked by it" 1 "$rc"
orch_stub_failing jq 'to_entries'
sb_scheduler_parent_stop_blocked && rc=0 || rc=$?
assert_eq "gate and step reads failing: the pending handoff still blocks" 0 "$rc"
sb_scheduler_parent_stop_block_reason >/dev/null
orch_unstub jq
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[{"join_status":"pending","next_skill":"silver-b"}]}}}'
orch_stub_failing jq 'batch_dispatch // empty'
assert_eq "batch read failing: generic reason" "Orchestrator scheduler: pending dispatch or join work remains." "$(sb_scheduler_parent_stop_block_reason)"
orch_unstub jq

tl_results
