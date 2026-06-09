#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CURRENT_VERSION="$(jq -r '.version' "$REPO_ROOT/package.json")"

pass() {
  echo "PASS: $1"
  (( PASS++ )) || true
}

fail() {
  echo "FAIL: $1"
  (( FAIL++ )) || true
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qE "$needle" "$file"; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in ${file#$REPO_ROOT/}"
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" path="$3"
  if ! grep -R -n -E "$needle" "$path" >/tmp/sb-site-freshness.$$ 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — unexpected matches:"
    sed 's/^/  /' /tmp/sb-site-freshness.$$
  fi
  rm -f /tmp/sb-site-freshness.$$
}

assert_contains "homepage displays current package version" "v${CURRENT_VERSION}" "$REPO_ROOT/site/index.html"
assert_contains "Help Center displays current package version" "v${CURRENT_VERSION}" "$REPO_ROOT/site/help/index.html"
assert_contains "SB vs GSD page displays current package version" "v${CURRENT_VERSION}" "$REPO_ROOT/site/sb-vs-gsd/index.html"
assert_contains "reference config sample uses current package version" "\"version\"</span>: <span class=\"str\">\"${CURRENT_VERSION}\"" "$REPO_ROOT/site/help/reference/index.html"
assert_contains "search index config entry uses current package version" "version ${CURRENT_VERSION}" "$REPO_ROOT/site/help/search.js"
assert_contains "homepage documents Codex public marketplace package" "public alo-labs/codex-plugins marketplace package|public alo-labs/codex-plugins Codex marketplace package|public alo-labs/codex-plugins" "$REPO_ROOT/site/index.html"
assert_contains "Help Center documents Codex public marketplace package" "public <code>alo-labs/codex-plugins</code> marketplace package" "$REPO_ROOT/site/help/getting-started/index.html"
assert_contains "search index documents Codex public marketplace package" "public alo-labs/codex-plugins Codex marketplace package" "$REPO_ROOT/site/help/search.js"
assert_contains "package metadata includes Codex support" "Claude Code and Codex" "$REPO_ROOT/package.json"

assert_not_contains "public site does not mention stale v0.37.16" "v?0\\.37\\.16" "$REPO_ROOT/site"
assert_not_contains "Help Center install docs do not advertise retired runtime installer paths" "forge-sb-install|silver-init|Forge Runtime" "$REPO_ROOT/site/help"
assert_not_contains "public workflow docs do not route to missing SB-local MultAI skill" "silver:multai" "$REPO_ROOT/site"
assert_not_contains "package metadata does not advertise stale fixed-step Claude-only workflow" "20-step|24-step|for Claude Code\\." "$REPO_ROOT/package.json"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
