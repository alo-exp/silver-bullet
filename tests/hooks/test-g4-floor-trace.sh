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
# a genuine new session: `clear` on every host (Codex restarts its process with `startup` inside one session)
fresh_session() { hook session-start '{"hook_event_name":"SessionStart","source":"clear","session_id":"s2"}'; }
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
printf 'checklist\n' >"$TL_TMP/checklist.md"; python3 -c 'import os,sys; t=int(sys.argv[1]); os.utime(sys.argv[2],(t,t))' "$((e1 - 80000))" "$TL_TMP/checklist.md"
fresh_session
# the doc-scheme gate (doc-scheme-gate.sh) flags a checklist older than the session epoch as not updated this session
assert_eq "a checklist from the earlier session is older than the new epoch" 1 "$(( $(stat -c %Y "$TL_TMP/checklist.md" 2>/dev/null || stat -f %m "$TL_TMP/checklist.md") < $(cat "$SD/session-start-time") ))"
assert_eq "a new session rotates the epoch" 1 "$(( $(cat "$SD/session-start-time") > e1 - 1000 ))"
assert_eq "a new session after committed work starts with no trace" 0 "$(find "$SD" -maxdepth 1 -name 'files-written.*' | wc -l | tr -d ' ')"
hook stop-check.sh '{"hook_event_name":"Stop","session_id":"s2"}'
assert_not_contains "a chat-only new session over the user's edits is not blocked" "$TL_OUT" '"decision":"block"'

# a worker SessionStart keeps the epoch and the trace of its parent
git -C "$EC_PROJ" commit -qam "user work" 2>/dev/null
fresh_session; edit_src
ew="$(cat "$SD/session-start-time")"
printf '%s\n' "$((ew - 50))" >"$SD/session-start-time"; mv "$SD/files-written.$ew" "$SD/files-written.$((ew - 50))"
SB_ORCHESTRATOR_WORKER=1 fresh_session
assert_eq "a worker start keeps the epoch" "$((ew - 50))" "$(cat "$SD/session-start-time")"
stop_twice
assert_contains "after a worker start Stop still blocks" "$TL_OUT" '"decision":"block"'
# the same start outside a worker rotates and carries the trace (HEAD unchanged: the work is not committed)
fresh_session
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
# ---- r6: the helper rules, HEAD that moves without a commit, stray and concurrent traces, the real doc gate ----
# shellcheck source=../../hooks/lib/session-epoch.sh
source "$TL_REPO_ROOT/hooks/lib/session-epoch.sh"
# BSD/GNU-neutral mtime setter
settime() { python3 -c 'import os,sys; t=int(sys.argv[1]); [os.utime(f,(t,t)) for f in sys.argv[2:]]' "$@"; }
trace_count() { find "$SD" -maxdepth 1 -name 'files-written.*' | wc -l | tr -d ' '; }
cur_trace() { printf '%s/files-written.%s' "$SD" "$(cat "$SD/session-start-time")"; }

# r6-01: which start is a new session (Codex fires startup on every process restart of one session)
rm -f "$SD/session-start-sid"
sr() { sb_session_epoch_should_rotate "$1" "$2" "$3" "$SD" && echo rotate || echo keep; }
assert_eq "clear rotates on every host" rotate "$(sr clear codex "")"
assert_eq "Claude startup rotates" rotate "$(sr startup claude "")"
assert_eq "resume keeps" keep "$(sr resume claude s9)"
assert_eq "Codex startup without a session id keeps" keep "$(sr startup codex "")"
assert_eq "Codex startup with a first session id rotates" rotate "$(sr startup codex s1)"
printf 's1\n' >"$SD/session-start-sid"
assert_eq "Codex startup, same session id (a process restart) keeps" keep "$(sr startup codex s1)"
assert_eq "Codex startup, new session id rotates" rotate "$(sr startup codex s2)"
rm -f "$SD/session-start-sid"; ln -s "$TL_TMP/sid-victim" "$SD/session-start-sid"
assert_eq "a symlinked id file is never trusted (keep)" keep "$(sr startup codex s2)"
rm -f "$SD/session-start-sid"
# end to end on the host under test: a genuinely new session id with the earlier work committed drops the trace
if [[ "${SILVER_BULLET_RUNTIME:-claude}" == codex ]]; then
  git -C "$EC_PROJ" commit -qam "sync" 2>/dev/null || true
  hook session-start '{"hook_event_name":"SessionStart","source":"startup","session_id":"cx1"}'
  echo agent >>"$EC_PROJ/src/a.js"; edit_src; e1="$(cat "$SD/session-start-time")"
  git -C "$EC_PROJ" commit -qam "agent work" 2>/dev/null
  printf '%s\n' "$((e1 - 90000))" >"$SD/session-start-time"; mv "$SD/files-written.$e1" "$SD/files-written.$((e1 - 90000))"
  echo user >>"$EC_PROJ/src/a.js"
  hook session-start '{"hook_event_name":"SessionStart","source":"startup","session_id":"cx1"}'
  assert_eq "Codex: a restart of the same session keeps the epoch" "$((e1 - 90000))" "$(cat "$SD/session-start-time")"
  hook session-start '{"hook_event_name":"SessionStart","source":"startup","session_id":"cx2"}'
  assert_eq "Codex: a new session id rotates and drops the committed work's trace" 0 "$(trace_count)"
  hook stop-check.sh '{"hook_event_name":"Stop","session_id":"cx2"}'
  assert_not_contains "Codex: a chat-only new session is not blocked" "$TL_OUT" '"decision":"block"'
