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
NOJQ="$(tl_path_without jq)"

echo "=== paths ==="
assert_eq "event log path" "$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl" "$LOG"

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

echo "=== bounded log (R4-29) ==="
rm -f "$LOG"
export SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES=2000 SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES=10
for i in $(seq 1 120); do sb_orchestrator_event_append "e$i" "{\"i\":$i}"; done
assert_eq "log never exceeds the cap by more than one trim window" 1 "$(( $(wc -c <"$LOG" | tr -d ' ') <= 2000 + 200 ? 1 : 0 ))"
assert_eq "newest event kept" e120 "$(tail -1 "$LOG" | jq -r .type)"
assert_eq "kept lines are whole JSON documents" 0 "$(jq -e . "$LOG" >/dev/null 2>&1; echo $?)"
assert_eq "no temp files left behind" 0 "$(find "$SB_RUNTIME_STATE_DIR" -name 'orchestrator-events.jsonl.*' | wc -l | tr -d ' ')"
export SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES=junk
before="$(wc -l <"$LOG" | tr -d ' ')"
sb_orchestrator_event_append more '{}'
assert_eq "non-numeric cap: no trimming, still appends" "$((before + 1))" "$(wc -l <"$LOG" | tr -d ' ')"
unset SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES
rm -f "$LOG"
printf '{}' >"$TL_TMP/elsewhere.jsonl"
ln -s "$TL_TMP/elsewhere.jsonl" "$LOG"
sb_orchestrator_event_append t '{}' && rc=0 || rc=$?
assert_eq "a symlinked log is refused" 1 "$rc"
assert_eq "symlink target untouched" "{}" "$(cat "$TL_TMP/elsewhere.jsonl")"
rm -f "$LOG"
export SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES=10 SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES=1
sb_orchestrator_event_append a '{}'
tl_stub mktemp 'exit 1'; hash -r
sb_orchestrator_event_append b '{}' && rc=0 || rc=$?
rm -f "$TL_BIN/mktemp"; hash -r
assert_eq "no temp file for the cut: the append still succeeds" 0 "$rc"
assert_eq "no temp file for the cut: the log keeps its lines" 2 "$(wc -l <"$LOG" | tr -d ' ')"
tl_stub mv 'exit 1'; tl_stub rm 'exit 1'; hash -r
sb_orchestrator_event_append c '{}' && rc=0 || rc=$?
/bin/rm -f "$TL_BIN/mv" "$TL_BIN/rm"; hash -r
assert_eq "a failing rename and a failing cleanup do not fail the append" 0 "$rc"
assert_eq "the log is intact after the failed cut" 3 "$(wc -l <"$LOG" | tr -d ' ')"
find "$SB_RUNTIME_STATE_DIR" -name 'orchestrator-events.jsonl.*' -delete
sb_orchestrator_event_append d '{}'
assert_eq "a working cut keeps only the newest line" d "$(tail -1 "$LOG" | jq -r .type)"
unset SB_ORCHESTRATOR_EVENT_LOG_MAX_BYTES SB_ORCHESTRATOR_EVENT_LOG_KEEP_LINES
rm -f "$LOG"

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

tl_results
