#!/usr/bin/env bash
# Tests for scripts/run-pre-release-host-smoke.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/run-pre-release-host-smoke.sh"
ISOLATION="$REPO_ROOT/scripts/lib/pre-release-host-isolation.sh"
VALIDATOR="$REPO_ROOT/scripts/validate-host-skill-surface.sh"
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

assert_contains() {
  local haystack="$1" needle="$2"
  grep -F -- "$needle" <<<"$haystack" >/dev/null
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  ! grep -F -- "$needle" <<<"$haystack" >/dev/null
}

script_body="$(<"$SCRIPT")"
isolation_body="$(<"$ISOLATION")"
gate_doc="$(<"$REPO_ROOT/docs/internal/pre-release-quality-gate.md")"

echo "--- run-pre-release-host-smoke.sh wiring ---"
assert_pass "script exists and is executable" test -x "$SCRIPT"
assert_pass "script sources isolation helper" assert_contains "$script_body" "pre-release-host-isolation.sh"
assert_pass "script references validate-host-skill-surface" assert_contains "$script_body" "validate-host-skill-surface.sh"
assert_pass "script no longer runs a Cursor CLI smoke" assert_not_contains "$script_body" "cursor-cli-smoke"
assert_pass "script uses host-bundles for codex route" assert_contains "$script_body" "sb_agent_bundle_root"
assert_pass "script does not reference agents/codex checkout path" assert_not_contains "$script_body" 'agents/codex"'
assert_pass "script does not reference host-bundles/cursor" assert_not_contains "$script_body" "host-bundles/cursor"
assert_pass "script writes pre-release-host-smoke marker" assert_contains "$script_body" "pre-release-host-smoke"

echo "--- isolation ---"
assert_pass "isolation helper documents isolated homes" assert_contains "$isolation_body" "never read or write"
assert_pass "isolation has no Cursor config" assert_not_contains "$isolation_body" "CURSOR_CONFIG_DIR"

echo "--- pre-release-quality-gate.md wiring ---"
assert_pass "quality gate doc mandates host smoke" assert_contains "$gate_doc" "run-pre-release-host-smoke.sh"
assert_pass "quality gate doc has no Cursor host smoke" assert_not_contains "$gate_doc" "pre-release-cursor-cli-smoke"

echo "--- silver-create-release SKILL wiring ---"
RELEASE_SKILL="$REPO_ROOT/skills/silver-create-release/SKILL.md"
assert_pass "create-release skill lists host smoke" assert_contains "$(<"$RELEASE_SKILL")" "run-pre-release-host-smoke.sh"

echo "--- validate-host-skill-surface.sh (live repo) ---"
assert_pass "live repo passes validate-host-skill-surface" bash "$VALIDATOR" --repo-root "$REPO_ROOT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
