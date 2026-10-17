#!/usr/bin/env bash
# Unit tests for hooks/lib/orchestrator-scheduler.sh (catalog lookup, batch planning,
# composition tailoring, join gates, batch dispatch/join bookkeeping, stop blocking).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init claude
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_RUNTIME_SCHEDULER SB_APO_CATALOG_FILE SB_ORCHESTRATOR_PARALLEL_DISPATCH SILVER_BULLET_TEST_HOOK_ENFORCED
export SILVER_BULLET_RUNTIME=claude
# shellcheck source=../../hooks/lib/orchestrator-scheduler.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-scheduler.sh"

NOJQ="$(tl_path_without jq)"
REAL_JQ="$(command -v jq)"
# stub_jq_failing_on PATTERN: jq that fails whenever any argument contains PATTERN, else real jq.
stub_jq_failing_on() {
  tl_stub jq "for a in \"\$@\"; do [[ \"\$a\" == *'$1'* ]] && exit 1; done; exec $REAL_JQ \"\$@\""
  hash -r
}
NOPY="$(tl_path_without python3)"
CAT="$TL_TMP/catalog.json"
orch_fixture_catalog "$CAT"
export SB_APO_CATALOG_FILE="$CAT"
PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
STATE="$(orch_state_file)"
rc_of() { "$@" >/dev/null 2>&1 && echo 0 || echo $?; }

echo "=== runtime enabled ==="
for v in 0 false no FALSE NO off OFF; do
  assert_eq "SB_ORCHESTRATOR_RUNTIME_SCHEDULER=$v disables" 1 "$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=$v rc_of sb_scheduler_runtime_enabled)"
done
assert_eq "default enabled" 0 "$(rc_of sb_scheduler_runtime_enabled)"
assert_eq "other values enable" 0 "$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=1 rc_of sb_scheduler_runtime_enabled)"

echo "=== catalog file ==="
assert_eq "env catalog wins" "$CAT" "$(sb_scheduler_catalog_file "$PROJ")"
assert_eq "disabled scheduler has no catalog" 1 "$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 rc_of sb_scheduler_catalog_file "$PROJ")"
mkdir -p "$PROJ/docs"
cp "$CAT" "$PROJ/docs/apo-catalog.json"
assert_eq "env pointing at a missing file is ignored" "$PROJ/docs/apo-catalog.json" "$(SB_APO_CATALOG_FILE=/no/such sb_scheduler_catalog_file "$PROJ")"
assert_contains "plugin catalog is the last resort" "$(unset SB_APO_CATALOG_FILE; sb_scheduler_catalog_file "")" "/../../docs/apo-catalog.json"
stg="$(dirname "$(dirname "$(orch_stage_libs orchestrator-scheduler.sh orchestrator-state.sh orchestrator-skill-atom.sh orchestrator-event-log.sh orchestrator-directive.sh orchestrator-parent.sh)")")"
assert_eq "no catalog anywhere" 1 "$(bash -c 'unset SB_APO_CATALOG_FILE; source "$1"; sb_scheduler_catalog_file "" >/dev/null; echo $?' _ "$stg/hooks/lib/orchestrator-scheduler.sh")"

echo "=== mutation scope conflicts ==="
assert_eq "overlap conflicts" 0 "$(rc_of sb_scheduler_mutation_scopes_conflict '["a","b"]' '["b","c"]')"
assert_eq "disjoint scopes" 1 "$(rc_of sb_scheduler_mutation_scopes_conflict '["a"]' '["c"]')"
assert_eq "empty scopes" 1 "$(rc_of sb_scheduler_mutation_scopes_conflict '[]' '["c"]')"
assert_eq "no jq" 1 "$(PATH="$NOJQ" rc_of sb_scheduler_mutation_scopes_conflict '["a"]' '["a"]')"
assert_eq "invalid JSON" 1 "$((($(rc_of sb_scheduler_mutation_scopes_conflict 'x' '[]')) != 0))"

echo "=== plan batches ==="
assert_eq "no catalog" 1 "$(rc_of sb_scheduler_plan_batches_json "" '[]')"
assert_eq "missing catalog file" 1 "$(rc_of sb_scheduler_plan_batches_json /no/such '[]')"
assert_eq "no python3" 1 "$(PATH="$NOPY" rc_of sb_scheduler_plan_batches_json "$CAT" '[]')"
plan="$(sb_scheduler_plan_batches_json "$CAT" '["AF-READ-A","AF-READ-B","AF-READ-C","AF-PLAN","AF-DEP","AF-LATER","AF-GHOST"]')"
assert_eq "batches" '[["AF-READ-A","AF-READ-B"],["AF-READ-C"],["AF-PLAN"],["AF-DEP"],["AF-LATER"]]' "$(jq -c .batches <<<"$plan")"
dec() { jq -r --arg a "$1" '.scheduler_decisions[] | select(.atom_id==$a) | .decision + "|" + .rationale' <<<"$plan"; }
assert_eq "parallel decision" "parallel|dependency inputs satisfied and mutation scopes do not conflict" "$(dec AF-READ-A)"
assert_eq "conflict decision" "serialized|mutation scope conflict with prior batch: a" "$(dec AF-READ-C)"
assert_eq "non-parallelizable decision" "serialized|atom is not parallelizable per catalog execution metadata" "$(dec AF-PLAN)"
assert_eq "dependency decision" "serialized|catalog depends_on_atoms unsatisfied: AF-LATER" "$(dec AF-DEP)"
assert_eq "unknown atoms are skipped" "skip|unknown catalog atom" "$(dec AF-GHOST)"
rec() { jq -r --arg a "$1" "[.dispatch_records[] | select(.atomic_flow_id==\$a)][0] | $2" <<<"$plan"; }
assert_eq "record carries worker template" templates/orchestrator-workers/PLAN.md "$(rec AF-PLAN .worker_template)"
assert_eq "record carries dispatch shape" plan-shape "$(rec AF-PLAN .dispatch_record_shape)"
assert_eq "record scheduling" parallel "$(rec AF-READ-A .scheduling)"
assert_eq "record serialization rationale (conflict)" "mutation scope conflict: a" "$(rec AF-READ-C .serialization_rationale)"
assert_eq "record serialization rationale (deps)" "depends_on_atoms: AF-LATER" "$(rec AF-DEP .serialization_rationale)"
assert_eq "record serialization rationale (serial)" "not parallelizable" "$(rec AF-PLAN .serialization_rationale)"
assert_eq "record join status pending" pending "$(rec AF-PLAN .join_status)"
# A dependency satisfied by an earlier atom lets the dependent run in the batch.
plan="$(sb_scheduler_plan_batches_json "$CAT" '["AF-LATER","AF-DEP"]')"
assert_eq "a dependency must be in an earlier batch" '[["AF-LATER"],["AF-DEP"]]' "$(jq -c .batches <<<"$plan")"
# Unsatisfied dependency flushes the open batch first.
plan="$(sb_scheduler_plan_batches_json "$CAT" '["AF-READ-A","AF-DEP"]')"
assert_eq "dependency flushes the open batch" '[["AF-READ-A"],["AF-DEP"]]' "$(jq -c .batches <<<"$plan")"
plan="$(sb_scheduler_plan_batches_json "$CAT" '["AF-READ-A","AF-PLAN"]')"
assert_eq "serial atom flushes the open batch" '[["AF-READ-A"],["AF-PLAN"]]' "$(jq -c .batches <<<"$plan")"

