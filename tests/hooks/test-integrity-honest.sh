#!/usr/bin/env bash
# The honest corpus: everyday work and every sanctioned writer keep working under the integrity
# record. Each row drives the real hooks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/integrity-harness.sh"

ok_cmd() { # NAME CMD [expect none|ok]
  ih_run "$2"
  assert_eq "$1: the command is not refused" "ok" "$(printf '%s' "$IH_PRE" | { read -r d; [[ "$d" == deny ]] && echo deny || echo ok; })"
  assert_eq "$1: nothing diverged" "" "$(ih_diverged)"
}
planned() { ih_rec inst-a; }

# 1. record, then edit
ih_project h1
planned
ih_edit
assert_eq "record inst-a, then edit src: allowed" "ok" "$(not_deny)"
ih_edit
assert_eq "and again" "ok" "$(not_deny)"

# 2. before planning the floor still stops edits (the record changes nothing for honest users)
ih_project h2
ih_edit
assert_contains "without planning an edit is refused as before" "$(message)" "Planning incomplete"

# 3. /sb:init stamps the contract through the file tools
ih_project h3
ih_rec silver-init
run_dc "$(edit_json "$PROJ/.silver-bullet.json" Write PreToolUse)"
assert_eq "the init skill may write the config" "ok" "$(not_deny)"
jq -n --arg v "$CFG_VERSION" '{config_version:$v,sb_initiated:true,skills:{required_planning:["inst-a"],all_tracked:["inst-a","inst-b"]},project:{src_pattern:"/src/"},note:"init"}' >"$PROJ/.silver-bullet.json"
printf '# SB init\n' >"$PROJ/silver-bullet.md"
printf 'new rules\n' >"$PROJ/CLAUDE.md"
run_dc "$(edit_json "$PROJ/.silver-bullet.json" Write PostToolUse)"
run_dc "$(edit_json "$PROJ/silver-bullet.md" Write PostToolUse)"
run_dc "$(edit_json "$PROJ/CLAUDE.md" Write PostToolUse)"
ih_lapse
assert_eq "afterwards the record follows what the skill wrote" "" "$(ih_diverged)"
planned
ih_edit
assert_eq "and source edits pass" "ok" "$(not_deny)"

# 4. /sb:add caches the GitHub project in the config: its declared keys are adopted
ih_project h4
ih_rec silver-add
jq '._github_project={"number":3}' "$PROJ/.silver-bullet.json" >"$PROJ/t.json" && mv "$PROJ/t.json" "$PROJ/.silver-bullet.json"
run_dc "$(bash_json 'jq ... > t.json && mv t.json .silver-bullet.json' PostToolUse)"
ih_lapse
sb_integrity_verify "$PROJ" ""
assert_eq "silver-add: no divergence once the skill is done" "" "$SB_IV_DIVERGED"
assert_eq "silver-add: the recorded config holds the cache" "3" "$(sb_iv_jq -r '._github_project.number')"
# ... but it does not bless another key: a weakened list stays a drift and the recorded list applies
ih_project h4b
ih_rec silver-add
jq '.skills.required_deploy=["inst-a"] | .skills.required_planning=[]' "$PROJ/.silver-bullet.json" >"$PROJ/t.json" && mv "$PROJ/t.json" "$PROJ/.silver-bullet.json"
run_dc "$(bash_json 'jq ... > t.json && mv t.json .silver-bullet.json' PostToolUse)"
ih_lapse
assert_eq "silver-add: a weakened required list stays a drift" "config" "$(ih_diverged)"
assert_eq "silver-add: the recorded planning list still applies" "inst-a" "$SB_IV_REQUIRED_PLANNING"

# 5-6. honest patches
ih_project h5
planned
ih_diff "$PROJ/src/app.js" "$FX/d.txt" src/app.js >"$FX/src.diff"
ih_run "git apply $FX/src.diff"
assert_eq "an honest git apply of a src diff after planning" "ok" "$(printf '%s' "$IH_PRE" | { read -r d; [[ "$d" == deny ]] && echo deny || echo ok; })"
ih_project h6
ih_diff "$PROJ/docs/README.md" "$FX/d.txt" docs/README.md >"$FX/docs.diff"
ih_run "git apply $FX/docs.diff"
assert_eq "a docs-only patch needs no planning" "ok" "$(printf '%s' "$IH_PRE" | { read -r d; [[ "$d" == deny ]] && echo deny || echo ok; })"

# 7-14. everyday commands
ih_project h7
for c in 'cd "$(git rev-parse --show-toplevel)" && ls' 'mkdir -p build && ls build' 'echo scratch > /tmp/sb-honest-$$.txt' 'cat .silver-bullet.json | jq .skills' 'grep -n rules CLAUDE.md' 'git status --short' 'python3 -c "print(open(\".silver-bullet.json\").read())"' 'perl -ne "print" CLAUDE.md' 'npm test' 'rm -f build/*.o' 'tar -tf $FX/s.tar'; do
  ok_cmd "everyday: $c" "$c"
