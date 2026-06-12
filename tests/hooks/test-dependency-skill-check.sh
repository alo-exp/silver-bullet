#!/usr/bin/env bash
# Tests for hooks/dependency-skill-check.sh
# Verifies absorbed legacy dependency skill surfaces no longer hard-block SB.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/dependency-skill-check.sh"
PASS=0
FAIL=0

setup() {
  TMPDIR_TEST=$(mktemp -d)
  export SILVER_BULLET_SKILL_ROOTS="$TMPDIR_TEST:$TMPDIR_TEST/plugins/cache"

  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF

  cat > "$TMPDIR_TEST/.silver-bullet.json" <<'EOF'
{
  "project": { "src_pattern": "/hooks/|/skills/|/templates/" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates", "verification-before-completion"]
  }
}
EOF
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  unset SILVER_BULLET_SKILL_ROOTS
}

run_hook() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_denied() {
  local output="$1"
  [[ -n "$output" ]] && printf '%s' "$output" | grep -q '"permissionDecision".*"deny"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected deny, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

make_skill() {
  local path="$1"
  local name="$2"
  mkdir -p "$(dirname "$TMPDIR_TEST/$path")"
  cat > "$TMPDIR_TEST/$path" <<EOF
---
name: $name
---

# $name
EOF
}

echo "=== dependency-skill-check.sh tests ==="

# Test 1: Missing absorbed Product Management dependency passes through
setup
out=$(run_hook "product-management:write-spec")
assert_passes "missing product-management:write-spec passes through" "$out"
teardown

# Test 2: product-management skill installed in skills/ passes
setup
make_skill "skills/product-management-write-spec/SKILL.md" "write-spec"
out=$(run_hook "product-management:write-spec")
assert_passes "installed product-management:write-spec passes" "$out"
teardown

# Test 3: design user-research installed in skills/ passes
setup
make_skill "skills/user-research/SKILL.md" "user-research"
out=$(run_hook "design:user-research")
assert_passes "installed design:user-research passes" "$out"
teardown

# Test 4: product-management skill installed in plugin upstream/skills passes
setup
make_skill "plugins/cache/alo-labs-codex/product-management/1.2.0/upstream/skills/write-spec/SKILL.md" "write-spec"
out=$(run_hook "product-management:write-spec")
assert_passes "installed product-management upstream write-spec passes" "$out"
teardown

# Test 5: Bare GSD dependency installed in skills/ passes
setup
make_skill "skills/gsd-plan-phase/SKILL.md" "gsd-plan-phase"
out=$(run_hook "gsd-plan-phase")
assert_passes "installed gsd-plan-phase passes" "$out"
teardown

# Test 6: Namespaced GSD dependency installed in skills/ passes
setup
make_skill "skills/gsd-discuss-phase/SKILL.md" "gsd-discuss-phase"
out=$(run_hook "gsd:discuss-phase")
assert_passes "installed gsd:discuss-phase passes" "$out"
teardown

# Test 7: Bare legacy optional skill passes through when missing
setup
out=$(run_hook "clarify")
assert_passes "missing clarify passes through" "$out"
teardown

# Test 8: Non-dependency skill passes through
setup
out=$(run_hook "silver:fast")
assert_passes "silver:fast passes" "$out"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
