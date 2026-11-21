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
# session.end has no tool name and Kay has no Stop gating: no hook runs on it
write_hooks "$(jq -cn --argjson h "$(cmd_of dump)" '{hooks:{Stop:[{matcher:".*",hooks:[$h]}]}}')"
rm -f "$TL_TMP_DUMP"
run_bridge session.end '{}'
assert_file_absent "session.end runs no hook" "$TL_TMP_DUMP"
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
for s in allowjson fail1; do
  write_hooks "$(jq -cn --argjson h "$(cmd_of "$s")" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
  run_bridge tool.before '{"command":"echo hi"}' "r-$s"
  assert_eq "$s: no usable reason, call allowed" "0" "$TL_STATUS"
done
# R7-07: a bare exit 2 is still the host's blocking error; "ask" cannot be
# answered on Kay and blocks too; a noisy stream falls back to its last line.
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2quiet)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_bridge tool.before '{"command":"echo hi"}' r-quiet
assert_eq "exit 2 with no output blocks" "2" "$TL_STATUS"
assert_contains "exit 2 default reason names the hook" "$TL_ERR" "blocked this call (exit 2)"
mk_script askjson 'cat >/dev/null; echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"ask\"}}"'
write_hooks "$(jq -cn --argjson h "$(cmd_of askjson)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_bridge tool.before '{"command":"echo hi"}' r-ask
assert_eq "permissionDecision ask blocks (fail closed)" "2" "$TL_STATUS"
assert_contains "ask has a default reason" "$TL_ERR" "requires approval"
mk_script noisyjson 'cat >/dev/null; echo "banner text"; echo "{\"decision\":\"block\",\"reason\":\"noisy block\"}"'
write_hooks "$(jq -cn --argjson h "$(cmd_of noisyjson)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_bridge tool.before '{"command":"echo hi"}' r-noisy
assert_eq "noisy stdout: last-line JSON block honoured" "2" "$TL_STATUS"
assert_contains "noisy stdout reason" "$TL_ERR" "noisy block"
mk_script blanknoise 'cat >/dev/null; echo "just text"'
write_hooks "$(jq -cn --argjson h "$(cmd_of blanknoise)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_bridge tool.before '{"command":"echo hi"}' r-text
assert_eq "plain text stdout is not a block" "0" "$TL_STATUS"

# R7-04: hooks run under a non-login shell: a login profile that prints or
# exits cannot disable a gate.
PROFILE_HOME="$TL_TMP/profilehome"
mkdir -p "$PROFILE_HOME"
write_hooks "$(jq -cn --argjson h "$(cmd_of denyjson)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
for profile_body in 'echo "Welcome back"' 'exit 0'; do
  printf '%s\n' "$profile_body" >"$PROFILE_HOME/.bash_profile"
  cp "$PROFILE_HOME/.bash_profile" "$PROFILE_HOME/.profile"
  tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="$4" CODE_HOOK_SOURCE_CALL_ID=prof bash "$5"' \
    _ "$WORK" "$PROFILE_HOME" "$PLUG" '{"command":"echo hi"}' "$BRIDGE"
  assert_eq "profile [$profile_body] cannot disable the deny" "2" "$TL_STATUS"
  assert_contains "profile [$profile_body]: reason kept" "$TL_ERR" "json deny reason"
done

# R7-03: every path of a multi-file write is gated, not just the first.
mk_script protect 'p="$(cat)"; case "$p" in *PROTECTED*) echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"protected path\"}}";; esac'
write_hooks "$(jq -cn --argjson h "$(cmd_of protect)" '{hooks:{PreToolUse:[{matcher:"Write|Edit|MultiEdit|apply_patch",hooks:[$h]}]}}')"
run_bridge file.before_write '{"changes":[{"path":"/x/PROTECTED.md"}]}' mf1
assert_eq "single protected path denied" "2" "$TL_STATUS"
run_bridge file.after_write '{}' mf1
run_bridge file.before_write '{"changes":[{"path":"/x/ok.md"},{"path":"/x/PROTECTED.md"}]}' mf2
assert_eq "protected SECOND path is denied" "2" "$TL_STATUS"
assert_contains "multi-file deny reason surfaced" "$TL_ERR" "protected path"
run_bridge file.after_write '{}' mf2
run_bridge file.before_write '{"changes":[{"path":"/x/a.md"},{"path":"/x/b.md"},{"path":"/x/a.md"}]}' mf3
assert_eq "all-clean multi-file write allowed" "0" "$TL_STATUS"

