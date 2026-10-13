#!/usr/bin/env bash
# MCP namespace tests — LeanCTX lctx_ prefix; no duplicate unprefixed ctx_* when CM+LeanCTX configured
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

# Baseline: Context Mode registered first (conflict #1 scenario).
cat >"${TEST_HOME}/.cursor/mcp.json" <<'EOF'
{
  "mcpServers": {
    "context-mode": {
      "command": "context-mode"
    }
  }
}
EOF

merge_out="$(python3 "$MERGE_PY" --host cursor 2>/dev/null || true)"
printf '%s' "$merge_out" | jq -e '.status == "ok"' >/dev/null 2>&1 && pass "merge script exits ok" || fail "merge script exits ok"

MCP="${TEST_HOME}/.cursor/mcp.json"
jq -e '.mcpServers.leanctx' "$MCP" >/dev/null 2>&1 && pass "leanctx server merged" || fail "leanctx server merged"
jq -e '.mcpServers.leanctx.env.LEANCTX_MCP_TOOL_PREFIX == "lctx_"' "$MCP" >/dev/null 2>&1 \
  && pass "lctx_ prefix env set" || fail "lctx_ prefix env set"

disabled="$(jq -r '.mcpServers.leanctx.disabledTools // [] | join(",")' "$MCP")"
for tool in ctx_execute ctx_search ctx_fetch_and_index; do
  if printf '%s' "$disabled" | grep -qF "$tool"; then
    pass "disabledTools includes $tool"
  else
    fail "disabledTools includes $tool"
  fi
done

# CM retains ctx_* namespace — leanctx must not register duplicate unprefixed ctx_execute server entry.
if jq -e '.mcpServers["ctx_execute"]' "$MCP" >/dev/null 2>&1; then
  fail "no duplicate unprefixed ctx_execute server"
else
  pass "no duplicate unprefixed ctx_execute server"
fi

# Both servers coexist.
jq -e '.mcpServers["context-mode"] and .mcpServers.leanctx' "$MCP" >/dev/null 2>&1 \
  && pass "CM and LeanCTX coexist" || fail "CM and LeanCTX coexist"

# LeanCTX overlap surfaces disabled when CM active.
for env_key in LEANCTX_DISABLE_SHELL_MCP LEANCTX_DISABLE_SANDBOX_MCP LEANCTX_DISABLE_FETCH_MCP LEANCTX_DISABLE_FTS; do
  val="$(jq -r --arg k "$env_key" '.mcpServers.leanctx.env[$k] // ""' "$MCP")"
  [[ "$val" == "1" ]] && pass "${env_key}=1" || fail "${env_key}=1 (got ${val:-empty})"
done

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