echo "=== write plan to state ==="
sb_scheduler_write_plan_to_state "" && rc=0 || rc=$?
assert_eq "empty plan" 1 "$rc"
sb_scheduler_write_plan_to_state "$plan" && rc=0 || rc=$?
assert_eq "no state file" 1 "$rc"
( PATH="$NOJQ"; sb_scheduler_write_plan_to_state "$plan" ) && rc=0 || rc=$?
assert_eq "no jq" 1 "$rc"
orch_write_state "$(jq -n --arg r "$PROJ" '{flow_queue:["silver-fixture-read-a"],repo_root:$r,active_intent:"intent"}')"
sb_scheduler_write_plan_to_state "$plan"
assert_eq "plan stored" '[["AF-READ-A"],["AF-PLAN"]]' "$(orch_state_get '.scheduler.batches|tojson')"
assert_eq "batch index reset" 0 "$(orch_state_get .scheduler.active_batch_index)"
assert_eq "batch dispatch refreshed" pending_dispatch "$(orch_state_get .scheduler.batch_dispatch.status)"
assert_eq "directive written for the first handoff" silver-fixture-read-a "$(orch_directive_get .next_skill)"
printf 'garbage' >"$STATE"
sb_scheduler_write_plan_to_state "$plan" && rc=0 || rc=$?
assert_eq "corrupt state" 1 "$rc"

echo "=== plan queue from state ==="
rm -f "$STATE"
assert_eq "no state" 1 "$(rc_of sb_scheduler_plan_queue_from_state "$PROJ")"
assert_eq "scheduler disabled" 1 "$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 rc_of sb_scheduler_plan_queue_from_state "$PROJ")"
orch_write_state "$(jq -n --arg r "$PROJ" '{flow_queue:["silver-fixture-read-a","silver-fixture-read-b","","unknown-token","security"],repo_root:$r}')"
assert_eq "no python3" 1 "$(PATH="$NOPY" rc_of sb_scheduler_plan_queue_from_state "$PROJ")"
out="$(sb_scheduler_plan_queue_from_state "$PROJ")"
assert_eq "queue tokens resolved and planned" '[["AF-READ-A","AF-READ-B"],["AF-SECURE"]]' "$(jq -c .batches <<<"$out")"
assert_eq "plan persisted" '[["AF-READ-A","AF-READ-B"],["AF-SECURE"]]' "$(orch_state_get '.scheduler.batches|tojson')"
orch_write_state '{"flow_queue":["unknown-token"]}'
assert_eq "nothing resolvable" 1 "$(rc_of sb_scheduler_plan_queue_from_state "$PROJ")"
orch_write_state '{}'
assert_eq "empty queue" 1 "$(rc_of sb_scheduler_plan_queue_from_state "$PROJ")"
orch_write_state '{"flow_queue":["silver-plan"]}'
tl_stub python3 'exit 1'; hash -r
assert_eq "planner failure" 1 "$(rc_of sb_scheduler_plan_queue_from_state "$PROJ")"
rm -f "$TL_BIN/python3"; hash -r

echo "=== composition log ==="
sb_scheduler_append_composition_log "" '{}' && rc=0 || rc=$?
assert_eq "no root" 1 "$rc"
sb_scheduler_append_composition_log "$PROJ" "" && rc=0 || rc=$?
assert_eq "no entry" 1 "$rc"
( PATH="$NOJQ"; sb_scheduler_append_composition_log "$PROJ" '{}' ) && rc=0 || rc=$?
assert_eq "no jq" 1 "$rc"
CLOG="$PROJ/.planning/orchestrator-composition-log.jsonl"
sb_scheduler_append_composition_log "$PROJ" '{"x":1}'
assert_eq "entry mode" runtime-scheduler "$(tail -1 "$CLOG" | jq -r .mode)"
assert_eq "entry payload" 1 "$(tail -1 "$CLOG" | jq -r .x)"
assert_match "entry timestamp" '^[0-9]{4}-' "$(tail -1 "$CLOG" | jq -r .at)"
rm -f "$CLOG"
sb_scheduler_record_composition_operation "$PROJ" "WF-1" substitute AF-X DR-1 "because"
assert_eq "operation recorded" substitute "$(tail -1 "$CLOG" | jq -r '.operations[0].op')"
assert_eq "operation workflow" WF-1 "$(tail -1 "$CLOG" | jq -r .selected_workflow)"
sb_scheduler_record_composition_operation "$PROJ" "" insert AF-X DR-1 "because"
assert_eq "default workflow id" WF-SCHEDULER-FIXTURE "$(tail -1 "$CLOG" | jq -r .selected_workflow)"
for missing in 1 3 4 5 6; do
  args=("$PROJ" WF op target rule why)
  args[missing-1]=""
  assert_eq "operation needs argument $missing" 1 "$(rc_of sb_scheduler_record_composition_operation "${args[@]}")"
done
assert_eq "operation needs jq" 1 "$(PATH="$NOJQ" rc_of sb_scheduler_record_composition_operation "$PROJ" WF op target rule why)"

echo "=== composer -> workflow id ==="
while IFS='=' read -r in want; do
  assert_eq "composer $in" "$want" "$(sb_scheduler_composer_catalog_workflow_id "$in")"