# R7-03 (r1): every path-like key of a change is gated, so the DESTINATION of a
# rename or move cannot hide a protected file behind a harmless source path.
for key in path filePath file_path new_path newPath move_path movePath old_path from_path to_path destination dest target_path targetPath; do
  run_bridge file.before_write "$(jq -cn --arg k "$key" '{changes:[{path:"/x/ok.md",($k):"/x/PROTECTED.md"}]}')" "key-$key"
  assert_eq "ok.md -> PROTECTED.md via [$key] is denied" "2" "$TL_STATUS"
  run_bridge file.after_write '{}' "key-$key"
done
run_bridge file.before_write '{"changes":[{"path":"/x/a.md","new_path":"/x/b.md"},{"filePath":"/x/c.md","destination":"/x/d.md"}]}' keys-clean
assert_eq "a rename between clean paths is allowed" "0" "$TL_STATUS"
run_bridge file.before_write '{"changes":[{"path":7,"new_path":""},{"path":"/x/PROTECTED.md"}]}' keys-weird
assert_eq "non-string and empty path values are ignored, later change still gated" "2" "$TL_STATUS"
run_bridge file.after_write '{}' keys-weird

# the matched hook list is cached per (event, tool): a 20-path write costs the
# same number of matching lookups as a 1-path write.
REAL_PY="$(command -v python3)"
MATCH_LOG="$TL_TMP/match-calls.log"
tl_stub python3 "case \"\$2\" in */hooks.json) echo m >>\"$MATCH_LOG\";; esac; exec $REAL_PY \"\$@\""
mk_script allowall 'cat >/dev/null'
write_hooks "$(jq -cn --argjson h "$(cmd_of allowall)" '{hooks:{PreToolUse:[{matcher:"Write|Edit|MultiEdit|apply_patch",hooks:[$h]}]}}')"
: >"$MATCH_LOG"
run_bridge file.before_write '{"changes":[{"path":"/x/1"}]}' cnt1
one_path_calls="$(wc -l <"$MATCH_LOG" | tr -d ' ')"
: >"$MATCH_LOG"
many="$(jq -cn '{changes:[range(0;20) | {path:("/x/f\(.)")}]}')"
run_bridge file.before_write "$many" cnt20
twenty_path_calls="$(wc -l <"$MATCH_LOG" | tr -d ' ')"
assert_eq "matching lookups do not scale with path count" "$one_path_calls" "$twenty_path_calls"
assert_eq "four tool aliases looked up once each" "4" "$twenty_path_calls"
rm -f "${TL_BIN:?}/python3"

# a banner before a pretty-printed multi-line deny is still a deny
mk_script prettydeny 'cat >/dev/null; echo "banner"; echo "{\"decision\":\"block\",\"reason\":\"pretty reason\"}" | jq .'
write_hooks "$(jq -cn --argjson h "$(cmd_of prettydeny)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_bridge tool.before '{"command":"echo hi"}' r-pretty
assert_eq "banner + pretty multi-line JSON deny is honoured" "2" "$TL_STATUS"
assert_contains "pretty deny reason" "$TL_ERR" "pretty reason"

# R7-05 (documented limit): Kay has no Stop/UserPromptSubmit gating
# (docs/RUNTIME-COMPATIBILITY.md, "Kay limits"). session.end runs no hooks, so a
# Stop block is not enforced. session.start runs the SessionStart hooks for their
# side effects only (branch-state reset): their output and decision are ignored.
write_hooks "$(jq -cn --argjson h "$(cmd_of dump)" --argjson b "$(cmd_of blockjson)" '{hooks:{SessionStart:[{matcher:"startup|clear|compact",hooks:[$b,$h]}],Stop:[{matcher:".*",hooks:[$b,$h]}]}}')"
rm -f "$TL_TMP_DUMP"
run_bridge session.start '{}' lim1
assert_eq "session.start never blocks, even when a SessionStart hook says block" "0" "$TL_STATUS"
assert_eq "session.start runs the SessionStart hooks (source startup)" "startup" "$(jq -r .source "$TL_TMP_DUMP")"
rm -f "$TL_TMP_DUMP"
run_bridge session.end '{}' lim2
assert_eq "documented limit: a Stop block is not enforced on session.end" "0" "$TL_STATUS"
assert_file_absent "documented limit: no Stop hook runs on session.end" "$TL_TMP_DUMP"
write_hooks "$(jq -cn --argjson h "$(cmd_of denyjson)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"

# the first reason wins
write_hooks "$(jq -cn --argjson a "$(cmd_of deny2)" --argjson b "$(cmd_of blockjson)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$a,$b]}]}}')"
run_bridge tool.before '{"command":"echo hi"}' r-first
assert_contains "first blocking reason wins" "$TL_ERR" "stderr reason"
assert_not_contains "later reason ignored" "$TL_ERR" "block reason"

tl_results
