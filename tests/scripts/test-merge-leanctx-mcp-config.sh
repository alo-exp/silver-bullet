#!/usr/bin/env bash
# Regression: merge-leanctx-mcp-config removes upstream lean-ctx duplicate
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MERGE_PY="$REPO_ROOT/scripts/lib/merge-leanctx-mcp-config.py"
PASS=0
FAIL=0
TEST_HOME=""

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
mkdir -p "${TEST_HOME}/.cursor"

cat >"${TEST_HOME}/.cursor/mcp.json" <<'EOF'
{
  "mcpServers": {
    "lean-ctx": {
      "command": "lean-ctx",
      "args": ["mcp"]
    },
    "leanctx": {
      "command": "lean-ctx",
      "args": ["mcp"],
      "env": {}
    }
  }
}
EOF

if python3 "$MERGE_PY" --host cursor >/dev/null 2>&1; then
  pass "merge exits 0 on duplicate fixture"
else
  fail "merge exits 0 on duplicate fixture"
fi

if jq -e '.mcpServers["lean-ctx"]' "${TEST_HOME}/.cursor/mcp.json" >/dev/null 2>&1; then
  fail "lean-ctx still present after merge"
else
  pass "lean-ctx removed after merge"
fi

if jq -e '.mcpServers.leanctx.command == "lean-ctx" or (.mcpServers.leanctx.command | endswith("/lean-ctx"))' "${TEST_HOME}/.cursor/mcp.json" >/dev/null 2>&1; then
  pass "leanctx preserved after merge"
else
  fail "leanctx missing after merge"
fi

if [[ -f "${TEST_HOME}/.cursor/mcp.json.bak" ]]; then
  pass "backup .bak written before merge overwrite"
else
  fail "backup .bak missing"
fi

if jq -e '.mcpServers["lean-ctx"]' "${TEST_HOME}/.cursor/mcp.json.bak" >/dev/null 2>&1; then
  pass "backup retains original lean-ctx entry"
else
  fail "backup should retain lean-ctx entry"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
