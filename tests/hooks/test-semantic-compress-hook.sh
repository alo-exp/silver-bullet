#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
PASS=0; FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true; fi
}

HOOK="$REPO_ROOT/hooks/semantic-compress.sh"
TMP=$(mktemp -d)
_saved_project_root_cache=""
if [[ -n "${SB_RUNTIME_STATE_DIR:-}" && -f "${SB_RUNTIME_STATE_DIR}/project-root" ]]; then
  _saved_project_root_cache="$(cat "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true)"
  rm -f "${SB_RUNTIME_STATE_DIR}/project-root"
fi
cleanup() {
  rm -rf "$TMP"
  if [[ -n "${_saved_project_root_cache:-}" && -n "${SB_RUNTIME_STATE_DIR:-}" ]]; then
    printf '%s\n' "$_saved_project_root_cache" > "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Isolated SB project with no phase planning artifacts — avoids false positives when
# the live repo tree has active .planning/ content from E2E runs.
mkdir -p "$TMP/.planning"
cat > "$TMP/.silver-bullet.json" << 'JSON'
{
  "project": { "name": "hook-test", "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\.test\\." },
  "semantic_compression": { "enabled": true, "context_budget_kb": 50, "min_file_size_bytes": 3072 }
}
JSON
printf '# SB hook test fixture\n' > "$TMP/silver-bullet.md"

run_hook() {
  local payload="$1"
  (
    cd "$TMP"
    export REPO_ROOT="$TMP"
    export SILVER_BULLET_PROJECT_ROOT="$TMP"
    printf '%s' "$payload" | "$HOOK" 2>/dev/null || true
  )
}

# Test 1: non-phase skill → no output, exit 0
result=$(run_hook '{"tool_input":{"skill":"superpowers:brainstorming"}}')
assert_eq "non-phase skill: no output" "" "$result"

# Test 2: silver:execute → hook delegates (no phase files = no output)
result=$(run_hook '{"tool_input":{"skill":"silver:execute"}}')
assert_eq "silver:execute without planning: no output" "" "$result"

# Test 3: silver:plan → same
result=$(run_hook '{"tool_input":{"skill":"silver:plan"}}')
assert_eq "silver:plan without planning: no output" "" "$result"

# Test 4: silver:context → same
result=$(run_hook '{"tool_input":{"skill":"silver:context"}}')
assert_eq "silver:context without planning: no output" "" "$result"

# Test 5: silver:deep-research → same
result=$(run_hook '{"tool_input":{"skill":"silver:deep-research"}}')
assert_eq "silver:deep-research without planning: no output" "" "$result"

# Test 6: hyphenated silver-execute → same
result=$(run_hook '{"tool_input":{"skill":"silver-execute"}}')
assert_eq "silver-execute without planning: no output" "" "$result"

# Test 7: hyphenated silver-plan → same
result=$(run_hook '{"tool_input":{"skill":"silver-plan"}}')
assert_eq "silver-plan without planning: no output" "" "$result"

# Test 8: missing skill field → no output, no crash
result=$(run_hook '{"tool_input":{}}')
assert_eq "missing skill field: no output" "" "$result"

# Test 9: empty stdin → no output, no crash
result=$(cd "$TMP" && export REPO_ROOT="$TMP" SILVER_BULLET_PROJECT_ROOT="$TMP" && printf '' | "$HOOK" 2>/dev/null || true)
assert_eq "empty stdin: no output" "" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
