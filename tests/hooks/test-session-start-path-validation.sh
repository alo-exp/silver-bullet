#!/usr/bin/env bash
# Tests for the path validation logic in hooks/session-start
# Tests that sp_file is cleared when the resolved path is outside ~/.claude/plugins/cache/

set -euo pipefail

PASS=0
FAIL=0

echo "=== session-start path validation tests ==="

# The validation snippet from hooks/session-start (lines 88-91):
#   if [[ -n "${sp_file:-}" ]]; then
#     _sp_resolved="$(cd "$(dirname "$sp_file")" 2>/dev/null && pwd)/$(basename "$sp_file")" || sp_file=""
#     [[ "${_sp_resolved:-}" == "${HOME}/.claude/plugins/cache/"* ]] || sp_file=""
#   fi

validate_sp_file() {
  local sp_file="$1"
  local _sp_resolved=""
  if [[ -n "${sp_file:-}" ]]; then
    _sp_resolved="$(cd "$(dirname "$sp_file")" 2>/dev/null && pwd)/$(basename "$sp_file")" || sp_file=""
    [[ "${_sp_resolved:-}" == "${HOME}/.claude/plugins/cache/"* ]] || sp_file=""
  fi
  printf '%s' "${sp_file:-}"
}

# ── Test 1: Valid path inside ~/.claude/plugins/cache/ is accepted ────────────
echo "--- Test 1: Valid path inside plugins/cache/ accepted ---"

CACHE_DIR="${HOME}/.claude/plugins/cache"
# Create a temp SKILL.md inside the cache dir for this test
TEST_PLUGIN_DIR="${CACHE_DIR}/test-validation-$$"
mkdir -p "$TEST_PLUGIN_DIR"
TEST_SKILL="${TEST_PLUGIN_DIR}/SKILL.md"
printf '# Test SKILL\n' > "$TEST_SKILL"

result=$(validate_sp_file "$TEST_SKILL")
if [[ -n "$result" ]]; then
  echo "  ✅ valid cache path accepted (sp_file not cleared)"
  PASS=$((PASS + 1))
else
  echo "  ❌ valid cache path incorrectly rejected"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TEST_PLUGIN_DIR"

# ── Test 2: Path outside cache (e.g. /tmp/evil-skill.md) is rejected ─────────
echo "--- Test 2: Path outside plugins/cache/ rejected ---"

# Create a real file in /tmp so cd succeeds (tests the actual validation)
EVIL_FILE="/tmp/evil-skill-$$.md"
printf '# Evil\n' > "$EVIL_FILE"

result=$(validate_sp_file "$EVIL_FILE")
if [[ -z "$result" ]]; then
  echo "  ✅ /tmp path rejected (sp_file cleared)"
  PASS=$((PASS + 1))
else
  echo "  ❌ /tmp path incorrectly accepted: $result"
  FAIL=$((FAIL + 1))
fi

rm -f "$EVIL_FILE"

# ── Test 3: Path traversal attempt is rejected ────────────────────────────────
echo "--- Test 3: Path traversal attempt rejected ---"

# Construct a traversal path that starts inside cache but escapes via ../
CACHE_DIR="${HOME}/.claude/plugins/cache"
mkdir -p "$CACHE_DIR"
# Create a file in /tmp to traverse to
TRAVERSAL_TARGET="/tmp/traversal-target-$$.md"
printf '# Traversal target\n' > "$TRAVERSAL_TARGET"

# The traversal path — resolves to outside cache
TRAVERSAL_PATH="${CACHE_DIR}/../../../tmp/traversal-target-$$.md"

result=$(validate_sp_file "$TRAVERSAL_PATH")
if [[ -z "$result" ]]; then
  echo "  ✅ path traversal attempt rejected (sp_file cleared)"
  PASS=$((PASS + 1))
else
  echo "  ❌ path traversal incorrectly accepted: $result"
  FAIL=$((FAIL + 1))
fi

rm -f "$TRAVERSAL_TARGET"

# ── Test 4: Empty sp_file is a no-op ─────────────────────────────────────────
echo "--- Test 4: Empty sp_file is unchanged (no-op) ---"

result=$(validate_sp_file "")
if [[ -z "$result" ]]; then
  echo "  ✅ empty sp_file remains empty"
  PASS=$((PASS + 1))
else
  echo "  ❌ empty sp_file changed to: $result"
  FAIL=$((FAIL + 1))
fi

# ── Test 5: Nonexistent file whose parent dir is outside cache is rejected ────
echo "--- Test 5: Nonexistent file outside cache rejected ---"

# /nonexistent/path/SKILL.md — cd will fail, sp_file should be cleared
result=$(validate_sp_file "/nonexistent/path/to/SKILL.md")
if [[ -z "$result" ]]; then
  echo "  ✅ nonexistent-outside-cache path rejected"
  PASS=$((PASS + 1))
else
  echo "  ❌ nonexistent path incorrectly accepted: $result"
  FAIL=$((FAIL + 1))
fi

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
