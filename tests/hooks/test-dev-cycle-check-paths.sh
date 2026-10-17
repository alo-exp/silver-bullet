#!/usr/bin/env bash
# hooks/dev-cycle-check.sh: jq-less blocking, lib-less fallbacks, plugin/state protection,
# config validation, shell write detection and the four-stage planning gate.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

HOOK="$TL_REPO_ROOT/hooks/dev-cycle-check.sh"
CFG_VERSION="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

SKILLS="$TL_TMP/skills"
for s in inst-a inst-b; do
  mkdir -p "$SKILLS/skills/$s"; printf -- '---\nname: %s\n---\n' "$s" >"$SKILLS/skills/$s/SKILL.md"
done
STATE="$SB_RUNTIME_STATE_DIR/state-test"
BRANCHF="$SB_RUNTIME_STATE_DIR/branch-test"
export SILVER_BULLET_STATE_FILE="$STATE"
export SILVER_BULLET_SKILL_ROOTS="$SKILLS"
export SILVER_BULLET_BRANCH_FILE="$BRANCHF"
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/verify-tests-test"

# mkproj <name> [jq filter]: SB project with a git repo, src/ files and a config.
mkproj() {
  PROJ="$TL_TMP/$1"
  tl_git_repo "$PROJ"
  mkdir -p "$PROJ/src"
  : >"$PROJ/src/app.js"
  printf '# SB\n' >"$PROJ/silver-bullet.md"
  jq -n --arg v "$CFG_VERSION" '{config_version:$v, sb_initiated:true,
      project:{src_pattern:"/src/", active_workflow:"full-dev-cycle"},
      skills:{required_planning:["inst-a"], required_deploy:["inst-a","inst-b"]}}' \
    | jq "${2:-.}" >"$PROJ/.silver-bullet.json"
  : >"$STATE"
  printf 'feature/test\n' >"$BRANCHF"
  rm -f "$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
}
state() { printf '%s\n' "$@" >"$STATE"; }

# run_dc <json> [env...]: run the hook in $PROJ.
run_dc() {
  local json="$1"
  shift
  tl_run_stdin "$json" env "$@" bash -c 'cd "$1" && exec bash "${HOOK_UNDER_TEST:-$2}"' _ "${RUN_DIR:-$PROJ}" "$HOOK"
}
edit_json() { jq -cn --arg e "${3:-PreToolUse}" --arg f "$1" --arg t "${2:-Edit}" --arg o "${4:-}" --arg n "${5:-}" \
  '{hook_event_name:$e,tool_name:$t,tool_input:({file_path:$f}+(if $o!="" then {old_string:$o,new_string:$n} else {} end))}'; }
bash_json() { jq -cn --arg e "${2:-PreToolUse}" --arg c "$1" '{hook_event_name:$e,tool_name:"Bash",tool_input:{command:$c}}'; }
# The hook can print several JSON objects (advisories, then a verdict): judge by the last one
# and search all messages.
decision() {
  if [[ -z "$TL_OUT" ]]; then echo none; return; fi
  jq -rs 'last | if .hookSpecificOutput.permissionDecision then .hookSpecificOutput.permissionDecision
         elif .decision then .decision else "allow" end' <<<"$TL_OUT" 2>/dev/null || echo invalid
}
message() { jq -rs 'map(.reason // .hookSpecificOutput.permissionDecisionReason // .hookSpecificOutput.message // "") | join("\n")' <<<"$TL_OUT"; }
BIG_OLD="$(printf 'x%.0s' {1..80})"
BIG_NEW="$(printf 'y%.0s' {1..80})"