fi

# r6-02: HEAD that moves without a commit (detach, soft reset) keeps the trace; a forward move drops it
git -C "$EC_PROJ" commit -qam "base" 2>/dev/null || true
echo more >"$EC_PROJ/src/b.js"; git -C "$EC_PROJ" add src/b.js; git -C "$EC_PROJ" commit -qm "second" 2>/dev/null
fresh_session; edit_src
git -C "$EC_PROJ" checkout -q --detach HEAD~1
fresh_session
assert_eq "a detached HEAD keeps the trace" 1 "$(trace_count)"
git -C "$EC_PROJ" checkout -q "$MAIN"
fresh_session
git -C "$EC_PROJ" reset -q --soft HEAD~1
fresh_session
assert_eq "a soft reset keeps the trace" 1 "$(trace_count)"
stop_twice
assert_contains "after the soft reset Stop still blocks" "$TL_OUT" '"decision":"block"'
git -C "$EC_PROJ" reset -q --soft ORIG_HEAD
git -C "$EC_PROJ" commit -qam "forward" 2>/dev/null
fresh_session
assert_eq "a forward move (a commit on top) drops the trace" 0 "$(trace_count)"
REPO_ID="$(cd "$EC_PROJ" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
printf '%s\ndeadbeef\n' "$REPO_ID" >"$SD/session-start-head"
printf 'f%s/src/a.js\n' "$EC_PROJ" >"$(cur_trace)"
fresh_session
assert_eq "an unreadable old HEAD of this repository keeps the trace" 1 "$(trace_count)"
printf 'deadbeef\n' >"$SD/session-start-head"
fresh_session
assert_eq "a record without a repository whose HEAD is not in this one is foreign: dropped" 0 "$(trace_count)"

# r7-01: a trace recorded in another project says nothing about this one (a `*` entry would block Stop anywhere)
OTHER="$TL_TMP/other-proj"; mkdir -p "$OTHER/src"; git -C "$OTHER" init -q -b main; git -C "$OTHER" config user.email a@b; git -C "$OTHER" config user.name a
printf '# sb\n' >"$OTHER/silver-bullet.md"; cp "$EC_PROJ/.silver-bullet.json" "$OTHER/.silver-bullet.json"
printf '%s\n' '.silver-bullet.json' 'silver-bullet.md' >>"$OTHER/.git/info/exclude"
echo x >"$OTHER/src/a.js"; git -C "$OTHER" add -A; git -C "$OTHER" commit -qm init
fresh_session_in() { tl_run_stdin '{"hook_event_name":"SessionStart","source":"clear","session_id":"s3"}' bash -c 'cd "$1" && exec bash "$2"' _ "$1" "$TL_REPO_ROOT/hooks/session-start"; }
fresh_session; printf '*\n' >"$(cur_trace)"
echo user >>"$OTHER/src/a.js"
fresh_session_in "$OTHER"
assert_eq "a trace of another project is dropped" 0 "$(trace_count)"
tl_run_stdin '{"hook_event_name":"Stop","session_id":"s3"}' bash -c 'cd "$1" && exec bash "$2"' _ "$OTHER" "$TL_REPO_ROOT/hooks/stop-check.sh"
assert_not_contains "a chat-only Stop in the other project is not blocked by the first project's trace" "$TL_OUT" '"decision":"block"'
# the same project keeps a `*` trace
fresh_session; printf '*\n' >"$(cur_trace)"; fresh_session
assert_eq "the same project keeps its trace" 1 "$(trace_count)"

