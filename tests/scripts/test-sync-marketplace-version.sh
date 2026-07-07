#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

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
SCRIPT="$REPO_ROOT/scripts/sync-marketplace-version.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REMOTE="$TMP/remote.git"
MARKETPLACE="$TMP/marketplace"
mkdir -p "$MARKETPLACE/.claude-plugin"

cp "$REPO_ROOT/.claude-plugin/marketplace.json" "$MARKETPLACE/.claude-plugin/marketplace.json"
jq '.plugins[] |= if .name == "silver-bullet" then .version = "0.0.1" else . end' \
  "$MARKETPLACE/.claude-plugin/marketplace.json" > "$TMP/marketplace.json"
mv "$TMP/marketplace.json" "$MARKETPLACE/.claude-plugin/marketplace.json"

git -C "$MARKETPLACE" init -q
git -C "$MARKETPLACE" checkout -q -b main
git -C "$MARKETPLACE" config user.email "tests@example.invalid"
git -C "$MARKETPLACE" config user.name "Tests"
git -C "$MARKETPLACE" add .
git -C "$MARKETPLACE" commit -q -m "seed stale marketplace"
git -C "$TMP" init --bare -q "$REMOTE"
git -C "$MARKETPLACE" remote add origin "$REMOTE"
git -C "$MARKETPLACE" push -q -u origin HEAD:main

plugin_v="$(jq -r '.version' "$REPO_ROOT/.claude-plugin/plugin.json")"
AGENT_PLUGINS_REPO_ROOT="$MARKETPLACE" bash "$SCRIPT" "$plugin_v" >/dev/null

remote_v="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$MARKETPLACE/.claude-plugin/marketplace.json")"
in_repo_v="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$REPO_ROOT/.claude-plugin/marketplace.json")"

assert_equal "remote Claude marketplace version bumped" "$plugin_v" "$remote_v"
assert_equal "in-repo Claude marketplace version matches plugin.json" "$plugin_v" "$in_repo_v"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