done <<'MAP'
silver-feature=WF-SILVER-FEATURE
silver-fast=WF-SILVER-FAST
silver-devops=WF-SILVER-DEVOPS
silver-release=WF-SILVER-RELEASE
silver-new-workflow=WF-SILVER-NEW-WORKFLOW
silver-ui=WF-SILVER-UI
silver-bugfix=WF-SILVER-BUGFIX
silver-router=WF-SILVER-ROUTER
silver-research=WF-SILVER-DEEP-RESEARCH
silver-ship=WF-SILVER-SHIP
sb:silver-feature=WF-SILVER-FEATURE
silver-canary=WF-SILVER-CANARY
MAP
assert_eq "namespaced composer" WF-SILVER-FEATURE "$(sb_scheduler_composer_catalog_workflow_id sb:silver:feature 2>/dev/null || true)"
assert_eq "non-silver composer" 1 "$(rc_of sb_scheduler_composer_catalog_workflow_id other)"

echo "=== intent detectors ==="
det() { "$@" && echo yes || echo no; }
assert_eq "doc-only: empty" no "$(det sb_scheduler_detect_doc_only_intent "")"
assert_eq "doc-only: badge" yes "$(det sb_scheduler_detect_doc_only_intent "add a README badge")"
assert_eq "doc-only: unrelated" no "$(det sb_scheduler_detect_doc_only_intent "refactor the parser")"
assert_eq "observability: empty" no "$(det sb_scheduler_detect_observability_only_intent "")"
assert_eq "observability: needs the constraint" no "$(det sb_scheduler_detect_observability_only_intent "add structured logging")"
assert_eq "observability: with constraint" yes "$(det sb_scheduler_detect_observability_only_intent "structured logging with zero API changes")"
assert_eq "multi-capability: empty" no "$(det sb_scheduler_detect_multi_capability_intent "")"
assert_eq "multi-capability: partial" no "$(det sb_scheduler_detect_multi_capability_intent "greenfield docker")"
assert_eq "multi-capability: full" yes "$(det sb_scheduler_detect_multi_capability_intent "greenfield waitlist API in docker, then ship it")"
assert_eq "net-new: empty" no "$(det sb_scheduler_detect_net_new_workflow_intent "")"
assert_eq "net-new: posture audit" yes "$(det sb_scheduler_detect_net_new_workflow_intent "run a posture audit")"
assert_eq "net-new: unrelated" no "$(det sb_scheduler_detect_net_new_workflow_intent "fix a bug")"

echo "=== tailoring ==="
CLOG="$PROJ/.planning/orchestrator-composition-log.jsonl"
ops() { [[ -f "$CLOG" ]] && jq -r '.operations[0] | .op + ":" + .target_ref' "$CLOG" | paste -sd, - || true; }
rm -f "$CLOG"
assert_eq "doc-only: needs root and composer" 1 "$(rc_of sb_scheduler_apply_doc_only_tailoring "" silver-fast "badge README")"
assert_eq "doc-only: needs composer" 1 "$(rc_of sb_scheduler_apply_doc_only_tailoring "$PROJ" "" "README badge")"
sb_scheduler_apply_doc_only_tailoring "$PROJ" silver-fast "unrelated"
assert_file_absent "doc-only: non-matching intent records nothing" "$CLOG"
sb_scheduler_apply_doc_only_tailoring "$PROJ" silver-fast "README badge only"
assert_eq "doc-only on fast path prunes" "substitute:WF-SILVER-FEATURE,prune:AF-PLAN" "$(ops)"
rm -f "$CLOG"
sb_scheduler_apply_doc_only_tailoring "$PROJ" silver-feature "README badge only"
assert_eq "doc-only on feature path substitutes" "substitute:WF-SILVER-FAST" "$(ops)"
rm -f "$CLOG"
sb_scheduler_apply_doc_only_tailoring "$PROJ" silver-bugfix "README badge only"
assert_file_absent "doc-only: other composers untouched" "$CLOG"
obs="structured logging runbook with zero API and no UI"
assert_eq "observability: needs root and composer" 1 "$(rc_of sb_scheduler_apply_observability_tailoring "" silver-fast "$obs")"
sb_scheduler_apply_observability_tailoring "$PROJ" silver-fast "refactor"
assert_file_absent "observability: non-matching intent" "$CLOG"
sb_scheduler_apply_observability_tailoring "$PROJ" silver-fast "$obs"
assert_eq "observability on fast path" "substitute:WF-SILVER-FEATURE,prune:AF-EXECUTE,prune:AF-UI" "$(ops)"
rm -f "$CLOG"
sb_scheduler_apply_observability_tailoring "$PROJ" silver-feature "$obs"
assert_eq "observability on feature path" "substitute:WF-SILVER-FAST" "$(ops)"
rm -f "$CLOG"
sb_scheduler_apply_observability_tailoring "$PROJ" silver-ui "$obs"
assert_file_absent "observability: other composers untouched" "$CLOG"
multi="greenfield waitlist micro-SaaS with an API, docker packaging, and ship readiness"
assert_eq "multi-chain: needs root and composer" 1 "$(rc_of sb_scheduler_apply_multi_workflow_chain "" silver-feature "$multi")"
sb_scheduler_apply_multi_workflow_chain "$PROJ" silver-fast "$multi"
assert_file_absent "multi-chain: only the feature composer" "$CLOG"
sb_scheduler_apply_multi_workflow_chain "$PROJ" silver-feature "just a bug"
assert_file_absent "multi-chain: non-matching intent" "$CLOG"
rm -f "$STATE"
sb_scheduler_apply_multi_workflow_chain "$PROJ" silver-feature "$multi"
assert_eq "multi-chain inserts" "insert:WF-SILVER-DEVOPS" "$(jq -r '.operations[0] | .op + ":" + .target_ref' "$CLOG" | head -1)"
assert_eq "multi-chain records both inserts" 2 "$(wc -l <"$CLOG" | tr -d ' ')"
assert_file_absent "multi-chain without state writes no state" "$STATE"
orch_write_state '{"flow_queue":["a"]}'
sb_scheduler_apply_multi_workflow_chain "$PROJ" silver-feature "$multi"
assert_eq "composer chain stored" '["silver-devops","silver-release"]' "$(orch_state_get '.composer_chain|tojson')"
rm -f "$CLOG"
assert_eq "net-new: needs root" 1 "$(rc_of sb_scheduler_apply_net_new_workflow_route "" silver-feature "posture audit")"
sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-feature "fix a bug"
assert_file_absent "net-new: non-matching intent" "$CLOG"
orch_write_state '{"flow_queue":["a"]}'
sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-feature "posture audit please"
assert_eq "net-new routing substitutes" "substitute:WF-SILVER-NEW-WORKFLOW" "$(ops)"
assert_eq "net-new chain stored" '["silver-new-workflow"]' "$(orch_state_get '.composer_chain|tojson')"
rm -f "$STATE" "$CLOG"
sb_scheduler_apply_net_new_workflow_route "$PROJ" silver "posture audit please"
assert_eq "net-new routing without state" "substitute:WF-SILVER-NEW-WORKFLOW" "$(ops)"
rm -f "$CLOG" "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"
sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-new-workflow "posture audit please"
assert_eq "net-new composer inserts a plan atom" "insert:AF-PLAN" "$(ops)"
assert_eq "net-new composer logs a dispatch event" NEW-WORKFLOW "$(jq -r 'select(.type=="dispatch") | .payload.worker_template' "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl")"
rm -f "$CLOG"
( unset -f sb_orchestrator_event_append; sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-new-workflow "posture audit please" )
assert_eq "net-new composer without the event log" "insert:AF-PLAN" "$(ops)"
rm -f "$CLOG"
sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-ui "posture audit please"
assert_file_absent "net-new: other composers untouched" "$CLOG"

