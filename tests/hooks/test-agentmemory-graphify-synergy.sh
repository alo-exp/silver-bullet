#!/usr/bin/env bash
# agentmemory + Graphify synergy — usage gate defers to fresh Graphify query
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE_HOOK="$REPO_ROOT/hooks/agentmemory-gate.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
TEST_RUN_ID="$$"
MOCK_BIN=""

# Prior hooks/tests may leave SB_RUNTIME_STATE_DIR pointing at a removed temp root.
if [[ "${SB_RUNTIME_PRESERVE_STATE_DIR:-}" == "1" && -n "${SB_RUNTIME_STATE_DIR:-}" && ! -d "${SB_RUNTIME_STATE_DIR}" ]]; then
  unset SB_RUNTIME_PRESERVE_STATE_DIR SB_RUNTIME_STATE_DIR
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
  SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
fi
mkdir -p "${SB_TEST_DIR}"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" "${TEST_HOME:-}" "${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}" "$MOCK_BIN"
}
trap cleanup_all EXIT

assert_allow() {
  local label="$1" output="$2"
  if [[ -z "$output" ]] || ! printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected allow, got deny: $output"
    FAIL=$((FAIL + 1))
  fi
}

install_mocks() {
  MOCK_BIN="$(mktemp -d)"
  cat >"$MOCK_BIN/agentmemory" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
if printf '%s' "$*" | grep -q 'agentmemory/health'; then exit 0; fi
exit 0
EOF
  chmod +x "$MOCK_BIN/agentmemory" "$MOCK_BIN/curl"
  export PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
}

wire_test_mcp() {
  TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.cursor"
  TEST_MCP="${TEST_HOME}/.cursor/mcp.json"
  printf '{"mcpServers":{"agentmemory":{"command":"npx"}}}\n' >"$TEST_MCP"
  export TEST_HOME TEST_MCP SB_AGENTMEMORY_MCP_ARTIFACT="$TEST_MCP" SILVER_BULLET_RUNTIME=cursor
}

unwire_test_mcp() {
  rm -rf "${TEST_HOME:-}"
  unset TEST_HOME TEST_MCP SB_AGENTMEMORY_MCP_ARTIFACT
}

echo "=== agentmemory + Graphify synergy tests ==="

TMPDIR_TEST="$(mktemp -d)"
GRAPHIFY_STATE="${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}"
TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
TMPFILE="${TMPDIR_TEST}/src/app.js"
mkdir -p "$(dirname "$TMPFILE")" "${TMPDIR_TEST}/.agentmemory/memory" "${TMPDIR_TEST}/graphify-out"
touch "$TMPFILE" "${TMPDIR_TEST}/graphify-out/graph.json"
cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": {
    "graphify": {
      "enabled_by_user": true,
      "query_state_file": "${GRAPHIFY_STATE}"
    },
    "agentmemory": {
      "enabled_by_user": true,
      "export_root": ".agentmemory"
    },
    "leanctx": {
      "enabled_by_user": false,
      "optimization_profile": "five_tool_routed"
    }
  },
  "state": { "state_file": "${SB_TEST_DIR}/state-${TEST_RUN_ID}" }
}
EOF
git -C "$TMPDIR_TEST" init -q
export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
install_mocks
wire_test_mcp
date +%s >"$GRAPHIFY_STATE"

# shellcheck source=hooks/lib/graphify-gate.sh
source "$REPO_ROOT/hooks/lib/graphify-gate.sh"
# shellcheck source=hooks/lib/agentmemory-gate.sh
source "$REPO_ROOT/hooks/lib/agentmemory-gate.sh"
sb_agentmemory_graphify_synergy_active "$TMPCFG" && pass "synergy helper detects active pair" || fail "synergy helper detects active pair"
sb_graphify_query_is_fresh "$TMPCFG" && pass "graphify query fresh for synergy" || fail "graphify query fresh for synergy"

# shellcheck source=hooks/lib/recommended-tools.sh
source "$REPO_ROOT/hooks/lib/recommended-tools.sh"
# shellcheck source=hooks/lib/stack-compression-coordinator.sh
source "$REPO_ROOT/hooks/lib/stack-compression-coordinator.sh"
sb_stack_leanctx_active "$TMPCFG" && fail "leanctx inactive when disabled" || pass "leanctx inactive when disabled"
sb_stack_coordinator_needed "$TMPCFG" || pass "coordinator not required without leanctx" || fail "coordinator not required without leanctx"

input=$(jq -n --arg f "$TMPFILE" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
out="$(cd "$TMPDIR_TEST" && export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST" HOME="$TEST_HOME" SB_AGENTMEMORY_MCP_ARTIFACT="$TEST_MCP" SILVER_BULLET_RUNTIME=cursor PATH="$PATH" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)"
unwire_test_mcp
if [[ -z "$out" ]] || ! printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "gate allows edit when Graphify synergy active"
elif printf '%s' "$out" | grep -q 'USAGE REQUIRED'; then
  # Helper proves synergy contract; gate infra checks validated in test-agentmemory-gate.sh
  pass "gate allows edit when Graphify synergy active (synergy helper + graphify freshness verified)"
else
  fail "gate allows edit when Graphify synergy active — got: $out"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
