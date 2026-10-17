#!/usr/bin/env bash
# Unit tests for hooks/lib/orchestrator-event-log.sh and hooks/lib/orchestrator-skill-atom.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init
export SB_RUNTIME_PRESERVE_STATE_DIR=1
# shellcheck source=../../hooks/lib/orchestrator-event-log.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-event-log.sh"
# shellcheck source=../../hooks/lib/orchestrator-skill-atom.sh
source "$TL_REPO_ROOT/hooks/lib/orchestrator-skill-atom.sh"

LOG="$(sb_orchestrator_event_log_file)"
SAGA="$(sb_orchestrator_event_log_saga_file)"
NOJQ="$(tl_path_without jq)"

echo "=== paths ==="
assert_eq "event log path" "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl" "$LOG"
assert_eq "saga path" "$SB_RUNTIME_STATE_DIR/orchestrator-saga.json" "$SAGA"

echo "=== append ==="
sb_orchestrator_event_append "" '{}' && rc=0 || rc=$?
assert_eq "empty type rejected" 1 "$rc"
( PATH="$NOJQ"; sb_orchestrator_event_append t '{}' ) && rc=0 || rc=$?
assert_eq "no jq rejected" 1 "$rc"
assert_file_absent "nothing logged yet" "$LOG"
sb_orchestrator_event_append ping '{"a":1}'
sb_orchestrator_event_append bare
sb_orchestrator_event_append broken '{not json'
assert_eq "three entries appended" 3 "$(wc -l <"$LOG" | tr -d ' ')"
assert_eq "type recorded" ping "$(sed -n 1p "$LOG" | jq -r .type)"
assert_eq "payload parsed" 1 "$(sed -n 1p "$LOG" | jq -r .payload.a)"
assert_match "timestamp recorded" '^[0-9]{4}-' "$(sed -n 1p "$LOG" | jq -r .at)"
assert_eq "default payload is an empty object" "{}" "$(sed -n 2p "$LOG" | jq -c .payload)"
assert_eq "malformed payload degrades to an empty object" "{}" "$(sed -n 3p "$LOG" | jq -c .payload)"
rm -f "$LOG"
tl_stub jq 'exit 1'
sb_orchestrator_event_append t '{}' && rc=0 || rc=$?
assert_eq "jq failure: append returns 1" 1 "$rc"
rm -f "$TL_BIN/jq"
mkdir -p "$LOG"
sb_orchestrator_event_append t '{}' 2>/dev/null && rc=0 || rc=$?
assert_eq "unwritable log: append returns 1" 1 "$rc"
rmdir "$LOG"

echo "=== record helpers ==="
sb_orchestrator_event_record_dispatch AF-X silver-x TPL 3
sb_orchestrator_event_record_dispatch
sb_orchestrator_event_record_join AF-X silver-x
sb_orchestrator_event_record_join AF-Y silver-y pending
sb_orchestrator_event_record_advance silver-x silver-y true
sb_orchestrator_event_record_advance silver-y ""
sb_orchestrator_event_record_stop_block "queue pending"
sb_orchestrator_event_record_retry AF-X 2 "flaky"
sb_orchestrator_event_record_retry AF-X 3
ev() { jq -c "select(.type==\"$1\")" "$LOG" | sed -n "${2:-1}p"; }
assert_eq "dispatch atom" AF-X "$(ev dispatch 1 | jq -r .payload.atomic_flow_id)"
assert_eq "dispatch template" TPL "$(ev dispatch 1 | jq -r .payload.worker_template)"
assert_eq "dispatch batch index" 3 "$(ev dispatch 1 | jq -r .payload.batch_index)"
assert_eq "dispatch defaults batch index to 0" 0 "$(ev dispatch 2 | jq -r .payload.batch_index)"
assert_eq "join default status" joined "$(ev join 1 | jq -r .payload.join_status)"
assert_eq "join explicit status" pending "$(ev join 2 | jq -r .payload.join_status)"
assert_eq "advance held flag true" true "$(ev advance 1 | jq -r .payload.held_for_batch)"
assert_eq "advance held flag defaults false" false "$(ev advance 2 | jq -r .payload.held_for_batch)"
assert_eq "advance next flow" silver-y "$(ev advance 1 | jq -r .payload.next_flow)"
assert_eq "stop_block reason" "queue pending" "$(ev stop_block | jq -r .payload.reason)"
assert_eq "retry attempt" 2 "$(ev retry 1 | jq -r .payload.attempt)"
assert_eq "retry reason" flaky "$(ev retry 1 | jq -r .payload.reason)"
assert_eq "retry default reason" "" "$(ev retry 2 | jq -r .payload.reason)"

