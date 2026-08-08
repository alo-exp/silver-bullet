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
CODEX_CFG_V="$(jq -r '.config_version' "$REPO_ROOT/plugins/silver-bullet/.codex-plugin/plugin.json")"

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
  "$REPO_ROOT/.cursor-plugin/marketplace.json" \
  "$REPO_ROOT/.agents/plugins/marketplace.json"
do
  name="$(basename "$marketplace")"
  check_eq "$name silver-bullet version matches package.json" "$PKG_V" \
    "$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$marketplace")"
done

check_eq "config template config_version matches package.json" "$PKG_V" "$CFG_V"
check_eq "Codex plugin config_version matches package.json" "$PKG_V" "$CODEX_CFG_V"

for runtime in cursor claude codex; do
  catalog_version="$(jq -r --arg runtime "$runtime" \
    '.plugins[] | select(.name=="silver-bullet") | .[$runtime].version' \
    "$REPO_ROOT/scripts/lib/agent-plugins-catalog.json")"
  check_eq "agent-plugins catalog $runtime version matches package.json" "$PKG_V" "$catalog_version"
done

check_eq "agent-plugins catalog Codex ref matches package.json" "v$PKG_V" \
  "$(jq -r '.plugins[] | select(.name=="silver-bullet") | .codex.ref' \
    "$REPO_ROOT/scripts/lib/agent-plugins-catalog.json")"

README_VERSION="$(sed -n '/^## Current Release$/,/^## /s/^- Version: `\([^`]*\)`.*/\1/p' "$REPO_ROOT/README.md" | head -1)"
README_RELEASE="$(sed -n '/^## Current Release$/,/^## /s/^- Release: \[v\([^]]*\)\].*/\1/p' "$REPO_ROOT/README.md" | head -1)"
check_eq "README current version matches package.json" "$PKG_V" "$README_VERSION"
check_eq "README release link matches package.json" "$PKG_V" "$README_RELEASE"

SUPPORTED_SERIES="$(awk -F'|' '$2 ~ /^[[:space:]]*[0-9]+\.[0-9]+\.x[[:space:]]*$/ && $3 ~ /Yes/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$REPO_ROOT/SECURITY.md")"
check_eq "security policy supported series matches package.json" "${PKG_V%.*}.x" "$SUPPORTED_SERIES"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
