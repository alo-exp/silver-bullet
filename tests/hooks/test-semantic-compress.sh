#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — looking for: [$needle]"; (( FAIL++ )) || true; fi
}

assert_json_key() {
  local desc="$1" key="$2" output="$3"
  if printf '%s' "$output" | jq -e "$key" > /dev/null 2>&1; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — key $key not found"; (( FAIL++ )) || true; fi
}

assert_neq() {
  local desc="$1" a="$2" b="$3"
  if [[ "$a" != "$b" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — values are identical when they should differ"; (( FAIL++ )) || true; fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true; fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/semantic-compress.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Setup fake project
mkdir -p "$TMP/src" "$TMP/docs" "$TMP/.planning"

cat > "$TMP/.silver-bullet.json" << 'JSON'
{
  "project": { "name": "testproject", "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\.test\\." },
  "semantic_compression": { "enabled": true, "context_budget_kb": 50, "min_file_size_bytes": 50, "chunk_size_bytes": 50, "top_chunks_per_file": 3, "debug": false }
}
JSON

echo "# Implement authentication middleware" > "$TMP/.planning/phase1-CONTEXT.md"
printf 'auth_validate() {\n  check_token "$1"\n}\n' > "$TMP/src/auth.sh"
printf '# Auth Docs\nDescribes authentication flow.\n' > "$TMP/docs/auth.md"

# Test 1: produces valid JSON with additionalContext
output=$(cd "$TMP" && REPO_ROOT="$TMP" printf '{"tool_input":{"skill":"gsd:execute-phase"}}' | "$HOOK")
assert_json_key "output is valid JSON" '.hookSpecificOutput.additionalContext' "$output"

# Test 2: context contains src file and phase goal
context=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
assert_contains "context contains src/auth.sh" "src/auth.sh" "$context"
assert_contains "context contains phase goal" "authentication middleware" "$context"

# Test 3: non-phase skill produces no output
output2=$(cd "$TMP" && REPO_ROOT="$TMP" printf '{"tool_input":{"skill":"superpowers:brainstorming"}}' | "$HOOK")
assert_eq "non-phase skill: no output" "" "$output2"

# Test 4: cache hit — same input returns identical output
output3=$(cd "$TMP" && REPO_ROOT="$TMP" printf '{"tool_input":{"skill":"gsd:execute-phase"}}' | "$HOOK")
assert_eq "cache hit: identical output on second call" "$output" "$output3"

# Test 5: cache invalidation — modify file, output changes
printf 'new_function_completely_different() { true; }\n' >> "$TMP/src/auth.sh"
# Ensure mtime differs from cached value for reliable cache invalidation.
# GNU touch -d is faster than sleep on Linux CI; BSD fallback uses sleep 1.
touch -d '+2 seconds' "$TMP/src/auth.sh" 2>/dev/null || sleep 1
output4=$(cd "$TMP" && REPO_ROOT="$TMP" printf '{"tool_input":{"skill":"gsd:execute-phase"}}' | "$HOOK")
context4=$(printf '%s' "$output4" | jq -r '.hookSpecificOutput.additionalContext')
context1=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
assert_neq "cache invalidated after file change" "$context1" "$context4"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