echo "=== owned steps and step V-loops ==="
assert_eq "owned steps" '["FS-PLAN-1","FS-PLAN-2"]' "$(sb_scheduler_owned_step_ids_json "$CAT" AF-PLAN)"
assert_eq "atom without flow_steps" '[]' "$(sb_scheduler_owned_step_ids_json "$CAT" AF-READ-C)"
assert_eq "owned steps: no catalog" 1 "$(rc_of sb_scheduler_owned_step_ids_json "" AF-PLAN)"
assert_eq "owned steps: no atom" 1 "$(rc_of sb_scheduler_owned_step_ids_json "$CAT" "")"
rm -f "$STATE"
for missing in 1 2 3; do
  args=(AF-PLAN FS-PLAN-1 pass); args[missing-1]=""
  assert_eq "set_step_vloop_status needs argument $missing" 1 "$(rc_of sb_scheduler_set_step_vloop_status "${args[@]}")"
done
assert_eq "set_step_vloop_status: no jq" 1 "$(PATH="$NOJQ" rc_of sb_scheduler_set_step_vloop_status AF-PLAN FS-PLAN-1 pass)"
assert_eq "set_step_vloop_status: no state" 1 "$(rc_of sb_scheduler_set_step_vloop_status AF-PLAN FS-PLAN-1 pass)"
orch_write_state '{"flow_queue":["a"]}'
sb_scheduler_set_step_vloop_status AF-PLAN FS-PLAN-1 pass
assert_eq "step status stored" pass "$(orch_state_get '.scheduler.step_v_loops["AF-PLAN"]["FS-PLAN-1"]')"
sb_scheduler_set_step_vloop_status AF-PLAN FS-PLAN-2 fail
assert_eq "second step stored beside the first" pass "$(orch_state_get '.scheduler.step_v_loops["AF-PLAN"]["FS-PLAN-1"]')"
printf 'garbage' >"$STATE"
assert_eq "corrupt state" 1 "$(rc_of sb_scheduler_set_step_vloop_status AF-PLAN FS-PLAN-1 pass)"

echo "=== join gate ==="
rm -f "$STATE"
assert_eq "join gate: no state" unknown "$(sb_scheduler_eval_join_gate "$PROJ" AF-PLAN || true)"
assert_eq "join gate: no catalog" unknown "$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_scheduler_eval_join_gate "$PROJ" AF-PLAN || true)"
orch_write_state '{"flow_queue":["a"]}'
assert_eq "steps pending: blocked" blocked "$(sb_scheduler_eval_join_gate "$PROJ" AF-PLAN)"
sb_scheduler_set_step_vloop_status AF-PLAN FS-PLAN-1 pass
assert_eq "one step passing: blocked" blocked "$(sb_scheduler_eval_join_gate "$PROJ" AF-PLAN)"
sb_scheduler_set_step_vloop_status AF-PLAN FS-PLAN-2 pass
assert_eq "all steps passing: open" open "$(sb_scheduler_eval_join_gate "$PROJ" AF-PLAN)"
assert_eq "atom without steps: open" open "$(sb_scheduler_eval_join_gate "$PROJ" AF-READ-C)"
printf 'garbage' >"$STATE"
assert_eq "corrupt state: unknown" unknown "$(sb_scheduler_eval_join_gate "$PROJ" AF-PLAN)"
orch_write_state '{"flow_queue":["a"]}'
assert_eq "refresh persists the gate" blocked "$(sb_scheduler_refresh_join_gate "$PROJ" AF-PLAN)"
assert_eq "gate stored" blocked "$(orch_state_get '.scheduler.join_gates["AF-PLAN"]')"
rm -f "$STATE"
sb_scheduler_refresh_join_gate "$PROJ" AF-PLAN >/dev/null && rc=0 || rc=$?
assert_eq "refresh without state" 1 "$rc"
orch_write_state '{"flow_queue":["a"]}'
stub_jq_failing_on join_gates
sb_scheduler_refresh_join_gate "$PROJ" AF-READ-C >/dev/null && rc=0 || rc=$?
assert_eq "refresh when jq cannot build the update" 1 "$rc"
rm -f "$TL_BIN/jq"; hash -r
orch_write_state '{"flow_queue":["a"]}'
assert_eq "vgate not ready while blocked" 1 "$(rc_of sb_scheduler_atom_vgate_ready "$PROJ" AF-PLAN)"
assert_eq "vgate ready when open" 0 "$(rc_of sb_scheduler_atom_vgate_ready "$PROJ" AF-READ-C)"

echo "=== workflow completion blocked ==="
rm -f "$STATE"
assert_eq "no state" 1 "$(rc_of sb_scheduler_workflow_completion_blocked "$PROJ")"
assert_eq "no catalog" 1 "$(SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 rc_of sb_scheduler_workflow_completion_blocked "$PROJ")"
orch_write_state '{"flow_queue":["a"]}'
assert_eq "active atom blocked" 0 "$(rc_of sb_scheduler_workflow_completion_blocked "$PROJ" AF-PLAN)"
assert_eq "active atom open" 1 "$(rc_of sb_scheduler_workflow_completion_blocked "$PROJ" AF-READ-C)"
assert_eq "no gates recorded" 1 "$(rc_of sb_scheduler_workflow_completion_blocked "$PROJ")"
orch_write_state '{"scheduler":{"join_gates":{"AF-A":"open","AF-B":"blocked"}}}'
assert_eq "a blocked gate blocks completion" 0 "$(rc_of sb_scheduler_workflow_completion_blocked "$PROJ")"
orch_write_state '{"scheduler":{"join_gates":{"AF-A":"open"}}}'
assert_eq "only open gates" 1 "$(rc_of sb_scheduler_workflow_completion_blocked "$PROJ")"