done
ih_project h8
planned
rm -f "$PROJ/src/old.js"; : >"$PROJ/src/old.js"
ih_run 'rm src/old.js'
assert_eq "an honest rm of a source file after planning" "ok" "$(printf '%s' "$IH_PRE" | { read -r d; [[ "$d" == deny ]] && echo deny || echo ok; })"
ih_project h9
mkdir -p "$FX/rel" && printf 'x\n' >"$FX/rel/a.txt" && tar -cf "$FX/rel.tar" -C "$FX/rel" a.txt
ok_cmd "an honest tar -x of a release artifact into dist/" 'tar -xf $FX/rel.tar -C dist'

# 15. session start re-baselines and clears a marker
ih_project h10
touch "$SD/trivial"
ih_session_start startup
assert_eq "session start removes a leftover marker" "absent" "$([[ -e "$SD/trivial" ]] && echo present || echo absent)"
assert_eq "and the record is intact" "" "$(ih_diverged)"
ih_project h11
printf '{"sb_initiated":true,"skills":{"required_planning":["inst-a","inst-b"]},"project":{"src_pattern":"/src/"}}\n' >"$PROJ/.silver-bullet.json"
ih_session_start startup
sb_integrity_verify "$PROJ" ""
assert_eq "a config the user changed between sessions is recorded at the next start" "inst-a inst-b" "$SB_IV_REQUIRED_PLANNING"
ih_project h12
printf '{"sb_initiated":true,"skills":{"required_planning":["zzz"]},"project":{"src_pattern":"/src/"}}\n' >"$PROJ/.silver-bullet.json"
ih_session_start compact
sb_integrity_verify "$PROJ" ""
assert_eq "a compact event is not a re-baseline" "config" "$SB_IV_DIVERGED"
ih_project h13
printf 'other/branch\n' >"$SILVER_BULLET_BRANCH_FILE"
ih_session_start startup
sb_integrity_verify "$PROJ" ""
assert_eq "a branch change resets and re-baselines" "ok" "$SB_IV_STATUS"

# 16. parallel subagents
ih_project h14
pids=()
for sk in inst-a inst-b; do
  ( ih_rec "$sk" ) &
  pids+=("$!")
done
for pid in "${pids[@]}"; do wait "$pid" || true; done
assert_eq "parallel recorders keep both skills" "2" "$(sb_state_seal_trusted "$STATE" | grep -cE '^inst-(a|b)$' || true)"

# 17-19. commit, stop
ih_project h15
planned
ih_hook completion-audit.sh "$(bash_json 'git commit -m x' PreToolUse)"
assert_eq "git commit after planning: allowed" "ok" "$(not_deny)"
echo dirty >>"$PROJ/src/app.js"
ih_hook stop-check.sh '{"hook_event_name":"Stop"}'
assert_not_contains "Stop with the planning floor satisfied is not blocked on planning" "$TL_OUT" "inst-a"

# 20. a customised state file path is honoured
ih_project h16 ".state.state_file=\"$SD/custom-state\""
sb_integrity_baseline "$PROJ" session
printf 'inst-a\n' >"$SD/custom-state"
sb_state_seal_write "$SD/custom-state"
unset SILVER_BULLET_STATE_FILE
ih_edit
assert_eq "the state file named by the recorded config is read" "ok" "$(not_deny)"
export SILVER_BULLET_STATE_FILE="$STATE"

# 21-22. small edits
ih_project h17
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "ab" "cd")"
assert_eq "a first small edit" "ok" "$(not_deny)"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "ef" "gh")"
assert_eq "a second small edit" "ok" "$(not_deny)"

# 23-24. other tools
ih_project h18
planned
run_dc "$(jq -cn --arg p "$PROJ/src/nb.ipynb" '{hook_event_name:"PreToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p}}')"
assert_eq "NotebookEdit of a notebook in src after planning" "ok" "$(not_deny)"
run_dc "$(jq -cn --arg p "$PROJ/src/a.js" '{hook_event_name:"PreToolUse",tool_name:"mcp__fs__write_file",tool_input:{path:$p,content:"x"}}')"
assert_eq "an MCP write to src after planning" "ok" "$(not_deny)"

# 24b. an MCP write is judged by its name when python3 is missing
ih_project h18b
NOPYH="$(tl_path_without python3 openssl)"
run_dc "$(jq -cn --arg p "$PROJ/src/a.js" '{hook_event_name:"PreToolUse",tool_name:"mcp__fs__write_file",tool_input:{path:$p,content:"x"}}')" PATH="$NOPYH"
assert_contains "without python3 a keyed record cannot be verified: the gate says so and stops" "$(message)" "openssl or python3 is needed"

