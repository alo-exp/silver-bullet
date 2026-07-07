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

assert_file_absent() {
  local desc="$1" path="$2"
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — should be absent: $path"
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
SCRIPT="$REPO_ROOT/scripts/sync-codex-marketplace-version.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MARKETPLACE="$TMP/marketplace"
REMOTE="$TMP/remote.git"
mkdir -p "$MARKETPLACE/.agents/plugins"

cp "$REPO_ROOT/.agents/plugins/marketplace.json" \
  "$MARKETPLACE/.agents/plugins/marketplace.json"
jq '.plugins[] |= if .name == "silver-bullet" then .version = "0.0.1" | .source.ref = "v0.0.1" else . end' \
  "$MARKETPLACE/.agents/plugins/marketplace.json" > "$TMP/marketplace.json"
mv "$TMP/marketplace.json" "$MARKETPLACE/.agents/plugins/marketplace.json"

git -C "$MARKETPLACE" init -q
git -C "$MARKETPLACE" config user.email "tests@example.invalid"
git -C "$MARKETPLACE" config user.name "Tests"
git -C "$MARKETPLACE" add .
git -C "$MARKETPLACE" commit -q -m "seed stale thin marketplace"
git -C "$MARKETPLACE" branch -M main
git -C "$TMP" init --bare -q "$REMOTE"
git -C "$MARKETPLACE" remote add origin "$REMOTE"
git -C "$MARKETPLACE" push -q -u origin HEAD:main

bash "$REPO_ROOT/scripts/sync-codex-package.sh" >/dev/null
plugin_v="$(jq -r '.version' "$REPO_ROOT/package.json")"

AGENT_PLUGINS_REPO_ROOT="$MARKETPLACE" bash "$SCRIPT" >/dev/null

manifest_v="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$MARKETPLACE/.agents/plugins/marketplace.json")"
manifest_ref="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .source.ref' "$MARKETPLACE/.agents/plugins/marketplace.json")"
codex_plugin_v="$(jq -r '.version' "$REPO_ROOT/plugins/silver-bullet/.codex-plugin/plugin.json")"

assert_file_absent "thin marketplace does not vendor plugins/silver-bullet tree" "$MARKETPLACE/plugins/silver-bullet"
assert_equal "thin marketplace manifest version bumped" "$plugin_v" "$manifest_v"
assert_equal "thin marketplace manifest ref pinned to release tag" "v${plugin_v}" "$manifest_ref"
assert_equal "in-repo Codex plugin manifest version matches release" "$plugin_v" "$codex_plugin_v"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
