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
tl_results
