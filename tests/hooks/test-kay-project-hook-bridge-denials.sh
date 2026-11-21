#!/usr/bin/env bash
# hooks/kay-project-hook-bridge.sh: denial filesystem blocks, shims and restore.
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

# ---- filesystem block on denial, then restore -------------------------------
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}],PostToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
mkdir -p "$WORK/dir"
printf 'data' >"$WORK/dir/f.txt"
chmod 755 "$WORK/dir"
chmod 644 "$WORK/dir/f.txt"
run_bridge tool.before "$(jq -cn --arg c "touch $WORK/dir/f.txt" '{command:$c}')" fsblock
assert_eq "denied write command: status 2" "2" "$TL_STATUS"
assert_file_exists "state file recorded" "$BR/blocks/fsblock.state"
assert_eq "target made read-only" "444" "$(stat -c %a "$WORK/dir/f.txt")"
assert_eq "parent directory made read-only" "555" "$(stat -c %a "$WORK/dir")"
assert_file_exists "rm shim installed" "$ACTIVE/rm"
shim_rc=0
shim_err="$(bash "$ACTIVE/rm" 2>&1 >/dev/null)" || shim_rc=$?
assert_eq "shim exits 2" "2" "$shim_rc"
assert_eq "shim prints the reason" "stderr reason" "$shim_err"
assert_contains "state lists the shim dir" "$(cat "$BR/blocks/fsblock.state")" "SHIMDIR"
run_bridge tool.after '{"command":"touch x"}' fsblock
assert_eq "target mode restored" "644" "$(stat -c %a "$WORK/dir/f.txt")"
assert_eq "parent mode restored" "755" "$(stat -c %a "$WORK/dir")"
assert_file_absent "shim dir removed" "$ACTIVE"
assert_file_absent "state file removed" "$BR/blocks/fsblock.state"
run_bridge tool.after '{"command":"touch x"}' fsblock
assert_eq "restore without state is a no-op" "0" "$TL_STATUS"

# per-call shim dir when the legacy fallback is off
SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK=0 run_bridge tool.before "$(jq -cn --arg c "touch $WORK/dir/f.txt" '{command:$c}')" percall
assert_file_exists "per-call shim dir" "$BHOME/.kay/.silver-bullet/path-prepend/percall/rm"
run_bridge tool.after '{"command":"touch x"}' percall
assert_file_absent "per-call shim dir removed on restore" "$BHOME/.kay/.silver-bullet/path-prepend/percall"

# script bodies and git commits add write targets
printf '#!/usr/bin/env bash\necho x > %s/dir/out.txt\n' "$WORK" >"$WORK/writer.sh"
chmod +x "$WORK/writer.sh"
run_bridge tool.before "$(jq -cn '{command:"bash writer.sh"}')" script
assert_eq "script invocation: status 2" "2" "$TL_STATUS"
assert_contains "script write target locked" "$(cat "$BR/blocks/script.state")" "$WORK/dir"
run_bridge tool.after '{"command":"x"}' script
run_bridge tool.before "$(jq -cn '{command:"git commit -m x"}')" gitc
assert_contains "git commit locks the git dir" "$(cat "$BR/blocks/gitc.state")" "$WORK/.git"
run_bridge tool.after '{"command":"x"}' gitc
assert_file_absent "git dir state restored" "$BR/blocks/gitc.state"
mkdir -p "$WORK/sub"
tl_run bash -c 'cd "$1/sub" && exec env HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT=tool.before CODE_HOOK_PAYLOAD="$4" CODE_HOOK_SOURCE_CALL_ID=gitrel bash "$5"' _ "$WORK" "$BHOME" "$PLUG" '{"command":"cd . && git commit -m x"}' "$BRIDGE"
assert_contains "git commit from a subdirectory locks the repo git dir" "$(cat "$BR/blocks/gitrel.state")" "$WORK/.git"
run_bridge tool.after '{"command":"x"}' gitrel

# no write target: entry-command shim instead
for spec in "myspecialtool --flag:myspecialtool" "bash -lc 'othertool x':othertool" "env FOO=1 bash -c 'envtool y':envtool" "FOO=1 plain:plain"; do
  c="${spec%:*}"
  n="${spec##*:}"
  run_bridge tool.before "$(jq -cn --arg c "$c" '{command:$c}')" "entry-$n"
  assert_file_exists "entry command shim for $n" "$ACTIVE/$n"
  run_bridge tool.after '{"command":"x"}' "entry-$n"
done
for c in "bash" "bash -c" "env" "FOO=1" "bash -c ''" "bash -lc 'nested'"; do
  run_bridge tool.before "$(jq -cn --arg c "$c" '{command:$c}')" entry-none
  assert_eq "no entry shim for [$c]: still denied" "2" "$TL_STATUS"
  run_bridge tool.after '{"command":"x"}' entry-none
done
assert_file_absent "no stray shim for shell names" "$ACTIVE/bash"

