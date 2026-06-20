#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/tests/e2e-live/lib/route-smoke-transcript.py"
FIXTURE_DIR="${REPO_ROOT}/tests/e2e-live/fixtures/route-smoke-transcript"
PASS=0
FAIL=0

assert_passes() {
  local label="$1"
  shift
  if "$@"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_fails() {
  local label="$1"
  shift
  if "$@"; then
    echo "FAIL: $label (expected failure)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $label"
    PASS=$((PASS + 1))
  fi
}

assert_passes "direct argv adapter invocation accepted" \
  python3 "$SCRIPT" "${FIXTURE_DIR}/direct-adapter.jsonl" "silver:ingest"

assert_passes "bash -lc wrapped adapter invocation accepted" \
  python3 "$SCRIPT" "${FIXTURE_DIR}/bash-lc-adapter.jsonl" "silver:ingest"

assert_passes "route-smoke completion echo wrappers around adapter accepted" \
  python3 "$SCRIPT" "${FIXTURE_DIR}/echo-adapter-echo.jsonl" "silver:forensics"

assert_passes "duplicate identical adapter invocations accepted" \
  python3 "$SCRIPT" "${FIXTURE_DIR}/duplicate-adapter.jsonl" "silver:feature"

assert_fails "exploratory command before adapter rejected" \
  python3 "$SCRIPT" "${FIXTURE_DIR}/extra-command.jsonl" "silver:ingest"

assert_fails "stale transcript prompt rejected" \
  python3 "$SCRIPT" "${FIXTURE_DIR}/stale-prompt.jsonl" "silver:ingest"

assert_fails "hook bridge only transcript rejected" \
  python3 "$SCRIPT" "${FIXTURE_DIR}/hook-bridge-only.jsonl" "silver:ingest"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
