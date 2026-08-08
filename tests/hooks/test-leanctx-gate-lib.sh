#!/usr/bin/env bash
# Unit tests for hooks/lib/leanctx-gate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SILVER_BULLET_RUNTIME=cursor
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

LIB="$REPO_ROOT/hooks/lib/leanctx-gate.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0
MOCK_BIN=""
TEST_HOME=""
TMP=""

cleanup() {
  rm -rf "$MOCK_BIN" "$TEST_HOME" "$TMP"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=hooks/lib/leanctx-gate.sh
source "$LIB"

MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/lean-ctx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "lean-ctx 0.1.0"; exit 0; fi
exit 0
EOF
chmod +x "$MOCK_BIN/lean-ctx"
export PATH="$MOCK_BIN:/usr/bin:/bin"

sb_leanctx_cli_available && pass "mock lean-ctx cli available" || fail "mock lean-ctx cli available"
sb_leanctx_cli_path | grep -q 'lean-ctx' && pass "cli path resolves" || fail "cli path resolves"

TEST_HOME="$(mktemp -d)"
TMP="$(mktemp -d)"
mkdir -p "${TEST_HOME}/.cursor"
printf '{"mcpServers":{"leanctx":{"command":"lean-ctx","args":["mcp"]}}}\n' >"${TEST_HOME}/.cursor/mcp.json"
export HOME="$TEST_HOME" SILVER_BULLET_RUNTIME=cursor SB_LEANCTX_MCP_ARTIFACT="${TEST_HOME}/.cursor/mcp.json"

USAGE_STATE="${SB_RUNTIME_STATE_DIR}/leanctx-usage-lib-test-$$"
cat >"$TMP/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "recommended_tools": {
    "leanctx": {
      "enabled_by_user": true,
      "usage_ttl_seconds": 1800,
      "usage_state_file": "${USAGE_STATE}"
    }
  }
}
EOF

sb_leanctx_platform_artifact_present "$TMP" cursor && pass "cursor mcp artifact present" || fail "cursor mcp artifact present"
sb_leanctx_usage_ttl_seconds "$TMP/.silver-bullet.json" | grep -q '^1800$' && pass "ttl from config" || fail "ttl from config"

sb_leanctx_clear_usage_state "$TMP/.silver-bullet.json"
sb_leanctx_usage_is_fresh "$TMP/.silver-bullet.json" && fail "missing usage is stale" || pass "missing usage is stale"

sb_leanctx_record_usage "$TMP/.silver-bullet.json"
sb_leanctx_usage_is_fresh "$TMP/.silver-bullet.json" && pass "fresh usage after record" || fail "fresh usage after record"

# Expire usage by backdating state file.
echo 1000000000 >"$USAGE_STATE"
sb_leanctx_usage_is_fresh "$TMP/.silver-bullet.json" && fail "expired usage is stale" || pass "expired usage is stale"

sb_leanctx_edit_path_is_exempt "${TMP}/.silver-bullet.json" "$TMP/.silver-bullet.json" && pass "config edit exempt" || fail "config edit exempt"
sb_leanctx_edit_path_is_exempt "${TMP}/docs/LEANCTX.md" "$TMP/.silver-bullet.json" && pass "LEANCTX.md exempt" || fail "LEANCTX.md exempt"
sb_leanctx_command_is_exempt 'lean-ctx status' && pass "lean-ctx command exempt" || fail "lean-ctx command exempt"
sb_leanctx_command_is_usage 'lean-ctx status' "$TMP/.silver-bullet.json" && pass "lean-ctx command is usage" || fail "lean-ctx command is usage"
sb_leanctx_mcp_tool_is_usage 'lctx_read_ast' && pass "lctx_read_ast is usage" || fail "lctx_read_ast is usage"
sb_leanctx_mcp_tool_is_usage 'memory_save' && fail "memory_save not leanctx usage" || pass "memory_save not leanctx usage"

# ── sb_leanctx_hooks_present: per-host wiring verification ───────────────────
# Regression coverage: the case had arms for cursor and codex only, so every
# other host fell through to an unconditional `return 0` and the hooks-wiring
# check was a silent no-op. Uses a throwaway HOME — never the real settings.
HOOKS_HOME="$(mktemp -d)"
trap 'rm -rf "$MOCK_BIN" "$TEST_HOME" "$TMP" "$HOOKS_HOME"' EXIT
mkdir -p "${HOOKS_HOME}/.claude"

(
  export HOME="$HOOKS_HOME"
  printf '{"hooks":{"PreToolUse":[{"command":"lean-ctx hook"}]}}\n' >"${HOME}/.claude/settings.json"
  sb_leanctx_hooks_present claude
) && pass "claude host with lean-ctx in settings.json passes" \
  || fail "claude host with lean-ctx in settings.json passes"

(
  export HOME="$HOOKS_HOME"
  printf '{"hooks":{"PreToolUse":[{"command":"something-else"}]}}\n' >"${HOME}/.claude/settings.json"
  sb_leanctx_hooks_present claude
) && fail "claude host without lean-ctx fails" \
  || pass "claude host without lean-ctx fails"

(
  export HOME="$HOOKS_HOME"
  rm -f "${HOME}/.claude/settings.json"
  sb_leanctx_hooks_present claude
) && fail "claude host with no settings.json fails" \
  || pass "claude host with no settings.json fails"

# Genuinely unknown hosts stay intentionally permissive.
sb_leanctx_hooks_present some-unknown-host \
  && pass "unknown host remains permissive" \
  || fail "unknown host remains permissive"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
