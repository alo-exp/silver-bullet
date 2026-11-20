#!/usr/bin/env bash
# The G3 write trace (files-written.<epoch>) is the evidence that the agent wrote project source: it survives a
# scope reset followed by a hand-run session-start (G4 r4-01), and the session epoch it is keyed by is not
# replaced when session-log-init creates the session's first log (r4-05). Stop keeps blocking in both cases.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

export SILVER_BULLET_TEST_HOOK_ENFORCED=1 SILVER_BULLET_UPDATE_CHECK_DISABLED=1
unset SILVER_BULLET_SESSION_SOURCE SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT
SD="${SB_RUNTIME_STATE_DIR:?}"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test" "$TL_TMP/proj/src"
ec_project "$TL_TMP/proj"
echo x >"$EC_PROJ/src/a.js"
git -C "$EC_PROJ" add -A >/dev/null 2>&1 || true
git -C "$EC_PROJ" commit -qm init 2>/dev/null || true
MAIN="$(git -C "$EC_PROJ" symbolic-ref --short HEAD)"

hook() { # hook payload
  tl_run_stdin "$2" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$TL_REPO_ROOT/hooks/$1"
}
start() { hook session-start '{"hook_event_name":"SessionStart","source":"startup","session_id":"s1"}'; }
edit_src() {
  echo y >>"$EC_PROJ/src/a.js"
  hook trivial-file-clear.sh "$(jq -nc --arg f "$EC_PROJ/src/a.js" '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$f,old_string:"x",new_string:"y"},session_id:"s1"}')"
}
stop_twice() { local _; for _ in 1 2; do hook stop-check.sh '{"hook_event_name":"Stop","session_id":"s1"}'; done; }

# honest baseline: the written source blocks Stop
start; edit_src
assert_eq "the edit leaves a write trace" 1 "$(find "$SD" -maxdepth 1 -name 'files-written.*' | wc -l | tr -d ' ')"
stop_twice
assert_contains "baseline: Stop blocks on written source" "$TL_OUT" '"decision":"block"'

# r4-01: a branch round trip with session-start run by hand does not erase the trace
git -C "$EC_PROJ" checkout -q -b evil
start
git -C "$EC_PROJ" checkout -q "$MAIN"
start
assert_eq "the trace survives the scope reset" 1 "$(find "$SD" -maxdepth 1 -name 'files-written.*' | wc -l | tr -d ' ')"
stop_twice
assert_contains "after the branch round trip Stop still blocks" "$TL_OUT" '"decision":"block"'

# r4-05: session-log-init (any command naming .silver-bullet/mode) keeps the session epoch
epoch_before="$(cat "$SD/session-start-time")"
printf '%s\n' "$((epoch_before - 100))" >"$SD/session-start-time"
mv "$SD"/files-written.* "$SD/files-written.$((epoch_before - 100))"
hook session-log-init.sh "$(jq -nc --arg c "cat $SD/mode" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c},session_id:"s1"}')"
assert_eq "session-log-init keeps an existing session epoch" "$((epoch_before - 100))" "$(cat "$SD/session-start-time")"
stop_twice
assert_contains "after session-log-init Stop still blocks" "$TL_OUT" '"decision":"block"'
# without an epoch (a bare state dir) the log still starts one
rm -f "$SD/session-start-time"; rm -rf "$EC_PROJ/docs/sessions"
hook session-log-init.sh "$(jq -nc --arg c "cat $SD/mode" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c},session_id:"s1"}')"
assert_file_exists "no epoch: session-log-init writes one" "$SD/session-start-time"
# r5-01: a genuinely new session (startup after the agent's work was committed) gets a fresh epoch and a clean
# trace, so the user's own edits do not block a chat-only session; a worker start never rotates the epoch.
rm -f "$SD"/files-written.*; rm -rf "$EC_PROJ/docs/sessions"
start; e1="$(cat "$SD/session-start-time")"
echo agent >>"$EC_PROJ/src/a.js"
hook trivial-file-clear.sh "$(jq -nc --arg f "$EC_PROJ/src/a.js" '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$f,old_string:"x",new_string:"y"},session_id:"s1"}')"
git -C "$EC_PROJ" commit -qam "agent work" 2>/dev/null
printf '%s\n' "$((e1 - 90000))" >"$SD/session-start-time"
mv "$SD/files-written.$e1" "$SD/files-written.$((e1 - 90000))"
echo user >>"$EC_PROJ/src/a.js"
start
assert_eq "a new session rotates the epoch" 1 "$(( $(cat "$SD/session-start-time") > e1 - 1000 ))"
assert_eq "a new session after committed work starts with no trace" 0 "$(find "$SD" -maxdepth 1 -name 'files-written.*' | wc -l | tr -d ' ')"
hook stop-check.sh '{"hook_event_name":"Stop","session_id":"s2"}'
assert_not_contains "a chat-only new session over the user's edits is not blocked" "$TL_OUT" '"decision":"block"'

# a worker SessionStart keeps the epoch and the trace of its parent
git -C "$EC_PROJ" commit -qam "user work" 2>/dev/null
start; edit_src
ew="$(cat "$SD/session-start-time")"
printf '%s\n' "$((ew - 50))" >"$SD/session-start-time"; mv "$SD/files-written.$ew" "$SD/files-written.$((ew - 50))"
SB_ORCHESTRATOR_WORKER=1 start
assert_eq "a worker start keeps the epoch" "$((ew - 50))" "$(cat "$SD/session-start-time")"
stop_twice
assert_contains "after a worker start Stop still blocks" "$TL_OUT" '"decision":"block"'
# the same start outside a worker rotates and carries the trace (HEAD unchanged: the work is not committed)
start
assert_eq "an uncommitted trace is carried to the new epoch" 1 "$(find "$SD" -maxdepth 1 -name "files-written.$(cat "$SD/session-start-time")" | wc -l | tr -d ' ')"
stop_twice
assert_contains "a hand-run startup does not erase the floor" "$TL_OUT" '"decision":"block"'

# r5-02: autonomous mode: the sentinel relaunch restamps the epoch and carries the trace with it
git -C "$EC_PROJ" checkout -q -- . 2>/dev/null; git -C "$EC_PROJ" commit -qam wip 2>/dev/null || true
rm -f "$SD"/files-written.* "$SD/session-start-time"; rm -rf "$EC_PROJ/docs/sessions"
export SENTINEL_SLEEP_OVERRIDE=2
start
echo autonomous >"$SD/mode"
hook session-log-init.sh "$(jq -nc --arg c "echo autonomous > $SD/mode" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c},session_id:"s1"}')"
edit_src
ea="$(cat "$SD/session-start-time")"
sleep 1
hook session-log-init.sh "$(jq -nc --arg c "cat $SD/mode" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c},session_id:"s1"}')"
assert_eq "the relaunch restamped the epoch" 1 "$(( $(cat "$SD/session-start-time") > ea ))"
assert_eq "the trace follows the new epoch" 1 "$(find "$SD" -maxdepth 1 -name "files-written.$(cat "$SD/session-start-time")" | wc -l | tr -d ' ')"
stop_twice
assert_contains "after an autonomous restamp Stop still blocks" "$TL_OUT" '"decision":"block"'
sleep 3
unset SENTINEL_SLEEP_OVERRIDE
tl_results
