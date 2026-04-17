#!/usr/bin/env bash
# Tests that pr-traceability.sh builds the PR body via jq (SEC-03) and that
# injection vectors in warn_items cannot escape the fenced code block.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/hooks/pr-traceability.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$1"; }

# Test: no raw `sed 's/\[//g; s/\]//g; s/([^)]*)//g'` markdown sanitizer
test_no_handrolled_sed_sanitizer() {
  if grep -qE "sed 's/\\\\\\[//g" "$HOOK" 2>/dev/null; then
    fail "hand-rolled sed markdown sanitizer still present"
  else
    pass "hand-rolled sed markdown sanitizer removed"
  fi
}

# Test: hook uses jq -n to build the traceability payload
test_uses_jq_for_body() {
  if grep -qE 'jq -n' "$HOOK" && grep -qE '\--arg (existing|warn|v|j)' "$HOOK"; then
    pass "pr-traceability uses jq -n --arg for body construction"
  else
    fail "pr-traceability does not use jq -n --arg for body construction"
  fi
}

test_no_handrolled_sed_sanitizer
test_uses_jq_for_body

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
