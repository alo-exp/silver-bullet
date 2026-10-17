#!/usr/bin/env bash
# End-to-end tests for hooks/v-loop-rollup-gate.sh (Stop: site-session V-loop rollup).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/b-orchestrator-helpers.sh"
tl_init

HOOK=hooks/v-loop-rollup-gate.sh
export SB_RUNTIME_PRESERVE_STATE_DIR=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_PROJECT_ROOT SB_AGENT_DELEGATE_GUARD SB_AGENT_DELEGATE_V2
# shellcheck source=../../hooks/lib/site-session.sh
source "$TL_REPO_ROOT/hooks/lib/site-session.sh"

PROJ="$TL_TMP/proj"
orch_make_project "$PROJ" '{"sb_initiated":true}'
mkdir -p "$PROJ/sub"
cd "$PROJ"
NOJQ="$(tl_path_without jq)"
SITE="$(sb_site_session_file)"
VLOOPS="$(sb_site_session_vloop_file)"
stop_json() { jq -cn --arg e "${1:-Stop}" '{hook_event_name:$e}'; }
blocked() { jq -r '.decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo bad; }
reset() { rm -f "$SITE" "$VLOOPS" "$(sb_site_session_live_evidence_file)" "$(sb_site_session_visual_evidence_file)" \
  "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json" "$SB_RUNTIME_STATE_DIR/trivial" "$SB_RUNTIME_STATE_DIR/orchestrator-worker-active.json"; }
start_site_session() { sb_site_session_mark_site_intent; sb_site_session_init_vloops; }

echo "=== early exits ==="
reset
start_site_session
PATH="$NOJQ" tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "no jq: silent" "0|" "$TL_STATUS|$TL_OUT"
tl_run_hook "$HOOK" "$(stop_json PostToolUse)"
assert_eq "non-Stop event: silent" "0|" "$TL_STATUS|$TL_OUT"
mkdir -p "$TL_TMP/plain/.git"
( cd "$TL_TMP/plain" && tl_run_hook "$HOOK" "$(stop_json)" && printf '%s|%s' "$TL_STATUS" "$TL_OUT" ) >"$TL_TMP/plain.out"
assert_eq "outside an SB project: silent" "0|" "$(cat "$TL_TMP/plain.out")"
staged="$(orch_stage_hook v-loop-rollup-gate.sh)"
tl_run_stdin "$(stop_json)" bash "$staged"
assert_eq "plugin without its libs: fails open" "0|" "$TL_STATUS|$TL_OUT"
SB_ORCHESTRATOR_WORKER=1 tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "worker session: silent" "0|" "$TL_STATUS|$TL_OUT"
: >"$SB_RUNTIME_STATE_DIR/trivial"
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "legacy trivial marker bypasses the gate" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$SB_RUNTIME_STATE_DIR/trivial"

echo "=== the gate only applies to genuine site sessions ==="
reset
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "no site session: silent" "0|" "$TL_STATUS|$TL_OUT"
start_site_session
rm -f "$SITE"
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "V-loops without an active site session: silent" "0|" "$TL_STATUS|$TL_OUT"
reset
sb_site_session_touch "edit:docs/readme.md"
sb_site_session_init_vloops
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "active session without site work: silent" "0|" "$TL_STATUS|$TL_OUT"
reset
start_site_session
jq -n '{active:true,host:"codex",task_id:"T1",work_dir:"/x",ownership_scope:[]}' >"$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "active agent delegation: gate does not apply" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"

echo "=== pending V-loops block Stop ==="
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "incomplete V-loops: block" block "$(blocked)"
reason="$(jq -r .reason <<<"$TL_OUT")"
assert_contains "block names the gate" "$reason" "Site V-loop rollup gate"
assert_contains "block lists incomplete steps" "$reason" "Site V-loop rollup — incomplete steps:"
assert_contains "block lists the preflight step" "$reason" "(preflight): pending"
assert_contains "block explains how to proceed" "$reason" "Complete sb:content batch steps"
assert_eq "an empty event name defaults to Stop" block "$(tl_run_hook "$HOOK" '{}' && blocked)"
tl_run_hook "$HOOK" 'not json'
assert_eq "invalid JSON defaults to Stop" block "$(blocked)"
( cd "$PROJ/sub" && tl_run_hook "$HOOK" "$(stop_json)" && blocked ) >"$TL_TMP/sub.out"
assert_eq "gate resolves the project from a subdirectory" block "$(cat "$TL_TMP/sub.out")"

echo "=== rollup progress ==="
sb_site_session_vloop_mark preflight ref
sb_site_session_vloop_mark implement ref
sb_site_session_vloop_mark regression ref
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "visual evidence still missing: block" block "$(blocked)"
assert_contains "remaining step named" "$(jq -r .reason <<<"$TL_OUT")" "(visual): pending"
assert_not_contains "completed steps are not listed" "$(jq -r .reason <<<"$TL_OUT")" "(preflight)"
sb_site_session_vloop_mark visual ref
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "all required steps done (publish optional): allowed" "0|" "$TL_STATUS|$TL_OUT"
sb_site_session_mark_push_intent
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "push intent makes the publish step required" block "$(blocked)"
assert_contains "publish step named" "$(jq -r .reason <<<"$TL_OUT")" "(publish): pending"
sb_site_session_vloop_mark publish ref
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "publish done: allowed" "0|" "$TL_STATUS|$TL_OUT"

echo "=== V-loop state is synced from session evidence before deciding ==="
reset
start_site_session
rm -f "$VLOOPS"
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "missing V-loop file is re-initialised and blocks" block "$(blocked)"
assert_eq "implement step derived from the active session" "done" "$(jq -r '.steps[]|select(.id=="implement")|.status' "$VLOOPS")"
sb_site_session_mark_visual_evidence "shots/home.png"
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "visual evidence file marks the visual step" "done" "$(jq -r '.steps[]|select(.id=="visual")|.status' "$VLOOPS")"
echo "=== sync failures do not break Stop ==="
reset
start_site_session
sb_site_session_mark_push_intent
printf 'garbage' >"$VLOOPS"
tl_run_hook "$HOOK" "$(stop_json)"
assert_eq "corrupt V-loop file: fails open" "0|" "$TL_STATUS|$TL_OUT"

echo "=== unreadable stdin ==="
reset
start_site_session
status=0
out="$(bash "$TL_REPO_ROOT/$HOOK" <"$TL_TMP")" || status=$?
assert_eq "stdin that cannot be read yields no event name: silent" "0|" "$status|$out"

tl_results
