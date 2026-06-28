#!/usr/bin/env bash
# Structural tests for tri-host install smoke wiring.
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in $file"
  fi
}

assert_file_exists "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "tri-host smoke script exists"
chmod +x "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh"
assert_executable "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "tri-host smoke script executable"

assert_file_exists "${REPO_ROOT}/docs/testing/pre-release-claims-registry.json" "pre-release claims registry exists"
assert_contains "pre-release registry wires tri-host smoke" \
  "${REPO_ROOT}/docs/testing/pre-release-claims-registry.json" "run-tri-host-install-smoke.sh"
assert_contains "pre-release registry documents hero-tri-host" \
  "${REPO_ROOT}/docs/testing/pre-release-claims-registry.json" "hero-tri-host"

PLAN="${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md"
assert_contains "validation plan documents pre-release taxonomy" "$PLAN" "Pre-release"
assert_contains "validation plan documents tri-host smoke" "$PLAN" "tri-host"

# Codex + Cursor smoke (no live Claude CLI required in CI)
if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" --host codex >/tmp/sb-trihost-codex.log 2>&1; then
  pass "codex tri-host smoke executes"
else
  fail "codex tri-host smoke failed — see /tmp/sb-trihost-codex.log"
fi

if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" --host cursor >/tmp/sb-trihost-cursor.log 2>&1; then
  pass "cursor tri-host smoke executes"
else
  fail "cursor tri-host smoke failed — see /tmp/sb-trihost-cursor.log"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
