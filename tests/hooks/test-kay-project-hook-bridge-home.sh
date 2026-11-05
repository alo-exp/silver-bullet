#!/usr/bin/env bash
# hooks/kay-project-hook-bridge.sh: debug log, PATH cleaning, home resolution and fallbacks.
# mapping, hook matching/dedupe, denial blocks, restore and debug logging.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

BRIDGE="$TL_REPO_ROOT/hooks/kay-project-hook-bridge.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset CODE_HOOK_EVENT CODE_HOOK_PAYLOAD CODE_HOOK_SOURCE_CALL_ID CODE_HOOK_CALL_ID KAY_HOME \
  SB_KAY_HOOK_BRIDGE_DEBUG SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK

PLUG="$TL_TMP/plugin"
WORK="$TL_TMP/work"
BHOME="$TL_TMP/bhome"
mkdir -p "$PLUG/hooks" "$WORK" "$BHOME"
ln -s "$TL_REPO_ROOT/hooks/lib" "$PLUG/hooks/lib"
git -C "$WORK" init -q
BR="$BHOME/.kay/.silver-bullet/kay-hook-bridge"
ACTIVE="$BHOME/.kay/.silver-bullet/path-prepend/active"

# ---- hook scripts -----------------------------------------------------------
mk_script() { # name body
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$TL_TMP/$1"
  chmod +x "$TL_TMP/$1"
}
mk_script dump 'cat >"$TL_TMP_DUMP"; printf "%s" "$PATH" >"$TL_TMP_DUMP.path"'
mk_script deny2 'cat >/dev/null; echo "stderr reason" >&2; exit 2'
mk_script deny2quiet 'cat >/dev/null; exit 2'
mk_script denyjson 'cat >/dev/null; echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"json deny reason\"}}"'
mk_script denyjson_noreason 'cat >/dev/null; echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"},\"reason\":\"top-level reason\"}"'
mk_script blockjson 'cat >/dev/null; echo "{\"decision\":\"block\",\"reason\":\"block reason\"}"'
mk_script allowjson 'cat >/dev/null; echo "{\"decision\":\"approve\"}"'
mk_script fail1 'cat >/dev/null; echo "oops" >&2; exit 1'
mk_script count 'cat >/dev/null; printf X >>"$TL_TMP_COUNT"'
export TL_TMP_DUMP="$TL_TMP/dump.json" TL_TMP_COUNT="$TL_TMP/count.txt" TL_TMP_CHFLAGS="$TL_TMP/chflags.log"

write_hooks() { # json
  printf '%s\n' "$1" >"$PLUG/hooks/hooks.json"
}
cmd_of() { jq -cn --arg c "$TL_TMP/$1" '{type:"command",command:$c}'; }

# run_bridge EVENT PAYLOAD [call-id] -> TL_OUT/TL_ERR/TL_STATUS ; stdin empty unless STDIN_PAYLOAD set
run_bridge() {
  local event="$1" payload="$2" call="${3:-call1}"
  tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT="$4" CODE_HOOK_PAYLOAD="$5" CODE_HOOK_SOURCE_CALL_ID="$6" bash "$7"' \
    _ "$WORK" "$BHOME" "$PLUG" "$event" "$payload" "$call" "$BRIDGE"
}

REAL_PY="$(command -v python3)"
# ---- call id suffix stripping, debug log, PATH cleaning ----------------------
write_hooks "$(jq -cn --argjson h "$(cmd_of dump)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
SB_KAY_HOOK_BRIDGE_DEBUG=1 run_bridge tool.before '{"command":"ls"}' 'abc_hook_tool_before_1'
assert_file_exists "debug log named without the hook suffix" "$BR/debug/abc.log"
assert_contains "debug log has entries" "$(cat "$BR/debug/abc.log")" "native_event=tool.before"
tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="{}" CODE_HOOK_SOURCE_CALL_ID=pathcall PATH="$4:$PATH:" bash "$5"' _ "$WORK" "$BHOME" "$PLUG" "$ACTIVE" "$BRIDGE"
assert_not_contains "active shim dir stripped from PATH" ":$(cat "$TL_TMP_DUMP.path"):" ":$ACTIVE:"
tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="{}" CODE_HOOK_CALL_ID=altcall bash "$4"' _ "$WORK" "$BHOME" "$PLUG" "$BRIDGE"
assert_eq "CODE_HOOK_CALL_ID accepted" "0" "$TL_STATUS"

