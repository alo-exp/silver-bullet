#!/usr/bin/env bash
# hooks/kay-project-hook-bridge.sh: helpers and best-effort steps that fail.
# mapping, hook matching/dedupe, denial blocks, restore and debug logging.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

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

BR="$BHOME/.kay/.silver-bullet/kay-hook-bridge"
REAL_PY="$(command -v python3)"
deny_hook() { write_hooks "$(jq -cn --argjson h "$(cmd_of "$1")" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}],PostToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"; }

dbg() { cat "$BR/debug/$1.log" 2>/dev/null || true; } # debug trace of a call (SB_KAY_HOOK_BRIDGE_DEBUG=1)
state_gone() { assert_file_absent "$1" "$BR/blocks/$2.state"; }

# ---- debug log that cannot be written -----------------------------------------
deny_hook count
rm -f "$TL_TMP_COUNT"
mkdir -p "$BR/debug/dbgdir.log"
SB_KAY_HOOK_BRIDGE_DEBUG=1 run_bridge tool.before '{"command":"ls"}' dbgdir
assert_eq "debug sink unwritable: bridge still allows" "0" "$TL_STATUS"
assert_eq "debug sink unwritable: quiet" "" "$TL_ERR"
assert_eq "debug sink unwritable: the hook still ran" "X" "$(cat "$TL_TMP_COUNT" 2>/dev/null)"

# ---- hook output that cannot be parsed for a reason -----------------------------
deny_hook denyjson
ec_fail jq '*"permissionDecision"*'
SB_KAY_HOOK_BRIDGE_DEBUG=1 run_bridge tool.before '{"command":"echo hi"}' badreason
ec_unfail jq
assert_eq "unparsable hook output: no reason, call allowed" "0" "$TL_STATUS"
assert_contains "unparsable hook output: the hook ran and was seen to exit 0 without a reason" "$(dbg badreason)" "hook_status=0 hook_reason="
assert_not_contains "unparsable hook output: nothing was blocked" "$(dbg badreason)" "block_reason="

# ---- matching helper yielding nothing / an empty command --------------------------
deny_hook deny2
tl_stub python3 "case \"\$2\" in *hooks.json) exit 0;; esac; exec $REAL_PY \"\$@\""
SB_KAY_HOOK_BRIDGE_DEBUG=1 run_bridge tool.before '{"command":"echo hi"}' nomatch
assert_eq "matching helper printed nothing: treated as no hooks" "0" "$TL_STATUS"
assert_contains "matching helper printed nothing: an empty hook list was used" "$(dbg nomatch)" "hooks=[]"
assert_not_contains "matching helper printed nothing: no hook ran" "$(dbg nomatch)" "hook_command="
tl_stub python3 "case \"\$2\" in *hooks.json) echo '[{\"command\":\"\"}]'; exit 0;; esac; exec $REAL_PY \"\$@\""
SB_KAY_HOOK_BRIDGE_DEBUG=1 run_bridge tool.before '{"command":"echo hi"}' emptycmd
assert_eq "empty hook command skipped" "0" "$TL_STATUS"
assert_contains "empty hook command skipped: the match was listed" "$(dbg emptycmd)" "matched_hooks tool=Bash"
assert_not_contains "empty hook command skipped: nothing was executed" "$(dbg emptycmd)" "hook_command="
ec_unfail python3
ec_fail jq '*"-c"*'
SB_KAY_HOOK_BRIDGE_DEBUG=1 run_bridge tool.before '{"command":"echo hi"}' nojq
ec_unfail jq
assert_eq "hook list that cannot be iterated: allowed" "0" "$TL_STATUS"
assert_contains "hook list that cannot be iterated: matching was reached" "$(dbg nojq)" "matched_hooks tool=Bash"
assert_not_contains "hook list that cannot be iterated: no hook ran" "$(dbg nojq)" "hook_command="

