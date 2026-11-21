#!/usr/bin/env bash
# scripts/lib/release-bypass-audit.sh: every release-gate bypass is printed and logged (R13-20).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

LIB="$TL_REPO_ROOT/scripts/lib/release-bypass-audit.sh"
REPO="$TL_TMP/repo"; tl_git_repo "$REPO"
SHA="$(git -C "$REPO" rev-parse HEAD)"
LOG="$SB_RUNTIME_STATE_DIR/release-bypass-log.jsonl"

tl_run env USER=alice bash -c 'source "$1"; sb_release_bypass_audit SB_SKIP_RC_MATRIX "$2"; echo "rc=$?"' _ "$LIB" "$REPO"
assert_contains "the bypass is announced on stderr" "$TL_ERR" "AUDIT: release gate bypass SB_SKIP_RC_MATRIX=1 by alice"
assert_contains "the call succeeds" "$TL_OUT" "rc=0"
assert_eq "the log line names switch, user, repo and commit" "SB_SKIP_RC_MATRIX alice $REPO $SHA" "$(jq -r '"\(.switch) \(.user) \(.repo) \(.commit)"' "$LOG")"
tl_run env USER=bob bash -c 'source "$1"; sb_release_bypass_audit SB_SKIP_PRE_RELEASE_GATE "$2"' _ "$LIB" "$TL_TMP/not-a-repo"
assert_eq "a second use appends a second line" "2" "$(wc -l <"$LOG" | tr -d ' ')"
assert_eq "outside a git repository the commit is empty" "" "$(tail -1 "$LOG" | jq -r '.commit')"

# the state directory comes from the runtime library when the caller has not set it
rm -f "$LOG"
tl_run env -u SB_RUNTIME_STATE_DIR bash -c 'source "$1"; sb_release_bypass_audit SB_SKIP_RC_MATRIX "$2"' _ "$LIB" "$REPO"
assert_file_exists "state dir resolved through hooks/lib/runtime-paths.sh" "$LOG"

# an unwritable state dir or a symlinked log never fails the caller and writes nothing through the link
: >"$TL_TMP/a-file"
tl_run env SB_RUNTIME_STATE_DIR="$TL_TMP/a-file/sub" bash -c 'source "$1"; sb_release_bypass_audit SB_SKIP_RC_MATRIX "$2"; echo "rc=$?"' _ "$LIB" "$REPO"
assert_contains "state dir that cannot be created: still succeeds" "$TL_OUT" "rc=0"
assert_contains "state dir that cannot be created: still announced" "$TL_ERR" "AUDIT: release gate bypass"
mkdir -p "$TL_TMP/st2"; echo precious >"$TL_TMP/victim"; ln -s "$TL_TMP/victim" "$TL_TMP/st2/release-bypass-log.jsonl"
tl_run env SB_RUNTIME_STATE_DIR="$TL_TMP/st2" bash -c 'source "$1"; sb_release_bypass_audit SB_SKIP_RC_MATRIX "$2"; echo "rc=$?"' _ "$LIB" "$REPO"
assert_eq "a symlinked log is never written through" "precious" "$(cat "$TL_TMP/victim")"
mkdir -p "$TL_TMP/st3"
tl_run env SB_RUNTIME_STATE_DIR="$TL_TMP/st3" PATH="$(tl_path_without jq)" bash -c 'source "$1"; sb_release_bypass_audit SB_SKIP_RC_MATRIX "$2"; echo "rc=$?"' _ "$LIB" "$REPO"
assert_contains "without jq the bypass is still announced and the call succeeds" "$TL_OUT" "rc=0"

tl_results