# ---- home resolution --------------------------------------------------------
write_hooks "$(jq -cn --argjson h "$(cmd_of count)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_nohome() { # extra env assignments...
  tl_run bash -c 'cd "$1" && shift && exec env -u HOME -u KAY_HOME "$@" CLAUDE_PLUGIN_ROOT="$PLUGIN" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="{}" CODE_HOOK_SOURCE_CALL_ID=hm bash "$BRIDGE"' _ "$WORK" "$@"
}
export PLUGIN="$PLUG" BRIDGE
run_nohome KAY_HOME="$TL_TMP/kh/.kay"
assert_eq "KAY_HOME with .kay suffix" "0" "$TL_STATUS"
assert_file_exists "bridge dir under KAY_HOME parent" "$TL_TMP/kh/.kay/.silver-bullet/kay-hook-bridge/blocks"
run_nohome KAY_HOME="$TL_TMP/kh2"
assert_file_exists "bridge dir under plain KAY_HOME" "$TL_TMP/kh2/.kay/.silver-bullet/kay-hook-bridge/blocks"
mkdir -p "$TL_TMP/codexhome/.codex/plugins/sb/hooks"
ln -s "$TL_REPO_ROOT/hooks/lib" "$TL_TMP/codexhome/.codex/plugins/sb/hooks/lib"
cp "$PLUG/hooks/hooks.json" "$TL_TMP/codexhome/.codex/plugins/sb/hooks/hooks.json"
tl_run bash -c 'cd "$1" && exec env -u HOME -u KAY_HOME CLAUDE_PLUGIN_ROOT="$2" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="{}" CODE_HOOK_SOURCE_CALL_ID=hm bash "$3"' _ "$WORK" "$TL_TMP/codexhome/.codex/plugins/sb" "$BRIDGE"
assert_file_exists "home derived from a .codex plugin root" "$TL_TMP/codexhome/.kay/.silver-bullet/kay-hook-bridge/blocks"
tl_run bash -c 'cd "$1" && exec env -u HOME -u KAY_HOME CLAUDE_PLUGIN_ROOT="$2" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="{}" CODE_HOOK_SOURCE_CALL_ID=hm bash "$3"' _ "$WORK" "$PLUG" "$BRIDGE"
assert_contains "HOME unset and unresolvable: the intended message, not an unbound variable" "$TL_ERR" "Unable to resolve Kay bridge home root"
assert_eq "HOME unset and unresolvable: exit 1" "1" "$TL_STATUS"
tl_run bash -c 'cd "$1" && exec env -u KAY_HOME HOME= CLAUDE_PLUGIN_ROOT="$2" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="{}" CODE_HOOK_SOURCE_CALL_ID=hm bash "$3"' _ "$WORK" "$PLUG" "$BRIDGE"
assert_eq "no home anywhere: exit 1" "1" "$TL_STATUS"
assert_contains "no home anywhere: explains" "$TL_ERR" "Unable to resolve Kay bridge home root"

# ---- plugin root defaults to the repository containing the bridge -----------
tl_run bash -c 'cd "$1" && exec env -u CLAUDE_PLUGIN_ROOT HOME="$2" CODE_HOOK_EVENT=session.start CODE_HOOK_PAYLOAD="{}" CODE_HOOK_SOURCE_CALL_ID=defroot bash "$3"' _ "$WORK" "$BHOME" "$BRIDGE"
assert_eq "default plugin root: session event allowed" "0" "$TL_STATUS"

# ---- detection failing for non-tool events ----------------------------------
tl_stub python3 "case \"\$2\" in tool.*|file.*|session.*) exit 1;; esac; exec $REAL_PY \"\$@\""
run_bridge session.start '{}'
assert_eq "detection failing for session.start: allowed" "0" "$TL_STATUS"
run_bridge file.before_write '{"changes":[{"path":"/x"}]}'
assert_eq "detection failing for file.before_write: still allowed without hooks" "0" "$TL_STATUS"
rm -f "${TL_BIN:?}/python3"

# ---- denial paths that find no command or no repository ----------------------
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_bridge tool.before '{}' nocmd
assert_eq "denial with no command: status 2" "2" "$TL_STATUS"
run_bridge tool.after '{}' nocmd
mkdir -p "$TL_TMP/nogit"
tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="$4" CODE_HOOK_SOURCE_CALL_ID=nogitc bash "$5"' _ "$TL_TMP/nogit" "$BHOME" "$PLUG" '{"command":"git commit -m x"}' "$BRIDGE"
assert_eq "git commit outside a repository: denied" "2" "$TL_STATUS"
assert_not_contains "no .git target outside a repository" "$(cat "$BR/blocks/nogitc.state")" ".git"
run_bridge tool.after '{}' nogitc

# tool-input library without the script helpers
PLUG2="$TL_TMP/plugin2"
mkdir -p "$PLUG2/hooks/lib"
for f in "$TL_REPO_ROOT"/hooks/lib/*; do ln -s "$f" "$PLUG2/hooks/lib/${f##*/}"; done
rm -f "$PLUG2/hooks/lib/tool-input.sh"
printf '%s\n' 'sb_tool_command_string() { jq -r ".tool_input.command | if type == \"array\" then join(\" \") else . end" <<<"$1"; }' >"$PLUG2/hooks/lib/tool-input.sh"
cp "$PLUG/hooks/hooks.json" "$PLUG2/hooks/hooks.json"
tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="$4" CODE_HOOK_SOURCE_CALL_ID=minlib bash "$5"' _ "$WORK" "$BHOME" "$PLUG2" '{"command":"somecmd --x"}' "$BRIDGE"
assert_eq "minimal tool-input lib: denied" "2" "$TL_STATUS"
assert_file_exists "minimal tool-input lib: entry command shim still installed" "$ACTIVE/somecmd"
run_bridge tool.after '{}' minlib

tl_results