echo "=== seed runtime state ==="
rm -f "$STATE"
sb_scheduler_seed_runtime_state "fixture intent" silver-fast "$PROJ"
assert_eq "seeded intent" "fixture intent" "$(orch_state_get .active_intent)"
assert_eq "seeded composer" silver-fast "$(orch_state_get .composer)"
sb_scheduler_seed_runtime_state
assert_eq "seed defaults: intent" "scheduler fixture" "$(orch_state_get .active_intent)"
assert_eq "seed defaults: composer" silver-feature "$(orch_state_get .composer)"

echo "=== pending joins and parallel hosts ==="
rm -f "$STATE"
assert_eq "pending joins: no state" 1 "$(rc_of sb_scheduler_active_batch_has_pending_joins)"
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[{"join_status":"joined"},{"join_status":"pending"}]}}}'
assert_eq "pending joins: one pending" 0 "$(rc_of sb_scheduler_active_batch_has_pending_joins)"
assert_eq "pending joins: no jq" 1 "$(PATH="$NOJQ" rc_of sb_scheduler_active_batch_has_pending_joins)"
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[{"join_status":"joined"}]}}}'
assert_eq "pending joins: all joined" 1 "$(rc_of sb_scheduler_active_batch_has_pending_joins)"
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[]}}}'
assert_eq "pending joins: empty batch" 1 "$(rc_of sb_scheduler_active_batch_has_pending_joins)"
for v in 0 false no FALSE NO; do
  assert_eq "parallel dispatch off ($v)" 1 "$(SB_ORCHESTRATOR_PARALLEL_DISPATCH=$v rc_of sb_scheduler_host_supports_parallel_dispatch)"
done
for v in 1 true yes TRUE YES; do
  assert_eq "parallel dispatch on ($v)" 0 "$(SB_ORCHESTRATOR_PARALLEL_DISPATCH=$v rc_of sb_scheduler_host_supports_parallel_dispatch)"
done
assert_eq "hook-enforced tier supports parallel" 0 "$(SILVER_BULLET_TEST_HOOK_ENFORCED=1 rc_of sb_scheduler_host_supports_parallel_dispatch)"
assert_eq "no enforced hooks: sequential" 1 "$(rc_of sb_scheduler_host_supports_parallel_dispatch)"
assert_eq "missing tier lib: sequential" 1 "$(bash -c 'source "$1"; sb_scheduler_host_supports_parallel_dispatch; echo $?' _ "$stg/hooks/lib/orchestrator-scheduler.sh" 2>/dev/null | tail -1)"

echo "=== worker template / skill for atom ==="
assert_eq "template from worker_template" PLAN "$(sb_scheduler_worker_template_for_atom "$CAT" AF-PLAN)"
assert_eq "template falls back to slug" FIXTURE-READ-B "$(sb_scheduler_worker_template_for_atom "$CAT" AF-READ-B)"
assert_eq "unknown atom has no template" 1 "$(rc_of sb_scheduler_worker_template_for_atom "$CAT" AF-GHOST)"
assert_eq "template: no catalog" 1 "$(rc_of sb_scheduler_worker_template_for_atom "" AF-PLAN)"
# Documents current behavior: an AF id is not a flow token, so flow_to_skill derives the name from it.
assert_eq "skill for atom id goes through flow_to_skill" silver-AF-PLAN "$(sb_scheduler_skill_for_atom "$CAT" AF-PLAN)"
( unset -f sb_orchestrator_flow_to_skill
  [[ "$(sb_scheduler_skill_for_atom "$CAT" AF-DEP)" == silver-dep ]] ) && rc=0 || rc=$?
assert_eq "skill for atom without flow_to_skill: slug" 0 "$rc"
( unset -f sb_orchestrator_flow_to_skill
  [[ "$(sb_scheduler_skill_for_atom "$CAT" AF-GHOST)" == AF-GHOST ]] ) && rc=0 || rc=$?
assert_eq "skill for unknown atom without flow_to_skill: token" 0 "$rc"

echo "=== build handoffs ==="
assert_eq "handoffs: no catalog" 1 "$(rc_of sb_scheduler_build_handoffs_json "" '[]')"
assert_eq "handoffs: no python3" 1 "$(PATH="$NOPY" rc_of sb_scheduler_build_handoffs_json "$CAT" '[]')"
ho="$(sb_scheduler_build_handoffs_json "$CAT" '["AF-PLAN","AF-READ-B","AF-LATER","AF-SECURE"]')"
hf() { jq -r ".[$1] | .$2" <<<"$ho"; }
assert_eq "handoff skill via queue token" silver-plan "$(hf 0 next_skill)"
assert_eq "handoff template from worker_template" PLAN "$(hf 0 next_worker_template)"
assert_eq "handoff skill via runtime token" silver-fixture-read-b "$(hf 1 next_skill)"
assert_eq "handoff template falls back to slug" FIXTURE-READ-B "$(hf 1 next_worker_template)"
assert_eq "handoff for token-less atom" silver-later "$(hf 2 next_skill)"
assert_eq "handoff for security token" silver-secure "$(hf 3 next_skill)"
assert_eq "handoff statuses" "pending/pending" "$(hf 0 dispatch_status)/$(hf 0 join_status)"
cat >"$TL_TMP/cat-map.json" <<'JSON'
{"atomic_flows":[{"id":"AF-Q","slug":"q"}],
 "migration_map":{"runtime_queue_tokens":{"FLOW-QUX":"AF-Q"},"skill_to_entity":{"x":"y"}}}
JSON
ho="$(sb_scheduler_build_handoffs_json "$TL_TMP/cat-map.json" '["AF-Q","AF-NOPE"]')"
assert_eq "queue token re-mapped through the runtime map" silver-q "$(hf 0 next_skill)"
assert_eq "unknown atom falls back to its id" silver-nope "$(hf 1 next_skill)"
assert_eq "unknown atom template is its id" AF-NOPE "$(hf 1 next_worker_template)"
cat >"$TL_TMP/cat-map2.json" <<'JSON'
{"atomic_flows":[{"id":"AF-Q","slug":"q"},{"id":"AF-Z","slug":"z"},{"id":"AF-R","slug":"r"}],
 "migration_map":{"runtime_queue_tokens":{"FIX-THING":"AF-Z","x":"AF-R"},"skill_to_entity":{"x":"FLOW-MAPPED"}}}