# ── jq missing ───────────────────────────────────────────────────────────────
mkproj nojq
NOJQ="$(tl_path_without jq)"
run_dc "$(edit_json "$PROJ/src/app.js")" PATH="$NOJQ"
assert_eq "no jq in an initiated project: edit is denied" "deny" "$(decision)"
assert_contains "jq-less denial explains the cause" "$(message)" "jq is required"
assert_eq "jq-less denial exits 0" 0 "$TL_STATUS"
NOJQPY="$(tl_path_without jq python3)"
run_dc "$(edit_json "$PROJ/src/app.js")" PATH="$NOJQPY"
assert_eq "no jq and no python3: still denied" "deny" "$(decision)"
UNINIT="$TL_TMP/uninit"; mkdir -p "$UNINIT"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
RUN_DIR="$UNINIT" run_dc "$(edit_json "$UNINIT/src/app.js")" PATH="$NOJQ"
assert_contains "no jq outside a project: warning only" "$TL_OUT" "Silver Bullet hooks require jq"
assert_eq "warning exits 0" 0 "$TL_STATUS"
unset RUN_DIR

# ── basic guards and event formats ───────────────────────────────────────────
mkproj basic
run_dc "$(edit_json "$PROJ/src/app.js")" SB_AGENT_CERT_RUN=1
assert_eq "cert run bypasses the gate" "none" "$(decision)"
run_dc "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:""}}')"
assert_eq "empty command is ignored" "none" "$(decision)"
run_dc "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{}}')"
assert_eq "non-shell tool without a file is ignored" "none" "$(decision)"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "no planning recorded: PreToolUse deny" "deny" "$(decision)"
assert_contains "stage A names the missing skill" "$(message)" "❌ inst-a"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PostToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "PostToolUse uses a block decision" "block" "$(decision)"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "kay bridge: deny exits 2" 2 "$TL_STATUS"
assert_contains "kay bridge: reason goes to stderr" "$TL_ERR" "HARD STOP"

# apply_patch
PATCH_SRC=$'*** Begin Patch\n*** Update File: src/app.js\n@@\n-a\n+b\n*** End Patch'
PATCH_DOC=$'*** Begin Patch\n*** Update File: notes/readme.txt\n@@\n-a\n+b\n*** End Patch'
run_dc "$(jq -cn --arg p "$PATCH_SRC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')"
assert_eq "apply_patch touching src is gated" "deny" "$(decision)"
run_dc "$(jq -cn --arg p "$PATCH_DOC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')"
assert_eq "apply_patch outside src is ignored" "none" "$(decision)"

# ── four-stage planning gate ─────────────────────────────────────────────────
edit() { run_dc "$(edit_json "$PROJ/src/app.js" Edit "${1:-PreToolUse}" "$BIG_OLD" "$BIG_NEW")"; }
mkproj stages '.skills.required_planning=["inst-a","ghost-a","ghost-b"]'
state ""
edit
assert_contains "missing and uninstalled: both reported" "$(message)" "Ignored required skills"
assert_contains "second uninstalled skill listed" "$(message)" "ghost-b (not installed anywhere invocable)"
state inst-a
edit
assert_eq "only uninstalled skills missing: allowed" "allow" "$(decision)"
assert_contains "advisory mentions unenforced skills" "$(message)" "not enforced"
mkproj stages2 '.skills.required_planning=["inst-a"] | .skills.required_deploy=["silver-context"]'
state inst-a
edit
assert_contains "stage B: planning verified" "$(message)" "Planning verified. Implementation edits allowed"
state inst-a silver-branch-finish
edit
assert_contains "stage B with finalization markers" "$(message)" "finalization markers exist before silver-review"
state inst-a silver-review
edit
assert_contains "stage C: review recorded" "$(message)" "SB code review recorded"
state inst-a silver-review silver-branch-finish
edit
assert_contains "stage D: all phases complete" "$(message)" "All workflow phases complete"

