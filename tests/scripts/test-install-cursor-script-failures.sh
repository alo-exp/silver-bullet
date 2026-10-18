#!/usr/bin/env bash
# scripts/install-cursor.sh failure paths, injected into the disposable snapshot:
# an install that vanishes mid-run, inconsistent command names, missing gitPath
# checkouts and a failing bundle renderer.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
# shellcheck source=tests/lib/install-cursor-script-fixture.sh
source "$TL_REPO_ROOT/tests/lib/install-cursor-script-fixture.sh"

REAL_GIT="$(command -v git)"

# ---- the cache version directory disappears right after the sync
fresh
tl_stub git 'if [[ "$1" == ls-remote ]]; then rm -rf "'"$CACHE"'/'"$VERSION"'"; fi; exec '"$REAL_GIT"' "$@"'
run
assert_eq "a vanished cache version aborts the install" 1 "$TL_STATUS"
assert_contains "vanished cache version explained" "$TL_ERR" "expected Cursor cache version dir missing after sync: $CACHE/$VERSION"
rm -f "${TL_BIN:?}/git"

# ---- colon-named command files make the installed identity inconsistent
fresh
echo c >"$SNAP/plugins/silver-bullet/commands/bad:name.md"
run
assert_eq "colon-named commands abort the install" 1 "$TL_STATUS"
assert_contains "colon names reported" "$TL_ERR" "Cursor command filenames contain colon characters"
assert_contains "inconsistent identity reported" "$TL_ERR" "Cursor install identity is inconsistent — refusing to leave a partial install"
rm -f "${SNAP:?}/plugins/silver-bullet/commands/bad:name.md"

# ---- gitPath checkouts that cannot be created leave the discovery paths incomplete
fresh
tl_stub git 'if [[ "$1" == clone && "${*: -1}" == */github.com/alo-exp/silver-bullet/* ]]; then exit 1; fi; exec '"$REAL_GIT"' "$@"'
run
assert_eq "missing gitPath fails the discovery check" 1 "$TL_STATUS"
assert_contains "missing gitPath reported" "$TL_ERR" "Cursor gitPath missing for $SNAP_SHA"
assert_contains "incomplete discovery reported" "$TL_ERR" "Cursor plugin discovery paths incomplete"
rm -f "${TL_BIN:?}/git"

# ---- a failing bundle renderer is tolerated
fresh
printf 'import sys\nsys.exit(1)\n' >"$SNAP/scripts/render-agent-bundle.py"
run
assert_eq "failing renderer tolerated" 0 "$TL_STATUS"
assert_contains "install still completes" "$TL_OUT" "Silver Bullet Cursor plugin synced to"

tl_results
