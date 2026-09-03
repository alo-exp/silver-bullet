#!/usr/bin/env bash
# Tests for scripts/validate-launch-review.sh and validate-sentinel-skills-manifest.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

assert_pass() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

assert_fail() {
  local name="$1"
  shift
  if ! "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected failure)"
    FAIL=$((FAIL + 1))
  fi
}

echo "--- validate-launch-review.sh ---"
assert_pass "live LAUNCH-REVIEW passes" \
  bash "$REPO_ROOT/scripts/validate-launch-review.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cat > "$tmpdir/bad-review.md" <<'EOF'
---
status: in-progress
discovery_clean_streak: 1
manifest_completion: "100/1177"
git_clean: false
---
EOF
assert_fail "bad frontmatter fails" \
  bash "$REPO_ROOT/scripts/validate-launch-review.sh" --file "$tmpdir/bad-review.md"

echo "--- validate-sentinel-skills-manifest.sh ---"
assert_pass "live sentinel manifest passes" \
  bash "$REPO_ROOT/scripts/validate-sentinel-skills-manifest.sh" --release-tag v0.45.0

echo "--- generate-sentinel-skills-manifest.sh ---"
assert_pass "generate manifest succeeds" \
  bash "$REPO_ROOT/scripts/generate-sentinel-skills-manifest.sh" \
    --out-dir "$tmpdir/generated-sentinel-skills" \
    --release-tag v0.45.0

expected_generated_count="$(find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -print | wc -l | tr -d ' ')"
generated_count="$(jq 'length' "$tmpdir/generated-sentinel-skills/manifest.json")"
if [[ "$generated_count" -eq "$expected_generated_count" ]]; then
  echo "PASS: generated manifest matches current skill inventory"
  PASS=$((PASS + 1))
else
  echo "FAIL: generated manifest count $generated_count != current inventory $expected_generated_count"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
