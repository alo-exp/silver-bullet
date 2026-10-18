#!/usr/bin/env bash
# sync-marketplace-version.sh against the real manifests, run from a disposable
# snapshot of the checkout (the script rewrites the in-repo marketplace.json, so
# it must never run from the repository under test).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=tests/lib/repo-snapshot.sh
source "$TL_REPO_ROOT/tests/lib/repo-snapshot.sh"
SNAP="$(sb_repo_snapshot --git "$TL_REPO_ROOT" "$TL_TMP/repo")"
SCRIPT="$SNAP/scripts/sync-marketplace-version.sh"
cd "$TL_TMP"

sb_version() { jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$1"; }
stale() {
  jq '(.plugins[] | select(.name=="silver-bullet") | .version) = "0.0.1"' "$1" >"$TL_TMP/stale.json"
  cp "$TL_TMP/stale.json" "$1"
}

REMOTE="$TL_TMP/remote.git"
MARKETPLACE="$TL_TMP/marketplace"
mkdir -p "$MARKETPLACE/.claude-plugin"
cp "$SNAP/.claude-plugin/marketplace.json" "$MARKETPLACE/.claude-plugin/marketplace.json"
stale "$MARKETPLACE/.claude-plugin/marketplace.json"
# The in-repo manifest is stale too: the sync must repair the snapshot's copy.
stale "$SNAP/.claude-plugin/marketplace.json"

git -C "$MARKETPLACE" init -q
git -C "$MARKETPLACE" checkout -q -b main
git -C "$MARKETPLACE" config user.email "tests@example.invalid"
git -C "$MARKETPLACE" config user.name "Tests"
git -C "$MARKETPLACE" add .
git -C "$MARKETPLACE" commit -q -m "seed stale marketplace"
git -C "$TL_TMP" init --bare -q "$REMOTE"
git -C "$MARKETPLACE" remote add origin "$REMOTE"
git -C "$MARKETPLACE" push -q -u origin HEAD:main

REAL_BEFORE="$(git -C "$TL_REPO_ROOT" status --porcelain --untracked-files=all -- .claude-plugin)"
plugin_v="$(jq -r '.version' "$SNAP/.claude-plugin/plugin.json")"
tl_run env AGENT_PLUGINS_REPO_ROOT="$MARKETPLACE" timeout 60 bash "$SCRIPT" "$plugin_v"
assert_eq "sync exits 0" 0 "$TL_STATUS"

assert_eq "remote Claude marketplace version bumped" "$plugin_v" "$(sb_version "$MARKETPLACE/.claude-plugin/marketplace.json")"
assert_eq "snapshot Claude marketplace version matches plugin.json" "$plugin_v" "$(sb_version "$SNAP/.claude-plugin/marketplace.json")"
assert_eq "bump pushed to the remote" "$plugin_v" "$(git -C "$REMOTE" show main:.claude-plugin/marketplace.json | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"
assert_eq "the real checkout is untouched" "$REAL_BEFORE" "$(git -C "$TL_REPO_ROOT" status --porcelain --untracked-files=all -- .claude-plugin)"

tl_results
