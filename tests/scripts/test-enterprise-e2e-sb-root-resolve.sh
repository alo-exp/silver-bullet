#!/usr/bin/env bash
# Behaviour tests for scripts/lib/enterprise-e2e-sb-root-resolve.sh: SB_ROOT / main-repo resolution
# precedence. Everything lives under $TL_TMP; the legacy /private/tmp worktree is simulated by
# redefining the validity predicate, never by touching the filesystem outside the sandbox.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-sb-root-resolve.sh"
BASE=(-u SB_ROOT -u SB_E2E_MAIN_REPO -u SB_E2E_SB_ROOT_CANDIDATES)

# mk_root DIR KIND: a harness root. KIND = dir (.git directory), file (worktree .git file),
# nogit (no .git), noscript (no run script).
mk_root() {
  mkdir -p "$1/scripts"
  [[ "$2" == noscript ]] || : >"$1/scripts/run-enterprise-e2e-live-test.sh"
  case "$2" in
    dir | noscript) mkdir -p "$1/.git" ;;
    file) echo "gitdir: elsewhere" >"$1/.git" ;;
  esac
}

mk_root "$TL_TMP/r-dir" dir
mk_root "$TL_TMP/r-file" file
mk_root "$TL_TMP/r-nogit" nogit
mk_root "$TL_TMP/r-noscript" noscript

# --- enterprise_e2e_sb_root_is_valid ---------------------------------------
valid() { e2e_call "$LIB" "${BASE[@]}" -- enterprise_e2e_sb_root_is_valid "$1"; }
valid "$TL_TMP/r-dir"
assert_eq "valid: .git directory" 0 "$TL_STATUS"
valid "$TL_TMP/r-file"
assert_eq "valid: .git file (worktree)" 0 "$TL_STATUS"
valid "$TL_TMP/r-nogit"
assert_eq "invalid: no .git" 1 "$TL_STATUS"
valid "$TL_TMP/r-noscript"
assert_eq "invalid: no run script" 1 "$TL_STATUS"
valid "$TL_TMP/absent"
assert_eq "invalid: missing dir" 1 "$TL_STATUS"
valid ""
assert_eq "invalid: empty arg" 1 "$TL_STATUS"

# --- enterprise_e2e_resolve_sb_root ----------------------------------------
resolve() { e2e_call "$LIB" "${BASE[@]}" "$@" -- enterprise_e2e_resolve_sb_root; }

resolve "SB_ROOT=$TL_TMP/r-dir" "SB_E2E_MAIN_REPO=$TL_TMP/r-file"
assert_eq "SB_ROOT wins: status" 0 "$TL_STATUS"
assert_eq "SB_ROOT wins over MAIN_REPO" "$TL_TMP/r-dir" "$TL_OUT"

# a relative SB_ROOT is emitted as an absolute path
(cd "$TL_TMP" && e2e_call "$LIB" "${BASE[@]}" "SB_ROOT=r-file/../r-dir" -- enterprise_e2e_resolve_sb_root)
assert_eq "relative SB_ROOT becomes absolute" "$TL_TMP/r-dir" "$TL_OUT"

resolve "SB_ROOT=$TL_TMP/r-nogit" "SB_E2E_MAIN_REPO=$TL_TMP/r-file"
assert_eq "invalid SB_ROOT falls to MAIN_REPO: status" 0 "$TL_STATUS"
assert_eq "invalid SB_ROOT falls to MAIN_REPO" "$TL_TMP/r-file" "$TL_OUT"

resolve "SB_E2E_MAIN_REPO=$TL_TMP/r-file" "SB_E2E_SB_ROOT_CANDIDATES=$TL_TMP/r-dir"
assert_eq "MAIN_REPO beats candidates" "$TL_TMP/r-file" "$TL_OUT"

resolve "SB_E2E_MAIN_REPO=$TL_TMP/r-noscript" "SB_E2E_SB_ROOT_CANDIDATES=$TL_TMP/absent $TL_TMP/r-nogit $TL_TMP/r-file $TL_TMP/r-dir"
assert_eq "first valid candidate is used: status" 0 "$TL_STATUS"
assert_eq "first valid candidate is used" "$TL_TMP/r-file" "$TL_OUT"

# No env hint at all: the legacy worktree is used only while it is still valid.
LEGACY=/private/tmp/sb-main-row11-fp
tl_run env "${BASE[@]}" bash -c "set -euo pipefail; source '$LIB'
enterprise_e2e_sb_root_is_valid() { [[ \"\$1\" == '$LEGACY' ]]; }
enterprise_e2e_resolve_sb_root"
assert_eq "legacy worktree used when still valid: status" 0 "$TL_STATUS"
assert_eq "legacy worktree is the fixed path" "$LEGACY" "$TL_OUT"

# Script-relative fallback: a copy of the lib inside a valid tree resolves to that tree.
mk_root "$TL_TMP/tree" dir
mkdir -p "$TL_TMP/tree/scripts/lib"
cp "$LIB" "$TL_TMP/tree/scripts/lib/"
tl_run env "${BASE[@]}" bash -c "set -euo pipefail; source '$TL_TMP/tree/scripts/lib/enterprise-e2e-sb-root-resolve.sh'; enterprise_e2e_resolve_sb_root"
assert_eq "script-relative fallback: status" 0 "$TL_STATUS"
assert_eq "script-relative fallback resolves the tree holding the lib" "$TL_TMP/tree" "$TL_OUT"

# Nothing valid anywhere: error on stderr, status 1, nothing on stdout.
mk_root "$TL_TMP/bad" noscript
mkdir -p "$TL_TMP/bad/scripts/lib"
cp "$LIB" "$TL_TMP/bad/scripts/lib/"
tl_run env "${BASE[@]}" bash -c "set -euo pipefail; source '$TL_TMP/bad/scripts/lib/enterprise-e2e-sb-root-resolve.sh'; enterprise_e2e_resolve_sb_root"
assert_eq "unresolvable: status" 1 "$TL_STATUS"
assert_eq "unresolvable: no stdout" "" "$TL_OUT"
assert_contains "unresolvable: error names the remedy" "$TL_ERR" "cannot resolve SB_ROOT"

# --- enterprise_e2e_resolve_main_repo --------------------------------------
mkdir -p "$TL_TMP/main-art/.planning/enterprise-e2e"
e2e_call "$LIB" "${BASE[@]}" "SB_E2E_MAIN_REPO=$TL_TMP/main-art" "SB_ROOT=$TL_TMP/r-dir" -- enterprise_e2e_resolve_main_repo
assert_eq "main repo: artifact dir present wins" "$TL_TMP/main-art" "$TL_OUT"

e2e_call "$LIB" "${BASE[@]}" "SB_E2E_MAIN_REPO=$TL_TMP/r-file" "SB_ROOT=$TL_TMP/r-dir" -- enterprise_e2e_resolve_main_repo
assert_eq "main repo: no .planning/enterprise-e2e falls back to SB root" "$TL_TMP/r-dir" "$TL_OUT"

e2e_call "$LIB" "${BASE[@]}" "SB_ROOT=$TL_TMP/r-file" -- enterprise_e2e_resolve_main_repo
assert_eq "main repo: unset hint falls back to SB root" "$TL_TMP/r-file" "$TL_OUT"

tl_results
