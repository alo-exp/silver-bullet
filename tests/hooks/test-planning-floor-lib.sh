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
# The source scope comes from the verified project (a root with a live config on an install that never ran
# a session reads it as written; hooks/lib/integrity.sh).
SPR="$P/srcproj"
mkdir -p "$SPR"
printf '# SB\n' >"$SPR/silver-bullet.md"
sf_cfg() { printf '%s\n' "$1" >"$SPR/.silver-bullet.json"; sb_integrity_forget; }
sf_cfg '{"project":{"src_pattern":"/src/|/lib/","src_exclude_pattern":"generated","active_workflow":"devops-cycle"}}'
sb_pf_src_load "$SPR"
assert_eq "a valid multi-segment pattern is honoured" "/src/|/lib/" "$SB_PF_SRC_PATTERN"
assert_eq "a valid exclusion is honoured" "generated" "$SB_PF_SRC_EXCLUDE"
assert_eq "the workflow is read" "devops-cycle" "$SB_PF_WORKFLOW"
sf_cfg '{"project":{"src_pattern":".*","src_exclude_pattern":"a b;c"}}'
sb_pf_src_load "$SPR"
assert_eq "a match-everything pattern falls back" "/src/" "$SB_PF_SRC_PATTERN"
assert_eq "an unsafe exclusion falls back" '__tests__|\.test\.' "$SB_PF_SRC_EXCLUDE"
sb_pf_src_load "$P/no-such-project"
assert_eq "a missing project gives the defaults" "/src/" "$SB_PF_SRC_PATTERN"
assert_eq "and the default workflow" "full-dev-cycle" "$SB_PF_WORKFLOW"
sf_cfg 'not json'
sb_pf_src_load "$SPR"
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

cd "$P"
load "python3 -c \"open('src/x.py','w')\""
assert_contains "opaque targets: a relative path in code" "$(sb_pf_opaque_targets)" "$P/src/x.py"
load "ls src/"
assert_eq "opaque targets: nothing without an opaque writer" "" "$(sb_pf_opaque_targets)"
assert_contains "opaque targets: all mode lists words of any command" "$(sb_pf_opaque_targets all)" "$P/src"
load "echo hello"
assert_eq "opaque targets: no path-like word, no target" "" "$(sb_pf_opaque_targets all)"
# write records / targets for every tool kind
load "echo x > src/a.js && rm src/b.js"
assert_contains "records: shell redirect" "$(sb_pf_write_records "x")" "redirect	$P/src/a.js"
assert_contains "records: rm" "$(sb_pf_write_records "x")" "rm	$P/src/b.js"
assert_contains "targets: paths only" "$(sb_pf_write_targets "x")" "$P/src/b.js"
PAYLOAD='{"tool_name":"mcp__fs__write_file","tool_input":{"path":"src/m.js","file_paths":["src/n.js"],"destination":"src/d.js"}}'
SB_TI_TOOL_KIND=mcp
assert_contains "records: MCP path field" "$(SB_TI_FILE_PATH="" SB_TI_PATCH_PATHS="" sb_pf_write_records "$PAYLOAD")" "edit	$PWD/src/m.js"
# the payload's cwd joins a relative path, and the logical spelling is recorded next to the resolved one
mkdir -p "$TL_TMP/lg/real/src"; ln -s "$TL_TMP/lg/real" "$TL_TMP/lg/link"
LGP='{"tool_name":"Write","cwd":"'"$TL_TMP/lg/link"'","tool_input":{"file_path":"src/x.js"}}'
out="$(SB_TI_TOOL_KIND=edit SB_TI_FILE_PATH="" SB_TI_PATCH_PATHS="" sb_pf_write_records "$LGP")"
assert_contains "records: relative path joined to the payload cwd (resolved)" "$out" "edit	$(cd "$TL_TMP/lg/real" && pwd -P)/src/x.js"
assert_contains "records: relative path joined to the payload cwd (logical)" "$out" "edit	$TL_TMP/lg/link/src/x.js"
out="$(SB_TI_TOOL_KIND=edit SB_TI_FILE_PATH="" SB_TI_PATCH_PATHS="" sb_pf_write_records '{"cwd": "broken')" || true
assert_eq "records: a payload that is not JSON yields no record and no failure" "" "$out"
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

for n in mcp__fs__write_file mcp__fs__edit_file mcp__fs__create_directory mcp__fs__move_file mcp__fs__fs_mv mcp__x__save_note mcp__x__apply_patch mcp__x__copy_file mcp__x__rename; do
  if sb_pf_mcp_write_tool "$n"; then tl_pass "$n writes"; else tl_fail "$n writes"; fi