# ── trivial edits and warnings ───────────────────────────────────────────────
mkproj trivial
state inst-a
run_dc "$(edit_json "$PROJ/src/config.json")"
assert_contains "json file under src is non-logic" "$(message)" "Non-logic file"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "a" "b")"
assert_contains "tiny edits are skipped" "$(message)" "Small edit"
run_dc "$(edit_json "$PROJ/lib/other.js")"
assert_eq "file outside the src scope is ignored" "none" "$(decision)"
run_dc "$(edit_json "$PROJ/src/app.test.js")"
assert_eq "excluded test file is ignored" "none" "$(decision)"
touch "$SB_RUNTIME_STATE_DIR/trivial"
state ""
edit
assert_eq "legacy trivial marker lets the edit through" "none" "$(decision)"
rm -f "$SB_RUNTIME_STATE_DIR/trivial"
mkproj devopsfiles '.project.active_workflow="devops-cycle" | .skills.required_planning_devops=["inst-a"]'
state inst-a
run_dc "$(edit_json "$PROJ/src/main.tf")"
assert_contains "devops: terraform stays gated (planning verified)" "$(message)" "Planning verified"
run_dc "$(edit_json "$PROJ/src/notes.md")"
assert_contains "devops: markdown is non-logic" "$(message)" "Non-logic file"
run_dc "$(edit_json "$PROJ/src/values.yaml")"
assert_contains "devops: yaml is infrastructure, still gated" "$(message)" "Planning verified"

mkproj branch
state inst-a
printf 'other/branch\n' >"$BRANCHF"
edit
assert_contains "branch mismatch is advisory" "$(message)" "Branch mismatch"
printf '' >"$BRANCHF"
edit
assert_not_contains "empty stored branch gives no mismatch warning" "$(message)" "Branch mismatch"
SB_OUTSIDE="$TL_TMP/outside-branch"; printf 'x\n' >"$SB_OUTSIDE"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_BRANCH_FILE="$SB_OUTSIDE" SILVER_BULLET_VERIFY_TESTS_STATE_FILE=/tmp/outside-vt SILVER_BULLET_STATE_FILE=/tmp/outside-state
assert_eq "paths outside the runtime root fall back to defaults" "deny" "$(decision)"

mkproj destructive
state inst-a
run_dc "$(bash_json 'rm src/old.js')"
assert_contains "rm of project files warns" "$(message)" "Destructive command detected"
run_dc "$(bash_json 'rm /tmp/scratch-file')"
assert_not_contains "rm under /tmp does not warn" "$(message)" "Destructive command"

# ── config validation ────────────────────────────────────────────────────────
mkproj cfgpat '.project.src_pattern="lib"'
state ""
run_dc "$(edit_json "$PROJ/lib/x.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "src_pattern without a leading slash falls back to /src/" "none" "$(decision)"
mkproj cfgpat2 '.project.src_pattern="/"'
run_dc "$(edit_json "$PROJ/lib/x.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "over-broad src_pattern falls back to /src/" "none" "$(decision)"
mkproj cfgpat3 '.project.src_pattern="/lib/"'
run_dc "$(edit_json "$PROJ/lib/x.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "valid custom src_pattern is honoured" "deny" "$(decision)"
LONG="$(printf 'a%.0s' {1..250})"
mkproj cfgex "$(jq -cn --arg l "$LONG" '.project.src_exclude_pattern=$l')"
run_dc "$(edit_json "$PROJ/src/app.test.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "over-long exclude pattern falls back to the default" "none" "$(decision)"
mkproj cfgex2 '.project.src_exclude_pattern="a b;c"'
run_dc "$(edit_json "$PROJ/src/app.test.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "unsafe exclude pattern falls back to the default" "none" "$(decision)"
mkproj cfgraw
printf '{ not json' >"$PROJ/.silver-bullet.json"
state inst-a
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "unreadable config falls back to defaults without crashing" "0" "$TL_STATUS"
NOCFG="$TL_TMP/nocfg"; tl_git_repo "$NOCFG"; mkdir -p "$NOCFG/src"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
RUN_DIR="$NOCFG" run_dc "$(edit_json "$NOCFG/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "no project config: hook still exits cleanly" "0" "$TL_STATUS"
unset RUN_DIR

