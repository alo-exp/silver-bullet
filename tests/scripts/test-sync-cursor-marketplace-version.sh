#!/usr/bin/env bash
# sync-cursor-marketplace-version.sh against the real manifests, run from a
# disposable snapshot of the checkout (the script rewrites the in-repo
# marketplace.json and the Cursor package, so it must never run from the
# repository under test).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=tests/lib/repo-snapshot.sh
source "$TL_REPO_ROOT/tests/lib/repo-snapshot.sh"
SNAP="$(sb_repo_snapshot --git "$TL_REPO_ROOT" "$TL_TMP/repo")"
SCRIPT="$SNAP/scripts/sync-cursor-marketplace-version.sh"
cd "$TL_TMP"

sb_version() { jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$1"; }
stale() {
  jq '(.plugins[] | select(.name=="silver-bullet") | .version) = "0.0.1"' "$1" >"$TL_TMP/stale.json"
  cp "$TL_TMP/stale.json" "$1"
}

REMOTE="$TL_TMP/remote.git"
MARKETPLACE="$TL_TMP/marketplace"
mkdir -p "$MARKETPLACE/.cursor-plugin"
cp "$SNAP/.cursor-plugin/marketplace.json" "$MARKETPLACE/.cursor-plugin/marketplace.json"
stale "$MARKETPLACE/.cursor-plugin/marketplace.json"
stale "$SNAP/.cursor-plugin/marketplace.json"

git -C "$MARKETPLACE" init -q
git -C "$MARKETPLACE" checkout -q -b main
git -C "$MARKETPLACE" config user.email "tests@example.invalid"
git -C "$MARKETPLACE" config user.name "Tests"
git -C "$MARKETPLACE" add .
git -C "$MARKETPLACE" commit -q -m "seed stale marketplace"
git -C "$TL_TMP" init --bare -q "$REMOTE"
git -C "$MARKETPLACE" remote add origin "$REMOTE"
git -C "$MARKETPLACE" push -q -u origin HEAD:main

REAL_BEFORE="$(git -C "$TL_REPO_ROOT" status --porcelain --untracked-files=all -- .cursor-plugin plugins)"
plugin_v="$(jq -r '.version' "$SNAP/.cursor-plugin/plugin.json")"
tl_run env AGENT_PLUGINS_REPO_ROOT="$MARKETPLACE" timeout 120 bash "$SCRIPT" "$plugin_v"
assert_eq "sync exits 0" 0 "$TL_STATUS"

package_v="$(jq -r '.version' "$SNAP/plugins/silver-bullet/.cursor-plugin/plugin.json")"
assert_eq "remote marketplace version bumped" "$plugin_v" "$(sb_version "$MARKETPLACE/.cursor-plugin/marketplace.json")"
assert_eq "snapshot marketplace version matches plugin.json" "$plugin_v" "$(sb_version "$SNAP/.cursor-plugin/marketplace.json")"
assert_eq "cursor package manifest version matches plugin.json" "$plugin_v" "$package_v"
assert_eq "bump pushed to the remote" "$plugin_v" "$(git -C "$REMOTE" show main:.cursor-plugin/marketplace.json | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"
assert_eq "the real checkout is untouched" "$REAL_BEFORE" "$(git -C "$TL_REPO_ROOT" status --porcelain --untracked-files=all -- .cursor-plugin plugins)"

tl_results
