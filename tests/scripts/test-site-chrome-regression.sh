#!/usr/bin/env bash
# Regression guards for help chrome + homepage card hover parity.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qE -- "$needle" "$file"; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in ${file#$REPO_ROOT/}"
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if ! grep -qE -- "$needle" "$file"; then
    pass "$desc"
  else
    fail "$desc — unexpected [$needle] in ${file#$REPO_ROOT/}"
  fi
}

WORKFLOWS_INDEX="$REPO_ROOT/site/help/workflows/index.html"
CHROME_CSS="$REPO_ROOT/site/chrome.css"
TOKENS_CSS="$REPO_ROOT/site/tokens.css"
HOMEPAGE="$REPO_ROOT/site/index.html"

# 1. Orchestration Workflows title must not carry a spurious APO badge in the h1.
assert_contains "workflows index h1 is Orchestration Workflows" '<h1>Orchestration Workflows</h1>' "$WORKFLOWS_INDEX"
assert_not_contains "workflows index h1 has no inline APO badge span" 'Orchestration Workflows[[:space:]]*<span[^>]*>APO</span>' "$WORKFLOWS_INDEX"

# 2. Help subnav uses a dedicated background token distinct from site header nav.
assert_contains "tokens define light help-subnav background" '--help-subnav-bg:rgba\(232,226,216' "$TOKENS_CSS"
assert_contains "tokens define dark help-subnav background" 'help-subnav-bg:rgba\(16,28,44' "$TOKENS_CSS"
assert_contains "chrome applies help-subnav background token" 'background:var\(--help-subnav-bg\)' "$CHROME_CSS"

# 3. Homepage card hover is unified via shared selector block + --card-shadow-hover.
assert_contains "homepage unified card surface comment present" 'UNIFIED CARD SURFACE' "$HOMEPAGE"
assert_contains "homepage callout uses unified hover selector" '\.callout:hover,' "$HOMEPAGE"
assert_contains "homepage enforcement-block uses unified hover selector" '\.enforcement-block:hover\{' "$HOMEPAGE"
assert_contains "homepage unified hover uses card-shadow-hover token" 'box-shadow:var\(--card-shadow-hover\)' "$HOMEPAGE"

# No per-card hover overrides outside the unified block (duplicate pain-card:hover = regression).
hover_count="$(grep -c '\.pain-card:hover' "$HOMEPAGE" || true)"
if [[ "$hover_count" -eq 1 ]]; then
  pass "homepage has single pain-card:hover rule (unified block only)"
else
  fail "homepage has $hover_count pain-card:hover rules (expected 1 unified block)"
fi

# Callouts must not keep competing inset shadows that bypass unified hover.
assert_not_contains "homepage callouts omit inset box-shadow override" '\.callout\{[^}]*box-shadow:inset' "$HOMEPAGE"
assert_contains "neutral-variants s3 applies unified card hover shadow" 'html\[data-neutral-variant="s3"\] \.pain-card:hover' "$REPO_ROOT/site/neutral-variants.css"
assert_contains "neutral-variants s3 hover uses card-shadow-hover token" 'box-shadow:var\(--card-shadow-hover\) !important' "$REPO_ROOT/site/neutral-variants.css"

# 4. Single Alpha Honesty callout in #proof (no duplicate callout-label blocks).
alpha_count="$(grep -c 'callout-label.*Alpha Honesty' "$HOMEPAGE" || true)"
if [[ "$alpha_count" -eq 1 ]]; then
  pass "homepage has single Alpha Honesty callout"
else
  fail "homepage has $alpha_count Alpha Honesty callouts (expected 1)"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
