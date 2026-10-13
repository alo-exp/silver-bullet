#!/usr/bin/env bash
# Unit tests for sb_shell_command_looks_read_only() in hooks/lib/tool-input.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../hooks/lib/tool-input.sh
source "$REPO_ROOT/hooks/lib/tool-input.sh"

PASS=0
FAIL=0

assert_read_only() {
  local label="$1"
  local cmd="$2"
  if sb_shell_command_looks_read_only "$cmd" >/dev/null 2>&1; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected read-only"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_read_only() {
  local label="$1"
  local cmd="$2"
  if sb_shell_command_looks_read_only "$cmd" >/dev/null 2>&1; then
    echo "  ❌ $label — expected write/mutating"
    FAIL=$((FAIL + 1))
  else
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  fi
}

echo "--- read-only: stderr discard redirects ---"
assert_read_only "ls with 2>/dev/null" "ls -la /tmp/project/src-tauri/src/proxy/ 2>/dev/null"
assert_read_only "compound ls with || and 2>/dev/null" 'ls -la /tmp/.planning/quality-gates/ 2>/dev/null || echo "no dir"; ls -la /tmp/src-tauri/src/proxy/ 2>/dev/null'
assert_read_only "ls with semicolon separators" 'ls -la /tmp/.planning/ 2>/dev/null; echo "---"; ls -la /tmp/src-tauri/src/proxy/ 2>/dev/null'

echo "--- read-only: grep with alternation inside quotes ---"
assert_read_only "grep pattern with | in quotes piped to head" 'grep -n "log::info\|tracing::info" /tmp/src-tauri/src/proxy/forwarder.rs | head -10'
assert_read_only "rg with src path" 'rg -n forwarder /tmp/src-tauri/src/proxy/forwarder.rs'
assert_read_only "rg searching for literal >> in src file" "rg '>>' src/app.js"

echo "--- not read-only: real redirects ---"
assert_not_read_only "tee append to src file" "printf 'x' | tee -a /tmp/src/app.js"
assert_not_read_only "redirect stdout to file" "echo probe > /tmp/src/app.js"

echo "--- read-only: graphify retrieval (#258) ---"
assert_read_only "graphify query" 'graphify query "hooks graphify-gate"'
assert_read_only "graphify path" 'graphify path "A" "B"'
assert_read_only "graphify explain" 'graphify explain "orchestrator"'
assert_read_only "graphifyy query alias" 'graphifyy query "foo"'
assert_not_read_only "graphify update mutates index" 'graphify update .'
assert_not_read_only "graphify install not read-only" 'graphify install --project'

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