# 25. not an SB project
RUN_DIR="$NOCFG" run_dc "$(edit_json "$NOCFG/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "outside an SB project nothing is gated" "none" "$(decision)"

# 26-30. edits to instruction and planning files
ih_project h19
planned
printf 'edited by the user\n' >>"$PROJ/CLAUDE.md"
ih_edit
assert_eq "the user edits CLAUDE.md in an editor: source edits still pass" "ok" "$(not_deny)"
assert_contains "with a notice" "$(message)" "CLAUDE.md changed outside a file tool"
ih_project h20
planned
printf 'edited by the user\n' >>"$PROJ/.planning/ROADMAP.md"
ih_edit
assert_eq "the user edits ROADMAP.md in an editor: source edits still pass" "ok" "$(not_deny)"
ih_project h21
planned
printf 'more rules\n' >>"$PROJ/CLAUDE.md"
run_dc "$(edit_json "$PROJ/CLAUDE.md" Edit PostToolUse)"
assert_eq "an Edit of CLAUDE.md through the file tool is recorded" "" "$(ih_diverged)"
printf 'more plan\n' >>"$PROJ/.planning/STATE.md"
run_dc "$(edit_json "$PROJ/.planning/STATE.md" Write PostToolUse)"
assert_eq "so is a planning file" "" "$(ih_diverged)"

# 31. /sb:update rewrites silver-bullet.md
ih_project h22
ih_rec silver-update
printf '# updated\n' >"$PROJ/silver-bullet.md"
run_dc "$(edit_json "$PROJ/silver-bullet.md" Write PostToolUse)"
ih_lapse
assert_eq "silver-update rewrites silver-bullet.md" "" "$(ih_diverged)"

# 32. the unlock window follows a Bash rewrite done by a contract skill
ih_project h23
ih_rec silver-devops
jq '.project.active_workflow="devops-cycle"' "$PROJ/.silver-bullet.json" >"$PROJ/t.json" && mv "$PROJ/t.json" "$PROJ/.silver-bullet.json"
run_dc "$(bash_json 'jq ... > t.json && mv t.json .silver-bullet.json' PostToolUse)"
ih_lapse
assert_eq "silver-devops rewrites the JSON through Bash during its window" "" "$(ih_diverged)"

# 33. devops workflow lists
ih_project h24 '.project.active_workflow="devops-cycle" | .skills.required_planning=["inst-b"] | .skills.required_planning_devops=["inst-a"]'
sb_integrity_baseline "$PROJ" session
ih_edit
assert_contains "the devops planning list is the recorded one" "$(message)" "inst-a"

# 34. two projects share one state directory
ih_project h25
P1="$PROJ"
ih_project h26
sb_integrity_verify "$P1" ""
assert_eq "each project has its own record" "ok" "$SB_IV_STATUS"
sb_integrity_verify "$PROJ" ""
assert_eq "second project" "ok" "$SB_IV_STATUS"

# 35. a project no session has baselined is unbaselined: strict, and it says to start a session
ih_project h27
rm -f "$SD"/integrity-*
touch "$SD/trivial"
ih_edit
assert_eq "before the first session start there is no marker bypass" "deny" "$(decision)"
assert_contains "and the message says what to do" "$(message)" "NOT BASELINED"
assert_contains "restart the session" "$(message)" "restart the session"
# an install that never made its key keeps the legacy marker (nothing was ever recorded)
rm -f "$SD/seal.key"
touch "$SD/trivial"
ih_edit
assert_eq "an install without a key honours the marker" "ok" "$(not_deny)"
rm -f "$SD/trivial"

# 36. a project nobody baselined (new worktree, fresh clone) is recorded by its first session start
ih_project h28
rm -f "$SD"/integrity-*
ih_edit
assert_eq "unbaselined: source edits stop" "deny" "$(decision)"
ih_session_start startup
assert_eq "after a session start it is verified" "ok" "$(ih_status)"
planned
ih_edit
assert_eq "and edits follow the planning floor again" "ok" "$(not_deny)"

# 37. the user edits the config in an editor: it is named, git checkout puts it right, nothing else is needed
ih_project h29
printf '%s\n' "$CFG_NEW" >"$PROJ/.silver-bullet.json"
ih_edit
assert_contains "an editor change is named" "$(message)" "ENFORCEMENT CONTRACT CHANGED"
git -C "$PROJ" checkout -- .silver-bullet.json
assert_eq "git checkout of the file puts the contract right" "" "$(ih_diverged)"
planned
ih_edit
assert_eq "and the edit passes" "ok" "$(not_deny)"

