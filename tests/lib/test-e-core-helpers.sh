#!/usr/bin/env bash
# Tests for tests/lib/e-core-helpers.sh: the command shims (ec_fail, ec_freeze_date) must
# resolve the real command even when $TL_BIN is not first on PATH and a shim already exists.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/e-core-helpers.sh"

ORIG_PATH="$PATH"

# --- Default layout: $TL_BIN first on PATH ------------------------------------------------
ec_freeze_date 2001-02-03
assert_eq "frozen calendar day" "2001-02-03" "$(date +%Y-%m-%d)"
assert_match "other formats run the real date" '^[0-9]+$' "$(date +%s)"

# --- $TL_BIN in the middle of PATH, date shim already present -----------------------------
PATH="/nonexistent-dir:$TL_BIN:${ORIG_PATH#"$TL_BIN":}"
hash -r
ec_freeze_date 2004-05-06
# A shim that resolved to itself would exec itself forever; bound each call.
tl_run timeout 5 date +%Y-%m-%d
assert_eq "re-freeze with TL_BIN mid-PATH" "2004-05-06" "$TL_OUT"
tl_run timeout 5 date +%s
assert_eq "real date reachable with TL_BIN mid-PATH: exit 0" 0 "$TL_STATUS"
assert_match "real date reachable with TL_BIN mid-PATH" '^[0-9]+$' "$TL_OUT"

# --- $TL_BIN last on PATH ----------------------------------------------------------------
PATH="${ORIG_PATH#"$TL_BIN":}:$TL_BIN"
hash -r
ec_fail git '*"--show-current"*'
PATH="$TL_BIN:${ORIG_PATH#"$TL_BIN":}"
hash -r
ec_fail git '*"--show-current"*'
tl_run timeout 5 git --version
assert_eq "ec_fail passes other calls through to the real git" 0 "$TL_STATUS"
assert_contains "real git answered" "$TL_OUT" "git version"
tl_run timeout 5 git branch --show-current
assert_eq "ec_fail fails the matched call" 1 "$TL_STATUS"
ec_unfail git

PATH="$ORIG_PATH"
tl_results
