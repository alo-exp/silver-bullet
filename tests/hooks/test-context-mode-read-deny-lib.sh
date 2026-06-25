#!/usr/bin/env bash
# Unit tests for hooks/lib/context-mode-read-deny.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=hooks/lib/tool-input.sh
source "$REPO_ROOT/hooks/lib/tool-input.sh"
# shellcheck source=hooks/lib/context-mode-read-deny.sh
source "$REPO_ROOT/hooks/lib/context-mode-read-deny.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_deny() {
  local label="$1"
  if sb_context_mode_should_deny_read "$2" "$3" "$4"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected deny"
    FAIL=$((FAIL + 1))
  fi
}

assert_allow() {
  local label="$1"
  if sb_context_mode_should_deny_read "$2" "$3" "$4"; then
    echo "  FAIL: $label — expected allow"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  fi
}

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
TMPCFG="$TMPDIR_TEST/.silver-bullet.json"
printf '{"recommended_tools":{"context_mode":{"read_deny_bytes":5120}}}\n' >"$TMPCFG"
LARGE="$TMPDIR_TEST/large.txt"
SMALL="$TMPDIR_TEST/small.txt"
python3 -c "open('$LARGE','wb').write(b'x'*6000)"
printf 'hi' >"$SMALL"

echo "=== context-mode-read-deny lib tests ==="
assert_eq "default threshold override" "5120" "$(sb_context_mode_read_deny_bytes "$TMPCFG")"

payload_large=$(jq -n --arg f "$LARGE" '{tool_name:"Read", tool_input:{file_path:$f}}')
payload_small=$(jq -n --arg f "$SMALL" '{tool_name:"Read", tool_input:{file_path:$f}}')
assert_deny "large file" "$payload_large" "$TMPCFG" "$TMPDIR_TEST"
assert_allow "small file" "$payload_small" "$TMPCFG" "$TMPDIR_TEST"

exempt="$TMPDIR_TEST/.silver-bullet/state/foo"
mkdir -p "$(dirname "$exempt")"
cp "$LARGE" "$exempt"
payload_exempt=$(jq -n --arg f "$exempt" '{tool_name:"Read", tool_input:{file_path:$f}}')
assert_allow "state path exempt" "$payload_exempt" "$TMPCFG" "$TMPDIR_TEST"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
