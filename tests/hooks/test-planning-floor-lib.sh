#!/usr/bin/env bash
# shellcheck disable=SC2034  # SB_TI_* are inputs read by the sourced library
# hooks/lib/planning-floor.sh: path canonicalisation, scope matching, read-only fallback, skill and
# workflow helpers shared by the planning-floor and protected-file gates.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/planning-floor.sh
source "$TL_REPO_ROOT/hooks/lib/planning-floor.sh"

P="$TL_TMP/proj"
mkdir -p "$P/src" "$P/tools" "$P/.planning/workflows"

# ── sb_pf_canon ───────────────────────────────────────────────────────────────
assert_eq "canon resolves ., .. and //" "$P/src/a.js" "$(sb_pf_canon "$P//src/./x/../a.js")"
assert_eq "canon joins a relative path to the base" "$P/src/a.js" "$(sb_pf_canon "src/a.js" "$P")"
ln -s src "$P/lib"
assert_eq "canon resolves a symlinked directory" "$P/src/a.js" "$(sb_pf_canon "$P/lib/a.js")"
ln -s loop2 "$P/loop1"; ln -s loop1 "$P/loop2"
assert_eq "canon of a symlink loop falls back to the lexical form" "$P/loop1/a.js" "$(sb_pf_canon "$P/loop1/a.js")"
assert_eq "canon of an empty path is empty" "" "$(sb_pf_canon "")"
assert_eq "canon of a Windows spelling (msys)" "/c/proj/src/a.js" "$(OSTYPE=msys sb_pf_canon 'C:\proj\src\a.js')"

# ── sb_pf_src_load / sb_pf_src_in_scope ──────────────────────────────────────
printf '{"project":{"src_pattern":"/src/|/lib/","src_exclude_pattern":"generated","active_workflow":"devops-cycle"}}\n' >"$P/cfg.json"
sb_pf_src_load "$P/cfg.json"
assert_eq "a valid multi-segment pattern is honoured" "/src/|/lib/" "$SB_PF_SRC_PATTERN"
assert_eq "a valid exclusion is honoured" "generated" "$SB_PF_SRC_EXCLUDE"
assert_eq "the workflow is read" "devops-cycle" "$SB_PF_WORKFLOW"
printf '{"project":{"src_pattern":".*","src_exclude_pattern":"a b;c"}}\n' >"$P/cfg.json"
sb_pf_src_load "$P/cfg.json"
assert_eq "a match-everything pattern falls back" "/src/" "$SB_PF_SRC_PATTERN"
assert_eq "an unsafe exclusion falls back" '__tests__|\.test\.' "$SB_PF_SRC_EXCLUDE"
sb_pf_src_load "$P/missing.json"
assert_eq "a missing config gives the defaults" "/src/" "$SB_PF_SRC_PATTERN"
assert_eq "and the default workflow" "full-dev-cycle" "$SB_PF_WORKFLOW"
printf 'not json\n' >"$P/cfg.json"
sb_pf_src_load "$P/cfg.json"
assert_eq "an unreadable config gives the default workflow" "full-dev-cycle" "$SB_PF_WORKFLOW"
sb_pf_src_load ""
check_scope() { # path expected label
  if sb_pf_src_in_scope "$1" "$P"; then got=in; else got=out; fi
  assert_eq "$3" "$2" "$got"
}
check_scope "$P/src/app.js" in "src/app.js is source"
check_scope "$P/src/deep/er/app.py" in "nested source"
check_scope "$P/tools/src-gen.py" out "tools/src-gen.py is not source"
check_scope "$P/vendor/zlib-src/x.py" out "zlib-src is not source"
check_scope "$P/src/test/java/FooTest.java" out "a Maven test is not source"
check_scope "$P/src/foo_test.go" out "a Go test is not source"
check_scope "$P/src/test_app.py" out "a pytest file is not source"
check_scope "$P/src/__tests__/a.js" out "a jest dir is not source"
check_scope "$P/src/app.test.js" out "a .test. file is not source"
check_scope "/elsewhere/src/app.js" out "outside the project root is not source"
check_scope "$P" out "the root itself is not source"
if sb_pf_src_in_scope "" "$P"; then echo bad; else tl_pass "an empty path is out of scope"; fi
if sb_pf_src_in_scope "$P/src/a.js" ""; then echo bad; else tl_pass "an empty root is out of scope"; fi
# a case-insensitive filesystem: SRC/ is src/
sb_path_case_insensitive() { return 0; }
check_scope "$P/SRC/App.JS" in "case-insensitive filesystem: SRC/ matches /src/"
check_scope "$P/Src/Test/FooTest.java" out "case-insensitive filesystem: the test layout is folded too"
sb_path_case_insensitive() { return 1; }
check_scope "$P/SRC/App.JS" out "case-sensitive filesystem: SRC/ is another directory"