# ---- write-target helpers failing / script bodies ------------------------------------
PLUG2="$TL_TMP/plugin2"
mkdir -p "$PLUG2/hooks/lib"
for f in "$TL_REPO_ROOT"/hooks/lib/*; do ln -s "$f" "$PLUG2/hooks/lib/${f##*/}"; done
rm -f "$PLUG2/hooks/lib/tool-input.sh"
SCRIPT="$WORK/body.sh"
printf '#!/usr/bin/env bash\necho x\n' >"$SCRIPT"
cat >"$PLUG2/hooks/lib/tool-input.sh" <<EOF
sb_tool_command_string() { jq -r '.tool_input.command | if type == "array" then join(" ") else . end' <<<"\$1"; }
sb_shell_invoked_script_path() { printf '%s' "$SCRIPT"; }
sb_shell_candidate_write_paths() { return 1; }
EOF
cp "$PLUG/hooks/hooks.json" "$PLUG2/hooks/hooks.json"
run_bridge2() { # event payload call
  tl_run bash -c 'cd "$1" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT="$4" CODE_HOOK_PAYLOAD="$5" CODE_HOOK_SOURCE_CALL_ID="$6" bash "$7"' _ "$WORK" "$BHOME" "$PLUG2" "$1" "$2" "$3" "$BRIDGE"
}
deny_hook deny2
write_hooks "$(cat "$PLUG/hooks/hooks.json")"
cp "$PLUG/hooks/hooks.json" "$PLUG2/hooks/hooks.json"
run_bridge2 tool.before '{"command":"bash body.sh"}' helperfail
assert_eq "candidate-path helper failing: still denied" "2" "$TL_STATUS"
assert_contains "candidate-path helper failing: with the hook's reason" "$TL_ERR" "stderr reason"
run_bridge2 tool.after '{"command":"x"}' helperfail
assert_eq "candidate-path helper failing: the after-hook exits 0" "0" "$TL_STATUS"
state_gone "candidate-path helper failing: block state restored" helperfail
ec_fail cat '*"body.sh"*'
run_bridge2 tool.before '{"command":"bash body.sh"}' catfail
ec_unfail cat
assert_eq "script body unreadable: still denied" "2" "$TL_STATUS"
assert_contains "script body unreadable: with the hook's reason" "$TL_ERR" "stderr reason"
run_bridge2 tool.after '{"command":"x"}' catfail
assert_eq "script body unreadable: the after-hook exits 0" "0" "$TL_STATUS"
state_gone "script body unreadable: block state restored" catfail
sed -i 's|^sb_shell_invoked_script_path() .*|sb_shell_invoked_script_path() { return 1; }|' "$PLUG2/hooks/lib/tool-input.sh"
run_bridge2 tool.before '{"command":"bash body.sh"}' nopath
assert_eq "script path lookup failing: still denied" "2" "$TL_STATUS"
assert_contains "script path lookup failing: with the hook's reason" "$TL_ERR" "stderr reason"
run_bridge2 tool.after '{"command":"x"}' nopath
assert_eq "script path lookup failing: the after-hook exits 0" "0" "$TL_STATUS"
state_gone "script path lookup failing: block state restored" nopath

# ---- failures while building shims / debug text ------------------------------------------
ec_fail tr '*"|"*'
run_bridge tool.before '{"command":"echo hi"}' trfail
ec_unfail tr
assert_eq "debug text builder failing: still denied" "2" "$TL_STATUS"
assert_contains "debug text builder failing: with the hook's reason" "$TL_ERR" "stderr reason"
run_bridge tool.after '{"command":"x"}' trfail
assert_eq "debug text builder failing: the after-hook exits 0" "0" "$TL_STATUS"
state_gone "debug text builder failing: block state restored" trfail
ec_fail mkdir '*"path-prepend/active"*'
run_bridge tool.before '{"command":"echo hi"}' shimfail
ec_unfail mkdir
assert_eq "shim directory cannot be created: still denied" "2" "$TL_STATUS"
assert_contains "shim directory cannot be created: with the hook's reason" "$TL_ERR" "stderr reason"
run_bridge tool.after '{"command":"x"}' shimfail
assert_eq "shim directory cannot be created: the after-hook exits 0" "0" "$TL_STATUS"
state_gone "shim directory cannot be created: block state restored" shimfail

# ---- file write denial with unreadable path / shim failure ---------------------------------
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Write",hooks:[$h]}]}}')"
ec_fail jq '*"tool_input.file_path"*'
run_bridge file.before_write '{"changes":[{"path":"/tmp/x"}]}' fwnojq
ec_unfail jq
assert_eq "file path unreadable: still denied" "2" "$TL_STATUS"
assert_contains "file path unreadable: with the hook's reason" "$TL_ERR" "stderr reason"
printf 'doc' >"$WORK/doc2.txt"
ec_fail mkdir '*"path-prepend/active"*'
run_bridge file.before_write "$(jq -cn --arg p "$WORK/doc2.txt" '{changes:[{path:$p}]}')" fwshim
ec_unfail mkdir
assert_eq "file write denial with shim failure: still denied" "2" "$TL_STATUS"
assert_contains "file write denial with shim failure: with the hook's reason" "$TL_ERR" "stderr reason"
run_bridge file.after_write '{}' fwshim
assert_eq "file write denial with shim failure: the after-write hook exits 0" "0" "$TL_STATUS"
state_gone "file write denial with shim failure: block state restored" fwshim

# ---- restore with a failing chflags ----------------------------------------------------------
deny_hook deny2
tl_stub chflags 'if [[ "$1" == "nouchg" ]]; then exit 1; fi; exit 0'
printf 'data' >"$WORK/locked.txt"
run_bridge tool.before "$(jq -cn --arg c "touch $WORK/locked.txt" '{command:$c}')" chfail
run_bridge tool.after '{"command":"x"}' chfail
ec_unfail chflags
assert_eq "failing chflags nouchg on restore is tolerated" "0" "$TL_STATUS"
assert_file_absent "state removed after restore" "$BR/blocks/chfail.state"

tl_results
