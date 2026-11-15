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
assert_contains "the message names the record path" "$(message)" "integrity-"
assert_contains "and the removal command" "$(message)" "rm -f"

# 42. first baseline of a worktree whose config is hidden from git status: compared by content, shown to the user
ih_project h42
git -C "$PROJ" branch -M main >/dev/null 2>&1
rm -f "$SD"/integrity-*
printf '%s\n' "$CFG_NEW" >"$PROJ/.silver-bullet.json"
git -C "$PROJ" update-index --skip-worktree .silver-bullet.json
OUT="$(ih_session_start_out startup)"
assert_contains "a hidden change is still found" "$OUT" "differ from what git has committed"
assert_contains "and goes out as a systemMessage the user sees" "$(jq -r '.systemMessage // ""' <<<"$OUT")" "SB INTEGRITY"

assert_eq "the honest corpus has at least 30 rows" "ok" "$([[ $(grep -c '^assert_\|^ok_cmd\|^  ok_cmd' "$0") -ge 30 ]] && echo ok || echo few)"
tl_results