JSON
ho="$(sb_scheduler_build_handoffs_json "$TL_TMP/cat-map2.json" '["AF-Z","AF-R"]')"
assert_eq "PREFIX-token maps to a silver skill" silver-z "$(hf 0 next_skill)"
assert_eq "second runtime-mapped atom" silver-r "$(hf 1 next_skill)"
cat >"$TL_TMP/cat-map3.json" <<'JSON'
{"atomic_flows":[{"id":"AF-Q","slug":"q"},{"id":"AF-S","slug":"s"}],
 "migration_map":{"runtime_queue_tokens":{},"skill_to_entity":{"AF-Q":"FLOW-MAPPED","AF-S":"silver-direct"}}}
JSON
ho="$(sb_scheduler_build_handoffs_json "$TL_TMP/cat-map3.json" '["AF-Q","AF-S"]')"
assert_eq "skill_to_entity redirect then FLOW-" silver-mapped "$(hf 0 next_skill)"
assert_eq "second atom keeps its own redirect" 2 "$(jq length <<<"$ho")"

echo "=== active batch dispatch / batch directive ==="
rm -f "$STATE" "$(orch_directive_file)"
sb_scheduler_refresh_active_batch_dispatch "$PROJ" && rc=0 || rc=$?
assert_eq "no state" 1 "$rc"
orch_write_state '{"flow_queue":["a"]}'
sb_scheduler_refresh_active_batch_dispatch "$PROJ" && rc=0 || rc=$?
assert_eq "no batches" 1 "$rc"
orch_write_state '{"scheduler":{"batches":[["AF-NOPE-AT-ALL"]]}}'
orch_write_state '{"scheduler":{"batches":[[]]}}'
sb_scheduler_refresh_active_batch_dispatch "$PROJ" && rc=0 || rc=$?
assert_eq "empty batch" 1 "$rc"
( PATH="$NOJQ"; sb_scheduler_refresh_active_batch_dispatch "$PROJ" ) && rc=0 || rc=$?
assert_eq "no jq" 1 "$rc"
orch_write_state '{"active_intent":"intent","scheduler":{"batches":[["AF-READ-A","AF-READ-B"],["AF-PLAN"]],"active_batch_index":0}}'
sb_scheduler_refresh_active_batch_dispatch "$PROJ"
assert_eq "sequential mode without a parallel host" sequential "$(orch_state_get .scheduler.batch_dispatch.dispatch_mode)"
assert_eq "host not parallel capable" false "$(orch_state_get .scheduler.batch_dispatch.host_parallel_capable)"
assert_eq "two handoffs" 2 "$(orch_state_get '.scheduler.batch_dispatch.handoffs|length')"
assert_eq "status pending dispatch" pending_dispatch "$(orch_state_get .scheduler.batch_dispatch.status)"
assert_contains "sequential directive reason" "$(orch_directive_get .reason)" "Scheduler batch: spawn Task worker for silver-fixture-read-a (2 handoff(s) remaining)"
assert_eq "directive carries the template" FIXTURE-READ-A "$(orch_directive_get .next_worker_template)"
assert_eq "directive carries the intent" intent "$(orch_directive_get .args)"
assert_eq "directive carries the batch" 2 "$(orch_directive_get '.batch_dispatch.handoffs|length')"
SB_ORCHESTRATOR_PARALLEL_DISPATCH=1 sb_scheduler_refresh_active_batch_dispatch "$PROJ"
assert_eq "parallel mode on a parallel host" parallel "$(orch_state_get .scheduler.batch_dispatch.dispatch_mode)"
assert_contains "parallel directive reason" "$(orch_directive_get .reason)" "Scheduler batch 0: spawn 2 Task workers in parallel (2 pending join)"
orch_write_state '{"scheduler":{"batches":[["AF-PLAN"]],"active_batch_index":0}}'
SB_ORCHESTRATOR_PARALLEL_DISPATCH=1 sb_scheduler_refresh_active_batch_dispatch "$PROJ"
assert_eq "single handoff stays sequential even on a parallel host" sequential "$(orch_state_get .scheduler.batch_dispatch.dispatch_mode)"
printf 'garbage' >"$STATE"
sb_scheduler_refresh_active_batch_dispatch "$PROJ" && rc=0 || rc=$?
assert_eq "corrupt state" 1 "$rc"
orch_write_state '{"scheduler":{"batches":[["AF-PLAN"]],"active_batch_index":0}}'
tl_stub python3 'exit 1'; hash -r
sb_scheduler_refresh_active_batch_dispatch "$PROJ" && rc=0 || rc=$?
assert_eq "handoff builder failure" 1 "$rc"
rm -f "$TL_BIN/python3"; hash -r
# jq fails while assembling the dispatch document.
stub_jq_failing_on dispatch_mode
sb_scheduler_refresh_active_batch_dispatch "$PROJ" && rc=0 || rc=$?
assert_eq "jq failure while updating" 1 "$rc"
rm -f "$TL_BIN/jq"; hash -r

rm -f "$STATE" "$(orch_directive_file)"
sb_scheduler_write_batch_directive "$PROJ" && rc=0 || rc=$?
assert_eq "batch directive: no state" 1 "$rc"
orch_write_state '{"flow_queue":["a"]}'
sb_scheduler_write_batch_directive "$PROJ" && rc=0 || rc=$?
assert_eq "batch directive: no batch dispatch" 1 "$rc"
( PATH="$NOJQ"; sb_scheduler_write_batch_directive "$PROJ" ) && rc=0 || rc=$?
assert_eq "batch directive: no jq" 1 "$rc"
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[]}}}'
sb_scheduler_write_batch_directive "$PROJ" && rc=0 || rc=$?
assert_eq "batch directive: no handoffs" 1 "$rc"
orch_write_state '{"active_intent":"x","scheduler":{"batch_dispatch":{"batch_index":2,"dispatch_mode":"parallel","handoffs":[
  {"next_skill":"silver-a","next_worker_template":"A","dispatch_status":"dispatched","join_status":"pending"},
  {"next_skill":"silver-b","next_worker_template":"B","dispatch_status":"pending","join_status":"pending"}]}}}'