# 38. the same change accepted by restarting the session: said in the banner and in the log
ih_project h30
printf '%s\n' "$CFG_NEW" >"$PROJ/.silver-bullet.json"
OUT="$(ih_session_start_out startup)"
assert_contains "the session start banner names the artifact" "$OUT" "SB INTEGRITY"
assert_contains "and how to revert it" "$OUT" "git diff"
assert_contains "the log says what was re-baselined" "$(cat "$SD/seal-events.log")" "integrity re-baselined at session start over: config"
assert_eq "the project verifies afterwards" "" "$(ih_diverged)"
# a session start over a clean project says nothing about integrity
OUT="$(ih_session_start_out resume)"
assert_not_contains "a clean restart is silent about integrity" "$OUT" "SB INTEGRITY"
# a deleted record
rm -f "$SD"/integrity-*.rec
OUT="$(ih_session_start_out startup)"
assert_contains "a session start over a deleted record says so" "$OUT" "SB INTEGRITY"
assert_eq "and records the project again" "ok" "$(ih_status)"

# 40. the devops reset after a ship follows the record, in the file and in the record
ih_project h40 '.project.active_workflow="devops-cycle"'
ih_hook flow-advance.sh "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:"silver-ship"}}')"
assert_eq "the live file is reset" "full-dev-cycle" "$(jq -r .project.active_workflow "$PROJ/.silver-bullet.json")"
assert_eq "the record is reset too, with no drift" "" "$(ih_diverged)"
assert_eq "recorded workflow" "full-dev-cycle" "$(sb_iv_jq -r .project.active_workflow)"
sb_integrity_set_workflow "$TL_TMP/no-such-root" full-dev-cycle
tl_pass "setting the workflow of a root without a record does nothing"

# 41. honest uninstall: the contract files are removed and committed, the next session retires the record
ih_project h41
rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
OUT="$(ih_session_start_out startup)"
assert_eq "removed but not committed: the record is kept" "yes" "$([[ -f "$(_sb_iv_rec_file "$PROJ")" ]] && echo yes || echo no)"
git -C "$PROJ" add -A >/dev/null 2>&1
git -C "$PROJ" commit -q -m "remove SB" >/dev/null 2>&1
OUT="$(ih_session_start_out startup)"
assert_contains "the user is told" "$OUT" "was removed"
assert_eq "the record is retired" "no" "$([[ -f "$(_sb_iv_rec_file "$PROJ")" ]] && echo yes || echo no)"
assert_contains "and it is logged" "$(cat "$SD/seal-events.log")" "integrity record retired"
ih_edit
assert_eq "edits are no longer held by a project that is gone" "ok" "$(not_deny)"
# the markdown contract still committed: not an uninstall either
ih_project h41e
git -C "$PROJ" rm -q --cached .silver-bullet.json >/dev/null 2>&1
rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
git -C "$PROJ" commit -q -m "json only" >/dev/null 2>&1
git -C "$PROJ" checkout -q HEAD~1 -- silver-bullet.md >/dev/null 2>&1; rm -f "$PROJ/silver-bullet.md"
OUT="$(ih_session_start_out startup)"
assert_eq "silver-bullet.md still in git HEAD: the record stays" "yes" "$([[ -f "$(_sb_iv_rec_file "$PROJ")" ]] && echo yes || echo no)"
# one file left: not an uninstall
ih_project h41b
rm -f "$PROJ/silver-bullet.md"
git -C "$PROJ" add -A >/dev/null 2>&1; git -C "$PROJ" commit -q -m "half" >/dev/null 2>&1
OUT="$(ih_session_start_out startup)"
assert_eq "half a contract is not an uninstall: the record stays" "yes" "$([[ -f "$(_sb_iv_rec_file "$PROJ")" ]] && echo yes || echo no)"
# not a git repository: nothing proves a committed removal
ih_project h41c
rm -rf "$PROJ/.git" "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
OUT="$(ih_session_start_out startup)"
assert_eq "without git there is no proof: the record stays" "yes" "$([[ -f "$(_sb_iv_rec_file "$PROJ")" ]] && echo yes || echo no)"
# the CONTRACT CHANGED message tells the user how to remove a record by hand
ih_project h41d
printf '%s\n' "$CFG_NEW" >"$PROJ/.silver-bullet.json"
ih_edit
assert_not_contains "the message never suggests deleting the record by hand" "$(message)" "rm -f"

# 42. first baseline of a worktree whose config is hidden from git status: compared by content, shown to the user
ih_project h42
git -C "$PROJ" branch -M main >/dev/null 2>&1
rm -f "$SD"/integrity-*
printf '%s\n' "$CFG_NEW" >"$PROJ/.silver-bullet.json"
git -C "$PROJ" update-index --skip-worktree .silver-bullet.json
OUT="$(ih_session_start_out startup)"
assert_contains "a hidden change is still found" "$OUT" "differ from what git has committed"
assert_contains "and goes out as a systemMessage the user sees" "$(jq -r '.systemMessage // ""' <<<"$OUT")" "SB INTEGRITY"

