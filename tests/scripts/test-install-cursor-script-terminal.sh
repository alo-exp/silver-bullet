#!/usr/bin/env bash
# scripts/install-cursor.sh on a terminal and over a legacy marketplace clone.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
# shellcheck source=tests/lib/install-cursor-script-fixture.sh
source "$TL_REPO_ROOT/tests/lib/install-cursor-script-fixture.sh"

# ---- interactive terminal: the sub-agent installer is not forced non-interactive
fresh
if command -v script >/dev/null 2>&1; then
  tl_run script -qec "bash '$SCRIPT'" /dev/null
  assert_eq "install on a terminal exits 0" 0 "$TL_STATUS"
  assert_contains "interactive sub-agent installer invoked" "$(<"$CALLS")" "csba --global repo="
  assert_not_contains "no --non-interactive on a terminal" "$(grep '^csba' "$CALLS" | head -1)" "--non-interactive"
  fresh
  tl_run script -qec "env STUB_CSBA_RC=1 bash '$SCRIPT'" /dev/null
  assert_contains "interactive installer failure warned about" "$TL_OUT$TL_ERR" "exited nonzero (continuing)"
else
  echo "SKIP: script(1) not available; terminal branch not exercised"
fi

# ---- legacy marketplace clone: notice, removal, legacy sha resolution
fresh
LEG="$CURSOR_HOME/plugins/marketplaces/github.com/alo-labs/alo-labs-cursor-marketplace"
mkdir -p "$LEG"
run
assert_eq "install over a legacy marketplace exits 0" 0 "$TL_STATUS"
assert_contains "migration notice printed" "$TL_ERR" "Cursor is still using the legacy alo-labs/alo-labs-cursor-marketplace source."
assert_file_absent "legacy clone removed" "$LEG"
assert_contains "UI switch hint printed" "$TL_OUT" "legacy clone removed — complete UI switch per notice above"

tl_results
