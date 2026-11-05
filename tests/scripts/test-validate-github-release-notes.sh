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

# The 0.51.7 CHANGELOG entry carries only a '### Fixes' section (R13-18): notes copied from
# the CHANGELOG must validate.
cat > "$TMP/fixes-only.md" <<'EOF'
## [0.51.7] — 2026-07-30

### Fixes
- `fix(hooks)`: keep the review ladder state across a session restart (`3f1a2b4c`)
EOF

cat > "$TMP/docs-only.md" <<'EOF'
### Docs
- `docs(release)`: describe the release order and the marketplace publish step
EOF

cat > "$TMP/keep-a-changelog.md" <<'EOF'
### Added
- A publish step for the unified marketplace.

### Fixed
- The release sync now pushes what it commits.
EOF

cat > "$TMP/lowercase.md" <<'EOF'
## bug fixes
- `fix(ci)`: lint every site page, not only the second-level ones
EOF

cat > "$TMP/not-a-category.md" <<'EOF'
### Headline
This release is mostly about the marketplace publish step.
EOF

echo "=== validate-github-release-notes.sh ==="
assert_pass "accepts categorized release notes" "$TMP/good.md"
assert_pass "accepts a CHANGELOG body with only '### Fixes'" "$TMP/fixes-only.md"
assert_pass "accepts '### Docs'" "$TMP/docs-only.md"
assert_pass "accepts Keep a Changelog sections (Added, Fixed)" "$TMP/keep-a-changelog.md"
assert_pass "accepts a category heading in any case" "$TMP/lowercase.md"
assert_fail "rejects generic CHANGELOG-only body" "$TMP/generic.md"
assert_fail "rejects body without categorized sections" "$TMP/empty-sections.md"
assert_fail "rejects a body whose only heading is not a category" "$TMP/not-a-category.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
