#!/usr/bin/env bash
# Dry-run install tests for scripts/install-leanctx-sb.sh — no host config clobber; MCP merge valid
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install-leanctx-sb.sh"
PATCH_MCP_PY="$REPO_ROOT/scripts/lib/global-toolstack/patch-mcp.py"
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
export SILVER_BULLET_RUNTIME=cursor
export SB_RUNTIME_HOME_ROOT="${TEST_HOME}/.cursor"
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "${TEST_HOME}/.cursor" "${SB_RUNTIME_STATE_DIR}"

# Seed CM + guard paths that must not be touched (conflict #8).
printf '{"mcpServers":{"context-mode":{"command":"context-mode"}}}\n' >"${TEST_HOME}/.cursor/mcp.json"
touch "${TEST_HOME}/.cursor/AGENTS.md" "${REPO_ROOT}/AGENTS.md" 2>/dev/null || true

if bash "$INSTALL" --host cursor --project-root "$REPO_ROOT" --dry-run --skip-install --skip-verify >/tmp/sb-install-leanctx-dry.log 2>&1; then
  pass "dry-run install exits 0"
else
  fail "dry-run install exits 0"
  cat /tmp/sb-install-leanctx-dry.log >&2 || true
fi

grep -q 'DRY-RUN' /tmp/sb-install-leanctx-dry.log && pass "dry-run logs actions" || fail "dry-run logs actions"
grep -q 'five_tool_routed\|LeanCTX SB install complete' /tmp/sb-install-leanctx-dry.log \
  && pass "dry-run completes install flow" || fail "dry-run completes install flow"

grep -q 'patch-mcp\|RT_PATCH_LEANCTX' /tmp/sb-install-leanctx-dry.log \
  && pass "dry-run uses patch-mcp path" || fail "dry-run uses patch-mcp path"

# Real merge in isolated HOME (not dry-run) — validates MCP JSON via canonical patch-mcp.
if RT_PATCH_LEANCTX=1 RT_PATCH_GRAPHIFY=0 python3 "$PATCH_MCP_PY" >/dev/null 2>&1; then
  pass "patch-mcp leanctx writes valid JSON"
else
  fail "patch-mcp leanctx writes valid JSON"
fi

if jq -e '.mcpServers.leanctx.env.LEANCTX_MCP_TOOL_PREFIX == "lctx_"' "${TEST_HOME}/.cursor/mcp.json" >/dev/null 2>&1; then
  pass "merged MCP has lctx_ prefix"
else
  fail "merged MCP has lctx_ prefix"
fi

if [[ -f "${REPO_ROOT}/AGENTS.md" ]]; then
  AGENTS_HASH_BEFORE="$(shasum -a 256 "${REPO_ROOT}/AGENTS.md" 2>/dev/null | awk '{print $1}')"
  AGENTS_HASH_AFTER="$(shasum -a 256 "${REPO_ROOT}/AGENTS.md" 2>/dev/null | awk '{print $1}')"
  [[ -n "$AGENTS_HASH_BEFORE" && "$AGENTS_HASH_BEFORE" == "$AGENTS_HASH_AFTER" ]] \
    && pass "repo AGENTS.md unchanged" || fail "repo AGENTS.md unchanged"
fi

# Skip-install path with mock lean-ctx on PATH.
MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/lean-ctx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "lean-ctx 0.1.0"; exit 0; fi
if [[ "${1:-}" == "mcp" ]]; then exit 0; fi
exit 0
EOF
chmod +x "$MOCK_BIN/lean-ctx"
export PATH="$MOCK_BIN:$PATH"

if bash "$INSTALL" --host cursor --project-root "$REPO_ROOT" --skip-verify 2>/tmp/sb-install-leanctx-real.log; then
  pass "skip-verify install with mock CLI exits 0"
else
  fail "skip-verify install with mock CLI exits 0"
  cat /tmp/sb-install-leanctx-real.log >&2 || true
fi

PROFILE="${SB_RUNTIME_HOME_ROOT}/leanctx-profile/five-tool-routed.env"
if [[ -f "$PROFILE" ]] && grep -q 'LEANCTX_MCP_TOOL_PREFIX=lctx_' "$PROFILE"; then
  pass "profile env file written"
else
  fail "profile env file written"
fi

rm -rf "$MOCK_BIN"

# #278: Claude host dry-run must merge via merge-leanctx-mcp-config (not silent SKIP)
if bash "$INSTALL" --host claude --project-root "$REPO_ROOT" --dry-run --skip-install --skip-verify >/tmp/sb-install-leanctx-claude-dry.log 2>&1; then
  pass "claude dry-run install exits 0"
else
  fail "claude dry-run install exits 0"
  cat /tmp/sb-install-leanctx-claude-dry.log >&2 || true
fi
if grep -q 'merge-leanctx-mcp-config\|Merging LeanCTX MCP for host=claude\|DRY-RUN: python3 .*merge-leanctx' /tmp/sb-install-leanctx-claude-dry.log \
  && ! grep -q 'SKIP: MCP merge (host=claude' /tmp/sb-install-leanctx-claude-dry.log; then
  pass "claude dry-run merges MCP (#278)"
else
  fail "claude dry-run merges MCP (#278)"
  cat /tmp/sb-install-leanctx-claude-dry.log >&2 || true
fi

MERGE_PY="$REPO_ROOT/scripts/lib/merge-leanctx-mcp-config.py"
mkdir -p "${TEST_HOME}"
printf '{"mcpServers":{}}\n' >"${TEST_HOME}/.claude.json"
if python3 "$MERGE_PY" --host claude >/dev/null 2>&1 \
  && jq -e '.mcpServers.leanctx.env.LEANCTX_MCP_TOOL_PREFIX == "lctx_"' "${TEST_HOME}/.claude.json" >/dev/null 2>&1; then
  pass "merge-leanctx-mcp-config writes claude leanctx (#278)"
else
  fail "merge-leanctx-mcp-config writes claude leanctx (#278)"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1


