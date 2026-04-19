#!/usr/bin/env bash
# Integration test: plugin.json and hooks.json validity checks
# Tests static file integrity — no runtime setup needed

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
HOOKS_JSON="$REPO_ROOT/hooks/hooks.json"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

print_results() {
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

echo "=== Plugin Integrity Checks ==="

# CHECK 1: plugin.json is valid JSON
echo "--- CHECK 1: plugin.json is valid JSON ---"
if jq . "$PLUGIN_JSON" >/dev/null 2>&1; then
  pass "plugin.json parses as valid JSON"
else
  fail "plugin.json is not valid JSON"
fi

# CHECK 2: hooks.json is valid JSON
echo "--- CHECK 2: hooks.json is valid JSON ---"
if jq . "$HOOKS_JSON" >/dev/null 2>&1; then
  pass "hooks.json parses as valid JSON"
else
  fail "hooks.json is not valid JSON"
fi

# CHECK 3: All "command" values that are file paths resolve to real files on disk.
# Inline shell expressions (containing spaces / operators) are not file paths and
# are intentionally skipped — they are valid hook commands but not scripts.
echo "--- CHECK 3: All hook commands resolve to real files ---"
commands=$(jq -r '.hooks[] | .[].hooks[] | select(.type == "command") | .command' "$HOOKS_JSON" 2>/dev/null \
  | sed 's/^"//;s/"$//' \
  | sed "s|\${CLAUDE_PLUGIN_ROOT}|$REPO_ROOT|g")

if [ -z "$commands" ]; then
  fail "No commands found in hooks.json — check jq extraction"
else
  while IFS= read -r cmd; do
    # Strip surrounding quotes if present
    cmd_path="${cmd%\"}"
    cmd_path="${cmd_path#\"}"
    # Only check absolute paths — inline shell expressions are not file paths
    case "$cmd_path" in
      /*)
        if [ -f "$cmd_path" ]; then
          pass "Command file exists: $(basename "$cmd_path")"
        else
          fail "Command file missing: $cmd_path"
        fi
        ;;
      *)
        pass "Inline shell command (no file check): ${cmd_path:0:50}"
        ;;
    esac
  done <<< "$commands"
fi

# CHECK 4: All referenced hook script files are executable
echo "--- CHECK 4: All hook script files are executable ---"
if [ -n "$commands" ]; then
  while IFS= read -r cmd; do
    cmd_path="${cmd%\"}"
    cmd_path="${cmd_path#\"}"
    case "$cmd_path" in
      /*)
        if [ -x "$cmd_path" ]; then
          pass "Executable: $(basename "$cmd_path")"
        else
          fail "Not executable: $cmd_path"
        fi
        ;;
      *)
        pass "Inline shell command (no executable check): ${cmd_path:0:50}"
        ;;
    esac
  done <<< "$commands"
fi

# CHECK 5: All "matcher" patterns are valid ERE regex
echo "--- CHECK 5: All matcher patterns are valid ERE regex ---"
matchers=$(jq -r '.hooks[] | .[].matcher' "$HOOKS_JSON" 2>/dev/null | sort -u)

if [ -z "$matchers" ]; then
  fail "No matcher patterns found in hooks.json"
else
  while IFS= read -r pattern; do
    # grep -E exit code 2 = invalid regex; 0 or 1 = valid
    echo "test" | grep -E "$pattern" >/dev/null 2>&1
    grep_exit=$?
    if [ "$grep_exit" -eq 2 ]; then
      fail "Invalid ERE regex: $pattern"
    else
      pass "Valid ERE regex: $pattern"
    fi
  done <<< "$matchers"
fi

# CHECK 6: hooks.json contains at least 17 hook registrations
echo "--- CHECK 6: hooks.json has at least 17 hook registrations ---"
hook_count=$(jq '[.hooks[] | .[].hooks[] | select(.type == "command")] | length' "$HOOKS_JSON" 2>/dev/null)
if [ -z "$hook_count" ]; then
  fail "Could not count hook registrations"
elif [ "$hook_count" -ge 17 ]; then
  pass "Hook registration count is $hook_count (>= 17)"
else
  fail "Hook registration count is $hook_count (< 17)"
fi

# CHECK 7: plugin.json "version" field exists and is non-empty
echo "--- CHECK 7: plugin.json version field exists and is non-empty ---"
plugin_version=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null)
if [ -n "$plugin_version" ]; then
  pass "plugin.json version field is present and non-empty: $plugin_version"
else
  fail "plugin.json version field is missing or empty"
fi

print_results
