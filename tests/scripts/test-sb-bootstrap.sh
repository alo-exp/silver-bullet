#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/sb-bootstrap.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

chmod +x "$SCRIPT"

out="$(bash "$SCRIPT" "$REPO_ROOT" 2>&1)"
if grep -q "Silver Bullet bootstrap" <<<"$out"; then
  pass "bootstrap prints header"
else
  fail "bootstrap prints header"
fi

if grep -q "Zuvo / AS1 migrator quickstart" <<<"$out"; then
  pass "bootstrap includes migrator quickstart"
else
  fail "bootstrap includes migrator quickstart"
fi

if grep -q "jq installed" <<<"$out"; then
  pass "bootstrap checks jq"
else
  fail "bootstrap checks jq"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