done
for n in mcp__fs__read_file mcp__fs__list_directory mcp__x__search Read Bash; do
  if sb_pf_mcp_write_tool "$n"; then tl_fail "$n does not write"; else tl_pass "$n does not write"; fi
done

# the unlock list: every skill that rewrites the contract files through the agent is on it
for sk in silver-init silver-update silver-add silver-devops silver-migrate; do
  case " $SB_PF_CONTRACT_WRITER_SKILLS " in *" $sk "*) tl_pass "$sk may rewrite the contract";; *) tl_fail "$sk missing from the unlock list";; esac
done
SB_IV_UNLOCK_SKILL=""
if sb_pf_contract_unlocked; then tl_fail "no unlock in force unlocks"; else tl_pass "without an unlock entry nothing unlocks"; fi
SB_IV_UNLOCK_SKILL=silver-add
if sb_pf_contract_unlocked json; then tl_pass "silver-add unlocks the JSON configuration"; else tl_fail "silver-add unlocks json"; fi
if sb_pf_contract_unlocked md; then tl_fail "silver-add unlocks silver-bullet.md"; else tl_pass "silver-add leaves silver-bullet.md locked"; fi
assert_eq "silver-add covers the JSON configuration" "config prompt" "$(sb_contract_skill_tags silver-add)"
assert_eq "silver-add is declared to write its tracker keys only" "_github_project issue_tracker issue_tracker_adapter" "$(sb_contract_skill_config_keys silver-add)"
assert_eq "silver-devops is declared to write the active workflow only" "project.active_workflow" "$(sb_contract_skill_config_keys silver-devops)"
assert_eq "silver-init may write any key" "" "$(sb_contract_skill_config_keys silver-init)"
SB_IV_UNLOCK_SKILL=silver-init
if sb_pf_contract_unlocked md; then tl_pass "silver-init unlocks silver-bullet.md"; else tl_fail "silver-init unlocks md"; fi
assert_eq "silver-init covers the contract and the instruction files" "config prompt md instr:CLAUDE.md instr:AGENTS.md" "$(sb_contract_skill_tags silver-init)"
SB_IV_UNLOCK_SKILL=""
if sb_contract_is_writer silver-add; then tl_pass "silver-add is a writer"; else tl_fail "silver-add is a writer"; fi
if sb_contract_is_writer silver-plan; then tl_fail "silver-plan is not a writer"; else tl_pass "silver-plan is not a writer"; fi
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

# tree writes
if sb_pf_extract_via "tar -x" && sb_pf_extract_via unzip; then tl_pass "tar -x and unzip extract"; else tl_fail "extractors"; fi
if sb_pf_extract_via patch; then tl_fail "patch is not an extractor"; else tl_pass "patch is not an extractor"; fi
if sb_pf_tree_via patch && sb_pf_tree_via "git apply" && sb_pf_tree_via "git am" && sb_pf_tree_via unzip; then tl_pass "patch appliers and extractors write the tree"; else tl_fail "tree vias"; fi
if sb_pf_tree_via cp; then tl_fail "cp is not a tree write"; else tl_pass "cp is not a tree write"; fi


# ── the state-tamper guard (sb_pf_state_violation, sb_pf_dynamic_violation, sb_pf_protected_name, sb_pf_nlink) ───────
source "$TL_REPO_ROOT/hooks/lib/path-canonical.sh"
SD17="$TL_TMP/sd17"
mkdir -p "$SD17/dir.d"
printf 'x\n' >"$SD17/baselined-roots"; printf 'x\n' >"$SD17/root-123"; printf 'k\n' >"$SD17/seal.key"; printf 's\n' >"$SD17/.hidden-state"
v() { if sb_pf_state_violation "$1" "$2" "$SD17"; then echo violation; else echo ok; fi; }
assert_eq "an ordinary file in the state dir is guarded" "violation" "$(v redirect "$SD17/baselined-roots")"
assert_eq "a file outside it is not" "ok" "$(v redirect "$TL_TMP/other")"
assert_eq "the state dir itself may be made" "ok" "$(v mkdir "$SD17")"
assert_eq "but not removed" "violation" "$(v rm "$SD17")"
assert_eq "a directory above it counts as deleting it (rm)" "violation" "$(v rm "$TL_TMP")"
assert_eq "git clean above it counts" "violation" "$(v "git clean" "$TL_TMP")"
assert_eq "git reset above it does not (only within)" "ok" "$(v "git reset" "$TL_TMP")"
assert_eq "git reset within it does" "violation" "$(v "git reset" "$SD17")"
# sentinels: a plain write only, and only while the name is a plain file nobody linked, a directory, or absent
for sn in session-init stack-compression-mutex sb-friction-log.md roadmap-edit-override; do
  assert_eq "$sn absent: a redirect is open" "ok" "$(v redirect "$SD17/$sn")"
  assert_eq "$sn absent: a link under the name is not" "violation" "$(v ln "$SD17/$sn")"
  assert_eq "$sn absent: a copy onto it is not" "violation" "$(v cp "$SD17/$sn")"
