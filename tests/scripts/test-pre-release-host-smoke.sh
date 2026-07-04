#!/usr/bin/env bash
# Tests for scripts/run-pre-release-host-smoke.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/run-pre-release-host-smoke.sh"
CURSOR_CLI="$REPO_ROOT/scripts/pre-release-cursor-cli-smoke.sh"
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
  printf '%s' "$haystack" | grep -qF -- "$needle"
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  ! printf '%s' "$haystack" | grep -qF -- "$needle"
}

script_body="$(<"$SCRIPT")"
isolation_body="$(<"$ISOLATION")"
cursor_body="$(<"$CURSOR_CLI")"
gate_doc="$(<"$REPO_ROOT/docs/internal/pre-release-quality-gate.md")"

echo "--- run-pre-release-host-smoke.sh wiring ---"
assert_pass "script exists and is executable" test -x "$SCRIPT"
assert_pass "script sources isolation helper" assert_contains "$script_body" "pre-release-host-isolation.sh"
assert_pass "script references validate-host-skill-surface" assert_contains "$script_body" "validate-host-skill-surface.sh"
assert_pass "script references pre-release-cursor-cli-smoke" assert_contains "$script_body" "pre-release-cursor-cli-smoke.sh"
assert_pass "script uses host-bundles for codex route" assert_contains "$script_body" "sb_agent_bundle_root"
assert_pass "script does not reference agents/codex checkout path" assert_not_contains "$script_body" 'agents/codex"'
assert_pass "script does not reference agents/cursor checkout path" assert_not_contains "$script_body" 'agents/cursor"'
assert_pass "script writes pre-release-host-smoke marker" assert_contains "$script_body" "pre-release-host-smoke"

echo "--- isolation + cursor CLI auth policy ---"
assert_pass "isolation helper documents isolated homes" assert_contains "$isolation_body" "never read or write"
assert_pass "isolation uses CURSOR_CONFIG_DIR" assert_contains "$isolation_body" "CURSOR_CONFIG_DIR"
assert_pass "isolation uses fake HOME for cursor" assert_contains "$isolation_body" "fake-home"
assert_pass "cursor CLI uses --plugin-dir" assert_contains "$cursor_body" "--plugin-dir"
assert_pass "cursor CLI uses --workspace" assert_contains "$cursor_body" "--workspace"
assert_pass "cursor CLI uses AGENT_CLI_CREDENTIAL_STORE=memory" assert_contains "$cursor_body" "AGENT_CLI_CREDENTIAL_STORE=memory"
assert_pass "cursor CLI passes --api-key" assert_contains "$cursor_body" "api-key"
assert_pass "isolation accepts HOST_API_KEY alias" assert_contains "$isolation_body" "HOST_API_KEY"
assert_pass "isolation supports operator cursor-api-key file" assert_contains "$isolation_body" ".silver-bullet/cursor-api-key"
assert_pass "cursor CLI forbids login" assert_contains "$cursor_body" "Do not use cursor-agent login"
assert_pass "cursor CLI forbids status" assert_contains "$cursor_body" "Never calls"
assert_pass "quality gate doc documents official cursor isolation" assert_contains "$gate_doc" "CURSOR_CONFIG_DIR"

echo "--- pre-release-quality-gate.md wiring ---"
assert_pass "quality gate doc mandates host smoke" assert_contains "$gate_doc" "run-pre-release-host-smoke.sh"
assert_pass "quality gate doc documents memory credential store" assert_contains "$gate_doc" "AGENT_CLI_CREDENTIAL_STORE=memory"
assert_pass "quality gate doc no longer marks cursor smoke optional only" assert_not_contains "$gate_doc" "Optional Cursor smoke:"

echo "--- silver-create-release SKILL wiring ---"
RELEASE_SKILL="$REPO_ROOT/skills/silver-create-release/SKILL.md"
assert_pass "create-release skill lists host smoke" assert_contains "$(<"$RELEASE_SKILL")" "run-pre-release-host-smoke.sh"

echo "--- validate-host-skill-surface.sh (live repo) ---"
assert_pass "live repo passes validate-host-skill-surface" bash "$VALIDATOR" --repo-root "$REPO_ROOT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
