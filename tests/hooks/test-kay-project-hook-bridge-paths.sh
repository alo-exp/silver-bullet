#!/usr/bin/env bash
# hooks/kay-project-hook-bridge.sh: payload sources, native events and hook matching.
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

# ---- no hooks.json / bad hooks.json -----------------------------------------
rm -f "$PLUG/hooks/hooks.json"
run_bridge tool.before '{"command":"ls"}'
assert_eq "missing hooks.json: allow" "0" "$TL_STATUS"
write_hooks 'not json'
run_bridge tool.before '{"command":"ls"}'
assert_eq "invalid hooks.json: allow" "0" "$TL_STATUS"

# ---- unknown / missing native events ----------------------------------------
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:".*",hooks:[$h]}]}}')"
run_bridge session.pause '{}'
assert_eq "unknown native event: allow" "0" "$TL_STATUS"
run_bridge '' '{}'
assert_eq "empty native event: allow" "0" "$TL_STATUS"

# ---- payload sources and synthetic payloads ---------------------------------
write_hooks "$(jq -cn --argjson h "$(cmd_of dump)" '{hooks:{PreToolUse:[{matcher:"Bash|exec_command",hooks:[$h]}],PostToolUse:[{matcher:"Bash|exec_command",hooks:[$h]}],SessionStart:[{matcher:".*",hooks:[$h]}],Stop:[{matcher:".*",hooks:[$h]}]}}')"
run_bridge tool.before '{"command":["echo","hi"]}'
assert_eq "env payload: hook event" "PreToolUse" "$(jq -r .hook_event_name "$TL_TMP_DUMP")"
assert_eq "env payload: default tool is Bash" "Bash" "$(jq -r .tool_name "$TL_TMP_DUMP")"
assert_eq "env payload: argv forwarded" "echo" "$(jq -r '.tool_input.command[0]' "$TL_TMP_DUMP")"
run_bridge tool.before '{"cmd":"ls -l"}'
assert_eq "cmd key forwarded" "ls -l" "$(jq -r '.tool_input.command' "$TL_TMP_DUMP")"
run_bridge tool.before '{"argv":["a","b"]}'
assert_eq "argv key forwarded" "b" "$(jq -r '.tool_input.command[1]' "$TL_TMP_DUMP")"
run_bridge tool.before '{}'
assert_eq "no command: empty list" "[]" "$(jq -c '.tool_input.command' "$TL_TMP_DUMP")"
run_bridge tool.before 'not json'
assert_eq "invalid payload JSON: empty list" "[]" "$(jq -c '.tool_input.command' "$TL_TMP_DUMP")"
run_bridge tool.before '[1,2]'
assert_eq "non-object payload JSON: empty list" "[]" "$(jq -c '.tool_input.command' "$TL_TMP_DUMP")"
run_bridge tool.before '{"tool_name":"exec_command","command":["x"]}'
assert_eq "exec_command tool name kept" "exec_command" "$(jq -r .tool_name "$TL_TMP_DUMP")"
run_bridge tool.before '{"tool":"Shell","command":"x"}'
assert_eq "Shell tool normalised to Bash" "Bash" "$(jq -r .tool_name "$TL_TMP_DUMP")"
run_bridge tool.before '{"command":["exec_command","x"]}'
assert_eq "argv entry exec_command selects exec_command" "exec_command" "$(jq -r .tool_name "$TL_TMP_DUMP")"
run_bridge tool.after '{"command":"ls","exit_code":3,"stdout":"o","stderr":"e"}'
assert_eq "post event" "PostToolUse" "$(jq -r .hook_event_name "$TL_TMP_DUMP")"
assert_eq "post exit_code" "3" "$(jq -r .tool_response.exit_code "$TL_TMP_DUMP")"
assert_eq "post stdout" "o" "$(jq -r .tool_response.stdout "$TL_TMP_DUMP")"
# file write events map to the Write tool
write_hooks "$(jq -cn --argjson h "$(cmd_of dump)" '{hooks:{PostToolUse:[{matcher:"Write",hooks:[$h]}]}}')"
run_bridge file.after_write '{"changes":["junk",{"filePath":"/a/b"}],"success":false}'
assert_eq "file write tool is Write" "Write" "$(jq -r .tool_name "$TL_TMP_DUMP")"
assert_eq "file path from filePath" "/a/b" "$(jq -r .tool_input.file_path "$TL_TMP_DUMP")"
assert_eq "success flag forwarded" "false" "$(jq -r .tool_response.success "$TL_TMP_DUMP")"
run_bridge file.after_write '{"changes":[{"path":""},{"new_path":"/n/p"}]}'
assert_eq "file path from new_path" "/n/p" "$(jq -r .tool_input.file_path "$TL_TMP_DUMP")"
run_bridge file.after_write '{}'
assert_eq "no changes: empty path" "" "$(jq -r .tool_input.file_path "$TL_TMP_DUMP")"
# session events have no tool name, so no tool-scoped hook runs
write_hooks "$(jq -cn --argjson h "$(cmd_of dump)" '{hooks:{SessionStart:[{matcher:".*",hooks:[$h]}],Stop:[{matcher:".*",hooks:[$h]}]}}')"
rm -f "$TL_TMP_DUMP"
run_bridge session.start '{}'
run_bridge session.end '{}'
assert_file_absent "session events run no tool-matched hooks" "$TL_TMP_DUMP"
assert_eq "session events are allowed" "0" "$TL_STATUS"
write_hooks "$(jq -cn --argjson h "$(cmd_of dump)" '{hooks:{PreToolUse:[{matcher:"Bash|exec_command",hooks:[$h]}],PostToolUse:[{matcher:"Bash|exec_command",hooks:[$h]}]}}')"