done
printf 'x\n' >"$SD17/session-init"
assert_eq "a plain sentinel file: tee, touch, rm, truncate and the file tools are open" "ok ok ok ok ok" \
  "$(v tee "$SD17/session-init") $(v touch "$SD17/session-init") $(v rm "$SD17/session-init") $(v truncate "$SD17/session-init") $(v edit "$SD17/session-init")"
ln "$SD17/baselined-roots" "$SD17/stack-compression-mutex"
assert_eq "a sentinel hard-linked to another file is guarded" "violation" "$(v redirect "$SD17/stack-compression-mutex")"
ln -s baselined-roots "$SD17/sb-friction-log.md"
assert_eq "a sentinel that is a symlink is guarded" "violation" "$(v redirect "$SD17/sb-friction-log.md")"
mkdir "$SD17/roadmap-edit-override"
assert_eq "a sentinel that is a directory is open" "ok" "$(v mkdir "$SD17/roadmap-edit-override")"
assert_eq "a sentinel under a subdirectory of the state dir is guarded by name" "violation" "$(v redirect "$SD17/dir.d/session-init")"
# the link count: GNU stat, then BSD stat, then "shared" when neither answers
assert_eq "sb_pf_nlink of a plain file" "1" "$(sb_pf_nlink "$SD17/dir.d/../seal.key")"
assert_eq "sb_pf_nlink of a linked file" "2" "$(sb_pf_nlink "$SD17/baselined-roots")"
STUBD="$TL_TMP/statstub"; mkdir -p "$STUBD"
printf '#!/bin/sh\ncase "$1" in -c) exit 1 ;; -f) echo 1 ;; esac\n' >"$STUBD/stat"; chmod +x "$STUBD/stat"
assert_eq "sb_pf_nlink falls back to BSD stat" "1" "$(PATH="$STUBD:$PATH" sb_pf_nlink "$SD17/seal.key")"
printf '#!/bin/sh\nexit 1\n' >"$STUBD/stat"
assert_eq "sb_pf_nlink without a stat that answers counts the file as shared" "2" "$(PATH="$STUBD:$PATH" sb_pf_nlink "$SD17/seal.key")"
# names: entries of the state dir (not sentinels), the contract files, globs
pn() { if sb_pf_protected_name "$1" "$SD17"; then echo yes; else echo no; fi; }
assert_eq "an entry of the state dir" "yes" "$(pn baselined-roots)"
assert_eq "a glob that matches an entry" "yes" "$(pn 'root-*')"
assert_eq "a glob that matches a hidden entry" "yes" "$(pn '.hid*')"
assert_eq "a contract file name" "yes" "$(pn silver-bullet.md)"
assert_eq "a contract file glob" "yes" "$(pn '.silver-bullet.*')"
assert_eq "a sentinel is not protected by name" "no" "$(pn session-init)"
assert_eq "an ordinary name" "no" "$(pn notes.txt)"
assert_eq "an empty name" "no" "$(pn '')"
assert_eq "no state directory, an ordinary glob" "no" "$(sb_pf_protected_name 'root-*' "$TL_TMP/no-such-dir" && echo yes || echo no)"
dv() { if sb_pf_dynamic_violation "$1" "$2" "$SD17"; then echo violation; else echo ok; fi; }
assert_eq "a dynamic write of a protected name" "violation" "$(dv rm "sub/dir/baselined-roots")"
assert_eq "a trailing slash is ignored" "violation" "$(dv rm "root-123/")"
assert_eq "a dynamic write of an ordinary name" "ok" "$(dv rm "notes.txt")"
assert_eq "a dynamic git clean" "violation" "$(dv "git clean" ".")"

