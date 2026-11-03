#!/usr/bin/env bash
# Path coverage for hooks/phase-archive.sh (archive phases before `phases clear`; fails closed).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/phase-archive.sh
P="$TL_TMP/proj"
bash_json() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
fresh() {
  rm -rf "$P"
  dg_project "$P"
  mkdir -p "$P/.planning/phases/001-a" "$P/.planning/phases/002-b"
  echo one >"$P/.planning/phases/001-a/PLAN.md"
  echo two >"$P/.planning/phases/002-b/PLAN.md"
  printf '# Project\n\nCurrent Milestone: V2 Launch (Beta)\n' >"$P/.planning/PROJECT.md"
}
CLEAR='node ladder-tools.cjs phases clear'
fresh

dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "archive: exits 0" 0 "$TL_STATUS"
assert_contains "archive: reports the copy" "$TL_OUT" "copied phases to .planning/archive/v2-launch-beta/"
assert_eq "archive: phase 1 copied" "one" "$(cat "$P/.planning/archive/v2-launch-beta/001-a/PLAN.md")"
assert_eq "archive: phase 2 copied" "two" "$(cat "$P/.planning/archive/v2-launch-beta/002-b/PLAN.md")"
assert_file_exists "archive: originals untouched" "$P/.planning/phases/001-a/PLAN.md"

dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "archive: identical phases are not copied twice" "$TL_OUT" "already preserved"
assert_eq "archive: the notice is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
echo changed >"$P/.planning/phases/001-a/PLAN.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "archive: prior archive content preserved" "one" "$(cat "$P/.planning/archive/v2-launch-beta/001-a/PLAN.md")"
assert_contains "archive: changed phases go to a new snapshot" "$TL_OUT" "archive/v2-launch-beta/snapshot-"
assert_eq "archive: the snapshot holds the changed phase" "changed" "$(cat "$P"/.planning/archive/v2-launch-beta/snapshot-*/001-a/PLAN.md)"

fresh
dg_run "$P" "$H" "$(bash_json 'ls -la')"
assert_eq "other commands pass silently" "" "$TL_OUT"
dg_assert_ok "other commands pass silently: exits 0"
assert_file_absent "other commands archive nothing" "$P/.planning/archive"
dg_run "$P" "$H" "$(bash_json '')"
assert_eq "empty command ignored" "" "$TL_OUT"
dg_assert_ok "empty command ignored: exits 0"
dg_run "$P" "$H" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{file_path:"/x"}}')"
assert_eq "non-shell tool ignored" "" "$TL_OUT"
dg_assert_ok "non-shell tool ignored: exits 0"
assert_file_absent "non-shell tool archives nothing" "$P/.planning/archive"

mkdir -p "$TL_TMP/outside"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
dg_run "$TL_TMP/outside" "$H" "$(bash_json "$CLEAR")"
assert_eq "outside an SB project nothing happens" "" "$TL_OUT"
dg_assert_ok "outside an SB project nothing happens: exits 0"

dg_run_nojq "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "no jq: phases clear is denied (fail closed)" "deny" "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
assert_contains "no jq: static reason" "$TL_OUT" "jq required for Silver Bullet enforcement"
assert_eq "no jq: hook itself exits 0" 0 "$TL_STATUS"
assert_file_absent "no jq: nothing archived" "$P/.planning/archive"
dg_run_nojq "$P" "$H" "$(bash_json 'ls -la')"
assert_eq "no jq: unrelated command is not denied" "" "$TL_OUT"
dg_assert_ok "no jq: unrelated command is not denied: exits 0"
assert_eq "no jq: unrelated command exits 0" 0 "$TL_STATUS"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
dg_run_nojq "$TL_TMP/outside" "$H" "$(bash_json "$CLEAR")"
assert_eq "no jq outside an SB project: inert" "" "$TL_OUT"
dg_assert_ok "no jq outside an SB project: inert: exits 0"
assert_eq "no jq outside an SB project: exits 0" 0 "$TL_STATUS"

rm -f "$P/.planning/PROJECT.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "no PROJECT.md: archived under unnamed-milestone" "$TL_OUT" "archive/unnamed-milestone/"
assert_file_exists "no PROJECT.md: the phases are preserved" "$P/.planning/archive/unnamed-milestone/001-a/PLAN.md"
rm -rf "$P/.planning/archive"
printf '# Project\n' >"$P/.planning/PROJECT.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "no milestone line: archived under unnamed-milestone" "$TL_OUT" "archive/unnamed-milestone/"
rm -rf "$P/.planning/archive"
printf 'Current Milestone: !!!\n' >"$P/.planning/PROJECT.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "milestone slug empty after sanitising: unnamed-milestone" "$TL_OUT" "archive/unnamed-milestone/"
assert_file_absent "an unsafe milestone slug never becomes a path" "$P/.planning/archive/!!!"

