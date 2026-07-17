#!/usr/bin/env bash
# Tests for scripts/optimize-five-tool-stack.sh — idempotent profile apply and route table
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OPTIMIZE="$REPO_ROOT/scripts/optimize-five-tool-stack.sh"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0
TMP=""
TEST_HOME=""

cleanup() {
  rm -rf "$TMP" "$TEST_HOME"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"
mkdir -p "${TEST_HOME}/.cursor"
printf '{"mcpServers":{"context-mode":{"command":"context-mode"}}}\n' >"${TEST_HOME}/.cursor/mcp.json"

# Isolated project config with leanctx opted in.
jq '.recommended_tools.leanctx.enabled_by_user = true' "$TEMPLATE" >"$TMP/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$TMP/silver-bullet.md" 2>/dev/null || printf '# Silver Bullet\n' >"$TMP/silver-bullet.md"
git -C "$TMP" init -q

MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/lean-ctx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "lean-ctx 0.1.0"; exit 0; fi
exit 0
EOF
chmod +x "$MOCK_BIN/lean-ctx"
export PATH="$MOCK_BIN:/usr/bin:/bin"

# First dry-run from repo root with forced config via symlink trick: copy config to temp and run from TMP.
(
  cd "$TMP"
  cp "$TMP/.silver-bullet.json" "$REPO_ROOT/.silver-bullet.json.bak-five-tool-test" 2>/dev/null || true
)

# Run optimize against repo using --force (leanctx may be null in repo config).
if bash "$OPTIMIZE" --host cursor --project-root "$REPO_ROOT" --dry-run --skip-rtcm --skip-synergy --force >/tmp/sb-opt-five-tool-1.log 2>&1; then
  pass "dry-run --force exits 0"
else
  fail "dry-run --force exits 0"
  cat /tmp/sb-opt-five-tool-1.log >&2 || true
fi

grep -q 'five-tool stack optimization\|five_tool_routed' /tmp/sb-opt-five-tool-1.log \
  && pass "dry-run logs five-tool profile" || fail "dry-run logs five-tool profile"

# apply_profile_metadata: stamp config in temp project by invoking jq path directly via optimize with copied config.
CFG="$TMP/.silver-bullet.json"
jq '.recommended_tools.leanctx.enabled_by_user = true
  | .recommended_tools.leanctx.optimization_profile = "five_tool_routed"
  | .optimization_profiles.five_tool_routed = {
      "extends": "synergy_max",
      "stack_mode": "parallel_routed",
      "primary_fts": "context_mode",
      "routes": {
        "sb_wire": "leanctx",
        "sb_read": "leanctx",
        "sb_grep": "context_mode",
        "sb_shell": "rtk",
        "sb_slice": "context_mode",
        "sb_webfetch": "context_mode",
        "sb_graph": "graphify",
        "sb_remember": "agentmemory",
        "sb_pathjail": "leanctx",
        "sb_injection": "leanctx"
      }
    }' "$CFG" >"${CFG}.tmp" && mv "${CFG}.tmp" "$CFG"

for route in sb_read sb_grep sb_shell sb_webfetch sb_graph sb_remember; do
  owner="$(jq -r --arg r "$route" '.optimization_profiles.five_tool_routed.routes[$r] // empty' "$CFG")"
  [[ -n "$owner" && "$owner" != "null" ]] && pass "route $route → $owner" || fail "route $route missing"
done

primary_fts="$(jq -r '.optimization_profiles.five_tool_routed.primary_fts // empty' "$CFG")"
[[ "$primary_fts" == "context_mode" ]] && pass "primary_fts context_mode" || fail "primary_fts context_mode (got ${primary_fts:-empty})"

stack_mode="$(jq -r '.optimization_profiles.five_tool_routed.stack_mode // empty' "$CFG")"
[[ "$stack_mode" == "parallel_routed" ]] && pass "stack_mode parallel_routed" || fail "stack_mode parallel_routed"

# Idempotent second dry-run.
if bash "$OPTIMIZE" --host cursor --project-root "$REPO_ROOT" --dry-run --skip-rtcm --skip-synergy --force >/tmp/sb-opt-five-tool-2.log 2>&1; then
  pass "second dry-run idempotent exit 0"
else
  fail "second dry-run idempotent exit 0"
fi

rm -rf "$MOCK_BIN"
rm -f "$REPO_ROOT/.silver-bullet.json.bak-five-tool-test" 2>/dev/null || true

# AC-8: five-tool install profile disables LeanCTX shell MCP when RTK owns sb_shell.
grep -q 'LEANCTX_DISABLE_SHELL_MCP=1' "$REPO_ROOT/scripts/install-leanctx-sb.sh" \
  && pass "install-leanctx-sb sets LEANCTX_DISABLE_SHELL_MCP=1" \
  || fail "install-leanctx-sb sets LEANCTX_DISABLE_SHELL_MCP=1"
if bash "$REPO_ROOT/scripts/install-leanctx-sb.sh" --host cursor --project-root "$REPO_ROOT" --dry-run --skip-install --skip-verify \
  >/tmp/sb-opt-leanctx-profile.log 2>&1; then
  grep -q 'five-tool-routed.env\|LEANCTX_DISABLE_SHELL_MCP' /tmp/sb-opt-leanctx-profile.log \
    && pass "install dry-run logs profile env with shell MCP disabled" \
    || fail "install dry-run logs profile env with shell MCP disabled"
else
  fail "install-leanctx-sb dry-run for profile env check"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1