# r7-02: a forward move without a commit keeps the agent's still-dirty entries that the move did not touch
rm -f "$SD"/files-written.*
git -C "$EC_PROJ" checkout -q "$MAIN"; git -C "$EC_PROJ" checkout -q -b ahead
echo c >"$EC_PROJ/src/c.js"; git -C "$EC_PROJ" add src/c.js; git -C "$EC_PROJ" commit -qm "ahead" 2>/dev/null
git -C "$EC_PROJ" checkout -q "$MAIN"
fresh_session
echo agent-edit >>"$EC_PROJ/src/a.js"; edit_src
git -C "$EC_PROJ" checkout -q ahead
fresh_session
assert_eq "a forward checkout keeps the still-dirty agent entry" 1 "$(trace_count)"
assert_eq "...exactly that entry" 1 "$(grep -c 'src/a.js' "$(cur_trace)")"
# a star entry and an entry for a path the move touched are dropped on a forward move
git -C "$EC_PROJ" checkout -q "$MAIN"; rm -f "$SD"/files-written.*; fresh_session
printf 'f%s/src/a.js\n*\nf%s/src/c.js\n' "$EC_PROJ" "$EC_PROJ" >"$(cur_trace)"
git -C "$EC_PROJ" checkout -q ahead
fresh_session
assert_eq "a forward move drops star entries and entries the move touched" "f$EC_PROJ/src/a.js" "$(cat "$(cur_trace)")"
git -C "$EC_PROJ" checkout -q -- . ; git -C "$EC_PROJ" checkout -q "$MAIN"; git -C "$EC_PROJ" branch -q -D ahead
fresh_session; rm -f "$SD"/files-written.*

# r7-03: a host that sends no session id rotates on startup once the epoch is a day old
sr2() { sb_session_epoch_should_rotate startup codex "" "$SD" "$SD/session-start-time" && echo rotate || echo keep; }
printf '%s\n' "$(( $(date +%s) - 100 ))" >"$SD/session-start-time"
assert_eq "no session id, a young epoch: keep" keep "$(sr2)"
printf '%s\n' "$(( $(date +%s) - 90000 ))" >"$SD/session-start-time"
assert_eq "no session id, an epoch over a day old: rotate" rotate "$(sr2)"
printf 'junk\n' >"$SD/session-start-time"
assert_eq "no session id, an unreadable epoch: keep" keep "$(sr2)"


# r6-03: traces that are not under the old epoch (unknown, other epochs) are merged into the new one
rm -f "$SD"/files-written.*
printf 'f/x/one\nf/x/two\n' >"$SD/files-written.unknown"
printf 'f/x/two\nf/x/three\n' >"$SD/files-written.123"
rm -f "$SD/session-start-time"
fresh_session
assert_eq "an erased epoch: the traces end up in one file" 1 "$(trace_count)"
assert_eq "...merged and de-duplicated" 3 "$(grep -c . "$(cur_trace)")"
# the cap: more than 500 entries become 500 plus `*`
rm -f "$SD"/files-written.*
seq 1 600 | sed 's|^|f/y/|' >"$SD/files-written.1"
fresh_session
assert_eq "the cap keeps 500 entries and a star" 501 "$(grep -c . "$(cur_trace)")"
assert_eq "...ending in the star" '*' "$(tail -n 1 "$(cur_trace)")"
# a planted link is never merged or followed
rm -f "$SD"/files-written.*; printf 'victim\n' >"$TL_TMP/link-victim"; ln -s "$TL_TMP/link-victim" "$SD/files-written.77"
printf 'f/z/a\n' >"$SD/files-written.88"
fresh_session
assert_eq "a planted link is left alone" "victim" "$(cat "$TL_TMP/link-victim")"
rm -f "$SD"/files-written.*

