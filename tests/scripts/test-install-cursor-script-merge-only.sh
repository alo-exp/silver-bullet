#!/usr/bin/env bash
# scripts/install-cursor.sh --merge-hooks-only.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
# shellcheck source=tests/lib/install-cursor-script-fixture.sh
source "$TL_REPO_ROOT/tests/lib/install-cursor-script-fixture.sh"

# ---- --merge-hooks-only
fresh
run --merge-hooks-only
assert_eq "merge-only without an install fails" 1 "$TL_STATUS"
assert_contains "merge-only failure explained" "$TL_ERR" "no installed Cursor plugin at $CACHE/current"
fresh
run
jq 'del(.plugins["silver-bullet@alo-labs"][0].gitCommitSha)' "$CURSOR_HOME/plugins/installed_plugins.json" >"$TL_TMP/reg.json"
cp "$TL_TMP/reg.json" "$CURSOR_HOME/plugins/installed_plugins.json"
run --merge-hooks-only
assert_eq "merge-only over an existing install exits 0" 0 "$TL_STATUS"
assert_contains "merge-only completes" "$TL_OUT" "Cursor hook merge complete"

# ---- the install version key falls back to the install sha when git cannot shorten HEAD
fresh
REAL_GIT="$(command -v git)"
tl_stub git 'if [[ "$*" == *"--short"* ]]; then exit 1; fi; exec '"$REAL_GIT"' "$@"'
run
assert_eq "install without a short HEAD exits 0" 0 "$TL_STATUS"
assert_contains "version key built from the install sha" "$TL_OUT" "SB install version key: $VERSION@${SNAP_SHA:0:8}"
rm -f "${TL_BIN:?}/git"

tl_results
