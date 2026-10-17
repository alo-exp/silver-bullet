#!/usr/bin/env bash
# hooks/lib/hook-bootstrap.sh: fallbacks when sibling libs are missing, cert-run bypass.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

BOOT="$TL_REPO_ROOT/hooks/lib/hook-bootstrap.sh"
EMPTY="$TL_TMP/empty-lib"
mkdir -p "$EMPTY"

# With no sibling libs at all the bootstrap defines safe fallbacks.
flow="$TL_TMP/flow.md"
printf '| 1 | a | complete |\n| 2 | b | skipped |\n| 3 | c | open |\nnot a row\n' >"$flow"

run_empty() { tl_run bash -c '_lib_dir="$1"; source "$2"; shift 2; "$@"' _ "$EMPTY" "$BOOT" "$@"; }

run_empty count_flow_log_rows "$flow"
assert_eq "fallback counts numbered flow rows" 3 "$TL_OUT"
run_empty count_flow_log_rows "$TL_TMP/missing.md"
assert_contains "fallback flow count on missing file prints 0" "$TL_OUT" "0"
printf '| x | y | open |\n' >"$TL_TMP/none.md"
run_empty count_flow_log_rows "$TL_TMP/none.md"
assert_eq "fallback flow count with no rows is a single 0" "0" "$TL_OUT"
run_empty count_complete_flow_rows "$TL_TMP/none.md"
assert_eq "fallback complete count with no rows is a single 0" "0" "$TL_OUT"
run_empty count_complete_flow_rows "$flow"
assert_eq "fallback counts complete/skipped rows" 2 "$TL_OUT"
run_empty sb_skill_is_installed anything
assert_eq "fallback treats every skill as installed" 0 "$TL_STATUS"
run_empty sb_github_run_list_json
assert_eq "fallback github run list fails" 1 "$TL_STATUS"
run_empty sb_hook_exit_on_cert_run
assert_eq "cert bypass helper is a no-op without cert-bypass lib" 0 "$TL_STATUS"

# With the real libs the real implementations win over the fallbacks.
tl_run bash -c '_lib_dir="$1/hooks/lib"; source "$1/hooks/lib/hook-bootstrap.sh"; declare -f sb_github_run_list_json | head -1' _ "$TL_REPO_ROOT"
assert_contains "real github-run-list lib is sourced" "$TL_OUT" "sb_github_run_list_json"
tl_run bash -c '_lib_dir="$1/hooks/lib"; source "$1/hooks/lib/hook-bootstrap.sh"; declare -f sb_github_run_list_json' _ "$TL_REPO_ROOT"
assert_contains "real implementation calls gh, not the failing stub" "$TL_OUT" "gh"

# Cert-run bypass: exits the calling hook with 0 when active, continues otherwise.
FAKE="$TL_TMP/fake-lib"
mkdir -p "$FAKE"
cat >"$FAKE/cert-bypass.sh" <<'LIB'
sb_cert_run_bypass_active() { [[ "${FAKE_CERT:-}" == "1" ]]; }
LIB
tl_run env FAKE_CERT=1 bash -c '_lib_dir="$1"; source "$2"; sb_hook_exit_on_cert_run; echo continued' _ "$FAKE" "$BOOT"
assert_eq "active cert run exits the hook" 0 "$TL_STATUS"
assert_eq "active cert run stops execution" "" "$TL_OUT"
tl_run env FAKE_CERT=0 bash -c '_lib_dir="$1"; source "$2"; sb_hook_exit_on_cert_run; echo continued' _ "$FAKE" "$BOOT"
assert_eq "inactive cert run continues" "continued" "$TL_OUT"

# phase-lock peek trap is installed when phase-path.sh provides the helper.
cat >"$FAKE/phase-path.sh" <<'LIB'
_phase_lock_peek_on_exit() { echo "peeked" >&2; }
LIB
tl_run bash -c '_lib_dir="$1"; source "$2"; exit 0' _ "$FAKE" "$BOOT"
assert_contains "exit trap from phase-path lib runs" "$TL_ERR" "peeked"
# ...and not when the lib lacks the helper.
printf '# no helper here\n' >"$FAKE/phase-path.sh"
tl_run bash -c '_lib_dir="$1"; source "$2"; trap -p EXIT' _ "$FAKE" "$BOOT"
assert_eq "no exit trap without the helper" "" "$TL_OUT"

tl_results