# ── sb_pf_is_non_logic ───────────────────────────────────────────────────────
for f in README.md notes.txt a.css i.svg x.ini y.cfg z.conf pkg.lock .env .env.local app.env a.json b.yml c.yaml d.toml; do
  if sb_pf_is_non_logic "$f"; then tl_pass "$f is non-logic"; else tl_fail "$f should be non-logic"; fi
done
for f in app.py settings.env.py main.go Makefile; do
  if sb_pf_is_non_logic "$f"; then tl_fail "$f should be logic"; else tl_pass "$f is logic"; fi
done
if sb_pf_is_non_logic "a.json" devops-cycle; then tl_fail "devops: json is infrastructure code"; else tl_pass "devops: json is logic"; fi
if sb_pf_is_non_logic "a.md" devops-cycle; then tl_pass "devops: markdown stays non-logic"; else tl_fail "devops: markdown"; fi

# ── sb_pf_plain_read_only ────────────────────────────────────────────────────
for c in "ls -la" "pwd" "git status" "git diff HEAD" "git log --oneline" "cat README.md" "grep -rn foo src" "rg foo"; do
  if sb_pf_plain_read_only "$c"; then tl_pass "read-only: $c"; else tl_fail "should be read-only: $c"; fi
done
for c in "" "ls; rm x" "echo x > f" "cat a | tee b" 'echo $HOME' "git commit -m x" "git branch -D x" "git diff --output=f" "ls *.c" "rm -rf x" $'ls\nrm x' "echo 'q'" "sed -i s/a/b/ f" "find . -delete" "git"; do
  if sb_pf_plain_read_only "$c"; then tl_fail "should not be read-only: $c"; else tl_pass "not read-only: $c"; fi
done

# ── sb_pf_unanalysable_message ───────────────────────────────────────────────
SB_TI_STATUS=helper_unavailable SB_TI_ERROR="python3 is not installed or not on PATH"
assert_contains "helper_unavailable: names python3 and the fix" "$(sb_pf_unanalysable_message)" "python3 is a required prerequisite"
SB_TI_STATUS=parse_failed SB_TI_ERROR="unterminated quote"
assert_contains "parse_failed: says it could not be parsed" "$(sb_pf_unanalysable_message)" "could not be parsed"
assert_contains "parse_failed: carries the reason" "$(sb_pf_unanalysable_message)" "unterminated quote"