fresh
rm -rf "$P/.planning/phases"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "no phases dir: nothing to archive" "" "$TL_OUT"
dg_assert_ok "no phases dir: nothing to archive: exits 0"
mkdir -p "$P/.planning/phases"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "empty phases dir: nothing to archive" "" "$TL_OUT"
dg_assert_ok "empty phases dir: nothing to archive: exits 0"
echo f >"$P/.planning/phases/notes.txt"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "phases dir with only files: reports success" "$TL_OUT" "copied phases"
rm -rf "$P/.planning/archive"
assert_eq "files-only phases dir: no phase dirs copied" "" "$(ls -A "$P/.planning/archive/v2-launch-beta")"

# fail closed when the copy fails
fresh
tl_stub cp 'exit 1'
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
rm -f "$TL_BIN/cp"
assert_eq "copy failure: deny decision" "deny" "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
assert_contains "copy failure: reason" "$TL_OUT" "blocking clear to prevent data loss"
assert_eq "copy failure: hook itself exits 0" 0 "$TL_STATUS"

# R2-21: only a real invocation archives; prose that mentions the phrase does not
fresh
dg_run "$P" "$H" "$(bash_json 'git commit -m "docs: explain phases clear"')"
assert_eq "a commit message mentioning phases clear archives nothing" "" "$TL_OUT"
assert_file_absent "a commit message creates no archive files" "$P/.planning/archive"
dg_run "$P" "$H" "$(bash_json 'echo phases clear')"
assert_eq "echo phases clear archives nothing" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json 'grep -rn "phases clear" docs')"
assert_eq "grep for phases clear archives nothing" "" "$TL_OUT"
assert_file_absent "prose creates no archive files" "$P/.planning/archive"
dg_run "$P" "$H" "$(bash_json 'cd . && node tools/gt.cjs phases clear --raw')"
assert_contains "a chained real invocation is archived" "$TL_OUT" "copied phases"
rm -rf "$P/.planning/archive"
dg_run "$P" "$H" "$(jq -cn --arg c "$CLEAR" '{hook_event_name:"PreToolUse",tool_name:"exec_command",tool_input:{cmd:$c}}')"
assert_contains "exec_command is covered" "$TL_OUT" "copied phases"
rm -rf "$P/.planning/archive"
# paths come from the project root, not the cwd
mkdir -p "$P/sub/deeper"
dg_run "$P/sub/deeper" "$H" "$(bash_json "$CLEAR")"
assert_file_exists "run from a subdirectory: archived at the project root" "$P/.planning/archive/v2-launch-beta/001-a/PLAN.md"
rm -rf "$P/.planning/archive"
# deleting the whole phases directory is the same loss
dg_run "$P" "$H" "$(bash_json 'rm -rf .planning/phases')"
assert_contains "rm -rf .planning/phases is archived first" "$TL_OUT" "copied phases"
rm -rf "$P/.planning/archive"
dg_run "$P" "$H" "$(bash_json 'rm -rf .planning')"
assert_contains "rm -rf .planning is archived first" "$TL_OUT" "copied phases"
rm -rf "$P/.planning/archive"
dg_run "$P" "$H" "$(bash_json 'rm -rf .planning/phases/001-a')"
assert_eq "deleting a single phase is not a clear" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json 'rm -rf build')"
assert_eq "deleting something else is not a clear" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json 'ls .planning/phases')"
assert_eq "listing the phases is not a clear" "" "$TL_OUT"
# a write that is not a delete is not a clear
fresh
dg_run "$P" "$H" "$(bash_json 'echo x > notes.txt')"
assert_eq "an ordinary write is not a clear" "" "$TL_OUT"
assert_file_absent "an ordinary write archives nothing" "$P/.planning/archive"
# an earlier snapshot already holds an identical phase
fresh
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
echo changed >"$P/.planning/phases/001-a/PLAN.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "the changed phase went to a snapshot" "$TL_OUT" "snapshot-"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "identical phases are found in the snapshot too" "$TL_OUT" "already preserved"
# files only under phases/, with an archive already present
fresh
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
rm -rf "$P/.planning/phases"; mkdir -p "$P/.planning/phases"; echo f >"$P/.planning/phases/notes.txt"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "files only plus an archive: nothing new to copy" "$TL_OUT" "already preserved"
fresh

# python3 missing / unparsable command
dg_run "$P" "$H" "$(bash_json "$CLEAR")" PATH="$(tl_path_without python3)"
assert_eq "no python3: deny" deny "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
assert_contains "no python3: the reason says how to proceed" "$TL_OUT" "python3"
assert_file_absent "no python3: nothing archived" "$P/.planning/archive"
dg_run "$P" "$H" "$(bash_json "ls")" PATH="$(tl_path_without python3)"
assert_eq "no python3: an unrelated command is untouched" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json "cat .planning/phases/phases-clear.md")" PATH="$(tl_path_without python3)"
assert_eq "no python3: a plainly read-only command is untouched" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json "echo 'phases clear")"
assert_eq "an unparsable command that mentions the words is denied" deny "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
dg_run "$TL_TMP/outside" "$H" "$(bash_json "echo 'phases clear")"
assert_eq "an unparsable command outside an SB project is untouched" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json "echo 'only one word")"
assert_eq "an unparsable command that does not mention the words is untouched" "" "$TL_OUT"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":""}}'
assert_eq "an empty command is untouched" "" "$TL_OUT"

tl_results