# 43. the devops reset keeps the record valid JSON with backslashes, quotes and unicode in other keys
for filt in '.project.active_workflow="devops-cycle" | .project.src_exclude_pattern="__tests__|\\.test\\."' '.project.active_workflow="devops-cycle" | .project.description="a \"quoted\" \\ back\\slash é"'; do
  ih_project h43 "$filt"
  ih_hook flow-advance.sh "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:"silver-ship"}}')"
  assert_eq "devops ship: no drift" "" "$(ih_diverged)"
  assert_eq "devops ship: the recorded config is valid JSON" "ok" "$(awk -F'\t' '$1 == "config" { print $3 }' "$(_sb_iv_rec_file "$PROJ")" | jq -e . >/dev/null 2>&1 && echo ok || echo bad)"
  sb_integrity_forget; sb_integrity_verify "$PROJ" ""
  assert_eq "devops ship: the backslashes survive" "$(jq -cS .project "$PROJ/.silver-bullet.json")" "$(sb_iv_jq -cS .project)"
done
ih_project h43t
jq '.project.active_workflow="devops-cycle"' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" >"$PROJ/.silver-bullet.json"
sb_integrity_baseline "$PROJ" session
ih_hook flow-advance.sh "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:"silver-ship"}}')"
assert_eq "the real template default config survives a devops ship without drift" "" "$(ih_diverged)"

# 44. a session that never tracked a skill still ends quietly with a changed tree (HOOK-04), and the keyed record says so
ih_project h44
rm -f "$SD"/integrity-*
sb_integrity_baseline "$PROJ" session
rm -f "$STATE" "$STATE.hwm" "$STATE.seal"
echo d >>"$PROJ/src/app.js"
ih_hook stop-check.sh '{"hook_event_name":"Stop"}'
assert_eq "never tracked, nothing recorded: Stop exits quietly" "" "$TL_OUT"
sb_integrity_forget; sb_integrity_verify "$PROJ" ""
assert_eq "the record does not claim tracking" "false" "$SB_IV_TRACKED"
sb_integrity_baseline "$PROJ" tracked
sb_integrity_baseline "$PROJ" tracked
sb_integrity_baseline "$PROJ" session
sb_integrity_forget; sb_integrity_verify "$PROJ" ""
assert_eq "tracking survives a session start" "true" "$SB_IV_TRACKED"

# 45. retirement is for a fresh session on a real commit: not compact/resume, not an orphan checkout, not another branch
uninstall_project() { # NAME: contract files removed and committed on the current branch
  ih_project "$1"
  git -C "$PROJ" rm -q --cached .silver-bullet.json silver-bullet.md >/dev/null 2>&1
  rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
  git -C "$PROJ" commit -q -m "remove SB" >/dev/null 2>&1
}
has_rec() { [[ -f "$(_sb_iv_rec_file "$PROJ")" ]] && echo yes || echo no; }
for src in compact resume; do
  uninstall_project "h45-$src"
  OUT="$(ih_session_start_out $src)"
  assert_eq "$src never retires the record" "yes" "$(has_rec)"
done
uninstall_project h45-orphan
git -C "$PROJ" checkout -q --orphan scratch >/dev/null 2>&1
OUT="$(ih_session_start_out startup)"
assert_eq "an orphan (unborn) checkout proves nothing: the record stays" "yes" "$(has_rec)"
uninstall_project h45-default
git -C "$PROJ" branch -f main HEAD~1 >/dev/null 2>&1
OUT="$(ih_session_start_out startup)"
assert_eq "only HEAD counts: a main that still carries the contract does not keep the record" "no" "$(has_rec)"
uninstall_project h45-head-md
git -C "$PROJ" checkout -q HEAD~1 -- silver-bullet.md >/dev/null 2>&1
git -C "$PROJ" commit -q -m "md back" >/dev/null 2>&1 || true
rm -f "$PROJ/silver-bullet.md"
OUT="$(ih_session_start_out startup)"
assert_eq "silver-bullet.md alone at HEAD keeps the record" "yes" "$(has_rec)"
uninstall_project h45-untrusted
rm -f "$SD/seal.key"
OUT="$(ih_session_start_out startup)"
assert_eq "a record that does not verify is not retired" "yes" "$(has_rec)"
uninstall_project 'h45"q\path'
OUT="$(ih_session_start_out startup)"
assert_eq "the message is valid JSON whatever the path holds" "ok" "$(jq -e .systemMessage >/dev/null 2>&1 <<<"$OUT" && echo ok || echo bad)"
assert_eq "and the record is retired" "no" "$(has_rec)"

# 46. a repository that never had Silver Bullet stays untouched on a live install
mkdir -p "$TL_TMP/plain"
git -C "$TL_TMP/plain" init -q
printf 'x\n' >"$TL_TMP/plain/a.txt"
git -C "$TL_TMP/plain" add -A >/dev/null 2>&1; git -C "$TL_TMP/plain" commit -q -m init >/dev/null 2>&1
mkdir -p "$TL_TMP/plain/src"
assert_eq "no record, no contract file, nothing tracked: no project" "" "$(sb_integrity_root "$TL_TMP/plain/src")"
assert_eq "and a directory outside git too" "" "$(sb_integrity_root "$TL_TMP")"

