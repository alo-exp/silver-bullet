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
assert_contains "archive: existing archive is not overwritten" "$TL_OUT" "already exists"
echo changed >"$P/.planning/phases/001-a/PLAN.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "archive: prior archive content preserved" "one" "$(cat "$P/.planning/archive/v2-launch-beta/001-a/PLAN.md")"

fresh
dg_run "$P" "$H" "$(bash_json 'ls -la')"
assert_eq "other commands pass silently" "" "$TL_OUT"
assert_file_absent "other commands archive nothing" "$P/.planning/archive"
dg_run "$P" "$H" "$(bash_json '')"
assert_eq "empty command ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{file_path:"/x"}}')"
assert_eq "non-shell tool ignored" "" "$TL_OUT"
assert_file_absent "non-shell tool archives nothing" "$P/.planning/archive"

mkdir -p "$TL_TMP/outside"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
dg_run "$TL_TMP/outside" "$H" "$(bash_json "$CLEAR")"
assert_eq "outside an SB project nothing happens" "" "$TL_OUT"

dg_run_nojq "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "no jq: phases clear is denied (fail closed)" "deny" "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
assert_contains "no jq: static reason" "$TL_OUT" "jq required for Silver Bullet enforcement"
assert_eq "no jq: hook itself exits 0" 0 "$TL_STATUS"
assert_file_absent "no jq: nothing archived" "$P/.planning/archive"
dg_run_nojq "$P" "$H" "$(bash_json 'ls -la')"
assert_eq "no jq: unrelated command is not denied" "" "$TL_OUT"
assert_eq "no jq: unrelated command exits 0" 0 "$TL_STATUS"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
dg_run_nojq "$TL_TMP/outside" "$H" "$(bash_json "$CLEAR")"
assert_eq "no jq outside an SB project: inert" "" "$TL_OUT"
assert_eq "no jq outside an SB project: exits 0" 0 "$TL_STATUS"

rm -f "$P/.planning/PROJECT.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "no PROJECT.md: allow silently" "" "$TL_OUT"
printf '# Project\n' >"$P/.planning/PROJECT.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "no milestone line: allow silently" "" "$TL_OUT"
printf 'Current Milestone: !!!\n' >"$P/.planning/PROJECT.md"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "milestone slug empty after sanitising: allow silently" "" "$TL_OUT"
assert_file_absent "unsafe milestone creates no archive" "$P/.planning/archive"

fresh
rm -rf "$P/.planning/phases"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "no phases dir: nothing to archive" "" "$TL_OUT"
mkdir -p "$P/.planning/phases"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_eq "empty phases dir: nothing to archive" "" "$TL_OUT"
echo f >"$P/.planning/phases/notes.txt"
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "phases dir with only files: reports success" "$TL_OUT" "copied phases"
assert_eq "files-only phases dir: no phase dirs copied" "" "$(ls -A "$P/.planning/archive/v2-launch-beta")"

# fail closed when the copy fails
fresh
tl_stub cp 'exit 1'
dg_run "$P" "$H" "$(bash_json "$CLEAR")"
rm -f "$TL_BIN/cp"
assert_eq "copy failure: deny decision" "deny" "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
assert_contains "copy failure: reason" "$TL_OUT" "blocking clear to prevent data loss"
assert_eq "copy failure: hook itself exits 0" 0 "$TL_STATUS"

# no helper libs: jq-based extraction still gates and archives
fresh
dg_run_nolib_in "$P" "$H" "$(bash_json "$CLEAR")"
assert_contains "no libs: still archives" "$TL_OUT" "copied phases"
assert_file_exists "no libs: archive written" "$P/.planning/archive/v2-launch-beta/001-a/PLAN.md"
fresh
dg_run_nolib_in "$P" "$H" "$(bash_json "")"
assert_eq "no libs: empty command allowed" "" "$TL_OUT"

# first lib-dir lookup fails, the retry succeeds: libraries still load and the clear is archived
fresh
rm -f "$TL_TMP/cd-failed-once"
TL_STATUS=0
printf '%s' "$(bash_json "$CLEAR")" | (cd "$P" && CDFLAG="$TL_TMP/cd-failed-once" bash -c 'cd() { if [[ ! -e "$CDFLAG" ]]; then : >"$CDFLAG"; return 1; fi; builtin cd "$@"; }; export -f cd; exec bash "$0"' "$TL_REPO_ROOT/$H") >"$TL_TMP/.out" 2>/dev/null || TL_STATUS=$?
TL_OUT="$(cat "$TL_TMP/.out")"
assert_contains "lib-dir retry succeeds and archives" "$TL_OUT" "copied phases"
assert_file_exists "lib-dir retry: first lookup really failed" "$TL_TMP/cd-failed-once"

tl_results