sb_scheduler_write_batch_directive "$PROJ"
assert_eq "first pending handoff is directed" silver-b "$(orch_directive_get .next_skill)"
assert_eq "its template" B "$(orch_directive_get .next_worker_template)"
assert_contains "parallel reason names the batch" "$(orch_directive_get .reason)" "Scheduler batch 2: spawn 2 Task workers in parallel (2 pending join)"
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[{"next_skill":"silver-a","next_worker_template":"A","dispatch_status":"dispatched"}]}}}'
sb_scheduler_write_batch_directive "$PROJ"
assert_eq "falls back to the first handoff" silver-a "$(orch_directive_get .next_skill)"
# Without the batch writer the plain writer is used.
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[{"next_skill":"silver-a","next_worker_template":"A","dispatch_status":"pending"}]}}}'
rm -f "$(orch_directive_file)"
(
  sb_orchestrator_directive_write_batch() { return 1; }
  source() { builtin source "$@"; unset -f sb_orchestrator_directive_write_batch; }
  sb_scheduler_write_batch_directive "$PROJ"
) || true
assert_eq "batch directive written" silver-a "$(orch_directive_get .next_skill)"
# The directive lib missing entirely: no directive, no failure.
rm -f "$(orch_directive_file)"
bash -c 'source "$1"; export SB_RUNTIME_STATE_DIR="$2"; sb_scheduler_write_batch_directive /x; echo "rc=$?"' _ "$stg/hooks/lib/orchestrator-scheduler.sh" "$SB_RUNTIME_STATE_DIR" >/dev/null 2>&1 || true
rm -f "$stg/hooks/lib/orchestrator-directive.sh"
rm -f "$(orch_directive_file)"
out="$(bash -c 'source "$1"; sb_scheduler_write_batch_directive /x; echo "rc=$?"' _ "$stg/hooks/lib/orchestrator-scheduler.sh" 2>&1 || true)"
assert_contains "directive lib missing: returns cleanly" "$out" "rc="

echo "=== mark dispatched ==="
rm -f "$STATE"
assert_eq "dispatched: needs atom or skill" 1 "$(rc_of sb_scheduler_mark_handoff_dispatched "" "")"
assert_eq "dispatched: no jq" 1 "$(PATH="$NOJQ" rc_of sb_scheduler_mark_handoff_dispatched AF-PLAN silver-plan)"
assert_eq "dispatched: no state" 1 "$(rc_of sb_scheduler_mark_handoff_dispatched AF-PLAN silver-plan)"
mkbatch() {
  orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, scheduler:{batch_dispatch:{batch_index:1,status:"pending_dispatch",handoffs:[
    {atomic_flow_id:"AF-PLAN",next_skill:"silver-plan",next_worker_template:"PLAN",dispatch_status:"pending",join_status:"pending"},
    {atomic_flow_id:"AF-READ-A",next_skill:"sb:fixture-read-a",next_worker_template:"FIXTURE-READ-A",dispatch_status:"pending",join_status:"pending"}]}}}')"
}
mkbatch
rm -f "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl"
sb_scheduler_mark_handoff_dispatched AF-PLAN ""
hs() { orch_state_get ".scheduler.batch_dispatch.handoffs[$1].dispatch_status"; }
assert_eq "dispatched by atom id" dispatched "$(hs 0)"
assert_eq "other handoff untouched" pending "$(hs 1)"
assert_eq "batch status" dispatched "$(orch_state_get .scheduler.batch_dispatch.status)"
assert_match "dispatched_at stored" '^[0-9]{4}-' "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].dispatched_at')"
assert_eq "dispatch event carries the template" PLAN "$(jq -r 'select(.type=="dispatch")|.payload.worker_template' "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl")"
assert_eq "dispatch event carries the batch index" 1 "$(jq -r 'select(.type=="dispatch")|.payload.batch_index' "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl")"
mkbatch
sb_scheduler_mark_handoff_dispatched "" silver-plan
assert_eq "dispatched by skill" dispatched "$(hs 0)"
mkbatch
sb_scheduler_mark_handoff_dispatched "" silver-fixture-read-a
assert_eq "dispatched by sb: alias of the skill" dispatched "$(hs 1)"
mkbatch
sb_scheduler_mark_handoff_dispatched "" silver-unknown-thing
assert_eq "unmatched skill dispatches nothing" pending "$(hs 0)"
assert_eq "unmatched skill leaves both pending" pending "$(hs 1)"
orch_write_state '{"scheduler":{}}'
sb_scheduler_mark_handoff_dispatched AF-PLAN silver-plan || true
assert_eq "no batch dispatch: state unchanged" null "$(orch_state_get .scheduler.batch_dispatch)"
printf 'garbage' >"$STATE"
assert_eq "corrupt state" 1 "$(rc_of sb_scheduler_mark_handoff_dispatched AF-PLAN silver-plan)"
mkbatch
( unset -f sb_orchestrator_event_record_dispatch; sb_scheduler_mark_handoff_dispatched AF-PLAN "" )
assert_eq "works without the event log" dispatched "$(hs 0)"

echo "=== mark joined / complete batch ==="
rm -f "$STATE"
assert_eq "joined: needs atom or skill" 1 "$(rc_of sb_scheduler_mark_handoff_joined "" "")"
assert_eq "joined: no jq" 1 "$(PATH="$NOJQ" rc_of sb_scheduler_mark_handoff_joined AF-PLAN silver-plan)"
assert_eq "joined: no state" 1 "$(rc_of sb_scheduler_mark_handoff_joined AF-PLAN silver-plan)"
mkbatch
rm -f "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl" "$(orch_directive_file)"
sb_scheduler_mark_handoff_joined AF-PLAN ""
assert_eq "joined by atom" joined "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
assert_eq "joined sets dispatch status" joined "$(hs 0)"
assert_eq "other handoff still pending" pending "$(orch_state_get '.scheduler.batch_dispatch.handoffs[1].join_status')"
assert_eq "join event logged" AF-PLAN "$(jq -r 'select(.type=="join")|.payload.atomic_flow_id' "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl")"
assert_eq "directive refreshed for the remaining handoff" sb:fixture-read-a "$(orch_directive_get .next_skill)"
mkbatch
sb_scheduler_mark_handoff_joined "" silver-plan
assert_eq "joined by skill (atom resolved from the catalog)" joined "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
mkbatch
SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0 sb_scheduler_mark_handoff_joined "" silver-plan
assert_eq "scheduler disabled: skill still joins via next_skill" joined "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
mkbatch
sb_scheduler_mark_handoff_joined "" silver-unknown-thing
assert_eq "unmatched skill joins nothing" pending "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
orch_write_state '{"scheduler":{}}'
sb_scheduler_mark_handoff_joined AF-PLAN silver-plan || true
assert_eq "no batch dispatch: nothing joined" null "$(orch_state_get .scheduler.batch_dispatch)"
printf 'garbage' >"$STATE"
assert_eq "corrupt state" 1 "$(rc_of sb_scheduler_mark_handoff_joined AF-PLAN silver-plan)"
mkbatch
( unset -f sb_orchestrator_event_record_join; sb_scheduler_mark_handoff_joined AF-PLAN "" )
assert_eq "works without the event log" joined "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].join_status')"
# All handoffs joined advances to the next batch, or finishes the last one.
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r, scheduler:{batches:[["AF-READ-A"],["AF-PLAN"]],active_batch_index:0,batch_dispatch:{batch_index:0,handoffs:[
  {atomic_flow_id:"AF-READ-A",next_skill:"silver-fixture-read-a",dispatch_status:"dispatched",join_status:"pending"}]}}}')"
