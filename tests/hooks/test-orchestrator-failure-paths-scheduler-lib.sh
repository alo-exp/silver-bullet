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
dirize "$EVENTS"
sb_scheduler_apply_net_new_workflow_route "$PROJ" silver-new-workflow "posture audit" 2>/dev/null && rc=0 || rc=$?
rm -rf "$EVENTS" "$PROJ/.planning/orchestrator-composition-log.jsonl"
assert_eq "net-new composer with an unwritable event log" 0 "$rc"
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
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,scheduler:{batches:[["AF-PLAN"],["AF-READ-A"]],active_batch_index:0,batch_dispatch:{handoffs:[{atomic_flow_id:"AF-PLAN",next_skill:"silver-plan",join_status:"pending"}]}}}')"
orch_stub_failing jq 'active_batch_index = $idx'
sb_scheduler_mark_handoff_joined AF-PLAN "" && rc=0 || rc=$?
orch_unstub jq
assert_eq "batch completion failing: join marking still succeeds" 0 "$rc"
assert_eq "batch completion failing: batch index unchanged" 0 "$(orch_state_get .scheduler.active_batch_index)"
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
