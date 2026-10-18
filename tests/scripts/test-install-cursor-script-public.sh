#!/usr/bin/env bash
# scripts/install-cursor.sh --public-release with the published marketplace and
# the release checkout redirected to local repositories.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
# shellcheck source=tests/lib/install-cursor-script-fixture.sh
source "$TL_REPO_ROOT/tests/lib/install-cursor-script-fixture.sh"

MKT="$TL_TMP/published-marketplace"
mkdir -p "$MKT/.cursor-plugin"
printf '{"plugins":[{"name":"silver-bullet","version":"5.5.5"}]}\n' >"$MKT/.cursor-plugin/marketplace.json"
git -C "$MKT" init -q
git -C "$MKT" config user.email t@example.invalid; git -C "$MKT" config user.name t; git -C "$MKT" config gc.auto 0
git -C "$MKT" add -A
git -C "$MKT" -c commit.gpgsign=false commit -q -m published
git config --global url."file://$SNAP".insteadOf https://github.com/alo-exp/silver-bullet.git

fresh
tl_run env CURSOR_UNIFIED_MARKETPLACE_SOURCE="file://$MKT" CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE="file://$MKT" bash "$SCRIPT" --public-release
assert_eq "public-release install exits 0" 0 "$TL_STATUS"
assert_contains "published source reported" "$TL_OUT" "Silver Bullet Cursor plugin refreshed from file://$MKT at $CACHE/5.5.5"
assert_eq "release version installed" 5.5.5 "$(jq -r .version "$CACHE/5.5.5/.cursor-plugin/plugin.json")"
assert_eq "registry records the release version" 5.5.5 "$(jq -r '.plugins["silver-bullet@alo-labs"][0].version' "$CURSOR_HOME/plugins/installed_plugins.json")"
assert_eq "current alias follows the release" "$CACHE/5.5.5" "$(readlink "$CACHE/current")"

tl_results
