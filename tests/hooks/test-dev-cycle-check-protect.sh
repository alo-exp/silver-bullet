#!/usr/bin/env bash
# dev-cycle-check: state tamper, plugin boundary, installed-copy protection, lib-less mode.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-dc.sh"

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

# ── self-protection from an installed (non-checkout) copy ────────────────────
INSTALLED="$SB_RUNTIME_HOME_ROOT/sbplugin"
mkdir -p "$INSTALLED/templates"
cp -R "$TL_REPO_ROOT/hooks" "$INSTALLED/hooks"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$INSTALLED/templates/"
mkproj selfprot
state inst-a silver-review silver-branch-finish
inst() { HOOK_UNDER_TEST="$INSTALLED/hooks/dev-cycle-check.sh" run_dc "$@"; }
HOOKS_DIR="$INSTALLED/hooks"
inst "$(edit_json "$HOOKS_DIR/dev-cycle-check.sh" Edit)"
assert_contains "editing installed hooks is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(edit_json "$INSTALLED/hooks.json" Write)"
assert_contains "editing the installed hooks.json is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "echo x > $HOOKS_DIR/evil.sh")"
assert_contains "shell write into installed hooks is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "rm -rf \"\$X\"; ls $HOOKS_DIR/")"
assert_contains "opaque deletion near installed hooks is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "ls $HOOKS_DIR/")"
assert_not_contains "reading installed hooks is allowed" "$(message)" "NEVER modifies"
inst "$(edit_json "$SB_RUNTIME_HOME_ROOT/other/hooks/x.sh" Edit)"
assert_contains "any hooks/ path under the runtime root is protected" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "echo x > $SB_RUNTIME_HOME_ROOT/other/hooks/a.sh")"
assert_contains "shell write into another runtime hooks dir is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "rm -rf \"\$X\"; ls $SB_RUNTIME_HOME_ROOT/other/hooks/")"
assert_contains "opaque deletion near a runtime hooks dir is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "cat $SB_RUNTIME_HOME_ROOT/other/hooks/a.sh")"
assert_not_contains "reading a runtime hooks dir is allowed" "$(message)" "NEVER modifies"
inst "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_contains "ordinary source edits still pass the installed copy" "$(message)" "All workflow phases complete"

# ── libraries unavailable (hook cannot resolve its lib dir) ──────────────────
mkproj libless
FLAG="$TL_TMP/pwd-fail-once"
LIBSTATE="$SB_RUNTIME_STATE_DIR/state"
printf 'inst-a\n' >"$LIBSTATE"
libless() { # libless <json> [env...]
  : >"$FLAG"
  local json="$1"
  shift
  tl_run_stdin "$json" env "$@" bash -c 'pwd() { if [[ -e "$1" ]]; then rm -f "$1"; return 1; fi; builtin pwd "$@"; }; export -f pwd; cd "$2" && exec bash "$3"' _ "$FLAG" "${LIBLESS_DIR:-$PROJ}" "$HOOK"
}
libless "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: planning satisfied is allowed" "allow" "$(decision)"
libless "$(bash_json 'echo x > src/app.js')" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: shell write into src is judged" "allow" "$(decision)"
libless "$(jq -cn --arg p "$PATCH_SRC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: apply_patch still handled" "0" "$TL_STATUS"
libless "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{}}')" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: non-shell tool without file exits quietly" "none" "$(decision)"
libless "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:""}}')" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: empty command exits quietly" "none" "$(decision)"
printf '' >"$LIBSTATE"
rm -rf "$PROJ/.git"
libless "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: exits cleanly without a git repo (config walk reaches /)" "0" "$TL_STATUS"
rm -f "$LIBSTATE"

# lib-less: config walk stops at a git root without config; default planning list
LIBLESS_DIR="$NOCFG" libless "$(edit_json "$NOCFG/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: git root without config ends the walk" "0" "$TL_STATUS"
mkproj libless2 'del(.skills.required_planning)'
LIBSTATE="$SB_RUNTIME_STATE_DIR/state"
printf '' >"$LIBSTATE"
libless "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_STATE_FILE= SILVER_BULLET_BRANCH_FILE=
assert_eq "lib-less: default planning list applies" "allow" "$(decision)"
rm -f "$LIBSTATE"

# ── remaining shell/config/state paths ───────────────────────────────────────
mkproj misc
state inst-a
run_dc "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Glob",tool_input:{command:"echo hi > src/app.js"}}')"
assert_eq "non-shell tool carrying a command string is ignored" "none" "$(decision)"
dc_cmd $'echo a > notes/a.txt\necho b > src/b.js\necho c > src/c.test.js'
assert_contains "only in-scope targets of a multi-write command are gated" "$(message)" "Planning verified"
dc_cmd $'echo a > notes/a.txt\necho c > src/c.test.js'
assert_eq "out-of-scope and excluded targets only: ignored" "none" "$(decision)"
dc_cmd $'cp $A /src/$B\nls'
assert_contains "multi-line opaque write is still judged by scope" "$(message)" "Planning verified"

STATE_ALT="$SB_RUNTIME_STATE_DIR/state-from-config"
TRIVIAL_ALT="$SB_RUNTIME_STATE_DIR/trivial-from-config"
mkproj cfgstate ".state={state_file:\"$STATE_ALT\",trivial_file:\"$TRIVIAL_ALT\"}"
printf 'inst-a\n' >"$STATE_ALT"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_STATE_FILE=
assert_contains "state file taken from the config" "$(message)" "Planning verified"
touch "$TRIVIAL_ALT"
printf '' >"$STATE_ALT"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_STATE_FILE=
assert_eq "trivial file taken from the config" "none" "$(decision)"
rm -f "$STATE_ALT" "$TRIVIAL_ALT"

# non-git project with a recorded branch: no mismatch warning
mkproj nogit
rm -rf "$PROJ/.git"
printf 'main\n' >"$BRANCHF"
state inst-a
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_not_contains "no git branch: no mismatch warning" "$(message)" "Branch mismatch"

# unremovable marker (a directory) does not break PostToolUse
mkproj dirmarker
state inst-a silver-review silver-branch-finish
mkdir -p "$SB_RUNTIME_STATE_DIR/vt-dir"
run_dc "$(edit_json "$PROJ/src/app.js" Write PostToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/vt-dir"
assert_contains "unremovable test marker is tolerated" "$(message)" "All workflow phases complete"

# unreadable config reaching the finalization lookup
mkproj badcfg
printf '{ not json' >"$PROJ/.silver-bullet.json"
state silver-quality-gates silver-context silver-plan
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_contains "invalid config still reaches the planning verdict" "$(message)" "Planning verified"


tl_results
