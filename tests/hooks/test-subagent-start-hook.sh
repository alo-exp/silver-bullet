#!/usr/bin/env bash
# End-to-end tests for hooks/subagent-start.sh (SubagentStart / SessionStart worker banner).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init

HOOK=hooks/subagent-start.sh
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_PROJECT_ROOT SB_APO_CATALOG_FILE
export SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ"
mkdir -p "$PROJ/sub/dir"
cd "$PROJ"
NOJQ="$(tl_path_without jq)"
MARKER="$SB_RUNTIME_STATE_DIR/orchestrator-worker-active.json"
start_json() { jq -cn --arg p "$1" --arg t "${2:-}" --arg e "${3:-SubagentStart}" \
  '{hook_event_name:$e, subagent_type:$t, prompt:$p}'; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }

echo "=== early exits ==="
PATH="$NOJQ" tl_run_hook "$HOOK" "$(start_json hi)"
assert_eq "no jq: silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" ""
assert_eq "empty input: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "empty input: no marker" "$MARKER"
tl_run_hook "$HOOK" "$(start_json hi "" PostToolUse)"
assert_eq "unrelated event: silent" "0|" "$TL_STATUS|$TL_OUT"
assert_file_absent "unrelated event: no marker" "$MARKER"
mkdir -p "$TL_TMP/plain/.git"
( cd "$TL_TMP/plain" && tl_run_hook "$HOOK" "$(start_json hi)" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/plain.out"
assert_eq "outside an SB project: silent" "0|" "$(cat "$TL_TMP/plain.out")"
assert_file_absent "outside an SB project: no marker" "$MARKER"
staged="$(orch_stage_hook subagent-start.sh)"
tl_run_stdin "$(start_json hi)" bash "$staged"
assert_eq "plugin without its libs: silent" "0|" "$TL_STATUS|$TL_OUT"

echo "=== banner and marker ==="
tl_run_hook "$HOOK" "$(start_json 'Run sb:plan for the login page' explorer)"
assert_eq "banner event name" SubagentStart "$(jq -r .hookSpecificOutput.hookEventName <<<"$TL_OUT")"
assert_contains "banner header" "$(ctx)" "SB WORKER SUBAGENT (mandatory)"
assert_contains "banner names the assigned skill" "$(ctx)" "Invoke assigned skill before substantive edits: sb:plan."
assert_contains "banner lists the evidence rule" "$(ctx)" "Write evidence artifact path"
assert_not_contains "banner no longer tells workers to set the env var" "$(ctx)" "SB_ORCHESTRATOR_WORKER=1"
assert_eq "marker skill" sb:plan "$(jq -r .assigned_skill "$MARKER")"
assert_eq "marker subagent type" explorer "$(jq -r .subagent_type "$MARKER")"
assert_eq "marker source" subagent-start "$(jq -r .source "$MARKER")"
assert_match "marker timestamp" '^[0-9]{4}-' "$(jq -r .spawned_at "$MARKER")"
assert_eq "marker prompt preview" "Run sb:plan for the login page" "$(jq -r .prompt_preview "$MARKER")"
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"
sb_orchestrator_is_worker_session && rc=0 || rc=$?
assert_eq "the marker makes this session a worker" 0 "$rc"
rm -f "$MARKER"

tl_run_hook "$HOOK" "$(start_json 'please use /sb:execute now')"
assert_eq "slash form: leading slash stripped" sb:execute "$(jq -r .assigned_skill "$MARKER")"
tl_run_hook "$HOOK" "$(start_json 'no skill mentioned at all')"
assert_eq "no skill in the prompt" "" "$(jq -r .assigned_skill "$MARKER")"
assert_contains "banner without a skill ends the step cleanly" "$(ctx)" "3. Invoke assigned skill before substantive edits."
tl_run_hook "$HOOK" '{"hook_event_name":"SubagentStart"}'
assert_eq "no prompt at all" "" "$(jq -r .prompt_preview "$MARKER")"
long="$(printf 'x%.0s' $(seq 1 400))"
tl_run_hook "$HOOK" "$(start_json "$long")"
assert_eq "prompt preview is bounded to 200 chars" 200 "$(jq -r '.prompt_preview|length' "$MARKER")"
tl_run_hook "$HOOK" "$(jq -cn '{hook_event_name:"subagentStart",subagentType:"camel",user_message:"use sb:review"}')"
assert_eq "camelCase event, subagentType and user_message accepted" camel "$(jq -r .subagent_type "$MARKER")"
assert_eq "user_message scanned for the skill" sb:review "$(jq -r .assigned_skill "$MARKER")"
assert_eq "camelCase event echoed in the output" subagentStart "$(jq -r .hookSpecificOutput.hookEventName <<<"$TL_OUT")"
tl_run_hook "$HOOK" "$(start_json 'run sb:plan' "" SessionStart)"
assert_eq "SessionStart accepted" SessionStart "$(jq -r .hookSpecificOutput.hookEventName <<<"$TL_OUT")"
tl_run_hook "$HOOK" '{"prompt":"sb:plan"}'
assert_eq "missing event name defaults to SubagentStart" SubagentStart "$(jq -r .hookSpecificOutput.hookEventName <<<"$TL_OUT")"
tl_run_hook "$HOOK" 'not json'
assert_eq "invalid JSON: treated as SubagentStart" "0" "$TL_STATUS"
( cd "$PROJ/sub/dir" && tl_run_hook "$HOOK" "$(start_json 'run sb:plan')" && printf '%s' "$TL_STATUS" ) >"$TL_TMP/sub.out"
assert_eq "found from a nested directory" 0 "$(cat "$TL_TMP/sub.out")"
assert_eq "nested directory still writes the marker" sb:plan "$(jq -r .assigned_skill "$MARKER")"

echo "=== marker write failures do not suppress the banner ==="
rm -f "$MARKER"
mkdir -p "$MARKER.tmp"
tl_run_hook "$HOOK" "$(start_json 'run sb:plan')"
rmdir "$MARKER.tmp"
assert_eq "unwritable marker temp file: banner still emitted" "0" "$TL_STATUS"
assert_contains "banner emitted" "$(ctx)" "SB WORKER SUBAGENT"
assert_file_absent "no marker when the write fails" "$MARKER"
notdir="$TL_TMP/notadir"
: >"$notdir"
SB_RUNTIME_STATE_DIR="$notdir/state" tl_run_hook "$HOOK" "$(start_json 'run sb:plan')"
assert_eq "state dir under a regular file: still exits 0" 0 "$TL_STATUS"

echo "=== scheduler handoff dispatch ==="
unset SB_ORCHESTRATOR_RUNTIME_SCHEDULER
CAT="$TL_TMP/catalog.json"
orch_fixture_catalog "$CAT"
export SB_APO_CATALOG_FILE="$CAT"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,scheduler:{batch_dispatch:{batch_index:0,status:"pending_dispatch",handoffs:[
  {atomic_flow_id:"AF-PLAN",next_skill:"silver-plan",next_worker_template:"PLAN",dispatch_status:"pending",join_status:"pending"},
  {atomic_flow_id:"AF-READ-A",next_skill:"silver-fixture-read-a",next_worker_template:"FIXTURE-READ-A",dispatch_status:"pending",join_status:"pending"}]}}}')"
tl_run_hook "$HOOK" "$(start_json 'run sb:plan please')"
assert_eq "the spawned worker's handoff is marked dispatched" dispatched "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].dispatch_status')"
assert_eq "other handoffs stay pending" pending "$(orch_state_get '.scheduler.batch_dispatch.handoffs[1].dispatch_status')"
assert_eq "batch status follows" dispatched "$(orch_state_get .scheduler.batch_dispatch.status)"
orch_write_state "$(jq -n --arg r "$PROJ" '{repo_root:$r,scheduler:{batch_dispatch:{handoffs:[{atomic_flow_id:"AF-PLAN",next_skill:"silver-plan",dispatch_status:"pending"}]}}}')"
tl_run_hook "$HOOK" "$(start_json 'no skill here')"
assert_eq "no assigned skill: nothing dispatched" pending "$(orch_state_get '.scheduler.batch_dispatch.handoffs[0].dispatch_status')"
rm -f "$(orch_state_file)"
tl_run_hook "$HOOK" "$(start_json 'run sb:plan')"
assert_eq "no orchestrator state: banner still emitted" "0" "$TL_STATUS"
assert_contains "banner after a failed dispatch" "$(ctx)" "sb:plan"

tl_results
