#!/usr/bin/env bash
# Unit tests for hooks/lib/context-mode-gate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/context-mode-gate.sh"
PASS=0
FAIL=0
TMP=""
MOCK_BIN=""
TEST_HOME=""

cleanup() {
  rm -rf "$TMP" "$MOCK_BIN" "$TEST_HOME"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=hooks/lib/context-mode-gate.sh
source "$LIB"

TMP="$(mktemp -d)"
MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/node" <<'EOF'
#!/usr/bin/env bash
echo v22.5.0
EOF
chmod +x "$MOCK_BIN/node"
export PATH="$MOCK_BIN:/usr/bin:/bin"

sb_context_mode_node_ok "" && pass "node >= 22.5 ok" || fail "node >= 22.5 ok"

cat >"$TMP/silver-bullet.md" <<'EOF'
<!-- BEGIN context-mode hint (do not edit) -->
Use ctx_index and ctx_search for large files.
<!-- END context-mode hint (do not edit) -->
EOF
sb_context_mode_instruction_fragment_present "$TMP" && pass "fragment detected" || fail "fragment detected"

TEST_HOME="$(mktemp -d)"
mkdir -p "$TEST_HOME/.cursor"
printf '{"mcpServers":{"context-mode":{"command":"context-mode"}}}\n' >"$TEST_HOME/.cursor/mcp.json"
export HOME="$TEST_HOME" SILVER_BULLET_RUNTIME=cursor SB_CONTEXT_MODE_MCP_ARTIFACT="$TEST_HOME/.cursor/mcp.json"
sb_context_mode_platform_artifact_present "$TMP" cursor && pass "cursor mcp present" || fail "cursor mcp present"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
