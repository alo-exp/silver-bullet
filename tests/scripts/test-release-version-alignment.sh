#!/usr/bin/env bash
# Release version alignment — all in-repo manifests must match package.json.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

check_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ok: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc — expected $expected, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

PKG_V="$(jq -r '.version' "$REPO_ROOT/package.json")"
CFG_V="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"

echo "[release-version-alignment]"

for manifest in \
  "$REPO_ROOT/.claude-plugin/plugin.json" \
  "$REPO_ROOT/.cursor-plugin/plugin.json" \
  "$REPO_ROOT/plugins/silver-bullet/.cursor-plugin/plugin.json" \
  "$REPO_ROOT/plugins/silver-bullet/.codex-plugin/plugin.json"
do
  name="$(basename "$(dirname "$manifest")")/$(basename "$manifest")"
  check_eq "$name version matches package.json" "$PKG_V" "$(jq -r '.version' "$manifest")"
done

for marketplace in \
  "$REPO_ROOT/.claude-plugin/marketplace.json" \
  "$REPO_ROOT/.cursor-plugin/marketplace.json"
do
  name="$(basename "$marketplace")"
  check_eq "$name silver-bullet version matches package.json" "$PKG_V" \
    "$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$marketplace")"
done

check_eq "config template config_version matches package.json" "$PKG_V" "$CFG_V"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
