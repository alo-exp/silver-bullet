#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_equal() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected $expected, got $actual"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-cursor-marketplace-version.sh"
TMP="$(mktemp -d)"
# This test asserts that the release script updates the in-repo manifest, so it
# cannot be sandboxed away — snapshot and restore it instead, otherwise every
# run leaves the tracked manifest re-pinned to the current HEAD.
IN_REPO_MANIFEST="$REPO_ROOT/.cursor-plugin/marketplace.json"
cp "$IN_REPO_MANIFEST" "$TMP/.in-repo-marketplace.json.orig"
trap 'cp -f "$TMP/.in-repo-marketplace.json.orig" "$IN_REPO_MANIFEST" 2>/dev/null || true; rm -rf "$TMP"' EXIT

REMOTE="$TMP/remote.git"
MARKETPLACE="$TMP/marketplace"
mkdir -p "$MARKETPLACE/.cursor-plugin"

cp "$REPO_ROOT/.cursor-plugin/marketplace.json" "$MARKETPLACE/.cursor-plugin/marketplace.json"
jq '.plugins[] |= if .name == "silver-bullet" then .version = "0.0.1" else . end' \
  "$MARKETPLACE/.cursor-plugin/marketplace.json" > "$TMP/marketplace.json"
mv "$TMP/marketplace.json" "$MARKETPLACE/.cursor-plugin/marketplace.json"

git -C "$MARKETPLACE" init -q
git -C "$MARKETPLACE" checkout -q -b main
git -C "$MARKETPLACE" config user.email "tests@example.invalid"
git -C "$MARKETPLACE" config user.name "Tests"
git -C "$MARKETPLACE" add .
git -C "$MARKETPLACE" commit -q -m "seed stale marketplace"
git -C "$TMP" init --bare -q "$REMOTE"
git -C "$MARKETPLACE" remote add origin "$REMOTE"
git -C "$MARKETPLACE" push -q -u origin HEAD:main

plugin_v="$(jq -r '.version' "$REPO_ROOT/.cursor-plugin/plugin.json")"
AGENT_PLUGINS_REPO_ROOT="$MARKETPLACE" bash "$SCRIPT" "$plugin_v" >/dev/null

remote_v="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$MARKETPLACE/.cursor-plugin/marketplace.json")"
in_repo_v="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$REPO_ROOT/.cursor-plugin/marketplace.json")"
package_v="$(jq -r '.version' "$REPO_ROOT/plugins/silver-bullet/.cursor-plugin/plugin.json")"

assert_equal "remote marketplace version bumped" "$plugin_v" "$remote_v"
assert_equal "in-repo marketplace version matches plugin.json" "$plugin_v" "$in_repo_v"
assert_equal "cursor package manifest version matches plugin.json" "$plugin_v" "$package_v"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
