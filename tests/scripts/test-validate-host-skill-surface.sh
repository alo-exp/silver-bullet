#!/usr/bin/env bash
# Tests for scripts/validate-host-skill-surface.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/validate-host-skill-surface.sh"
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

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

write_skill() {
  local root="$1" dir="$2" name="$3" invocable="${4:-true}"
  mkdir -p "$root/$dir"
  cat >"$root/$dir/SKILL.md" <<EOF
---
name: ${name}
user-invocable: ${invocable}
---
body
EOF
}

write_command() {
  local root="$1" file="$2" name="$3"
  mkdir -p "$root"
  cat >"$root/$file" <<EOF
---
name: "${name}"
title: "Test"
---
body
EOF
}

fixture_root="$tmpdir/good"
write_skill "$fixture_root/agents/claude" "sb" "sb"
write_skill "$fixture_root/agents/claude" "sb:feature" "sb:feature"
write_skill "$fixture_root/agents/claude" "modularity" "modularity" "false"
write_skill "$fixture_root/host-bundles/codex" "sb" "sb"
write_skill "$fixture_root/host-bundles/codex" "sb:feature" "sb:feature" "false"
write_skill "$fixture_root/host-bundles/cursor" "sb" "sb"
write_skill "$fixture_root/host-bundles/cursor" "sb:plan" "sb:plan"
  write_command "$fixture_root/plugins/silver-bullet/commands" "sb-feature.md" "sb-feature"

bad_prefix_root="$tmpdir/bad-prefix"
write_skill "$bad_prefix_root/host-bundles/cursor" "silver-feature" "silver-feature"

bad_command_stem_root="$tmpdir/bad-command-stem"
write_command "$bad_command_stem_root/plugins/silver-bullet/commands" "init.md" "sb:init"
write_skill "$bad_command_stem_root/host-bundles/cursor" "sb:plan" "sb:plan"

dup_root="$tmpdir/bad-dup"
write_skill "$dup_root/host-bundles/cursor" "silver-feature" "silver-feature"
  write_command "$dup_root/plugins/silver-bullet/commands" "sb-feature.md" "sb-feature"

hyphen_root="$tmpdir/bad-hyphen"
write_skill "$hyphen_root/agents/claude" "silver-feature" "sb:feature"

overlap_root="$tmpdir/bad-overlap"
write_skill "$overlap_root/host-bundles/cursor" "sb:feature" "sb:feature"
  write_command "$overlap_root/plugins/silver-bullet/commands" "sb-feature.md" "sb-feature"

echo "--- validate-host-skill-surface.sh (fixtures) ---"
assert_pass "clean fixture passes" \
  bash "$SCRIPT" --repo-root "$fixture_root"
assert_fail "bad prefix fails" \
  bash "$SCRIPT" --repo-root "$bad_prefix_root"
assert_fail "command filename stem mismatch fails" \
  bash "$SCRIPT" --repo-root "$bad_command_stem_root"
assert_fail "duplicate route names fail" \
  bash "$SCRIPT" --repo-root "$dup_root"
assert_fail "claude hyphen directory fails" \
  bash "$SCRIPT" --repo-root "$hyphen_root"
assert_fail "cursor command/skill overlap fails" \
  bash "$SCRIPT" --repo-root "$overlap_root"

echo "--- validate-host-skill-surface.sh (live repo) ---"
assert_pass "live repo passes" \
  bash "$SCRIPT" --repo-root "$REPO_ROOT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
