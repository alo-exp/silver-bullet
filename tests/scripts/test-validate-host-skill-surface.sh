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

# R8-06: N directories exposing the identical route are duplicates, too.
dup_same_root="$tmpdir/bad-dup-same-name"
write_skill "$dup_same_root/host-bundles/codex" "sb-feature" "sb:feature"
write_skill "$dup_same_root/host-bundles/codex" "sb-feature-dup" "sb:feature"
dup_out="$(bash "$SCRIPT" --repo-root "$dup_same_root" 2>&1)" && dup_rc=0 || dup_rc=$?
if [[ "$dup_rc" -eq 1 && "$dup_out" == *"logical route 'sb:feature' exposed 2 times"* && "$dup_out" == *"codex: FAIL"* ]]; then
  echo "PASS: two Codex dirs with the same route fail (R8-06)"; PASS=$((PASS + 1))
else
  echo "FAIL: two Codex dirs with the same route fail (R8-06) rc=$dup_rc: $dup_out"; FAIL=$((FAIL + 1))
fi
if [[ "$dup_out" != *"deduplicated"* ]]; then
  echo "PASS: duplicate surface is not reported as deduplicated"; PASS=$((PASS + 1))
else
  echo "FAIL: duplicate surface is not reported as deduplicated"; FAIL=$((FAIL + 1))
fi
codex_dir_root="$tmpdir/bad-codex-dir"
write_skill "$codex_dir_root/host-bundles/codex" "zz-unprefixed" "sb:feature"
dir_out="$(bash "$SCRIPT" --repo-root "$codex_dir_root" 2>&1)" && dir_rc=0 || dir_rc=$?
if [[ "$dir_rc" -eq 1 && "$dir_out" == *"host-bundles/codex/zz-unprefixed/SKILL.md: directory 'zz-unprefixed' does not match route 'sb-feature'"* ]]; then
  echo "PASS: a Codex dir not named sb-<route> fails"; PASS=$((PASS + 1))
else
  echo "FAIL: a Codex dir not named sb-<route> fails rc=$dir_rc: $dir_out"; FAIL=$((FAIL + 1))
fi
hy_out="$(bash "$SCRIPT" --repo-root "$hyphen_root" 2>&1)" || true
mkdir -p "$hyphen_root/agents/claude/sb-feature"
hy_out="$(bash "$SCRIPT" --repo-root "$hyphen_root" 2>&1)" || true
if [[ "$(grep -c 'redundant hyphen directory agents/claude/sb-feature' <<<"$hy_out")" -eq 1 ]]; then
  echo "PASS: a hyphen directory is reported once, not once per host"; PASS=$((PASS + 1))
else
  echo "FAIL: a hyphen directory is reported once, not once per host: $hy_out"; FAIL=$((FAIL + 1))
fi

echo "--- validate-host-skill-surface.sh (live repo) ---"
assert_pass "live repo passes" \
  bash "$SCRIPT" --repo-root "$REPO_ROOT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