# stdin payload when no env payload
rm -f "$TL_TMP_DUMP"
tl_run_stdin '{"command":"from-stdin"}' bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_SOURCE_CALL_ID=c9 bash "$4"' _ "$WORK" "$BHOME" "$PLUG" "$BRIDGE"
assert_eq "stdin payload used" "from-stdin" "$(jq -r '.tool_input.command' "$TL_TMP_DUMP")"
rm -f "$TL_TMP_DUMP"
tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_SOURCE_CALL_ID=c9 bash "$4"' _ "$WORK" "$BHOME" "$PLUG" "$BRIDGE"
assert_eq "no payload: empty command list" "[]" "$(jq -c '.tool_input.command' "$TL_TMP_DUMP")"

# python unavailable for event detection: fallback tool names
REAL_PY="$(command -v python3)"
tl_stub python3 "case \"\$2\" in tool.*|file.*) exit 1;; esac; exec $REAL_PY \"\$@\""
run_bridge tool.before '{"command":"x"}'
assert_eq "detection failing: tool.before falls back to Bash" "Bash" "$(jq -r .tool_name "$TL_TMP_DUMP")"
rm -f "${TL_BIN:?}/python3"

# ---- matching, aliases and dedupe -------------------------------------------
: >"$TL_TMP_COUNT"
write_hooks "$(jq -cn --argjson h "$(cmd_of count)" '{hooks:{PreToolUse:[
  {matcher:"Bash",hooks:[$h]},{matcher:"exec_command",hooks:[$h]},{matcher:"(",hooks:[$h]},{hooks:[$h]},
  {matcher:"Bash",hooks:[{type:"command"},{type:"command",command:"  "},{type:"command",command:7}]}]}}')"
run_bridge tool.before '{"tool_name":"exec_command","command":"ls"}'
assert_eq "same command via alias groups runs once; bad matchers/commands ignored" "X" "$(cat "$TL_TMP_COUNT")"
: >"$TL_TMP_COUNT"
run_bridge file.before_write '{"changes":[{"path":"/x"}]}'
assert_eq "no Write matcher: nothing ran" "" "$(cat "$TL_TMP_COUNT")"
write_hooks "$(jq -cn --argjson h "$(cmd_of count)" '{hooks:{PreToolUse:[{matcher:"Write|Edit|MultiEdit|apply_patch",hooks:[$h]}]}}')"
run_bridge file.before_write '{"changes":[{"path":"/x"}]}'
assert_eq "file writes match all write aliases once" "X" "$(cat "$TL_TMP_COUNT")"
assert_eq "file write without block is allowed" "0" "$TL_STATUS"

# ---- denial reasons ---------------------------------------------------------
for spec in "deny2:stderr reason" "denyjson:json deny reason" "denyjson_noreason:top-level reason" "blockjson:block reason"; do
  s="${spec%%:*}"
  want="${spec#*:}"
  write_hooks "$(jq -cn --argjson h "$(cmd_of "$s")" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
  run_bridge tool.before '{"command":"echo hi"}' "r-$s"
  assert_eq "$s: native deny status" "2" "$TL_STATUS"
  assert_contains "$s: reason on stderr" "$TL_ERR" "$want"
done
for s in allowjson fail1 deny2quiet; do
  write_hooks "$(jq -cn --argjson h "$(cmd_of "$s")" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
  run_bridge tool.before '{"command":"echo hi"}' "r-$s"
  assert_eq "$s: no usable reason, call allowed" "0" "$TL_STATUS"
done
# the first reason wins
write_hooks "$(jq -cn --argjson a "$(cmd_of deny2)" --argjson b "$(cmd_of blockjson)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$a,$b]}]}}')"
run_bridge tool.before '{"command":"echo hi"}' r-first
assert_contains "first blocking reason wins" "$TL_ERR" "stderr reason"
assert_not_contains "later reason ignored" "$TL_ERR" "block reason"

tl_results