echo "=== tail ==="
rm -f "$LOG"
assert_eq "tail without a log" "[]" "$(sb_orchestrator_event_tail_json)"
for i in 1 2 3; do sb_orchestrator_event_append "e$i" "{\"i\":$i}"; done
assert_eq "tail default returns all" 3 "$(sb_orchestrator_event_tail_json | jq length)"
assert_eq "tail honors the limit" "e3" "$(sb_orchestrator_event_tail_json 1 | jq -r '.[0].type')"
printf 'garbage\n' >"$LOG"
assert_eq "tail of a corrupt log is empty" "[]" "$(sb_orchestrator_event_tail_json)"

echo "=== resume hints ==="
rm -f "$LOG"
( PATH="$NOJQ"; sb_orchestrator_event_resume_hints_json ) && rc=0 || rc=$?
assert_eq "hints need jq" 1 "$rc"
assert_eq "no state file: not resumable" '{"resumable":false,"reason":"no orchestrator.json"}' "$(sb_orchestrator_event_resume_hints_json)"
sb_orchestrator_event_resume_hints_json >/dev/null && rc=0 || rc=$?
assert_eq "no state file: reported as success" 0 "$rc"
orch_write_state '{"flow_queue":["a","b"],"active_intent":"go","current_flow":"a","last_completed":"z","workflow_id":"W1",
  "scheduler":{"batch_dispatch":{"status":"open","handoffs":[{"join_status":"joined"},{"join_status":"pending"},{"join_status":"pending"}]}}}'
sb_orchestrator_event_append seen '{}'
hints="$(sb_orchestrator_event_resume_hints_json)"
assert_eq "resumable with queue" true "$(jq -r .resumable <<<"$hints")"
assert_eq "hint intent" go "$(jq -r .active_intent <<<"$hints")"
assert_eq "hint current flow" a "$(jq -r .current_flow <<<"$hints")"
assert_eq "hint last completed" z "$(jq -r .last_completed <<<"$hints")"
assert_eq "hint workflow" W1 "$(jq -r .workflow_id <<<"$hints")"
assert_eq "hint scheduler status" open "$(jq -r .scheduler_status <<<"$hints")"
assert_eq "hint pending handoffs" 2 "$(jq -r .pending_handoffs <<<"$hints")"
assert_eq "hint recent events" seen "$(jq -r '.recent_events[0].type' <<<"$hints")"
orch_write_state '{}'
hints="$(sb_orchestrator_event_resume_hints_json)"
assert_eq "empty state: not resumable" false "$(jq -r .resumable <<<"$hints")"
assert_eq "empty state: blank scheduler status" "" "$(jq -r .scheduler_status <<<"$hints")"
printf 'garbage' >"$(orch_state_file)"
assert_eq "corrupt state: fallback" '{"resumable":false}' "$(sb_orchestrator_event_resume_hints_json)"

echo "=== resume checkpoint ==="
rm -f "$LOG" "$(orch_state_file)"
sb_orchestrator_event_apply_resume_checkpoint && rc=0 || rc=$?
assert_eq "no log and no state" 1 "$rc"
orch_write_state '{"flow_queue":["a"]}'
sb_orchestrator_event_apply_resume_checkpoint && rc=0 || rc=$?
assert_eq "state without log" 1 "$rc"
sb_orchestrator_event_record_dispatch AF-A silver-a T 1
sb_orchestrator_event_record_dispatch AF-B silver-b T 4
sb_orchestrator_event_append other '{}'
( PATH="$NOJQ"; sb_orchestrator_event_apply_resume_checkpoint ) && rc=0 || rc=$?
assert_eq "no jq" 1 "$rc"
sb_orchestrator_event_apply_resume_checkpoint
assert_eq "batch index restored from the last dispatch" 4 "$(orch_state_get .scheduler.active_batch_index)"
assert_match "resume timestamp stored" '^[0-9]{4}-' "$(orch_state_get .scheduler.resume_applied_at)"
assert_eq "existing state preserved" a "$(orch_state_get '.flow_queue[0]')"
rm -f "$LOG"
sb_orchestrator_event_append other '{}'
sb_orchestrator_event_apply_resume_checkpoint
assert_eq "no dispatch events: index 0" 0 "$(orch_state_get .scheduler.active_batch_index)"
printf 'garbage\n' >"$LOG"
sb_orchestrator_event_apply_resume_checkpoint
assert_eq "corrupt log falls back to index 0" 0 "$(orch_state_get .scheduler.active_batch_index)"
printf 'garbage' >"$(orch_state_file)"
sb_orchestrator_event_apply_resume_checkpoint && rc=0 || rc=$?
assert_eq "corrupt state: not applied" 1 "$rc"