# chflags-capable hosts record and release immutability
tl_stub chflags 'echo "$*" >>"$TL_TMP_CHFLAGS"'
: >"$TL_TMP_CHFLAGS"
run_bridge tool.before "$(jq -cn --arg c "touch $WORK/dir/f.txt" '{command:$c}')" imm
assert_contains "chflags uchg applied" "$(cat "$TL_TMP_CHFLAGS")" "uchg"
assert_contains "state records IMMUTABLE" "$(cat "$BR/blocks/imm.state")" "IMMUTABLE"
run_bridge tool.after '{"command":"x"}' imm
assert_contains "chflags nouchg on restore" "$(cat "$TL_TMP_CHFLAGS")" "nouchg"
rm -f "${TL_BIN:?}/chflags"
# blank state lines are skipped on restore
printf '\n' >"$BR/blocks/blank.state"
run_bridge tool.after '{"command":"x"}' blank
assert_file_absent "blank-only state restored" "$BR/blocks/blank.state"

# file.before_write denial
printf 'doc' >"$WORK/doc.txt"
chmod 644 "$WORK/doc.txt"
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Write",hooks:[$h]}]}}')"
run_bridge file.before_write "$(jq -cn --arg p "$WORK/doc.txt" '{changes:[{newPath:$p}]}')" fw
assert_eq "file write denied" "2" "$TL_STATUS"
assert_eq "written file locked" "444" "$(stat -c %a "$WORK/doc.txt")"
run_bridge file.after_write '{}' fw
assert_eq "written file unlocked" "644" "$(stat -c %a "$WORK/doc.txt")"
run_bridge file.before_write '{"changes":[]}' fw-empty
assert_eq "file write denial without a path still denies" "2" "$TL_STATUS"
assert_file_absent "no state for an empty path" "$BR/blocks/fw-empty.state"
run_bridge file.before_write "$(jq -cn --arg p "$WORK/not-yet/new.txt" '{changes:[{path:$p}]}')" fw-missing
assert_eq "missing target and parent: still denied" "2" "$TL_STATUS"

# R7-06: a denial whose tool.after never arrives does not leave the project
# read-only: session.start/session.end restore every stale state (newest first)
# and remove the shared shim dir.
printf 'x' >"$WORK/dir/stale.txt"
chmod 644 "$WORK/dir/stale.txt"
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
run_bridge tool.before "$(jq -cn --arg c "touch $WORK/dir/stale.txt" '{command:$c}')" stale1
run_bridge tool.before "$(jq -cn --arg c "touch $WORK/dir/stale.txt" '{command:$c}')" stale2
assert_eq "stale denial left the file locked" "444" "$(stat -c %a "$WORK/dir/stale.txt")"
assert_eq "stale denial left the parent locked" "555" "$(stat -c %a "$WORK/dir")"
run_bridge session.start '{}' fresh-session
assert_eq "session.start restores the stale file mode" "644" "$(stat -c %a "$WORK/dir/stale.txt")"
assert_eq "session.start restores the stale parent mode" "755" "$(stat -c %a "$WORK/dir")"
assert_eq "session.start empties blocks/" "" "$(ls "$BR/blocks")"
assert_file_absent "session.start removes the shim dir" "$ACTIVE"
run_bridge tool.before "$(jq -cn --arg c "touch $WORK/dir/stale.txt" '{command:$c}')" stale3
run_bridge session.end '{}' fresh-end
assert_eq "session.end also restores" "755" "$(stat -c %a "$WORK/dir")"
assert_file_absent "session.end removes the shim dir" "$ACTIVE"

# a leftover shim dir with no state file is removed on session.start too
mkdir -p "$ACTIVE"
run_bridge session.start '{}' fresh-orphan
assert_file_absent "orphan shim dir removed on session.start" "$ACTIVE"

# a file write denial locks only the target, never its parent directory
printf 'doc' >"$WORK/dir/exact.txt"
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Write",hooks:[$h]}]}}')"
run_bridge file.before_write "$(jq -cn --arg p "$WORK/dir/exact.txt" '{changes:[{path:$p}]}')" exact1
assert_eq "exact: target locked" "444" "$(stat -c %a "$WORK/dir/exact.txt")"
assert_eq "exact: parent directory untouched" "755" "$(stat -c %a "$WORK/dir")"
# every path of a multi-file denial is locked
printf 'a' >"$WORK/dir/m1.txt"; printf 'b' >"$WORK/dir/m2.txt"
run_bridge file.before_write "$(jq -cn --arg a "$WORK/dir/m1.txt" --arg b "$WORK/dir/m2.txt" '{changes:[{path:$a},{path:$b}]}')" multi1
assert_eq "multi-file denial locks the first path" "444" "$(stat -c %a "$WORK/dir/m1.txt")"
assert_eq "multi-file denial locks the second path" "444" "$(stat -c %a "$WORK/dir/m2.txt")"
run_bridge session.start '{}' fresh2
assert_eq "stale multi-file locks restored" "644" "$(stat -c %a "$WORK/dir/m2.txt")"
assert_eq "stale exact lock restored" "644" "$(stat -c %a "$WORK/dir/exact.txt")"