sb_scheduler_mark_handoff_joined AF-READ-A ""
assert_eq "next batch becomes active" 1 "$(orch_state_get .scheduler.active_batch_index)"
assert_eq "next batch dispatch refreshed" AF-PLAN "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].atomic_flow_id')"
sb_scheduler_mark_handoff_joined AF-PLAN ""
assert_eq "last batch completes" joined "$(orch_state_get .scheduler.batch_dispatch.status)"
assert_eq "last batch keeps its index" 1 "$(orch_state_get .scheduler.active_batch_index)"
rm -f "$STATE"
assert_eq "complete batch: no state" 1 "$(rc_of sb_scheduler_complete_active_batch "$PROJ")"
orch_write_state '{"scheduler":{}}'
assert_eq "complete batch: no jq" 1 "$(PATH="$NOJQ" rc_of sb_scheduler_complete_active_batch "$PROJ")"
printf 'garbage' >"$STATE"
assert_eq "complete batch: corrupt state" 1 "$((($(rc_of sb_scheduler_complete_active_batch "$PROJ")) != 0))"
orch_write_state '{"scheduler":{"batches":[["a"],["b"]],"active_batch_index":0}}'
stub_jq_failing_on active_batch_index
assert_eq "complete batch: jq fails advancing" 1 "$(rc_of sb_scheduler_complete_active_batch "$PROJ")"
rm -f "$TL_BIN/jq"; hash -r

echo "=== state applies to project ==="
rm -f "$STATE"
sap() { sb_scheduler_state_applies_to_project "$@" && echo yes || echo no; }
assert_eq "empty root" no "$(sap "")"
assert_eq "no state" no "$(sap "$PROJ")"
orch_write_state '{"flow_queue":["a"]}'
assert_eq "no stored root" no "$(sap "$PROJ")"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r}')"
assert_eq "matching root" yes "$(sap "$PROJ")"
orch_write_state '{"repo_root":"/else"}'
assert_eq "other root" no "$(sap "$PROJ")"
assert_eq "no jq" no "$(PATH="$NOJQ" sap "$PROJ")"
assert_eq "no normaliser" no "$( unset -f sb_orchestrator_normalize_repo_root; sap "$PROJ")"

echo "=== parent stop blocked ==="
psb() { sb_scheduler_parent_stop_blocked "$@" && echo blocked || echo free; }
rm -f "$STATE"
assert_eq "no state" free "$(psb "$PROJ")"
orch_write_state '{"scheduler":{}}'
assert_eq "no jq" free "$(PATH="$NOJQ" psb "$PROJ")"
assert_eq "empty scheduler" free "$(psb "$PROJ")"
assert_eq "state of another project" free "$(orch_write_state '{"repo_root":"/else","scheduler":{"join_gates":{"AF-A":"blocked"}}}'; psb "$PROJ")"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,scheduler:{join_gates:{"AF-A":"blocked"}}}')"
assert_eq "blocked gate" blocked "$(psb "$PROJ")"
assert_eq "blocked gate, no root given" blocked "$(psb)"
orch_write_state '{"scheduler":{"step_v_loops":{"AF-A":{"S1":"pass","S2":"fail"}}}}'
assert_eq "failing step V-loop" blocked "$(psb)"
for st in pending_dispatch dispatched joining; do
  orch_write_state "{\"scheduler\":{\"batch_dispatch\":{\"status\":\"$st\"}}}"
  assert_eq "batch status $st" blocked "$(psb)"
done
orch_write_state '{"scheduler":{"batch_dispatch":{"status":"joined","handoffs":[{"atomic_flow_id":"AF-A","join_status":"joined"}]}}}'
assert_eq "everything joined" free "$(psb)"
orch_write_state '{"scheduler":{"batch_dispatch":{"status":"joined","handoffs":[{"atomic_flow_id":"AF-A","join_status":"pending"}]}}}'
assert_eq "pending handoff" blocked "$(psb)"
orch_write_state '{"scheduler":{"step_v_loops":{"AF-A":{"S1":"pass"}}}}'
assert_eq "passing step V-loops" free "$(psb)"

echo "=== parent stop block reason ==="
rs() { sb_scheduler_parent_stop_block_reason; }
rm -f "$STATE"
assert_eq "no state" "Orchestrator scheduler: pending batch dispatch." "$(rs)"
orch_write_state '{"scheduler":{}}'
assert_eq "no jq" "Orchestrator scheduler: pending batch dispatch." "$(PATH="$NOJQ" rs)"
assert_eq "nothing specific" "Orchestrator scheduler: pending dispatch or join work remains." "$(rs)"
orch_write_state '{"scheduler":{"join_gates":{"AF-X":"blocked"}}}'
assert_contains "blocked gate named" "$(rs)" "join gate blocked for AF-X"
orch_write_state '{"scheduler":{"batch_dispatch":{"dispatch_mode":"parallel","handoffs":[{"join_status":"joined"},{"join_status":"pending"},{"join_status":"pending"}]}}}'
out="$(SILVER_BULLET_RUNTIME=codex rs)"
assert_contains "parallel batch progress" "$out" "parallel batch (1/3 joined)"
assert_contains "parallel batch names the host spawn tool" "$out" "spawn spawn_agent (multi_agent_v1.spawn_agent)"
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[{"join_status":"joined"},{"join_status":"pending","next_skill":"silver-b","next_worker_template":"B"}]}}}'
out="$(rs)"
assert_contains "sequential: pending skill" "$out" "pending handoff for /silver-b"
assert_contains "sequential: template" "$out" "(B.md)"
orch_write_state '{"scheduler":{"batch_dispatch":{"handoffs":[{"join_status":"pending","next_skill":"silver-b"}]}}}'
assert_contains "sequential: default template" "$(rs)" "(WORKER.md)"
assert_contains "label from the unset-label fallback" "$( unset -f sb_orchestrator_spawn_tool_label; rs)" "spawn Task worker"

tl_results
