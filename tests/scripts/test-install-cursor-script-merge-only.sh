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

tl_results