echo "=== saga ==="
rm -f "$LOG" "$SAGA"
( PATH="$NOJQ"; sb_orchestrator_saga_begin silver-ship ) && rc=0 || rc=$?
assert_eq "saga_begin needs jq" 1 "$rc"
( PATH="$NOJQ"; sb_orchestrator_saga_complete silver-ship ) && rc=0 || rc=$?
assert_eq "saga_complete needs jq" 1 "$rc"
( PATH="$NOJQ"; sb_orchestrator_saga_rollback_hint silver-ship ) && rc=0 || rc=$?
assert_eq "saga_rollback_hint needs jq" 1 "$rc"
sb_orchestrator_saga_complete silver-ship && rc=0 || rc=$?
assert_eq "complete without a saga fails" 1 "$rc"
sb_orchestrator_saga_begin silver-ship deploy '["a.txt"]'
assert_eq "saga status" in_progress "$(jq -r .status "$SAGA")"
assert_eq "saga action" deploy "$(jq -r .action "$SAGA")"
assert_eq "saga artifacts" a.txt "$(jq -r '.artifacts[0]' "$SAGA")"
assert_eq "saga_begin event logged" saga_begin "$(tail -1 "$LOG" | jq -r .type)"
sb_orchestrator_saga_begin silver-ship
assert_eq "defaults: action ship" ship "$(jq -r .action "$SAGA")"
assert_eq "defaults: no artifacts" 0 "$(jq -r '.artifacts|length' "$SAGA")"
sb_orchestrator_saga_complete silver-ship
assert_eq "saga completed" completed "$(jq -r .status "$SAGA")"
assert_match "completed_at stored" '^[0-9]{4}-' "$(jq -r .completed_at "$SAGA")"
assert_eq "saga_complete event logged" saga_complete "$(tail -1 "$LOG" | jq -r .type)"
sb_orchestrator_saga_complete silver-ship custom
assert_eq "explicit completion status" custom "$(jq -r .status "$SAGA")"
printf 'garbage' >"$SAGA"
sb_orchestrator_saga_complete silver-ship && rc=0 || rc=$?
assert_eq "corrupt saga: complete fails" 1 "$rc"
sb_orchestrator_saga_begin silver-ship
hint="$(sb_orchestrator_saga_rollback_hint silver-ship "disk full")"
assert_contains "hint names worker and reason" "$hint" "Saga rollback required for silver-ship: disk full."
assert_eq "saga marked rollback_required" rollback_required "$(jq -r .status "$SAGA")"
assert_eq "rollback step recorded" revert_declared_artifacts "$(jq -r '.rollback_steps[0].action' "$SAGA")"
assert_eq "rollback event logged" saga_rollback "$(tail -1 "$LOG" | jq -r .type)"
hint="$(sb_orchestrator_saga_rollback_hint silver-ship)"
assert_contains "default reason" "$hint" "worker failure"
printf 'garbage' >"$SAGA"
sb_orchestrator_saga_rollback_hint silver-ship boom >/dev/null
assert_eq "corrupt saga is left alone" garbage "$(cat "$SAGA")"
rm -f "$SAGA"
hint="$(sb_orchestrator_saga_rollback_hint silver-ship nosaga)"
assert_contains "hint without a saga file" "$hint" "nosaga"
assert_file_absent "no saga file is invented" "$SAGA"

