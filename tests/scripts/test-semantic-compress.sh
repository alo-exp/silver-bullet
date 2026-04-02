#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true; fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — looking for: [$needle]"; (( FAIL++ )) || true; fi
}

assert_json_key() {
  local desc="$1" key="$2" output="$3"
  if printf '%s' "$output" | jq -e "$key" > /dev/null 2>&1; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc — key $key not found in JSON"; (( FAIL++ )) || true; fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/semantic-compress.sh"
REPO_ROOT_ORIG="$(cd "$(dirname "$0")/../.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

base_config() {
  cat > "$TMP/.silver-bullet.json" << 'JSON'
{
  "project": { "name": "test", "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\.test\\." },
  "semantic_compression": { "enabled": true, "context_budget_kb": 50, "min_file_size_bytes": 100, "chunk_size_bytes": 50, "top_chunks_per_file": 3, "debug": false }
}
JSON
}

# Test 1: no .planning/ — empty output
base_config
result=$(cd "$TMP" && REPO_ROOT="$TMP" "$SCRIPT" 2>/dev/null || true)
assert_eq "no planning dir: empty output" "" "$result"

# Test 2: planning dir, no phase files — empty output
mkdir -p "$TMP/.planning"
result=$(cd "$TMP" && REPO_ROOT="$TMP" "$SCRIPT" 2>/dev/null || true)
assert_eq "no phase files: empty output" "" "$result"

# Test 3: phase goal + source files → valid JSON with additionalContext
echo "# Implement authentication" > "$TMP/.planning/phase1-CONTEXT.md"
mkdir -p "$TMP/src"
python3 -c "print('authentication login validate user credentials\n' * 20)" > "$TMP/src/auth.sh"
result=$(cd "$TMP" && REPO_ROOT="$TMP" "$SCRIPT" 2>/dev/null)
[[ -n "$result" ]] && { echo "PASS: produces output with phase+files"; (( PASS++ )) || true; } \
                   || { echo "FAIL: empty output with phase+files"; (( FAIL++ )) || true; }
[[ -n "$result" ]] && assert_json_key "output is valid JSON" '.hookSpecificOutput.additionalContext' "$result"

# Test 4: compression disabled → empty output
base_config
echo "# Implement authentication" > "$TMP/.planning/phase1-CONTEXT.md"
mkdir -p "$TMP/src"
python3 -c "print('content here\n' * 20)" > "$TMP/src/file.sh"
jq '.semantic_compression.enabled = false' "$TMP/.silver-bullet.json" > "$TMP/.sb.tmp" \
  && mv "$TMP/.sb.tmp" "$TMP/.silver-bullet.json"
result=$(cd "$TMP" && REPO_ROOT="$TMP" "$SCRIPT" 2>/dev/null || true)
assert_eq "disabled: empty output" "" "$result"
base_config

# Test 5: src_exclude_pattern respected — test files excluded
echo "# Auth" > "$TMP/.planning/phase1-CONTEXT.md"
mkdir -p "$TMP/src"
python3 -c "print('authentication content\n' * 20)" > "$TMP/src/auth.sh"
python3 -c "print('authentication test content\n' * 20)" > "$TMP/src/auth.test.sh"
result=$(cd "$TMP" && REPO_ROOT="$TMP" "$SCRIPT" 2>/dev/null || true)
if [[ -n "$result" ]]; then
  context=$(printf '%s' "$result" | jq -r '.hookSpecificOutput.additionalContext')
  if printf '%s' "$context" | grep -q 'auth\.test\.sh'; then
    echo "FAIL: excluded file auth.test.sh appeared in context"; (( FAIL++ )) || true
  else
    echo "PASS: src_exclude_pattern excludes test files"; (( PASS++ )) || true
  fi
else
  echo "PASS: no output (acceptable if budget too small)"; (( PASS++ )) || true
fi

# Test 6: debug flag creates debug.log
base_config
echo "# Debug test" > "$TMP/.planning/debug-CONTEXT.md"
mkdir -p "$TMP/src"
python3 -c "print('debug content here\n' * 20)" > "$TMP/src/debug.sh"
jq '.semantic_compression.debug = true' "$TMP/.silver-bullet.json" > "$TMP/.sb.tmp" \
  && mv "$TMP/.sb.tmp" "$TMP/.silver-bullet.json"
(cd "$TMP" && REPO_ROOT="$TMP" "$SCRIPT" > /dev/null 2>/dev/null || true)
if [[ -f "$TMP/.planning/.context-cache/debug.log" ]]; then
  echo "PASS: debug flag creates debug.log"; (( PASS++ )) || true
else
  echo "FAIL: debug.log not created when debug=true"; (( FAIL++ )) || true
fi
base_config

# Test 7: binary file excluded
echo "# Binary test" > "$TMP/.planning/bin-CONTEXT.md"
mkdir -p "$TMP/src"
printf '\x00\x01\x02\x03binary content' > "$TMP/src/binary.bin"
python3 -c "print('real text content\n' * 20)" > "$TMP/src/text.sh"
result=$(cd "$TMP" && REPO_ROOT="$TMP" "$SCRIPT" 2>/dev/null || true)
if [[ -n "$result" ]]; then
  context=$(printf '%s' "$result" | jq -r '.hookSpecificOutput.additionalContext')
  if printf '%s' "$context" | grep -q 'binary\.bin'; then
    echo "FAIL: binary file appeared in context"; (( FAIL++ )) || true
  else
    echo "PASS: binary file excluded from context"; (( PASS++ )) || true
  fi
else
  echo "PASS: no output (binary excluded, budget tight)"; (( PASS++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