# 47. retirement consults HEAD only: not origin/HEAD, main or master
has_rec() { [[ -f "$(_sb_iv_rec_file "$PROJ")" ]] && echo yes || echo no; }
uninst47() { git -C "$PROJ" rm -q --cached .silver-bullet.json silver-bullet.md >/dev/null 2>&1; rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"; git -C "$PROJ" commit -q -m "remove SB" >/dev/null 2>&1; }
ih_project h47c
git -C "$PROJ" branch -m trunk >/dev/null 2>&1; git -C "$PROJ" checkout -q -b feat >/dev/null 2>&1
git -C "$PROJ" branch -D main master >/dev/null 2>&1 || true
uninst47
OUT="$(ih_session_start_out startup)"
assert_eq "a repository whose default branch nobody can name: HEAD without the files retires" "no" "$(has_rec)"
ih_project h47d
git init -q --bare "$TL_TMP/h47d.git"; git -C "$PROJ" remote add origin "$TL_TMP/h47d.git" || true
git -C "$PROJ" push -q origin HEAD:main >/dev/null 2>&1 || true; git -C "$PROJ" fetch -q origin >/dev/null 2>&1 || true
git -C "$PROJ" checkout -q -b feat >/dev/null 2>&1 || true
uninst47
OUT="$(ih_session_start_out startup)"
assert_eq "origin/main still carries the files: HEAD without them retires all the same" "no" "$(has_rec)"
ih_project h47e
git -C "$PROJ" rm -q --cached .silver-bullet.json silver-bullet.md >/dev/null 2>&1 || true; rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
ih_edit
assert_contains "removed, not committed: the advice says to commit" "$(message)" "commit the removal"
git -C "$PROJ" commit -q -m rm >/dev/null 2>&1 || true
ih_edit
assert_contains "committed: the advice says start a new session" "$(message)" "start a new session and the record is retired"
ih_project h47f
rm -f "$PROJ/silver-bullet.md"
ih_edit
assert_contains "one file left: restore it" "$(message)" "restore it"

reg_has() { [[ -f "$SD/baselined-roots" && $'\n'"$(<"$SD/baselined-roots")" == *$'\n'"$1"$'\t'* ]]; }
# 48. the registry of baselined roots: honest flows are untouched, only a baselined root is anchored
ih_project h48
git -C "$PROJ" rm -q --cached .silver-bullet.json silver-bullet.md >/dev/null 2>&1 || true; rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
ih_edit
assert_not_contains "uncommitted removal: no advice to strip the default branch" "$(message)" "default branch"
assert_not_contains "uncommitted removal: no advice to push the removal" "$(message)" "push"
git -C "$PROJ" commit -q -m rm >/dev/null 2>&1 || true
OUT="$(ih_session_start_out startup)"
assert_eq "uninstall: the record is retired" "no" "$(has_rec)"
assert_eq "uninstall: the root leaves the registry" "no" "$(reg_has "$PROJ" && echo yes || echo no)"
printf '# SB\n' >"$PROJ/silver-bullet.md"; cp "$FX/cfg.orig" "$PROJ/.silver-bullet.json"
OUT="$(ih_session_start_out startup)"
assert_eq "reinstall: session start baselines the project again" "yes" "$(has_rec)"
assert_eq "reinstall: and registers it" "yes" "$(reg_has "$PROJ" && echo yes || echo no)"
# an unrelated repository with a doc called silver-bullet.md: allowed, as before
U="$TL_TMP/blog"; mkdir -p "$U/posts/sub"; git -C "$U" init -q >/dev/null 2>&1
printf 'hi\n' >"$U/posts/silver-bullet.md"; printf 'x\n' >"$U/posts/gen.js"
git -C "$U" add -A >/dev/null 2>&1; git -C "$U" -c user.email=a@b -c user.name=n commit -q -m a >/dev/null 2>&1 || true
for tgt in "$U/posts/gen.js" "$U/posts/new.js" "$U/posts/silver-bullet.md" "$U/posts/sub/deeper/x.ts"; do
  run_dc "$(edit_json "$tgt" Write PreToolUse)"
  assert_eq "unrelated repo, ${tgt#"$U"/}: allowed" "none" "$(decision)"
done
V="$TL_TMP/vend"; mkdir -p "$V/vendor/sb/hooks"; git -C "$V" init -q >/dev/null 2>&1
printf '{}\n' >"$V/vendor/sb/.silver-bullet.json"; printf 'x\n' >"$V/vendor/sb/hooks/a.sh"
run_dc "$(edit_json "$V/vendor/sb/hooks/a.sh" Edit PreToolUse)"
assert_eq "a vendored .silver-bullet.json is no project" "none" "$(decision)"
# a branch from before the adoption, a fresh clone and a new worktree of an adopted repository
ih_project h48b
git -C "$PROJ" branch -f adopted HEAD >/dev/null 2>&1
git -C "$PROJ" checkout -q -b pre-sb >/dev/null 2>&1; git -C "$PROJ" rm -q .silver-bullet.json silver-bullet.md >/dev/null 2>&1; git -C "$PROJ" commit -q -m pre >/dev/null 2>&1 || true
WT="$TL_TMP/h48b-wt"; git -C "$PROJ" worktree add -q "$WT" adopted >/dev/null 2>&1 || true
assert_eq "a new worktree of the adopted repository is no registered root" "" "$(sb_integrity_record_root "$WT")"
assert_eq "its files make it a project the session start baselines" "$WT" "$(sb_integrity_root "$WT")"
OUT="$(PROJ="$WT" ih_session_start_out startup)"
assert_eq "session start baselines the new worktree" "yes" "$([[ -f "$(_sb_iv_rec_file "$WT")" ]] && echo yes || echo no)"
git -C "$PROJ" worktree remove --force "$WT" >/dev/null 2>&1 || true
CL="$TL_TMP/h48b-clone"; git clone -q "$PROJ" "$CL" >/dev/null 2>&1 || true
git -C "$CL" checkout -q pre-sb >/dev/null 2>&1 || true
assert_eq "a fresh clone on the pre-adoption branch is no project: edits are allowed" "" "$(sb_integrity_root "$CL")"

# 49. the advice names what is needed for every state a registered root can be in
ih_project h49a
rm -rf "$PROJ/.git"; rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
ih_edit
assert_contains "not a git repository: says no committed removal can be shown" "$(message)" "not a git repository"
assert_contains "not a git repository: re-run /sb:init" "$(message)" "/sb:init"
assert_contains "not a git repository: points to the Recovery section, a user action" "$(message)" 'under "Recovery"'
assert_not_contains "not a git repository: no recipe for the agent (registry file)" "$(message)" "baselined-roots"
assert_not_contains "not a git repository: no recipe for the agent (record file)" "$(message)" "integrity-"
OUT="$(ih_session_start_out startup)"
assert_eq "not a git repository: a restart retires nothing" "yes" "$(has_rec)"
ih_project h49b
git -C "$PROJ" rm -q --cached .silver-bullet.json silver-bullet.md >/dev/null 2>&1; rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
git -C "$PROJ" commit -q -m rm >/dev/null 2>&1 || true
rm -f "$(_sb_iv_rec_file "$PROJ")"*
ih_edit
assert_contains "committed removal, record gone: no restart retires it" "$(message)" "no restart retires the root"
assert_contains "committed removal, record gone: re-run /sb:init" "$(message)" "/sb:init"
assert_contains "committed removal, record gone: points to the Recovery section" "$(message)" 'under "Recovery"'
assert_not_contains "committed removal, record gone: no recipe for the agent" "$(message)" "baselined-roots"
assert_not_contains "committed removal, record gone: no false promise of retirement" "$(message)" "the record is retired"
OUT="$(ih_session_start_out startup)"
assert_eq "record gone: a restart keeps the root registered" "yes" "$(reg_has "$PROJ" && echo yes || echo no)"
# the documented recovery for an intentional uninstall: the user retires the root from a terminal
sb_integrity_unregister_root "$PROJ"
rm -f "$(_sb_iv_rec_file "$PROJ")"*
assert_eq "after the documented removal the root is no project" "" "$(sb_integrity_root "$PROJ")"
ih_edit
assert_eq "and edits are allowed again" "none" "$(decision)"
# the honest restore: the files back from HEAD, a restart records them again
ih_project h49c
git -C "$PROJ" rm -q --cached .silver-bullet.json silver-bullet.md >/dev/null 2>&1; rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
rm -f "$(_sb_iv_rec_file "$PROJ")"*
cp "$FX/cfg.orig" "$PROJ/.silver-bullet.json"; printf '# SB\n' >"$PROJ/silver-bullet.md"
OUT="$(ih_session_start_out startup)"
assert_eq "restoring the files and restarting records the root again" "yes" "$(has_rec)"
ih_edit
assert_not_contains "and the gates judge it as a baselined project (the floor, not NOT BASELINED)" "$(message)" "NOT BASELINED"

# 50. identity is dev:ino:birth time: reuse of an inode, rename and uninstall, pruning, the cap
# (a) a baselined project is deleted; a new directory takes its place in the registry's eyes (best effort: an
# inode reuse, else a forged line holding the new directory's device:inode without the birth time)
ih_project h50a
OLDP="$PROJ"; OLDID="$(_sb_iv_dir_id "$OLDP")"
rm -rf "$OLDP"
sleep 1 # the birth time has a resolution of one second
REUSED=""
for n in $(seq 1 12); do
  mkdir "$TL_TMP/h50a-new$n"
  if [[ "$(_sb_iv_dir_id "$TL_TMP/h50a-new$n")" == "$OLDID" ]]; then REUSED="$TL_TMP/h50a-new$n"; break; fi
done
if [[ -z "$REUSED" ]]; then
  REUSED="$TL_TMP/h50a-new1"
  forged="$(stat -c '%d:%i' "$REUSED")"
  printf '%s\t%s\n' "$OLDP" "$forged" >>"$SD/baselined-roots"
fi
mkdir -p "$REUSED/oss/src"; git -C "$REUSED/oss" init -q >/dev/null 2>&1
assert_eq "an inode that is not the root's (no matching birth time) makes no project" "" "$(sb_integrity_root "$REUSED/oss/src")"
run_dc "$(edit_json "$REUSED/oss/src/a.js" Write PreToolUse)"
assert_eq "an unrelated repository in a reused inode's place is allowed" "none" "$(decision)"
# (b) rename, restart, honest uninstall of the renamed project
ih_project h50b
OLDP="$PROJ"; NEWP="${OLDP}-ren"
mv "$OLDP" "$NEWP"; PROJ="$NEWP"; export PROJ
assert_eq "renamed: the record follows the identity" "$NEWP" "$(sb_integrity_root "$NEWP/src")"
OUT="$(ih_session_start_out startup)"
assert_eq "renamed: a session start registers the new path" "yes" "$(reg_has "$NEWP" && echo yes || echo no)"
git -C "$PROJ" rm -q --cached .silver-bullet.json silver-bullet.md >/dev/null 2>&1; rm -f "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md"
git -C "$PROJ" commit -q -m rm >/dev/null 2>&1 || true
OUT="$(ih_session_start_out startup)"
assert_contains "renamed uninstall: reported" "$OUT" "was removed"
assert_eq "renamed uninstall: no root" "" "$(sb_integrity_root "$NEWP/src")"
assert_eq "renamed uninstall: no line of the old path is left" "no" "$(reg_has "$OLDP" && echo yes || echo no)"
assert_eq "renamed uninstall: no line of the new path is left" "no" "$(reg_has "$NEWP" && echo yes || echo no)"
ih_edit
assert_eq "renamed uninstall: edits are allowed" "none" "$(decision)"
# (c) stale lines are pruned at a fresh session, the cap keeps the newest
ih_project h50c
printf '%s\t%s\n' "$TL_TMP/gone-a" "9:9:9" >>"$SD/baselined-roots"
printf '%s\t%s\n' "$TL_TMP" "9:8:7" >>"$SD/baselined-roots"
printf '%s\n' "$TL_TMP/plain-line" >>"$SD/baselined-roots"
OUT="$(ih_session_start_out startup)"
assert_eq "prune: a line whose path now holds another directory goes" "no" "$(reg_has "$TL_TMP" && echo yes || echo no)"
assert_eq "prune: a live line stays" "yes" "$(reg_has "$PROJ" && echo yes || echo no)"
assert_eq "prune: a gone path with an unknown identity stays until the cap" "yes" "$(reg_has "$TL_TMP/gone-a" && echo yes || echo no)"
for n in $(seq 1 210); do printf '%s\t%s\n' "$TL_TMP/cap$n" "8:$n:1" >>"$SD/baselined-roots"; done
OUT="$(ih_session_start_out startup)"
assert_eq "cap: the registry keeps at most 200 lines" "ok" "$([[ "$(grep -c . "$SD/baselined-roots")" -le 200 ]] && echo ok || echo big)"
assert_eq "cap: the newest lines survive" "yes" "$(reg_has "$TL_TMP/cap210" && echo yes || echo no)"
assert_eq "cap: the oldest are dropped" "no" "$(reg_has "$TL_TMP/cap1" && echo yes || echo no)"

# (d) a record from before identity naming (named by the CRC of the path) is replaced by a session start
ih_project h50d
_sb_iv_cksum_var "$PROJ"; LEG="$SD/integrity-$_SB_IV_SUM.rec"
printf 'v2\nhmac\n1\n-\nx\nconfig\t-\t{}\n' >"$LEG"; printf '1\n' >"$LEG.hwm"
OUT="$(ih_session_start_out startup)"
assert_eq "a legacy path-named record is removed by the session start" "no" "$([[ -e "$LEG" || -e "$LEG.hwm" ]] && echo yes || echo no)"
assert_eq "and the identity-named record is there" "yes" "$(has_rec)"

assert_eq "the honest corpus has at least 30 rows" "ok" "$([[ $(grep -c '^assert_\|^ok_cmd\|^  ok_cmd' "$0") -ge 30 ]] && echo ok || echo few)"
tl_results