# R7-06 (r1): a repeated call id (including the shared "hook" fallback) never
# drops earlier restore records. State files are append-only.
printf 'a' >"$WORK/dir/ra.txt"; printf 'b' >"$WORK/dir/rb.txt"
chmod 644 "$WORK/dir/ra.txt" "$WORK/dir/rb.txt"
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Write",hooks:[$h]}]}}')"
tl_run_nocall() { # event payload: no CODE_HOOK_SOURCE_CALL_ID at all
  tl_run bash -c 'cd "$1" && exec env -u CODE_HOOK_SOURCE_CALL_ID -u CODE_HOOK_CALL_ID HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT="$4" CODE_HOOK_PAYLOAD="$5" bash "$6"' _ "$WORK" "$BHOME" "$PLUG" "$1" "$2" "$BRIDGE"
}
tl_run_nocall file.before_write "$(jq -cn --arg p "$WORK/dir/ra.txt" '{changes:[{path:$p}]}')"
tl_run_nocall file.before_write "$(jq -cn --arg p "$WORK/dir/rb.txt" '{changes:[{path:$p}]}')"
assert_eq "no call id: both files locked" "444 444" "$(stat -c '%a' "$WORK/dir/ra.txt") $(stat -c '%a' "$WORK/dir/rb.txt")"
run_bridge session.start '{}' fresh-nocall
assert_eq "no call id: both restored by session.start" "644 644" "$(stat -c '%a' "$WORK/dir/ra.txt") $(stat -c '%a' "$WORK/dir/rb.txt")"
# the same path denied twice with the same id
run_bridge file.before_write "$(jq -cn --arg p "$WORK/dir/ra.txt" '{changes:[{path:$p}]}')" same
run_bridge file.before_write "$(jq -cn --arg p "$WORK/dir/ra.txt" '{changes:[{path:$p}]}')" same
run_bridge session.end '{}' fresh-same
assert_eq "same path denied twice is restored to the original mode" "644" "$(stat -c %a "$WORK/dir/ra.txt")"
run_bridge file.before_write "$(jq -cn --arg p "$WORK/dir/ra.txt" '{changes:[{path:$p}]}')" same2
run_bridge file.before_write "$(jq -cn --arg p "$WORK/dir/ra.txt" '{changes:[{path:$p}]}')" same2
run_bridge file.after_write '{}' same2
assert_eq "tool.after/after_write restores a twice-denied path" "644" "$(stat -c %a "$WORK/dir/ra.txt")"
# two denied git commits with no call id leave nothing read-only
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[$h]}]}}')"
mkdir -p "$WORK/gdir"; git -C "$WORK/gdir" init -q
GITC="$(jq -cn '{command:"git commit -m x"}')"
gitc_run() { tl_run bash -c 'cd "$1/gdir" && exec env -u CODE_HOOK_SOURCE_CALL_ID -u CODE_HOOK_CALL_ID HOME="$2" CLAUDE_PLUGIN_ROOT="$3" CODE_HOOK_EVENT="$4" CODE_HOOK_PAYLOAD="$5" bash "$6"' _ "$WORK" "$BHOME" "$PLUG" "$1" "$2" "$BRIDGE"; }
gitc_run tool.before "$GITC"
gitc_run tool.before "$GITC"
gitc_run tool.after '{"command":"x"}'
assert_eq "two denied git commits: .git restored by tool.after" "755" "$(stat -c %a "$WORK/gdir/.git")"
assert_eq "two denied git commits: repo dir restored" "755" "$(stat -c %a "$WORK/gdir")"
gitc_run tool.before "$GITC"
gitc_run tool.before "$GITC"
run_bridge session.start '{}' fresh-git
assert_eq "two denied git commits: restored by session.start" "755" "$(stat -c %a "$WORK/gdir/.git")"
assert_eq "no state left behind" "" "$(ls "$BR/blocks")"

# the state record is written before the path is changed: a path whose mode
# cannot be changed (a /proc file raises EPERM even for root) keeps its record,
# the deny still goes out, and the restore tolerates the same failure.
write_hooks "$(jq -cn --argjson h "$(cmd_of deny2)" '{hooks:{PreToolUse:[{matcher:"Write",hooks:[$h]}]}}')"
if [[ -r /proc/self/status ]]; then
  run_bridge file.before_write '{"changes":[{"path":"/proc/self/status"}]}' chmodfail
  assert_eq "chmod failure: still denied" "2" "$TL_STATUS"
  assert_contains "record written before the change" "$(cat "$BR/blocks/chmodfail.state")" "/proc/"
  printf 'd' >"$WORK/dir/d.txt"
  run_bridge file.before_write "$(jq -cn --arg p "$WORK/dir/d.txt" '{changes:[{path:$p}]}')" chmodfail2
  run_bridge session.start '{}' fresh3
  assert_eq "restore survives an unrestorable path" "644" "$(stat -c %a "$WORK/dir/d.txt")"
  assert_eq "stale state with unrestorable path removed" "" "$(ls "$BR/blocks")"
fi

tl_results