# ── shell commands ───────────────────────────────────────────────────────────
mkproj shell
state inst-a
dc_cmd() { run_dc "$(bash_json "$1" "${2:-PreToolUse}")" "${@:3}"; }
dc_cmd 'echo hi'
assert_eq "plain read-only command is ignored" "none" "$(decision)"
dc_cmd 'scripts/silver-bullet invoke-skill silver-plan'
assert_eq "skill adapter invocation is ignored" "none" "$(decision)"
dc_cmd 'echo x > notes/out.txt'
assert_eq "write outside src is ignored" "none" "$(decision)"
dc_cmd 'echo x > src/app.js'
assert_contains "write into src passes the planning gate with an advisory" "$(message)" "Planning verified"
assert_contains "logic write with no composed workflow gets the F-06 advisory" "$(message)" "WORKFLOW ADVISORY"
dc_cmd 'echo x > src/data.json'
assert_contains "non-logic shell write is skipped" "$(message)" "Non-logic file"
dc_cmd 'cp $SRC /src/$DEST'
assert_contains "opaque write mentioning src falls back to scope matching" "$(message)" "Planning verified"
dc_cmd 'cp $SRC /lib/$DEST'
assert_eq "opaque write outside src is ignored" "none" "$(decision)"
dc_cmd 'cp $SRC /src/a.test.js$DEST'
assert_eq "opaque write to an excluded path is ignored" "none" "$(decision)"
dc_cmd 'ls /src/$DIR'
assert_eq "opaque read-only listing is ignored" "none" "$(decision)"
dc_cmd 'git status && echo src/ done'
assert_eq "command without write intent is ignored" "none" "$(decision)"
state ""
dc_cmd 'echo x > src/app.js'
assert_eq "shell write into src is gated without planning" "deny" "$(decision)"

# scripts invoked by the command
state inst-a
printf '#!/usr/bin/env bash\ncat src/app.js\n' >"$PROJ/check.sh"
dc_cmd 'bash check.sh'
assert_eq "read-only script body is ignored" "none" "$(decision)"
printf '#!/usr/bin/env bash\necho x > src/gen.js\n' >"$PROJ/gen.sh"
dc_cmd 'bash gen.sh'
assert_contains "script that writes into src is gated" "$(message)" "Planning verified"
printf '#!/usr/bin/env bash\ncp "$1" "$2"\n' >"$PROJ/opaque.sh"
dc_cmd 'bash opaque.sh /src/a'
# Characterisation: write intent is judged from the command text, not from the script body.
assert_eq "opaque script body without write intent in the command is ignored" "none" "$(decision)"
dc_cmd 'bash opaque.sh /src/a > /dev/null && cp x /src/$Y'
assert_contains "command text with opaque write intent is gated" "$(message)" "Planning verified"

# PostToolUse invalidates the fresh-test marker only for real source writes
mkproj post
state inst-a silver-review silver-branch-finish
VT="$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
printf 'v\n' >"$VT"
run_dc "$(edit_json "$PROJ/src/app.js" Write PostToolUse "$BIG_OLD" "$BIG_NEW")"
assert_file_absent "Write PostToolUse invalidates the test marker" "$VT"
printf 'v\n' >"$VT"
run_dc "$(edit_json "$PROJ/src/app.js" Read PostToolUse)"
assert_file_exists "Read PostToolUse keeps the test marker" "$VT"
dc_cmd 'echo x > src/app.js' PostToolUse
assert_file_absent "shell write into src invalidates the marker" "$VT"
printf 'v\n' >"$VT"
dc_cmd 'cp $A /src/$B' PostToolUse
assert_file_absent "opaque cp into src invalidates the marker" "$VT"
printf 'v\n' >"$VT"
dc_cmd 'sed -i s/a/b/ $F /src/' PostToolUse
assert_file_absent "opaque sed -i on src invalidates the marker" "$VT"
printf 'v\n' >"$VT"
dc_cmd 'echo x > notes/out.txt' PostToolUse
assert_file_exists "write outside src keeps the marker" "$VT"

# devops shell non-logic handling
mkproj devshell '.project.active_workflow="devops-cycle" | .skills.required_planning_devops=["inst-a"]'
state inst-a
dc_cmd 'echo x > src/notes.md'
assert_contains "devops: markdown shell write is non-logic" "$(message)" "Non-logic file"
dc_cmd 'echo x > src/stack.yaml'
assert_contains "devops: yaml shell write is logic" "$(message)" "Planning verified"

