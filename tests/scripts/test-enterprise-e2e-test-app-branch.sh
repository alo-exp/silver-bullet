#!/usr/bin/env bash
# Structural tests for enterprise-grade-test-app fixture branch isolation policy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in $file"
  fi
}

HARNESS_CONFIG="${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json"
HARNESS_CORE="${REPO_ROOT}/scripts/enterprise-e2e/lib/core.sh"
METHODOLOGY="${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md"

[[ -f "$HARNESS_CONFIG" ]] && pass "hosts.json exists" || fail "hosts.json exists — missing $HARNESS_CONFIG"
[[ -f "$HARNESS_CORE" ]] && pass "harness core lib exists" || fail "harness core lib exists — missing $HARNESS_CORE"
[[ -f "$METHODOLOGY" ]] && pass "methodology doc exists" || fail "methodology doc exists — missing $METHODOLOGY"

assert_contains "core lib defines enterprise_e2e_fixture_branch" "$HARNESS_CORE" "enterprise_e2e_fixture_branch()"
assert_contains "core lib defines enterprise_e2e_fixture_ensure_branch" "$HARNESS_CORE" "enterprise_e2e_fixture_ensure_branch()"
assert_contains "core lib defines enterprise_e2e_assert_row_product_commit_delta" "$HARNESS_CORE" "enterprise_e2e_assert_row_product_commit_delta()"
assert_contains "methodology documents fixture branch pattern" "$METHODOLOGY" "enterprise-e2e/round-"
assert_contains "methodology documents SB_E2E_TEST_APP_BRANCH" "$METHODOLOGY" "SB_E2E_TEST_APP_BRANCH"

if command -v jq >/dev/null 2>&1; then
  for host in claude codex cursor; do
    branch="$(jq -r --arg h "$host" '.hosts[$h].fixture_branch // empty' "$HARNESS_CONFIG")"
    if [[ -n "$branch" && "$branch" == enterprise-e2e/* ]]; then
      pass "hosts.json fixture_branch for $host: $branch"
    elif [[ -n "$branch" ]]; then
      fail "hosts.json fixture_branch for $host must match enterprise-e2e/* (got: $branch)"
    else
      fail "hosts.json missing fixture_branch for $host"
    fi
  done
else
  pass "hosts.json parse skipped (jq missing)"
fi

# shellcheck source=scripts/enterprise-e2e/lib/core.sh
source "$HARNESS_CORE"

export SB_E2E_LIVE_RUNTIME=codex
export SILVER_BULLET_RUNTIME=codex
codex_branch="$(enterprise_e2e_fixture_branch)"
if [[ "$codex_branch" == "enterprise-e2e/round-9-codex" ]]; then
  pass "enterprise_e2e_fixture_branch resolves codex → $codex_branch"
else
  fail "enterprise_e2e_fixture_branch codex expected enterprise-e2e/round-9-codex (got: ${codex_branch:-empty})"
fi

export SB_E2E_LIVE_RUNTIME=cursor
export SILVER_BULLET_RUNTIME=cursor
cursor_branch="$(enterprise_e2e_fixture_branch)"
if [[ -n "$cursor_branch" && "$cursor_branch" == enterprise-e2e/* ]]; then
  pass "enterprise_e2e_fixture_branch resolves cursor → $cursor_branch"
else
  fail "enterprise_e2e_fixture_branch cursor must match enterprise-e2e/* (got: ${cursor_branch:-empty})"
fi

DEFAULT_FIXTURE_ROOT="$(cd "${REPO_ROOT}/../.." && pwd)/enterprise-grade-test-app"
FIXTURE_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-$DEFAULT_FIXTURE_ROOT}"
if [[ -d "${FIXTURE_ROOT}/.git" ]]; then
  if git -C "$FIXTURE_ROOT" show-ref --verify --quiet "refs/heads/enterprise-e2e/round-9-codex" 2>/dev/null; then
    pass "fixture repo has enterprise-e2e/round-9-codex branch"
  else
    fail "fixture repo missing enterprise-e2e/round-9-codex branch"
  fi
  baseline_sha="${SB_E2E_TEST_APP_BASELINE_SHA:-09f8d1a}"
  if git -C "$FIXTURE_ROOT" merge-base --is-ancestor "$baseline_sha" enterprise-e2e/round-9-codex 2>/dev/null; then
    pass "round-9-codex contains baseline $baseline_sha"
  else
    fail "round-9-codex must contain baseline $baseline_sha"
  fi
  if git -C "$FIXTURE_ROOT" rev-parse enterprise-e2e/round-9-codex 2>/dev/null | grep -q .; then
    head_sha="$(git -C "$FIXTURE_ROOT" rev-parse --short enterprise-e2e/round-9-codex 2>/dev/null || true)"
    if git -C "$FIXTURE_ROOT" merge-base --is-ancestor 826cb5c enterprise-e2e/round-9-codex 2>/dev/null; then
      fail "round-9-codex must not include pre-seed 826cb5c (got HEAD $head_sha)"
    else
      pass "round-9-codex excludes pre-seed 826cb5c (honest product baseline)"
    fi
  fi
else
  pass "fixture repo check skipped (no git at $FIXTURE_ROOT)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