# ── analysed-call helpers ────────────────────────────────────────────────────
cmd_payload() { jq -cn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
load() { SB_TI_TOOL_KIND=""; sb_tool_input_load "$(cmd_payload "$1")" "$P"; }
load "scripts/silver-bullet invoke-skill sb:plan"
assert_eq "invoked skill via the adapter" "silver-plan" "$(sb_pf_invoked_skills "$(cmd_payload "x")" | head -1)"
assert_eq "raw mode keeps the spelling" "sb:plan" "$(sb_pf_invoked_skills "$(cmd_payload "x")" raw | head -1)"
load "bash /x/scripts/silver-bullet invoke-skill sb:fast extra"
assert_eq "bash-wrapped adapter" "silver-fast" "$(sb_pf_invoked_skills "x")"
load "echo scripts/silver-bullet invoke-skill sb:plan"
assert_eq "an echo of the adapter command invokes nothing" "" "$(sb_pf_invoked_skills "x")"
assert_eq "Skill payload" "silver-plan" "$(sb_pf_invoked_skills '{"tool_name":"Skill","tool_input":{"skill":"sb:plan"}}')"
assert_eq "Skill payload, skillName spelling" "silver-release" "$(sb_pf_invoked_skills '{"tool_name":"Skill","tool_input":{"skillName":"silver-release"}}')"
assert_eq "Skill payload without a skill" "" "$(sb_pf_invoked_skills '{"tool_name":"Skill","tool_input":{}}')"
sb_pf_skill_calls '{"tool_name":"Skill","tool_input":{"skill":"sb:plan"}}' || true
assert_eq "skill_calls: Skill tool" "silver-plan" "$SB_PF_SKILLS"
rc=0; sb_pf_skill_calls '{"tool_name":"Read","tool_input":{}}' || rc=$?
assert_eq "skill_calls: other tools are not skill channels" 1 "$rc"
rc=0; sb_pf_skill_calls "$(cmd_payload "scripts/silver-bullet invoke-skill sb:plan")" || rc=$?
assert_eq "skill_calls: Bash adapter" 0 "$rc"
assert_eq "skill_calls: adapter skill" "silver-plan" "$SB_PF_SKILLS"
rc=0; sb_pf_skill_calls "$(cmd_payload "echo 'invoke-skill")" || rc=$?
assert_eq "skill_calls: an unparsable invoke-skill command" 2 "$rc"
rc=0; sb_pf_skill_calls "$(cmd_payload "echo 'unterminated")" || rc=$?
assert_eq "skill_calls: an unparsable command that is no skill call" 1 "$rc"
rc=0; sb_pf_skill_calls '{"tool_name":"Bash"}' || rc=$?
assert_eq "skill_calls: an empty command" 1 "$rc"

load "bash $TL_REPO_ROOT/hooks/record-skill.sh"
if sb_pf_runs_sb_recorder; then tl_pass "recorder: bash record-skill.sh"; else tl_fail "recorder: bash record-skill.sh"; fi
load "./hooks/record-flow.sh"
if sb_pf_runs_sb_recorder; then tl_pass "recorder: direct record-flow.sh"; else tl_fail "recorder: direct"; fi
load "source hooks/record-skill.sh"
if sb_pf_runs_sb_recorder; then tl_pass "recorder: source"; else tl_fail "recorder: source"; fi
load "cat hooks/record-skill.sh"
if sb_pf_runs_sb_recorder; then tl_fail "recorder: cat is not execution"; else tl_pass "recorder: cat is not execution"; fi
load "bash -x"
if sb_pf_runs_sb_recorder; then tl_fail "recorder: bash with no script"; else tl_pass "recorder: bash with no script"; fi

cd "$P"
load "python3 -c \"open('src/x.py','w')\""
assert_contains "opaque targets: a relative path in code" "$(sb_pf_opaque_targets)" "$P/src/x.py"
load "ls src/"
assert_eq "opaque targets: nothing without an opaque writer" "" "$(sb_pf_opaque_targets)"
assert_contains "opaque targets: all mode lists words of any command" "$(sb_pf_opaque_targets all)" "$P/src"
load "echo hello"
assert_eq "opaque targets: no path-like word, no target" "" "$(sb_pf_opaque_targets all)"
load "python3 -c \"open('.silver-bullet/state','a')\""
if sb_pf_opaque_mentions ".silver-bullet/" "x"; then tl_pass "opaque mentions: state dir"; else tl_fail "opaque mentions"; fi
if sb_pf_opaque_mentions "nothing-here"; then tl_fail "opaque mentions: absent needle"; else tl_pass "opaque mentions: absent needle"; fi
load "echo .silver-bullet/"
if sb_pf_opaque_mentions ".silver-bullet/"; then tl_fail "opaque mentions: needs an opaque writer"; else tl_pass "opaque mentions: needs an opaque writer"; fi

# write records / targets for every tool kind
load "echo x > src/a.js && rm src/b.js"
assert_contains "records: shell redirect" "$(sb_pf_write_records "x")" "redirect	$P/src/a.js"
assert_contains "records: rm" "$(sb_pf_write_records "x")" "rm	$P/src/b.js"
assert_contains "targets: paths only" "$(sb_pf_write_targets "x")" "$P/src/b.js"
PAYLOAD='{"tool_name":"mcp__fs__write_file","tool_input":{"path":"src/m.js","file_paths":["src/n.js"],"destination":"src/d.js"}}'
SB_TI_TOOL_KIND=mcp
assert_contains "records: MCP path field" "$(SB_TI_FILE_PATH="" SB_TI_PATCH_PATHS="" sb_pf_write_records "$PAYLOAD")" "edit	$PWD/src/m.js"
assert_contains "records: file_paths list" "$(SB_TI_FILE_PATH="" SB_TI_PATCH_PATHS="" sb_pf_write_records "$PAYLOAD")" "src/n.js"
assert_contains "records: destination" "$(SB_TI_FILE_PATH="" SB_TI_PATCH_PATHS="" sb_pf_write_records "$PAYLOAD")" "src/d.js"
SB_TI_TOOL_KIND=patch SB_TI_PATCH_PATHS=$'a/one.js\nb/two.js' SB_TI_FILE_PATH="a/one.js"
assert_contains "records: patch paths" "$(sb_pf_write_records '{}')" "b/two.js"
SB_TI_TOOL_KIND=""

# config files, workflow id, state skill
assert_eq "config files of a project" "$P/.silver-bullet.json
$P/silver-bullet.md
$P/.silver-bullet.prompt.json" "$(sb_pf_config_files "$P/")"
WF=20260101T000000Z-abc123-silver-feature
printf 'x\n' >"$P/.planning/workflows/$WF.md"
assert_eq "workflow id: the only workflow" "$WF" "$(sb_pf_workflow_id "$P/.planning/workflows" "")"
assert_eq "workflow id: the environment override" "wfx" "$(SB_WORKFLOW_ID=wfx sb_pf_workflow_id "$P/.planning/workflows" "")"
printf 'x\n' >"$P/.planning/workflows/20260102T000000Z-def456-silver-bugfix.md"
assert_eq "workflow id: ambiguous without a selector" "" "$(sb_pf_workflow_id "$P/.planning/workflows" "")"
assert_eq "workflow id: export on the first line" "$WF" "$(sb_pf_workflow_id "$P/.planning/workflows" "export SB_WORKFLOW_ID=$WF; ls")"
assert_eq "workflow id: env prefix" "$WF" "$(sb_pf_workflow_id "$P/.planning/workflows" "env SB_WORKFLOW_ID=$WF ls")"
assert_eq "workflow id: inline assignment" "$WF" "$(sb_pf_workflow_id "$P/.planning/workflows" "SB_WORKFLOW_ID=$WF ls")"
printf '%s\n' "$WF" >"$SB_RUNTIME_STATE_DIR/active-workflow"
assert_eq "workflow id: persisted id" "$WF" "$(sb_pf_workflow_id "$P/.planning/workflows" "")"
printf 'nonexistent\n' >"$SB_RUNTIME_STATE_DIR/active-workflow"
assert_eq "workflow id: a persisted id without a file is ignored" "" "$(sb_pf_workflow_id "$P/.planning/workflows" "")"
rm -f "$SB_RUNTIME_STATE_DIR/active-workflow"
ln -s "$P/.planning/workflows/$WF.md" "$P/.planning/workflows/link.md"
rm -f "$P/.planning/workflows/20260102T000000Z-def456-silver-bugfix.md" "$P/.planning/workflows/$WF.md"
assert_eq "workflow id: a symlinked workflow file does not count" "" "$(sb_pf_workflow_id "$P/.planning/workflows" "")"

export SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/state"
rm -f "$SILVER_BULLET_STATE_FILE"
if sb_pf_state_has_skill silver-phase; then tl_fail "no state file"; else tl_pass "state skill: no state file"; fi
printf 'silver-phase\n' >"$SILVER_BULLET_STATE_FILE"
if sb_pf_state_has_skill silver-undo silver-phase; then tl_pass "state skill: recorded"; else tl_fail "state skill: recorded"; fi
if sb_pf_state_has_skill silver-undo; then tl_fail "state skill: other skill"; else tl_pass "state skill: other skill"; fi
SILVER_BULLET_STATE_FILE=/etc/outside
if sb_pf_state_has_skill silver-phase; then tl_pass "state skill: a state path outside the root falls back to the default"; else tl_fail "state skill fallback"; fi

# ── review repair helpers ───────────────────────────────────────────────────────────────────
cd "$P"
load "ls src"
SB_SA_UNSEEN_REASONS="" assert_eq "no unseen reason for a normal command" "" "$(sb_pf_unseen_reason)"
SB_SA_UNSEEN_REASONS=$'command too large to analyze\nmore' SB_SA_READ_ONLY=false
assert_eq "the unseen reasons are listed" "command too large to analyze;more" "$(sb_pf_unseen_reason)"
SB_SA_READ_ONLY=true
assert_eq "a plainly read-only command is not refused for being unseen" "" "$(sb_pf_unseen_reason)"
SB_SA_READ_ONLY=false SB_SA_UNSEEN_REASONS=""
assert_contains "the unseen message names the reason and the way forward" "$(sb_pf_unseen_message "boom")" "cannot inspect this command: boom"
assert_contains "and offers a split" "$(sb_pf_unseen_message "boom")" "Split it into smaller commands"

mkdir -p "$P/d"
load "cp -r /tmp/a $P/d"
if sb_pf_dir_capable_via cp; then tl_pass "cp -r is directory-capable"; else tl_fail "cp -r is directory-capable"; fi
load "cp -a /tmp/a $P/d"
if sb_pf_dir_capable_via cp; then tl_pass "cp -a is directory-capable"; else tl_fail "cp -a"; fi
load "cp notes.md $P/d"
if sb_pf_dir_capable_via cp; then tl_fail "cp of a plain file"; else tl_pass "cp of a plain file is not"; fi
load "cp silver-bullet.md $P/d"
if sb_pf_dir_capable_via cp; then tl_pass "cp of a protected name is"; else tl_fail "cp of a protected name"; fi
load "mv $P/d /tmp/dd"
if sb_pf_dir_capable_via mv; then tl_pass "mv of a directory is"; else tl_fail "mv of a directory"; fi
load "mv a.txt b.txt"
if sb_pf_dir_capable_via mv; then tl_fail "mv of a plain file"; else tl_pass "mv of a plain file is not"; fi
load "install -m 644 notes.md $P/d"
if sb_pf_dir_capable_via install; then tl_fail "install of a plain file"; else tl_pass "install of a plain file is not"; fi
for v in rsync "tar -x" unzip "unzip -d" "git checkout" "git restore"; do
  if sb_pf_dir_capable_via "$v"; then tl_pass "$v is directory-capable"; else tl_fail "$v"; fi
done
for v in redirect tee touch mkdir rm edit "sed -i"; do
  if sb_pf_dir_capable_via "$v"; then tl_fail "$v is not"; else tl_pass "$v is not directory-capable"; fi
done
rec=$'rsync\t/h\nredirect\t/h/x\ncp\t/elsewhere'
load "rsync -a /tmp/a /h"
exp="$(sb_pf_expand_ancestors "$rec" /h/.sb/state /h/.sb/trivial /other)"
assert_contains "an rsync into /h covers /h/.sb/state" "$exp" $'rsync\t/h/.sb/state'
assert_contains "and /h/.sb/trivial" "$exp" $'rsync\t/h/.sb/trivial'
assert_not_contains "but not an unrelated path" "$exp" "/other"
assert_not_contains "a plain redirect covers nothing" "$exp" $'redirect\t/h/.sb'
assert_contains "the records themselves are kept" "$exp" $'cp\t/elsewhere'
assert_eq "no path under a file target" "" "$(sb_pf_expand_ancestors $'rsync\t/h/.sb/state' /h/.sb/state | tail -n +2 | grep -v '^$' || true)"

load "ln -s /h/sd /tmp/l"
if sb_pf_argv_touches_dir /h/sd; then tl_pass "ln of the protected dir"; else tl_fail "ln of the protected dir"; fi
if sb_pf_argv_touches_dir /h/other; then tl_fail "a sibling directory is not named"; else tl_pass "ln source in a sibling"; fi
load "ln -s /h /tmp/l"
if sb_pf_argv_touches_dir /h/sd; then tl_pass "ln of a directory above the protected dir"; else tl_fail "ln above"; fi
load "find /h/sd -name x -exec sh -c 'echo {}' \;"
if sb_pf_argv_touches_dir /h/sd; then tl_pass "find -exec rooted in the protected dir"; else tl_fail "find -exec"; fi
load "find /h/sd -name x"
if sb_pf_argv_touches_dir /h/sd; then tl_fail "find without -exec"; else tl_pass "find without -exec reads only"; fi
load "find src -name x -exec ls {} \;"
if sb_pf_argv_touches_dir /h/sd; then tl_fail "find elsewhere"; else tl_pass "find -exec elsewhere"; fi
if sb_pf_argv_touches_dir; then tl_fail "no dir given"; else tl_pass "no dir given"; fi

printf "print('x')\n" >"$P/ok.py"
printf "open('/h/.claude/.silver-bullet/state')\n" >"$P/bad.py"
load "python3 ok.py"
if sb_pf_script_mentions ".claude/.silver-bullet"; then tl_fail "script mentions"; else tl_pass "a script that names nothing"; fi
load "python3 bad.py"
if sb_pf_script_mentions ".claude/.silver-bullet"; then tl_pass "a script that names the state dir"; else tl_fail "script mentions state dir"; fi
load "python3 missing.py"
if sb_pf_script_mentions "x"; then tl_fail "missing script"; else tl_pass "a missing script file"; fi
load "ls bad.py"
if sb_pf_script_mentions ".claude/.silver-bullet"; then tl_fail "ls is no interpreter"; else tl_pass "ls is no interpreter"; fi

for n in mcp__fs__write_file mcp__fs__edit_file mcp__fs__create_directory mcp__fs__move_file mcp__fs__fs_mv mcp__x__save_note mcp__x__apply_patch mcp__x__copy_file mcp__x__rename; do
  if sb_pf_mcp_write_tool "$n"; then tl_pass "$n writes"; else tl_fail "$n writes"; fi
done
for n in mcp__fs__read_file mcp__fs__list_directory mcp__x__search Read Bash; do
  if sb_pf_mcp_write_tool "$n"; then tl_fail "$n does not write"; else tl_pass "$n does not write"; fi
done

load "python3 -c 'import subprocess;subprocess.run([\"bash\",\"/i/hooks/record-skill.sh\"])'"
if sb_pf_text_names_recorder; then tl_pass "inline code spelling a recorder path"; else tl_fail "inline recorder path"; fi
load "cat /i/hooks/record-skill.sh"
if sb_pf_text_names_recorder; then tl_fail "reading a recorder"; else tl_pass "reading a recorder is fine"; fi
load "python3 /i/hooks/record-skill.sh"
if sb_pf_names_sb_recorder; then tl_pass "an interpreter given a recorder"; else tl_fail "interpreter recorder"; fi
load "python3 /i/hooks/record-skill"
if sb_pf_names_sb_recorder; then tl_pass "a recorder without .sh"; else tl_fail "recorder without .sh"; fi
load "cat /i/hooks/record-skill.sh"
if sb_pf_names_sb_recorder; then tl_fail "cat names a recorder"; else tl_pass "cat is a reader"; fi
load "git add hooks/record-skill.sh"
if sb_pf_names_sb_recorder; then tl_fail "git add"; else tl_pass "git add is a reader"; fi
load "cp -r /i/hooks /tmp/hh"
if sb_pf_names_sb_recorder /i/hooks; then tl_pass "copying the hooks dir out (installed copy)"; else tl_fail "cp hooks dir"; fi
if sb_pf_names_sb_recorder; then tl_fail "cp hooks dir without a hooks guard"; else tl_pass "no hooks guard in a source checkout"; fi
load "ls /i/hooks"
if sb_pf_names_sb_recorder /i/hooks; then tl_fail "ls hooks dir"; else tl_pass "ls of the hooks dir"; fi

# the unlock list: every skill that rewrites the contract files through the agent is on it
for sk in silver-init silver-update silver-add silver-devops silver-migrate; do
  case " $SB_PF_CONTRACT_WRITER_SKILLS " in *" $sk "*) tl_pass "$sk may rewrite the contract";; *) tl_fail "$sk missing from the unlock list";; esac
