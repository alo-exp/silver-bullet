#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/validate-github-release-notes.sh"
PASS=0
FAIL=0
TMP="$(mktemp -d)"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

assert_pass() {
  local label="$1"
  local file="$2"
  if bash "$SCRIPT" --file "$file" >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_fail() {
  local label="$1"
  local file="$2"
  if bash "$SCRIPT" --file "$file" >/dev/null 2>&1; then
    echo "  FAIL: $label (expected rejection)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  fi
}

cat > "$TMP/good.md" <<'EOF'
## Bug Fixes
- `fix(scan): improve session discovery` (ab12e86)

## Tests
- `test(hooks): cover cross-runtime receipt lookup`
EOF

cat > "$TMP/generic.md" <<'EOF'
## @alo-labs/kay v0.9.25

See CHANGELOG.md for details.
EOF

cat > "$TMP/empty-sections.md" <<'EOF'
# v0.39.1

This release includes important fixes.
EOF

echo "=== validate-github-release-notes.sh ==="
assert_pass "accepts categorized release notes" "$TMP/good.md"
assert_fail "rejects generic CHANGELOG-only body" "$TMP/generic.md"
assert_fail "rejects body without categorized sections" "$TMP/empty-sections.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
