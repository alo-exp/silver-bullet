#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPLOG="$(mktemp)"

assert_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

assert_fail() {
  local desc="$1"
  shift
  if "$@"; then
    echo "FAIL: $desc — expected failure"
    ((FAIL++)) || true
  else
    echo "PASS: $desc"
    ((PASS++)) || true
  fi
}

trap 'rm -f "$TMPLOG"' EXIT

# shellcheck source=scripts/lib/matrix-quota.sh
source "${REPO_ROOT}/scripts/lib/matrix-quota.sh"

assert_ok "detects 429 in output" is_quota_failure "API Error: 429 Token Plan usage limit" ""
printf 'usage limit reached\n' >"$TMPLOG"
assert_ok "detects usage limit in log" is_quota_failure "" "$TMPLOG"
assert_fail "rejects unrelated timeout" is_quota_failure "ERROR: timed out waiting for Claude response" ""

script_body="$(cat "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh")"
if grep -qF 'SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL' <<<"$script_body"; then
  echo "PASS: matrix script documents quota retry interval"
  ((PASS++)) || true
else
  echo "FAIL: matrix script documents quota retry interval"
  ((FAIL++)) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