# ── sb_pf_multi_ai_cli_exempt / sb_pf_multi_ai_root_records ───────────────────────────────────────────────
PLUGIN_ROOT="$(cd "$TL_REPO_ROOT" && pwd -P)"
TASK_CLI="$PLUGIN_ROOT/skills/silver-multi-ai-task/scripts/multi_ai_cli.py"
DR_CLI="$PLUGIN_ROOT/skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py"
printf 'print(1)\n' >"$P/tools/other.py"
exempt() { # exempt CWD ARGV...: loads a one-command analysis and reports status, root and mode
  local cwd="$1"
  shift
  SB_TI_STATUS=ok SB_SA_WRITE_PATHS="" SB_SA_RTK_UNWRAPPED="" SB_SA_UNSEEN_REASONS=""
  SB_SA_JSON="$(jq -cn '{commands:[{argv:$ARGS.positional}]}' --args -- "$@")"
  if sb_pf_multi_ai_cli_exempt "$cwd"; then printf 'yes|%s' "$SB_PF_EXEMPT_ROOT"; else printf 'no'; fi
}
assert_eq "exempt: task CLI with a plain root" "yes|$P/out/run" "$(exempt "$P" python3 "$TASK_CLI" --output-root out/run --dry-run)"
assert_eq "exempt: the = form" "yes|$P/out/run" "$(exempt "$P" python3.12 "$TASK_CLI" --output-root=out/run)"
assert_eq "exempt: a task dry run needs no root and writes nothing" "yes|" "$(exempt "$P" python3 "$TASK_CLI" --dry-run)"
assert_eq "exempt: deep research without a root writes below research/" "yes|$P/research" "$(exempt "$P" python3 "$DR_CLI" probe)"
assert_eq "exempt: deep research dry run without a root writes nothing" "yes|" "$(exempt "$P" python3 "$DR_CLI" probe --dry-run)"
assert_eq "exempt: any other script is not exempt" "no" "$(exempt "$P" python3 "$P/tools/other.py" --output-root out)"
assert_eq "exempt: an invalid analysis is not exempt" "no" "$(SB_TI_STATUS=ok SB_SA_WRITE_PATHS="" SB_SA_RTK_UNWRAPPED="" SB_SA_UNSEEN_REASONS="" SB_SA_JSON="{not json" sb_pf_multi_ai_cli_exempt "$P" && echo yes || echo no)"
assert_eq "exempt: a payload cwd that is not an absolute directory is refused" "no|no" "$(exempt rel python3 "$TASK_CLI" --dry-run)|$(exempt "$P/missing" python3 "$TASK_CLI" --dry-run)"
for root in 's"rc"' '$X' '`x`' 's*' '../x' '~/x' 'a\b' "a'b" 'a!b' 'a{b}'; do
  assert_eq "exempt: no exemption for the root $root" "no" "$(exempt "$P" python3 "$TASK_CLI" --output-root "$root")"
done
assert_eq "exempt: repeated roots" "no" "$(exempt "$P" python3 "$TASK_CLI" --output-root a --output-root b)"
assert_eq "exempt: an abbreviated option" "no" "$(exempt "$P" python3 "$TASK_CLI" --output-r a)"
assert_eq "exempt: a root option without a value" "no|no" "$(exempt "$P" python3 "$TASK_CLI" --output-root)|$(exempt "$P" python3 "$TASK_CLI" --output-root --dry-run)"
assert_eq "exempt: a relative or flagged script" "no|no|no" "$(exempt "$P" python3 skills/silver-multi-ai-task/scripts/multi_ai_cli.py)|$(exempt "$P" python3 -I "$TASK_CLI")|$(exempt "$P" bash "$TASK_CLI")"
assert_eq "exempt: a symlink to the CLI" "no" "$(ln -sf "$TASK_CLI" "$P/tools/linked.py"; exempt "$P" python3 "$P/tools/linked.py")"
SB_SA_WRITE_PATHS="x"; assert_eq "exempt: a command with a write" "no" "$(SB_TI_STATUS=ok SB_SA_WRITE_PATHS=x SB_SA_RTK_UNWRAPPED="" SB_SA_UNSEEN_REASONS="" SB_SA_JSON='{"commands":[]}' sb_pf_multi_ai_cli_exempt "$P" && echo yes || echo no)"; SB_SA_WRITE_PATHS=""
assert_eq "exempt: two commands" "no" "$(SB_TI_STATUS=ok SB_SA_WRITE_PATHS="" SB_SA_RTK_UNWRAPPED="" SB_SA_UNSEEN_REASONS="" SB_SA_JSON="{\"commands\":[{\"argv\":[\"python3\",\"$TASK_CLI\"]},{\"argv\":[\"true\"]}]}" sb_pf_multi_ai_cli_exempt "$P" && echo yes || echo no)"
exempt "$P" python3 "$TASK_CLI" --output-root lib/x --dry-run >/dev/null
assert_eq "root records: resolved and logical spelling of a symlinked root" "multi-ai	$P/src/x
multi-ai	$P/lib/x" "$(sb_pf_multi_ai_root_records)"
exempt "$P" python3 "$TASK_CLI" --output-root out >/dev/null
assert_eq "root records: one line when both spellings agree" "multi-ai	$P/out" "$(sb_pf_multi_ai_root_records)"
exempt "$P" python3 "$TASK_CLI" --dry-run >/dev/null
assert_eq "root records: none when nothing is written" "" "$(sb_pf_multi_ai_root_records)"

tl_results
