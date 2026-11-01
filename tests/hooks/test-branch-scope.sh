#!/usr/bin/env bash
# hooks/lib/branch-scope.sh: stored branch + worktree scope. Reads and writes must use the
# same validated runtime path, never a raw SILVER_BULLET_BRANCH_FILE outside the state root
# and never a shared /tmp/branch (R3-27).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIB="$TL_REPO_ROOT/hooks/lib/branch-scope.sh"
# shellcheck source=../../hooks/lib/branch-scope.sh
source "$LIB"
SD="$SB_RUNTIME_STATE_DIR"

# ---- write / read / mismatch (honest path) --------------------------------------
export SILVER_BULLET_BRANCH_FILE="$SD/branch-test"
sb_branch_scope_write "feature-a" "/repo/main"
if sb_branch_scope_read; then tl_pass "read after write"; else tl_fail "read after write"; fi
assert_eq "write/read branch" "feature-a" "$SB_BRANCH_SCOPE_STORED_BRANCH"
assert_eq "write/read toplevel" "/repo/main" "$SB_BRANCH_SCOPE_STORED_TOPLEVEL"
if sb_branch_scope_mismatch "feature-a" "/repo/worktree-a"; then tl_pass "worktree toplevel mismatch detected"; else tl_fail "worktree toplevel mismatch detected"; fi
if sb_branch_scope_mismatch "feature-a" "/repo/main"; then tl_fail "same scope no mismatch"; else tl_pass "same scope no mismatch"; fi
if sb_branch_scope_mismatch "feature-b" ""; then tl_pass "branch change detected"; else tl_fail "branch change detected"; fi
if sb_branch_scope_mismatch "" "/repo/main"; then tl_fail "unknown current branch is never a mismatch"; else tl_pass "unknown current branch is never a mismatch"; fi
if SILVER_BULLET_BRANCH_FILE="$SD/never-written" sb_branch_scope_mismatch "feature-a" "/repo/main"; then
  tl_fail "nothing stored is never a mismatch"
else
  tl_pass "nothing stored is never a mismatch"
fi
sb_branch_scope_write "feature-c" ""
assert_eq "branch without toplevel stores one line" "feature-c" "$(cat "$SD/branch-test")"
if sb_branch_scope_write "" "/x"; then tl_fail "empty branch refused"; else tl_pass "empty branch refused"; fi
assert_eq "env path inside the root is used" "$SD/branch-test" "$(sb_branch_scope_file)"

# ---- the validated path, not the raw environment value -------------------------
OUTSIDE="$TL_TMP/outside-branch"
export SILVER_BULLET_BRANCH_FILE="$OUTSIDE"
assert_eq "env path outside the root falls back to the state dir" "$SD/branch" "$(sb_branch_scope_file)"
rm -f "$SD/branch"
sb_branch_scope_write "feature-x" "/repo"
assert_file_absent "nothing written outside the state root" "$OUTSIDE"
assert_eq "written to the validated runtime path" "feature-x" "$(sed -n 1p "$SD/branch")"
if sb_branch_scope_read && [[ "$SB_BRANCH_SCOPE_STORED_BRANCH" == feature-x ]]; then
  tl_pass "read uses the same validated path as write"
else
  tl_fail "read uses the same validated path as write"
fi
export SILVER_BULLET_BRANCH_FILE="$SD/../../escape-branch"
assert_eq "env path with '..' falls back" "$SD/branch" "$(sb_branch_scope_file)"
unset SILVER_BULLET_BRANCH_FILE
assert_eq "default path is the runtime state dir" "$SD/branch" "$(sb_branch_scope_file)"

# Explicit, already-validated file argument (callers such as session-start).
sb_branch_scope_write "feature-y" "/repo" "$SD/explicit-branch"
assert_eq "explicit validated file honoured" "feature-y" "$(sed -n 1p "$SD/explicit-branch")"

# Never a shared /tmp path: without a state dir there is nowhere safe to write.
out="$(bash -c 'source "$1"; unset SB_RUNTIME_STATE_DIR SILVER_BULLET_BRANCH_FILE; sb_branch_scope_file || echo NONE' _ "$LIB")"
assert_eq "no state dir: no fallback path" "NONE" "$out"
out="$(cd "$TL_TMP" && bash -c 'source "$1"; unset SB_RUNTIME_STATE_DIR SILVER_BULLET_BRANCH_FILE; sb_branch_scope_write b t || echo REFUSED' _ "$LIB")"
assert_eq "no state dir: write refused" "REFUSED" "$out"
assert_file_absent "no state dir: nothing written to a shared /tmp/branch by this run" "$TL_TMP/branch"
out="$(bash -c 'source "$1"; unset SB_RUNTIME_STATE_DIR SILVER_BULLET_BRANCH_FILE; sb_branch_scope_read || echo NOREAD' _ "$LIB")"
assert_eq "no state dir: read reports nothing stored" "NOREAD" "$out"
# Without the runtime-paths validator an override is ignored, never trusted raw.
mkdir -p "$TL_TMP/farm/hooks/lib"
ln -s "$LIB" "$TL_TMP/farm/hooks/lib/branch-scope.sh"
out="$(env -i PATH="$PATH" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" SB_RUNTIME_STATE_DIR="$SD" SILVER_BULLET_BRANCH_FILE="$OUTSIDE" bash -c 'source "$1"; sb_branch_scope_file' _ "$TL_TMP/farm/hooks/lib/branch-scope.sh")"
assert_eq "no validator: override ignored" "$SD/branch" "$out"

# A symlinked branch file is refused without killing the calling hook.
printf 'precious\n' >"$TL_TMP/target"
ln -sfn "$TL_TMP/target" "$SD/branch"
out="$(bash -c 'source "$1"; sb_branch_scope_write z /r || echo REFUSED; echo still-running' _ "$LIB")"
assert_eq "symlinked branch file: write refused, caller keeps running" $'REFUSED\nstill-running' "$out"
assert_eq "symlink target untouched" "precious" "$(cat "$TL_TMP/target")"
if sb_branch_scope_read; then tl_fail "symlinked branch file is not read"; else tl_pass "symlinked branch file is not read"; fi
rm -f "$SD/branch"

# ---- session-start integration -------------------------------------------------
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1 SILVER_BULLET_UPDATE_CHECK_DISABLED=1
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test"
ec_project
rm -f "$SD/branch" "$OUTSIDE"
tl_run_stdin '{"hook_event_name":"SessionStart","source":"startup"}' env SILVER_BULLET_BRANCH_FILE="$OUTSIDE" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$TL_REPO_ROOT/hooks/session-start"
assert_file_absent "session-start: rejected branch file is not written" "$OUTSIDE"
assert_eq "session-start: validated branch file initialised" "feature/test" "$(sed -n 1p "$SD/branch" 2>/dev/null)"
assert_not_contains "session-start: no write-failure warning" "$TL_ERR" "branch file write failed"

tl_results