done
rm -f "$SB_RUNTIME_STATE_DIR/contract-unlock"
if sb_pf_contract_unlocked; then tl_fail "no record unlocks"; else tl_pass "without a record nothing unlocks"; fi
sb_contract_unlock_write silver-plan
if sb_pf_contract_unlocked; then tl_fail "silver-plan unlocks"; else tl_pass "an unrelated skill does not unlock"; fi
sb_contract_unlock_write silver-add
if sb_pf_contract_unlocked json; then tl_pass "silver-add unlocks the JSON configuration"; else tl_fail "silver-add unlocks"; fi
if sb_pf_contract_unlocked md; then tl_fail "silver-add unlocks silver-bullet.md"; else tl_pass "silver-add leaves silver-bullet.md locked"; fi
sb_contract_unlock_write silver-init
if sb_pf_contract_unlocked md; then tl_pass "silver-init unlocks silver-bullet.md"; else tl_fail "silver-init unlocks md"; fi
rm -f "$SB_RUNTIME_STATE_DIR/contract-unlock"
# drift: a skill that rewrites .silver-bullet.json with jq and mv must be on the list
while IFS= read -r f; do
  name="$(basename "$(dirname "$f")")"
  case " $SB_PF_CONTRACT_WRITER_SKILLS " in *" $name "*) tl_pass "$name rewrites the config and is listed";; *) tl_fail "$name rewrites .silver-bullet.json but is not on SB_PF_CONTRACT_WRITER_SKILLS";; esac