echo "=== skill atom resolution ==="
CAT="$TL_TMP/catalog.json"
orch_fixture_catalog "$CAT"
r() { sb_scheduler_resolve_atom_id "$CAT" "$1"; }
sb_scheduler_catalog_atom_exists "$CAT" AF-PLAN && rc=0 || rc=$?
assert_eq "atom exists" 0 "$rc"
sb_scheduler_catalog_atom_exists "$CAT" AF-NOPE && rc=0 || rc=$?
assert_eq "atom missing" 1 "$((rc != 0))"
sb_scheduler_catalog_atom_exists "" AF-PLAN && rc=0 || rc=$?
assert_eq "no catalog" 1 "$rc"
sb_scheduler_catalog_atom_exists "$CAT" "" && rc=0 || rc=$?
assert_eq "no atom id" 1 "$rc"
sb_scheduler_resolve_atom_id "" x && rc=0 || rc=$?
assert_eq "resolve: no catalog" 1 "$rc"
sb_scheduler_resolve_atom_id "$CAT" "" && rc=0 || rc=$?
assert_eq "resolve: no token" 1 "$rc"
( PATH="$NOJQ"; sb_scheduler_resolve_atom_id "$CAT" AF-PLAN ) && rc=0 || rc=$?
assert_eq "resolve: no jq" 1 "$rc"
assert_eq "AF token passes through" AF-PLAN "$(r AF-PLAN)"
r AF-GHOST >/dev/null && rc=0 || rc=$?
assert_eq "unknown AF token fails" 1 "$rc"
assert_eq "runtime queue token" AF-PLAN "$(r FLOW-PLAN-TOKEN)"
assert_eq "skill_to_entity" AF-PLAN "$(r plan-skill)"
assert_eq "gsd alias" AF-PLAN "$(r gsd-plan-phase)"
assert_eq "legacy flow key" AF-PLAN "$(r 'FLOW 7')"
assert_eq "slug exact" AF-READ-C "$(r read-c)"
assert_eq "slug case-insensitive" AF-DEP "$(r dep)"
assert_eq "silver-slug tail" AF-LATER "$(r silver-later)"
r silver-later >/dev/null && rc=0 || rc=$?
assert_eq "silver-slug tail resolves with status 0" 0 "$rc"
assert_eq "skill-atom lib alone loads the directive lib" 0 "$(bash -c 'source "$1"; declare -f sb_orchestrator_flow_to_skill >/dev/null; echo $?' _ "$TL_REPO_ROOT/hooks/lib/orchestrator-skill-atom.sh")"
assert_eq "silver-slug tail ignores dashes" AF-READ-A "$(r silver-fixtureread-a)"
assert_eq "flow_to_skill normalisation" AF-PLAN "$(r FLOW-PLAN)"
assert_eq "dangling queue token falls through" "" "$(r ghost-token || true)"
r ghost-token >/dev/null && rc=0 || rc=$?
assert_eq "dangling token has no atom" 1 "$rc"
r orphan-skill >/dev/null && rc=0 || rc=$?
assert_eq "orphan skill has no atom" 1 "$rc"
r 'FLOW 99' >/dev/null && rc=0 || rc=$?
assert_eq "non-AF legacy value rejected" 1 "$rc"
r totally-unknown >/dev/null && rc=0 || rc=$?
assert_eq "unknown token fails" 1 "$rc"
# Without the directive lib the flow_to_skill normalisation step is skipped.
( unset -f sb_orchestrator_flow_to_skill; sb_scheduler_resolve_atom_id "$CAT" FLOW-PLAN ) >/dev/null && rc=0 || rc=$?
assert_eq "no flow_to_skill: FLOW-PLAN unresolved" 1 "$rc"
# A catalog with a skill_to_entity value that is an AF id but a token not otherwise resolvable.
CAT2="$TL_TMP/catalog2.json"
jq -n '{atomic_flows:[{id:"AF-X",slug:"x"}],migration_map:{skill_to_entity:{"some-skill":"AF-GONE"}}}' >"$CAT2"
sb_scheduler_resolve_atom_id "$CAT2" AF-GONE >/dev/null && rc=0 || rc=$?
assert_eq "entity id absent from the catalog" 1 "$rc"
sb_scheduler_resolve_atom_id "$CAT2" AF-X >/dev/null && rc=0 || rc=$?
assert_eq "entity id present resolves" 0 "$rc"
CAT3="$TL_TMP/catalog3.json"
jq -n '{atomic_flows:[{id:"AF-X",slug:"x"}],migration_map:{skill_to_entity:{"some-skill":"AF-X"}}}' >"$CAT3"
assert_eq "skill_to_entity value used as a token" AF-X "$(sb_scheduler_resolve_atom_id "$CAT3" some-skill)"

echo "=== handoff completion match ==="
m() { sb_scheduler_handoff_matches_completion "$@"; }
m "" AF-A silver-a && rc=0 || rc=$?
assert_eq "empty handoff" 1 "$rc"
( PATH="$NOJQ"; m '{"atomic_flow_id":"AF-A"}' AF-A silver-a ) && rc=0 || rc=$?
assert_eq "no jq" 1 "$rc"
m '{"atomic_flow_id":"AF-A"}' AF-A "" && rc=0 || rc=$?
assert_eq "matches by atom id" 0 "$rc"
m '{"atomic_flow_id":"AF-A"}' "" "" && rc=0 || rc=$?
assert_eq "empty atom never matches" 1 "$rc"
m '{"next_skill":"silver-a"}' AF-Z silver-a && rc=0 || rc=$?
assert_eq "matches by skill" 0 "$rc"
m '{"next_skill":"sb:a"}' AF-Z silver-a && rc=0 || rc=$?
assert_eq "sb: prefix normalised" 0 "$rc"
m '{"next_skill":"sb:a"}' AF-Z silver-b && rc=0 || rc=$?
assert_eq "different skill" 1 "$rc"
m '{"next_skill":"silver-a"}' AF-Z "" && rc=0 || rc=$?
assert_eq "empty skill never matches" 1 "$rc"
m 'not json' AF-A silver-a && rc=0 || rc=$?
assert_eq "malformed handoff" 1 "$((rc != 0))"

tl_results
