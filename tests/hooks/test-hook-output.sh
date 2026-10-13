#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

# shellcheck source=hooks/lib/hook-output.sh
source "${REPO_ROOT}/hooks/lib/hook-output.sh"

out="$(sb_emit_hook_message PostToolUse 'hello')"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null; then
  echo "PASS: includes hookEventName"
  ((PASS++)) || true
else
  echo "FAIL: includes hookEventName"
  ((FAIL++)) || true
fi
if printf '%s' "$out" | jq -e '.hookSpecificOutput.message == "hello"' >/dev/null; then
  echo "PASS: includes message"
  ((PASS++)) || true
else
  echo "FAIL: includes message"
  ((FAIL++)) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