# r6-04: concurrent rotations never orphan the trace, and the epoch is written whole
printf 'f/c/one\nf/c/two\n' >"$SD/files-written.5"
printf '5\n' >"$SD/session-start-time"
for _ in 1 2 3 4 5 6; do ( sb_session_epoch_restamp "$SD/session-start-time" "$SD" ) & done
wait
assert_eq "parallel rotations leave one trace" 1 "$(trace_count)"
assert_eq "...under the current epoch" 1 "$([[ -f "$(cur_trace)" ]] && echo 1 || echo 0)"
assert_eq "...with every entry" 2 "$(grep -c . "$(cur_trace)")"
sleep 1; sb_session_epoch_restamp "$SD/session-start-time" "$SD"
assert_eq "back-to-back rotations (a second later) merge instead of orphaning" 2 "$(grep -c . "$(cur_trace)")"
assert_eq "the epoch is a bare number" 1 "$(grep -cE '^[0-9]+$' "$SD/session-start-time")"
# a failing temp file leaves the epoch as it was
printf '42\n' >"$SD/session-start-time"
tl_stub mktemp 'exit 1'
sb_session_epoch_restamp "$SD/session-start-time" "$SD" || true
rm -f "$TL_BIN/mktemp"
assert_eq "no temp file: the epoch is untouched" 42 "$(cat "$SD/session-start-time")"
# a failing rename leaves no temp file behind, and a symlinked head or id file is never written through
printf '43\n' >"$SD/session-start-time"
tl_stub mv 'exit 1'; hash -r
sb_session_epoch_restamp "$SD/session-start-time" "$SD" || true
rm -f "$TL_BIN/mv"; hash -r
assert_eq "a failing rename: the epoch is untouched" 43 "$(cat "$SD/session-start-time")"
printf 'f/keep/me\n' >"$SD/files-written.9"; printf '44\n' >"$SD/session-start-time"
tl_stub mv 'exit 1'; hash -r
r=0; sb_session_epoch_restamp "$SD/session-start-time" "$SD" || r=$?
rm -f "$TL_BIN/mv"; hash -r
assert_eq "a failed merge write reports failure" 1 "$r"
assert_eq "...keeps the source trace" "f/keep/me" "$(cat "$SD/files-written.9")"
assert_eq "...and the old epoch" 44 "$(cat "$SD/session-start-time")"
tl_stub mktemp 'exit 1'; hash -r
r=0; sb_session_epoch_restamp "$SD/session-start-time" "$SD" || r=$?
rm -f "$TL_BIN/mktemp"; hash -r
assert_eq "no temp file for the merge: failure, trace kept" "1 f/keep/me" "$r $(cat "$SD/files-written.9")"
rm -f "$SD/files-written.9"
assert_eq "...and no temp file is left" 0 "$(find "$SD" -maxdepth 1 -name 'session-start-time.*' | wc -l | tr -d ' ')"
rm -f "$SD/session-start-head" "$SD/session-start-sid"; ln -s "$TL_TMP/head-victim" "$SD/session-start-head"; ln -s "$TL_TMP/sid-victim2" "$SD/session-start-sid"
sb_session_epoch_rotate "$SD/session-start-time" "$SD" "$EC_PROJ" keep cx9
assert_file_absent "a symlinked HEAD file is not written through" "$TL_TMP/head-victim"
assert_file_absent "a symlinked id file is not written through" "$TL_TMP/sid-victim2"
rm -f "$SD/session-start-head" "$SD/session-start-sid"
# an epoch path that is a directory is left alone (mv would move the temp file into it)
mkdir "$SD/ss-dir"
sb_session_epoch_restamp "$SD/ss-dir" "$SD" || true
assert_eq "a directory as the epoch file stays empty" 0 "$(find "$SD/ss-dir" | wc -l | tr -d ' ' | awk '{print $1-1}')"
rmdir "$SD/ss-dir"
# a symlinked epoch file is never written through
rm -f "$SD/session-start-time"; ln -s "$TL_TMP/epoch-victim" "$SD/session-start-time"
sb_session_epoch_restamp "$SD/session-start-time" "$SD" || true
assert_file_absent "a symlinked epoch is not written through" "$TL_TMP/epoch-victim"
rm -f "$SD/session-start-time"; rm -f "$SD"/files-written.*

# r6-05: the real doc-scheme gate: a checklist from an earlier session is stale, one from this session passes
# shellcheck source=../../hooks/lib/doc-scheme-gate.sh
source "$TL_REPO_ROOT/hooks/lib/doc-scheme-gate.sh"
DR="$TL_TMP/docrepo"; rm -rf "$DR"; mkdir -p "$DR/docs"
echo "# scheme" >"$DR/docs/doc-scheme.md"
cat >"$DR/docs/doc-scheme.json" <<'JSON'
{"enforcement":{"enabled":true,"granularity_levels":[2,3]},
 "mandatory_updated_docs":[],
 "required_docs":[{"key":"docs/ARCH.md","mandatory_updated":false,"required_sections":[]}]}
JSON
echo arch >"$DR/docs/ARCH.md"
echo '{"task_id":"T-1","task_granularity":2,"docs":{"docs/ARCH.md":"not-needed:unchanged"},"sections":{}}' >"$DR/docs/task-doc-checklist.json"
old_epoch=$(( $(date +%s) - 100000 ))
settime "$((old_epoch + 10))" "$DR/docs/ARCH.md" "$DR/docs/task-doc-checklist.json"
printf '%s\n' "$old_epoch" >"$SD/session-start-time"
EMITTED="$TL_TMP/doc-emitted"; rm -f "$EMITTED"; emit() { printf '%s' "$1" >"$EMITTED"; }
(sb_doc_scheme_gate_enforce task "$DR" "$SD" emit) || true
assert_file_absent "a checklist from the current session satisfies the gate" "$EMITTED"
fresh_session
rm -f "$EMITTED"; (sb_doc_scheme_gate_enforce task "$DR" "$SD" emit) || true
assert_contains "after a new session the earlier checklist is stale" "$(cat "$EMITTED" 2>/dev/null)" "Stale checklist (not updated this session)"
touch "$DR/docs/task-doc-checklist.json" "$DR/docs/ARCH.md"
rm -f "$EMITTED"; (sb_doc_scheme_gate_enforce task "$DR" "$SD" emit) || true
assert_file_absent "a checklist touched in the new session passes again" "$EMITTED"

tl_results
