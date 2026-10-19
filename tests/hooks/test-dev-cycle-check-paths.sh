#!/usr/bin/env bash
# dev-cycle-check: jq-less blocking, event formats, planning stages, trivial edits and warnings.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-dc.sh"

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
PATCH_DOC=$'*** Begin Patch\n*** Update File: notes/readme.txt\n@@\n-a\n+b\n*** End Patch'
run_dc "$(jq -cn --arg p "$PATCH_SRC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')"
assert_eq "apply_patch touching src is gated" "deny" "$(decision)"
run_dc "$(jq -cn --arg p "$PATCH_DOC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')"
assert_eq "apply_patch outside src is ignored" "none" "$(decision)"

# ── four-stage planning gate ─────────────────────────────────────────────────
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


tl_results