# ── composed workflow admission ──────────────────────────────────────────────
WF=20260101T000000Z-abc123-silver-feature
mkproj adm
state inst-a
mkdir -p "$PROJ/.planning/workflows"
printf '## Flow Log\n| 1 | a | pending |\n' >"$PROJ/.planning/workflows/$WF.md"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_contains "active workflow without SB_WORKFLOW_ID blocks" "$(message)" "SB_WORKFLOW_ID is unset"
assert_contains "block lists the workflow" "$(message)" "• $WF"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID=BAD
assert_contains "malformed id blocks" "$(message)" "invalid format: BAD"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID=20260101T000000Z-zzz999-silver-feature
assert_contains "unknown id blocks" "$(message)" "no active workflow file matches"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID="$WF"
assert_contains "matching id admits the edit" "$(message)" "Planning verified"
dc_cmd "export SB_WORKFLOW_ID=$WF; echo x > src/app.js"
assert_contains "id taken from an export assignment" "$(message)" "Planning verified"
dc_cmd "env SB_WORKFLOW_ID=$WF echo x > src/app.js"
assert_contains "id taken from an env prefix" "$(message)" "Planning verified"
dc_cmd "SB_WORKFLOW_ID=BAD-ID echo x > src/app.js"
assert_contains "malformed id in the command blocks" "$(message)" "invalid format"
dc_cmd 'FOO=1 echo x > src/app.js'
assert_contains "no id anywhere in the command blocks" "$(message)" "SB_WORKFLOW_ID is unset"
dc_cmd "echo x > src/app.js" PostToolUse
assert_not_contains "admission is a PreToolUse check" "$(message)" "WORKFLOW ADMISSION"
ln -s "$PROJ/.planning/workflows/$WF.md" "$PROJ/.planning/workflows/20260101T000000Z-lnk123-silver-feature.md"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID=20260101T000000Z-lnk123-silver-feature
assert_contains "symlinked workflow file is not accepted" "$(message)" "no active workflow file matches"

# ── state tamper and plugin boundary ─────────────────────────────────────────
mkproj tamper
state inst-a
run_dc "$(edit_json "$SB_RUNTIME_STATE_DIR/state" Write)"
assert_contains "editing the state file is blocked" "$(message)" "STATE TAMPER BLOCKED"
run_dc "$(edit_json "$SB_RUNTIME_STATE_DIR/planning-edit-override" Write)"
assert_eq "state sentinels may be written" "none" "$(decision)"
dc_cmd "echo inst-a >> $SB_RUNTIME_STATE_DIR/state"
assert_contains "shell append to the state file is blocked" "$(message)" "STATE TAMPER BLOCKED"
dc_cmd "cp /tmp/x $SB_RUNTIME_STATE_DIR/state"
assert_contains "cp onto the state file is blocked" "$(message)" "STATE TAMPER BLOCKED"
dc_cmd "git commit -m 'mention $SB_RUNTIME_STATE_DIR/state > x'"
assert_not_contains "git messages mentioning the state path are fine" "$(message)" "STATE TAMPER"
dc_cmd "touch $SB_RUNTIME_STATE_DIR/trivial"
assert_not_contains "touching a state sentinel is fine" "$(message)" "STATE TAMPER"
dc_cmd "touch"
assert_not_contains "bare touch is not a state write" "$(message)" "STATE TAMPER"
run_dc "$(edit_json "$SB_RUNTIME_PLUGIN_CACHE_ROOT/x/y/SKILL.md" Edit)"
assert_contains "editing the plugin cache is blocked" "$(message)" "THIRD-PARTY PLUGIN BOUNDARY"
dc_cmd "echo x > $SB_RUNTIME_PLUGIN_CACHE_ROOT/x/file"
assert_contains "writing into the plugin cache from a shell is blocked" "$(message)" "PLUGIN BOUNDARY VIOLATION via Bash"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0"
printf '{"plugins":{}}' >"$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json" 2>/dev/null || { mkdir -p "$SB_RUNTIME_HOME_ROOT/plugins"; printf '{"plugins":{}}' >"$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"; }
dc_cmd "rm -rf $SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0"
assert_not_contains "uninstall cleanup of the plugin cache is allowed" "$(message)" "BOUNDARY"

tl_results
