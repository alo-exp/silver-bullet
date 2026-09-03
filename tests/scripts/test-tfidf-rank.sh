#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $desc"; (( PASS++ )) || true
  else
    echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true
  fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/tfidf-rank.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# File A: mentions "authentication" and "login" heavily
python3 -c "
lines = ['authentication login function validate user credentials']
lines += ['authentication checks password hash comparison'] * 10
lines += ['']
lines += ['unrelated database connection pooling setup'] * 10
print('\n'.join(lines))
" > "$TMP/file_a.sh"

# File B: only mentions "database"
python3 -c "
lines = ['database connection pool configuration']
lines += ['query execution timeout settings'] * 10
print('\n'.join(lines))
" > "$TMP/file_b.sh"

# Test 1: auth query — file_a chunk with auth terms should appear first
result=$(printf '%s\n' "$TMP/file_a.sh" "$TMP/file_b.sh" | "$SCRIPT" "authentication login")
first_file=$(printf '%s\n' "$result" | head -1 | cut -f2)
assert_eq "auth query: file_a chunk scores higher" "$TMP/file_a.sh" "$first_file"

# Test 2: output has exactly 5 tab-separated fields
first_line=$(printf '%s\n' "$result" | head -1)
field_count=$(printf '%s\n' "$first_line" | awk -F'\t' '{print NF}')
assert_eq "output has 5 tab fields" "5" "$field_count"

# Test 3: empty query returns output without crashing
result=$(printf '%s\n' "$TMP/file_a.sh" | "$SCRIPT" "" 2>&1) || true
if [[ -n "$result" ]]; then
  echo "PASS: empty query exits cleanly"; (( PASS++ )) || true
else
  echo "FAIL: empty query crashed or produced no output"; (( FAIL++ )) || true
fi

# Test 4: dense file (no blank lines) split into multiple chunks
python3 -c "print('\n'.join(['no blank lines here content stuff'] * 100))" > "$TMP/dense.sh"
result=$(printf '%s\n' "$TMP/dense.sh" | "$SCRIPT" "content")
chunk_count=$(printf '%s\n' "$result" | grep -c . || true)
[[ $chunk_count -ge 2 ]] && { echo "PASS: dense file split into multiple chunks (got $chunk_count)"; (( PASS++ )) || true; } \
                          || { echo "FAIL: dense file not split, chunks=$chunk_count"; (( FAIL++ )) || true; }

# Test 5: chunk text containing tabs — output still has exactly 5 fields
printf 'term1\tterm2\nmore content here\n' > "$TMP/tabfile.sh"
result=$(printf '%s\n' "$TMP/tabfile.sh" | "$SCRIPT" "term1")
field_count=$(printf '%s\n' "$result" | head -1 | awk -F'\t' '{print NF}')
assert_eq "tab in chunk text: still 5 fields" "5" "$field_count"

# Test 6: mixed-case content is preserved in output (not lowercased)
printf 'AuthManager CLASS UPPERCASE_FUNCTION validateCredentials\nmore content here\n' > "$TMP/mixed_case.sh"
result=$(printf '%s\n' "$TMP/mixed_case.sh" | "$SCRIPT" "authmanager")
chunk_text=$(printf '%s\n' "$result" | head -1 | cut -f5-)
if [[ "$chunk_text" == *"AuthManager"* ]]; then
  echo "PASS: mixed-case content preserved in output"; (( PASS++ )) || true
else
  echo "FAIL: mixed-case content was lowercased"; echo "  actual: [$chunk_text]"; (( FAIL++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
