#!/usr/bin/env bash
# Unit tests for hooks/lib/site-session.sh (site profile, session state, vloops, evidence helpers).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# shellcheck source=../../hooks/lib/site-session.sh
source "$TL_REPO_ROOT/hooks/lib/site-session.sh"
# shellcheck source=../../hooks/lib/tool-input.sh
source "$TL_REPO_ROOT/hooks/lib/tool-input.sh"

unset SB_SITE_PREVIEW_PORT
export SB_RUNTIME_STATE_DIR="$TL_TMP/state"
mkdir -p "$SB_RUNTIME_STATE_DIR"
SESS="$SB_RUNTIME_STATE_DIR/site-session.json"

PROJ="$TL_TMP/proj"
mkdir -p "$PROJ/site/help" "$PROJ/sub/deeper" "$PROJ/node_modules/x/site" "$PROJ/tests/scripts"
CFG="$PROJ/.silver-bullet.json"
echo '# sb' >"$PROJ/silver-bullet.md"
# load_in_proj: load the profile of $PROJ from wherever the test is standing (the loader reads the project of $PWD)
load_in_proj() { local old="$PWD" r=0; sb_integrity_forget; cd "$PROJ"; sb_site_profile_load || r=$?; cd "$old"; return "$r"; }
profile() { jq -cn --argjson p "$1" '{sb_initiated:true, site_profile:$p}' >"$CFG"; load_in_proj; }
git -C "$PROJ" init -q -b main
git -C "$PROJ" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
PROJ_REAL="$(cd "$PROJ" && pwd -P)"
HEAD_SHA="$(git -C "$PROJ" rev-parse HEAD)"
SCOPE="$PROJ_REAL|main"

rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
# rcn: 0 on success, 1 on any failure (jq answers 5 for unparsable input)
rcn() { local r=0; "$@" >/dev/null 2>&1 || r=1; echo "$r"; }
reset() { rm -f "$SB_RUNTIME_STATE_DIR"/*.json "$SB_RUNTIME_STATE_DIR"/*.jsonl "$SB_RUNTIME_STATE_DIR"/*.log 2>/dev/null || true; }
# session JSON: an active session in this scope with one counted edit, merged with $1
mksession() { jq -cn --arg sc "$SCOPE" --argjson x "${1:-{\}}" '{active:true,scope:$sc,edit_seq:1,regression_passed_seq:0,touch_reason:"edit:site/a.html"} + $x' >"$SESS"; }

# --- profile load ---------------------------------------------------------
assert_eq "profile: outside any project" 1 "$(cd "$TL_TMP" && rc sb_site_profile_load)"
echo '{"sb_initiated":true}' >"$CFG"
assert_eq "profile: no site_profile section is not a site project (R9-02)" 1 "$(rc load_in_proj)"
load_in_proj || true
assert_eq "profile: no section leaves the root empty" "" "$SB_SITE_ROOT"
echo '{"site_profile":{"enabled":false}}' >"$CFG"
assert_eq "profile: enabled false" 1 "$(rc load_in_proj)"
echo '{"site_profile":{"enabled":"yes"}}' >"$CFG"
assert_eq "profile: enabled must be the boolean true" 1 "$(rc load_in_proj)"
profile '{"enabled":true}'
assert_eq "profile: enabled loads" "$PROJ_REAL" "$SB_SITE_ROOT"
assert_eq "profile: default site dir" "site" "$SB_SITE_DIR"
assert_eq "profile: no scripts by default" "" "$SB_SITE_REGRESSION_SCRIPTS"
assert_eq "profile: no live url by default" "" "$SB_SITE_LIVE_URL"
assert_eq "profile: default evidence age is a day" "86400" "$SB_SITE_LIVE_MAX_AGE"
profile '{"enabled":true,"dir":"web/public/","regression_scripts":["tests/a.sh","../x.sh","/abs.sh","~/h.sh","a/../b.sh","tests/b.sh"],"live_url":"https://ex.test/","preview_port":9001,"preview_script":"bin/serve.sh","live_evidence_max_age_seconds":600}'
assert_eq "profile: site dir without the trailing slash" "web/public" "$SB_SITE_DIR"
assert_eq "profile: only project-relative scripts are kept" $'tests/a.sh\ntests/b.sh\n' "$SB_SITE_REGRESSION_SCRIPTS"
assert_eq "profile: live url" "https://ex.test/" "$SB_SITE_LIVE_URL"
assert_eq "profile: preview port" "9001" "$SB_SITE_PROFILE_PORT"
assert_eq "profile: preview script" "bin/serve.sh" "$SB_SITE_PREVIEW_SCRIPT"
assert_eq "profile: evidence max age" "600" "$SB_SITE_LIVE_MAX_AGE"
profile '{"enabled":true,"dir":"../up","live_url":"ftp://x","preview_script":"/etc/x","preview_port":"80","live_evidence_max_age_seconds":0}'
assert_eq "profile: a site dir that escapes is replaced by the default" "site" "$SB_SITE_DIR"
assert_eq "profile: a non-http live url is dropped" "" "$SB_SITE_LIVE_URL"
assert_eq "profile: an absolute preview script is dropped" "" "$SB_SITE_PREVIEW_SCRIPT"
assert_eq "profile: a non-numeric port is dropped" "" "$SB_SITE_PROFILE_PORT"
assert_eq "profile: a zero evidence age is dropped" "86400" "$SB_SITE_LIVE_MAX_AGE"
profile '{"enabled":true,"preview_port":9001}'
profile '{"enabled":true}'
assert_eq "profile: a profile without a port forgets the previous one" "" "$SB_SITE_PROFILE_PORT"

# a failing config read is an unset value, never a crash
real_jq="$(command -v jq)"
echo '{"sb_initiated":true,"site_profile":{"enabled":true,"dir":"web","live_url":"https://ex.test/"}}' >"$CFG"
tl_stub jq "if [[ \"\$*\" == *'site_profile.dir'* || \"\$*\" == *'site_profile.live_url'* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r
load_in_proj
assert_eq "profile: a failing read of the site dir keeps the default" "site" "$SB_SITE_DIR"
assert_eq "profile: a failing read of the live url leaves it unset" "" "$SB_SITE_LIVE_URL"
rm -f "$TL_BIN/jq"; hash -r
profile '{"enabled":true}'

# --- path_is_site: anchored to <root>/<dir> -------------------------------
cd "$PROJ/sub/deeper"
SB_SITE_CWD=""
assert_eq "path_is_site: empty path" 1 "$(rc sb_site_session_path_is_site "")"
assert_eq "path_is_site: relative path is judged from the cwd (not the site)" 1 "$(rc sb_site_session_path_is_site "site/index.html")"
assert_eq "path_is_site: absolute site file" 0 "$(rc sb_site_session_path_is_site "$PROJ/site/index.html")"
assert_eq "path_is_site: ../ spelling that lands in the site" 0 "$(rc sb_site_session_path_is_site "../../site/help/a.html")"
assert_eq "path_is_site: a site/ directory elsewhere on disk (R9-02)" 1 "$(rc sb_site_session_path_is_site "/elsewhere/site/x.css")"
assert_eq "path_is_site: a site/ directory inside node_modules (R9-02)" 1 "$(rc sb_site_session_path_is_site "$PROJ/node_modules/x/site/a.js")"
assert_eq "path_is_site: a sibling called site-old" 1 "$(rc sb_site_session_path_is_site "$PROJ/site-old/a.html")"
assert_eq "path_is_site: ordinary source" 1 "$(rc sb_site_session_path_is_site "$PROJ/src/a.sh")"
SB_SITE_CWD="$PROJ"
assert_eq "path_is_site: SB_SITE_CWD is the base of a relative path" 0 "$(rc sb_site_session_path_is_site "site/index.html")"
cd "$PROJ"
sb_site_set_cwd "$(jq -cn --arg c "$PROJ/site" '{cwd:$c}')"
assert_eq "set_cwd: the payload cwd" "$PROJ/site" "$SB_SITE_CWD"
sb_site_set_cwd "$(jq -cn '{cwd:"/no/such/dir"}')"
assert_eq "set_cwd: a missing cwd falls back to the hook's" "$PROJ" "$SB_SITE_CWD"
sb_site_set_cwd 'not json'
assert_eq "set_cwd: no payload cwd falls back to the hook's" "$PROJ" "$SB_SITE_CWD"
SB_SITE_ROOT_SAVE="$SB_SITE_ROOT"; SB_SITE_ROOT=""
assert_eq "path_is_site: no loaded profile is never a site" 1 "$(rc sb_site_session_path_is_site "$PROJ/site/index.html")"
SB_SITE_ROOT="$SB_SITE_ROOT_SAVE"
assert_eq "path_is_site: an unnormalisable path is not a site path" 1 "$(rc sb_site_session_path_is_site "$(printf 'a\0b')")"

# --- intent detectors -----------------------------------------------------
assert_eq "site intent: empty prompt" 1 "$(rc sb_site_prompt_is_site_intent "")"
assert_eq "site intent: matches Help Center (case-insens)" 0 "$(rc sb_site_prompt_is_site_intent "Update the HELP CENTER")"
assert_eq "site intent: unrelated prompt" 1 "$(rc sb_site_prompt_is_site_intent "fix the parser")"
assert_eq "delegation intent: empty" 1 "$(rc sb_site_text_is_agent_delegation_intent "")"
assert_eq "delegation intent: silver-agent-codex" 0 "$(rc sb_site_text_is_agent_delegation_intent "run silver-agent-codex now")"
assert_eq "delegation intent: plain text" 1 "$(rc sb_site_text_is_agent_delegation_intent "hello")"

# --- scope ----------------------------------------------------------------
assert_eq "scope: project and branch" "$SCOPE" "$(sb_site_session_scope)"
SB_SITE_ROOT_SAVE="$SB_SITE_ROOT"; SB_SITE_ROOT=""
assert_eq "scope: no profile loaded" "|" "$(sb_site_session_scope)"
SB_SITE_ROOT="$SB_SITE_ROOT_SAVE"
git -C "$PROJ" checkout -q --detach
assert_eq "scope: a detached HEAD has an empty branch" "$PROJ_REAL|" "$(sb_site_session_scope)"
git -C "$PROJ" checkout -q main

# --- touch / note ---------------------------------------------------------
reset
sb_site_session_touch
assert_eq "touch creates an active session with the default reason" "edit" "$(jq -r .touch_reason "$SESS")"
assert_eq "touch: first edit is counted" "1" "$(jq -r .edit_seq "$SESS")"
assert_eq "touch: the session is stamped with its scope" "$SCOPE" "$(jq -r .scope "$SESS")"
assert_eq "touch new file: push_intent false" "false" "$(jq -r .push_intent "$SESS")"
sb_site_session_touch "edit:site/a.html"
assert_eq "touch updates the existing reason" "edit:site/a.html" "$(jq -r .touch_reason "$SESS")"
assert_eq "touch: the second edit is counted" "2" "$(jq -r .edit_seq "$SESS")"
jq '.scope="/other|main" | .push_intent=true' "$SESS" >"$SESS.t" && mv "$SESS.t" "$SESS"
sb_site_session_touch "edit:site/b.html"
assert_eq "touch: a session left by another scope restarts" "1" "$(jq -r .edit_seq "$SESS")"
assert_eq "touch: the restart drops stale flags" "false" "$(jq -r .push_intent "$SESS")"
reset
sb_site_session_mark_site_intent
assert_file_absent "mark_site_intent never starts a session (R9-02)" "$SESS"
sb_site_session_mark_push_intent
assert_file_absent "mark_push_intent never starts a session (R9-01)" "$SESS"
sb_site_session_mark_live_claim_pending
assert_file_absent "mark_live_claim_pending never starts a session (R9-02)" "$SESS"
mksession '{"edit_seq":0}'
sb_site_session_mark_push_intent
assert_eq "mark_push_intent: a session without site edits is not annotated" "false" "$(jq -r '.push_intent // false' "$SESS")"
mksession
sb_site_session_mark_site_intent
assert_eq "mark_site_intent reason" "site-intent" "$(jq -r .touch_reason "$SESS")"
assert_eq "mark_site_intent does not move the edit counter (R9-13)" "1" "$(jq -r .edit_seq "$SESS")"
sb_site_session_mark_push_intent
assert_eq "mark_push_intent sets the flag" "true" "$(jq -r .push_intent "$SESS")"
assert_eq "mark_push_intent reason" "push-intent" "$(jq -r .touch_reason "$SESS")"
assert_eq "mark_push_intent does not move the edit counter (R9-13)" "1" "$(jq -r .edit_seq "$SESS")"
sb_site_session_mark_live_claim_pending
assert_eq "live_claim_pending set" "true" "$(jq -r .live_claim_pending "$SESS")"
sb_site_session_mark_live_claim_pending
assert_eq "live_claim_pending idempotent" "true" "$(jq -r .live_claim_pending "$SESS")"

# --- active / has_site_work / gates_apply ---------------------------------
reset
assert_eq "active: no file" 1 "$(rc sb_site_session_active)"
assert_eq "has_site_work: no file" 1 "$(rc sb_site_session_has_site_work)"
assert_eq "gates_apply: no session" 1 "$(rc sb_site_session_gates_apply)"
mksession
assert_eq "active: true" 0 "$(rc sb_site_session_active)"
assert_eq "has_site_work: a counted edit" 0 "$(rc sb_site_session_has_site_work)"
assert_eq "gates_apply: genuine site session" 0 "$(rc sb_site_session_gates_apply)"
mksession '{"edit_seq":0,"touch_reason":"push-intent","push_intent":true,"live_claim_pending":true}'
assert_eq "has_site_work: push intent and claims are not site work (R9-01)" 1 "$(rc sb_site_session_has_site_work)"
assert_eq "gates_apply: push intent alone does not apply the gates (R9-01)" 1 "$(rc sb_site_session_gates_apply)"
mksession '{"active":false}'
assert_eq "gates_apply: inactive session" 1 "$(rc sb_site_session_gates_apply)"
mksession '{"scope":"/elsewhere|main"}'
assert_eq "active: a session of another scope is not active (R9-08)" 1 "$(rc sb_site_session_active)"
mksession
echo '{"active":true}' >"$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
assert_eq "gates_apply: an active agent delegation does not switch the gates off (R9-04)" 0 "$(rc sb_site_session_gates_apply)"
rm -f "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
SB_SITE_ROOT_SAVE="$SB_SITE_ROOT"; SB_SITE_ROOT=""
assert_eq "gates_apply: no profile loaded" 1 "$(rc sb_site_session_gates_apply)"
SB_SITE_ROOT="$SB_SITE_ROOT_SAVE"
echo 'not json' >"$SESS"
assert_eq "has_site_work: unparsable state is not site work" 1 "$(rcn sb_site_session_has_site_work)"
assert_eq "active: unparsable state" 1 "$(rcn sb_site_session_active)"
ln -sf "$TL_TMP/none" "$SESS"
assert_eq "active: a symlinked session file is refused" 1 "$(rc sb_site_session_active)"
rm -f "$SESS"

# --- stop loop release ----------------------------------------------------
reset
assert_eq "loop release: a first Stop is not released" 1 "$(rc sb_site_stop_loop_release gate-a '{"hook_event_name":"Stop"}')"
assert_eq "loop release: invalid input is not released" 1 "$(rc sb_site_stop_loop_release gate-a 'not json')"
assert_eq "loop release: a Stop already continuing is released" 0 "$(rc sb_site_stop_loop_release gate-a '{"stop_hook_active":true}')"
assert_contains "loop release: the release leaves an audit line" "$(cat "$SB_RUNTIME_STATE_DIR/stop-loop-release.log")" "gate-a released on stop_hook_active"
rm -f "$SB_RUNTIME_STATE_DIR/stop-loop-release.log"; mkdir "$SB_RUNTIME_STATE_DIR/stop-loop-release.log"
assert_eq "loop release: an unwritable audit log still releases" 0 "$(rc sb_site_stop_loop_release gate-a '{"stop_hook_active":true}')"
rmdir "$SB_RUNTIME_STATE_DIR/stop-loop-release.log"

# --- subagent input detection --------------------------------------------
assert_eq "subagent related: empty" 1 "$(rc sb_site_session_subagent_input_is_site_related "")"
assert_eq "subagent related: delegation text excluded" 1 "$(rc sb_site_session_subagent_input_is_site_related "silver-agent-codex edit site/a.html")"
assert_eq "subagent related: site path" 0 "$(rc sb_site_session_subagent_input_is_site_related "edit site/help/a.html")"
assert_eq "subagent related: unrelated" 1 "$(rc sb_site_session_subagent_input_is_site_related "refactor parser")"

# --- regression_current / mark_regression_pass ----------------------------
reset
assert_eq "regression_current: no file" 1 "$(rc sb_site_session_regression_current)"
mksession '{"edit_seq":3,"regression_passed_seq":3}'
assert_eq "regression_current: passed for the latest edit" 0 "$(rc sb_site_session_regression_current)"
mksession '{"edit_seq":4,"regression_passed_seq":3}'
assert_eq "regression_current: an edit after the pass makes it stale" 1 "$(rc sb_site_session_regression_current)"
mksession '{"regression_passed_seq":null}'
assert_eq "regression_current: never passed" 1 "$(rc sb_site_session_regression_current)"
echo 'not json' >"$SESS"
assert_eq "regression_current: unparsable state false" 1 "$(rcn sb_site_session_regression_current)"
reset
sb_site_session_mark_regression_pass 1
assert_file_absent "mark_regression_pass: no session, nothing created" "$SESS"
mksession '{"edit_seq":5}'
sb_site_session_mark_regression_pass 5
assert_eq "mark_regression_pass records the covered edit" "5" "$(jq -r .regression_passed_seq "$SESS")"
assert_match "mark_regression_pass records the time" '^20[0-9]{2}-' "$(jq -r .regression_passed_at "$SESS")"
sb_site_session_mark_regression_pass
assert_eq "mark_regression_pass without a seq records 0" "0" "$(jq -r .regression_passed_seq "$SESS")"

# --- run_regression_tests -------------------------------------------------
suite() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$PROJ/tests/scripts/$1.sh"; }
commit_suites() { git -C "$PROJ" add -A >/dev/null 2>&1; git -C "$PROJ" -c user.name=t -c user.email=t@t commit -q --allow-empty -m s; }
profile '{"enabled":true,"regression_scripts":["tests/scripts/one.sh","tests/scripts/two.sh"]}'
suite one 'echo ran-one'
suite two 'echo ran-two'
commit_suites
reset
assert_eq "run_regression: empty root => 90" 90 "$(rc sb_site_session_run_regression_tests "")"
rm "$PROJ/tests/scripts/two.sh"
assert_eq "run_regression: a configured script that is missing => 90" 90 "$(rc sb_site_session_run_regression_tests "$PROJ")"
suite two 'echo ran-two # edited'
assert_eq "run_regression: an uncommitted script is untrusted => 92 (R9-07)" 92 "$(rc sb_site_session_run_regression_tests "$PROJ")"
assert_eq "regression_untrusted names it" "tests/scripts/two.sh" "$(sb_site_regression_untrusted "$PROJ")"
commit_suites
assert_eq "regression_untrusted: committed scripts are trusted" "" "$(sb_site_regression_untrusted "$PROJ")"
suite one 'exit 0'
assert_eq "regression_untrusted: a committed script edited in the work tree is not" "tests/scripts/one.sh" "$(sb_site_regression_untrusted "$PROJ")"
git -C "$PROJ" checkout -q -- tests/scripts/one.sh
rm "$PROJ/tests/scripts/two.sh"; ln -s one.sh "$PROJ/tests/scripts/two.sh"
assert_eq "regression_untrusted: a symlink is not trusted" "tests/scripts/two.sh" "$(sb_site_regression_untrusted "$PROJ")"
rm "$PROJ/tests/scripts/two.sh"; git -C "$PROJ" checkout -q -- tests/scripts/two.sh
mksession '{"edit_seq":2}'
log="$(sb_site_session_run_regression_tests "$PROJ")"
assert_match "run_regression: log file under state dir with .log" '/site-regression\.[A-Za-z0-9]+\.log$' "$log"
assert_contains "run_regression: log captures the first script" "$(cat "$log")" "ran-one"
assert_contains "run_regression: log captures the last script" "$(cat "$log")" "ran-two"
assert_eq "run_regression: the pass covers the counted edit" "2" "$(jq -r .regression_passed_seq "$SESS")"
suite two 'echo boom; exit 3'
commit_suites
mksession '{"edit_seq":2}'
r=0; log="$(sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_eq "run_regression: suite failure rc propagated" 3 "$r"
assert_contains "run_regression: failure log content" "$(cat "$log")" "boom"
assert_eq "run_regression: failure does not mark a pass" "0" "$(jq -r .regression_passed_seq "$SESS")"
suite one 'exit 4'
suite two 'echo ran-two-after-failure'
commit_suites
r=0; log="$(sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_eq "run_regression: the first failing script stops the run" 4 "$r"
assert_not_contains "run_regression: later scripts do not run after a failure" "$(cat "$log")" "after-failure"
suite one 'echo ok'
suite two 'echo ok'
commit_suites
# state dir not creatable -> falls back to TMPDIR pid log
echo blocker >"$TL_TMP/blocker"
mkdir -p "$TL_TMP/tmpd"
r=0; log="$(SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub" TMPDIR="$TL_TMP/tmpd" sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_match "run_regression: mktemp failure falls back to TMPDIR pid log" "^$TL_TMP/tmpd/site-regression-[0-9]+\\.log\$" "$log"
rm -f "$log"
mkdir -p "$TL_TMP/fallback"
r=0; log="$(SB_SITE_REGRESSION_FALLBACK_DIR="$TL_TMP/fallback" SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub" TMPDIR="$TL_TMP/blocker/nope" sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_match "run_regression: second fallback is the fallback-dir pid log" "^$TL_TMP/fallback/site-regression-[0-9]+\\.log\$" "$log"
rm -f "$log"
assert_contains "run_regression: fallback default is /tmp" "$(grep -c 'SB_SITE_REGRESSION_FALLBACK_DIR:-/tmp' "$TL_REPO_ROOT/hooks/lib/site-session.sh")" "1"
mkdir -p "$TL_TMP/fallback/site-regression-$$.log"
r=0; SB_SITE_REGRESSION_FALLBACK_DIR="$TL_TMP/fallback" SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub" TMPDIR="$TL_TMP/blocker/nope" sb_site_session_run_regression_tests "$PROJ" >/dev/null 2>&1 || r=$?
rmdir "$TL_TMP/fallback/site-regression-$$.log"
assert_eq "run_regression: no log can be allocated => 91" 91 "$r"
mkdir -p "$TL_TMP/mvfail"
tl_stub mv 'exit 1'; hash -r
r=0; log="$(SB_RUNTIME_STATE_DIR="$TL_TMP/mvfail" sb_site_session_run_regression_tests "$PROJ")" || r=$?
rm -f "$TL_BIN/mv"; hash -r
assert_match "run_regression: mv failure keeps un-suffixed log" '/site-regression\.[A-Za-z0-9]+$' "$log"
eval 'cd() { return 1; }'
r=0; log="$(SB_RUNTIME_STATE_DIR="$TL_TMP/mvfail" sb_site_session_run_regression_tests "$PROJ")" || r=$?
unset -f cd
assert_eq "run_regression: cd into repo failing => rc 1" 1 "$r"
profile '{"enabled":true}'
r=0; log="$(sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_eq "run_regression: no configured script is a pass" 0 "$r"

# --- shell push classification -------------------------------------------
push_kind() { # command: the kind the shell analysis gives it ("" for none)
  sb_tool_input_load "$(jq -cn --arg c "$1" --arg d "$PROJ" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')"
  sb_site_shell_push_kind || true
}
git -C "$PROJ" remote add origin https://example.invalid/r.git
git -C "$PROJ" update-ref refs/remotes/origin/main HEAD
git -C "$PROJ" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
assert_eq "push kind: the default branch is a final delivery" "final" "$(push_kind 'git push origin main')"
assert_eq "push kind: a global option does not hide a push (R9-06)" "final" "$(push_kind 'git -C . push origin main')"
assert_eq "push kind: doubled spaces do not hide a push (R9-06)" "final" "$(push_kind 'git  push origin main')"
assert_eq "push kind: a branch whose name contains main is not the default (R9-06)" "final" "$(push_kind 'git push origin fix/main-nav')"
git -C "$PROJ" checkout -q -b fix/main-nav
assert_eq "push kind: a provable feature branch push (R9-06)" "feature" "$(push_kind 'git push origin fix/main-nav')"
git -C "$PROJ" checkout -q main
assert_eq "push kind: a command that mentions git push is not a push (R9-06)" "" "$(push_kind "grep -rn 'git push' docs/")"
assert_eq "push kind: no push" "" "$(push_kind 'git status')"

# --- live publish evidence ------------------------------------------------
EV="$(sb_site_session_live_evidence_file)"
ev() { # [status] [sha] [epoch offset]
  jq -n --arg st "${1:-LIVE}" --arg sha "${2:-$(git -C "$PROJ" rev-parse HEAD)}" --arg r "$PROJ_REAL" --argjson e "$(( $(date +%s) + ${3:-0} ))" \
    '{status:$st,commit_sha:$sha,project:$r,urls:["https://x"],markers_matched:["m"],verified_at:"t",verified_epoch:$e}' >"$EV"
}
reset
assert_eq "live evidence: missing" 1 "$(rc sb_live_publish_evidence_valid)"
ev
assert_eq "live evidence: complete for HEAD" 0 "$(rc sb_live_publish_evidence_valid)"
ev NOT_LIVE
jq '.markers_matched=[]' "$EV" >"$EV.t" && mv "$EV.t" "$EV"
assert_eq "live evidence: an honest NOT_LIVE needs no markers" 0 "$(rc sb_live_publish_evidence_valid)"
ev LIVE
jq '.markers_matched=[]' "$EV" >"$EV.t" && mv "$EV.t" "$EV"
assert_eq "live evidence: LIVE needs a matched marker" 1 "$(rc sb_live_publish_evidence_valid)"
ev LIVE deadbeef
assert_eq "live evidence: another commit (R9-08)" 1 "$(rc sb_live_publish_evidence_valid)"
ev LIVE "$HEAD_SHA" -90000
assert_eq "live evidence: older than the max age (R9-08)" 1 "$(rc sb_live_publish_evidence_valid)"
ev LIVE "$HEAD_SHA" 1000
assert_eq "live evidence: from the future" 1 "$(rc sb_live_publish_evidence_valid)"
ev
jq '.urls=[]' "$EV" >"$EV.t" && mv "$EV.t" "$EV"
assert_eq "live evidence: no urls" 1 "$(rc sb_live_publish_evidence_valid)"
ev MAYBE
assert_eq "live evidence: bad status" 1 "$(rc sb_live_publish_evidence_valid)"
ev
jq '.project="/other"' "$EV" >"$EV.t" && mv "$EV.t" "$EV"
assert_eq "live evidence: another project" 1 "$(rc sb_live_publish_evidence_valid)"
echo '{"status":"LIVE","commit_sha":"abc","urls":["u"],"verified_at":"t","markers_matched":["m"]}' >"$EV"
assert_eq "live evidence: the old hand-written shape" 1 "$(rc sb_live_publish_evidence_valid)"
ev
SB_SITE_ROOT_SAVE="$SB_SITE_ROOT"; SB_SITE_ROOT="$TL_TMP/not-a-repo"
assert_eq "live evidence: no HEAD to compare with" 1 "$(rc sb_live_publish_evidence_valid)"
SB_SITE_ROOT="$SB_SITE_ROOT_SAVE"
rm -f "$EV"; echo '{"status":"LIVE"}' >"$TL_TMP/real-ev.json"; ln -s "$TL_TMP/real-ev.json" "$EV"
assert_eq "live evidence: symlink refused" 1 "$(rc sb_live_publish_evidence_valid)"
rm -f "$EV"

# --- subagent log ---------------------------------------------------------
reset
assert_eq "subagents_spawned: no log" 1 "$(rc sb_site_session_subagents_spawned)"
sb_site_session_record_subagent_spawn ""
assert_file_absent "record_spawn: empty input writes nothing" "$(sb_site_session_subagent_log)"
mksession '{"touch_reason":"edit:x"}'
sb_site_session_record_subagent_spawn "update site/help/x.html"
LOG="$(sb_site_session_subagent_log)"
assert_eq "record_spawn: site_related true" "true" "$(tail -n1 "$LOG" | jq -r .site_related)"
assert_eq "record_spawn: site input annotates an existing session" "subagent-site" "$(jq -r .touch_reason "$SESS")"
assert_eq "subagents_spawned: non-empty log" 0 "$(rc sb_site_session_subagents_spawned)"
reset
sb_site_session_record_subagent_spawn "update site/help/x.html"
assert_file_absent "record_spawn: a site spawn never starts a session (R9-02)" "$SESS"
mksession
sb_site_session_record_subagent_spawn "refactor parser"
assert_eq "record_spawn: unrelated input does not touch the session" "edit:site/a.html" "$(jq -r .touch_reason "$SESS")"
assert_eq "record_spawn: unrelated site_related false" "false" "$(tail -n1 "$LOG" | jq -r .site_related)"
: >"$LOG"
assert_eq "subagents_spawned: empty log" 1 "$(rc sb_site_session_subagents_spawned)"
sb_site_session_clear_subagent_log
assert_file_absent "clear_subagent_log removes log" "$LOG"

# --- vloops ---------------------------------------------------------------
reset
VL="$(sb_site_session_vloop_file)"
assert_eq "vloop_pending: no file" 1 "$(rc sb_site_session_vloop_pending)"
assert_eq "vloop_mark: empty id => 1" 1 "$(rc sb_site_session_vloop_mark "")"
sb_site_session_vloop_mark "preflight" "ref1"
assert_eq "vloop_mark initialises file and marks" "done" "$(jq -r '.steps[]|select(.id=="preflight").status' "$VL")"
assert_eq "vloop_mark stores evidence ref" "ref1" "$(jq -r '.steps[]|select(.id=="preflight").evidence_ref' "$VL")"
sb_site_session_vloop_mark "preflight" ""
assert_eq "vloop_mark empty ref keeps old ref" "ref1" "$(jq -r '.steps[]|select(.id=="preflight").evidence_ref' "$VL")"
assert_eq "vloop_pending: required steps remain" 0 "$(rc sb_site_session_vloop_pending)"
for s in implement regression visual; do sb_site_session_vloop_mark "$s"; done
assert_eq "vloop_pending: only optional publish left => not pending" 1 "$(rc sb_site_session_vloop_pending)"
jq '(.steps[]|select(.id=="publish")).required=true' "$VL" >"$VL.t" && mv "$VL.t" "$VL"
assert_eq "vloop_pending: a required publish counts" 0 "$(rc sb_site_session_vloop_pending)"
sb_site_session_vloop_mark publish
assert_eq "vloop_pending: all done" 1 "$(rc sb_site_session_vloop_pending)"
assert_eq "vloop summary: complete => empty" "" "$(sb_site_session_vloop_pending_summary)"
sb_site_session_init_vloops
assert_contains "vloop summary lists pending step" "$(sb_site_session_vloop_pending_summary)" "Preflight regression (preflight): pending"
rm -f "$VL"
assert_eq "vloop summary: no file => empty" "" "$(sb_site_session_vloop_pending_summary)"
echo 'not json' >"$VL"
assert_eq "vloop_pending_summary: unparsable file prints nothing" "" "$(sb_site_session_vloop_pending_summary)"

# --- sync_vloops_from_state ----------------------------------------------
shot="$TL_TMP/shot.png"; printf 'png' >"$shot"
reset
sb_site_session_sync_vloops_from_state
assert_eq "sync: no session creates pending vloops" "pending" "$(jq -r '.steps[]|select(.id=="implement").status' "$VL")"
mksession '{"edit_seq":2,"regression_passed_seq":2,"push_intent":false}'
ev
jq -n --arg r "$PROJ_REAL" --arg p "$shot" '{captured_at:"t",project:$r,edit_seq:2,paths:[$p]}' >"$(sb_site_session_visual_evidence_file)"
sb_site_session_sync_vloops_from_state
for s in preflight regression implement publish visual; do
  assert_eq "sync: $s marked done" "done" "$(jq -r --arg s "$s" '.steps[]|select(.id==$s).status' "$VL")"
done
assert_eq "sync: publish stays optional without push intent" "false" "$(jq -r '.steps[]|select(.id=="publish").required' "$VL")"
jq '.push_intent=true' "$SESS" >"$SESS.t" && mv "$SESS.t" "$SESS"
sb_site_session_sync_vloops_from_state
assert_eq "sync: push intent makes publish required" "true" "$(jq -r '.steps[]|select(.id=="publish").required' "$VL")"
jq '.edit_seq=3' "$SESS" >"$SESS.t" && mv "$SESS.t" "$SESS"
sb_site_session_sync_vloops_from_state
assert_eq "sync: a later edit makes the regression step pending again (R9-08)" "pending" "$(jq -r '.steps[]|select(.id=="regression").status' "$VL")"
assert_eq "sync: a later edit makes the visual step pending again (R9-08)" "pending" "$(jq -r '.steps[]|select(.id=="visual").status' "$VL")"

# --- visual evidence / pending audit -------------------------------------
reset
mksession '{"edit_seq":2}'
VE="$(sb_site_session_visual_evidence_file)"
assert_eq "visual valid: missing" 1 "$(rc sb_site_session_visual_evidence_valid)"
sb_site_session_mark_visual_evidence "$shot"
assert_eq "mark_visual_evidence records the path" "$shot" "$(jq -r '.paths[0]' "$VE")"
assert_eq "mark_visual_evidence records the project" "$PROJ_REAL" "$(jq -r .project "$VE")"
assert_eq "mark_visual_evidence records the covered edit" "2" "$(jq -r .edit_seq "$VE")"
assert_eq "mark_visual_evidence records viewport" "1280" "$(jq -r .viewport "$VE")"
assert_eq "mark_visual_evidence marks vloop visual" "done" "$(jq -r '.steps[]|select(.id=="visual").status' "$VL")"
assert_eq "visual valid: good" 0 "$(rc sb_site_session_visual_evidence_valid)"
printf 'png' >"$TL_TMP/shot2.png"
sb_site_session_mark_visual_evidence "$TL_TMP/shot2.png"
assert_eq "mark_visual_evidence adds a second shot of the same edit" "2" "$(jq -r '.paths|length' "$VE")"
sb_site_session_mark_visual_evidence "$shot"
assert_eq "mark_visual_evidence keeps a path once" "2" "$(jq -r '.paths|length' "$VE")"
jq '.edit_seq=3' "$SESS" >"$SESS.t" && mv "$SESS.t" "$SESS"
assert_eq "visual valid: older than the latest edit" 1 "$(rc sb_site_session_visual_evidence_valid)"
sb_site_session_mark_visual_evidence "$shot"
assert_eq "mark_visual_evidence after a later edit starts afresh" "1" "$(jq -r '.paths|length' "$VE")"
rm -f "$shot"
assert_eq "visual valid: the screenshot file is gone" 1 "$(rc sb_site_session_visual_evidence_valid)"
printf 'png' >"$shot"
jq '.project="/other"' "$VE" >"$VE.t" && mv "$VE.t" "$VE"
assert_eq "visual valid: another project" 1 "$(rc sb_site_session_visual_evidence_valid)"
echo '{"paths":[],"captured_at":"t"}' >"$VE"
assert_eq "visual valid: empty paths" 1 "$(rc sb_site_session_visual_evidence_valid)"
rm -f "$VE"; ln -s "$TL_TMP/real-ev.json" "$VE"
assert_eq "visual valid: symlink refused" 1 "$(rc sb_site_session_visual_evidence_valid)"
rm -f "$VE"

reset
assert_eq "pending audit: none" 1 "$(rc sb_site_session_pending_completion_audit)"
sb_site_session_mark_pending_completion_audit "$(printf 'x%.0s' $(seq 1 400))"
assert_eq "pending audit: marked" 0 "$(rc sb_site_session_pending_completion_audit)"
assert_eq "pending audit: preview truncated to 300" 300 "$(jq -r '.task_preview|length' "$(sb_site_session_pending_audit_file)")"
sb_site_session_clear_pending_completion_audit
assert_eq "pending audit: cleared" 1 "$(rc sb_site_session_pending_completion_audit)"
PA="$(sb_site_session_pending_audit_file)"
ln -s "$TL_TMP/real-ev.json" "$PA"
assert_eq "pending audit: symlink refused" 1 "$(rc sb_site_session_pending_completion_audit)"
rm -f "$PA"

# --- fault injection: unusable state dir -----------------------------------
reset
BROKEN="$TL_TMP/blocker/sub"
(
  export SB_RUNTIME_STATE_DIR="$BROKEN"
  sb_site_session_touch "x"
  sb_site_session_init_vloops
  sb_site_session_mark_visual_evidence "p"
  sb_site_session_mark_pending_completion_audit "p"
  sb_site_session_record_subagent_spawn "site/a.html"
) >/dev/null 2>&1 || true
assert_file_absent "broken state dir: nothing created" "$BROKEN"
mkdir -p "$TL_TMP/failbin"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/failbin/rm"; chmod +x "$TL_TMP/failbin/rm"
assert_eq "clear_subagent_log tolerates rm failure" 0 "$(PATH="$TL_TMP/failbin:$PATH" rc sb_site_session_clear_subagent_log)"
assert_eq "clear_pending_audit tolerates rm failure" 0 "$(PATH="$TL_TMP/failbin:$PATH" rc sb_site_session_clear_pending_completion_audit)"
mkdir -p "$(sb_site_session_subagent_log)"
assert_eq "record_spawn: unwritable log tolerated" 0 "$(rc sb_site_session_record_subagent_spawn "plain text")"
rmdir "$(sb_site_session_subagent_log)"
reset

# --- preview health -------------------------------------------------------
assert_eq "preview healthy: no port configured" 1 "$(rc sb_site_preview_healthy)"
profile '{"enabled":true,"preview_port":8765}'
tl_stub curl 'echo -n 200'
assert_eq "preview healthy: curl 200" 0 "$(rc sb_site_preview_healthy)"
tl_stub curl 'echo -n "$*" >"'"$TL_TMP"'/curl.args"; echo -n 200'
SB_SITE_PREVIEW_PORT=7777 sb_site_preview_healthy
assert_contains "preview healthy: an environment port wins over the profile" "$(cat "$TL_TMP/curl.args")" ":7777/"
tl_stub curl 'echo -n 200'

tl_stub curl 'echo -n 500'
assert_eq "preview healthy: curl 500" 1 "$(rc sb_site_preview_healthy)"
tl_stub curl 'exit 7'
assert_eq "preview healthy: curl failure" 1 "$(rc sb_site_preview_healthy)"
rm -f "$TL_BIN/curl"
NOCURL="$(tl_path_without curl lsof)"
assert_eq "preview healthy: no curl, no lsof" 1 "$(PATH="$NOCURL" rc sb_site_preview_healthy)"
mkdir -p "$TL_TMP/lsofbin"
printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/lsofbin/lsof"; chmod +x "$TL_TMP/lsofbin/lsof"
assert_eq "preview healthy: lsof listening" 0 "$(PATH="$TL_TMP/lsofbin:$NOCURL" rc sb_site_preview_healthy)"
printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/lsofbin/lsof"
assert_eq "preview healthy: lsof not listening" 1 "$(PATH="$TL_TMP/lsofbin:$NOCURL" rc sb_site_preview_healthy)"

tl_results
