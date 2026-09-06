#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -F "$needle" >/dev/null <<<"$haystack"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
  fi
}

workflow="$(cd "$(dirname "$0")/../.." && pwd)/.github/workflows/announce-release.yml"
content="$(cat "$workflow")"

assert_contains "workflow uses fixed thread key" "silver-bullet-updates" "$content"
assert_contains "workflow sets threadKey" "threadKey" "$content"
assert_contains "workflow falls back to new thread" "messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD" "$content"
assert_contains "workflow keeps stable thread title" "Silver Bullet Updates" "$content"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