done < <(grep -lE 'mv "?\$[A-Za-z_]+"? \.silver-bullet\.json|> *\.silver-bullet\.json|Write `?\.silver-bullet\.json|set `\.silver-bullet\.json` ' "$TL_REPO_ROOT"/skills/*/SKILL.md 2>/dev/null || true)

# hooks.json: the guards see MCP file-write tools too
for h in planning-file-guard instruction-file-guard workflow-chain-guard dev-cycle-check; do
  n="$(jq -r --arg h "$h.sh" '[.hooks.PreToolUse[] | select(.matcher | test("mcp__")) | .hooks[] | select(.command | endswith($h + "\""))] | length' "$TL_REPO_ROOT/hooks/hooks.json")"
  assert_eq "$h is registered for MCP write tools" 1 "$n"
done

# round 2: the unlock record, inline-code reasons, tree writes outside the runtime home
UL="$SB_RUNTIME_STATE_DIR/contract-unlock"
rm -f "$UL"
ln -s "$TL_TMP/elsewhere-unlock" "$UL"
sb_contract_unlock_write silver-init
assert_file_absent "an unlock is never written through a symlink" "$TL_TMP/elsewhere-unlock"
rm -f "$UL"
: >"$UL"
if sb_pf_contract_unlocked; then tl_fail "an empty record unlocks"; else tl_pass "an empty unlock record unlocks nothing"; fi
rm -f "$UL"
assert_eq "an unreadable analysis names no inline code" "" "$(SB_SA_JSON='not json' SB_SA_READ_ONLY=false sb_pf_inline_code_reason)"
OUT_HOME="$TL_TMP/outside-home"
ex="$(sb_pf_expand_ancestors "$(printf 'patch\t%s\n' "$TL_TMP")" "$OUT_HOME/x" "$SB_RUNTIME_HOME_ROOT/.silver-bullet" "$SB_RUNTIME_HOME_ROOT/.silver-bullet/state")"
assert_not_contains "a patch tree does not cover a path outside the runtime home" "$ex" "$OUT_HOME/x"
ex2="$(sb_pf_expand_ancestors "$(printf 'patch\t%s\n' "$SB_RUNTIME_HOME_ROOT")" "$SB_RUNTIME_HOME_ROOT/.silver-bullet/state")"
assert_contains "but covers one inside it" "$ex2" "$SB_RUNTIME_HOME_ROOT/.silver-bullet/state"

tl_results
