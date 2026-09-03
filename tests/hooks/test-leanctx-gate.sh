#!/usr/bin/env bash
# Tests for hooks/leanctx-gate.sh — PreToolUse block when usage stale
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SILVER_BULLET_RUNTIME=cursor
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
ORIGINAL_HOME="${HOME}"

GATE_HOOK="$REPO_ROOT/hooks/leanctx-gate.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0
MOCK_BIN=""
TEST_HOME=""
TMPDIR_TEST=""
TEST_RUN_ID=""

cleanup_all() {
  [[ -n "${TMPDIR_TEST:-}" ]] && rm -rf "$TMPDIR_TEST"
  [[ -n "${MOCK_BIN:-}" ]] && rm -rf "$MOCK_BIN"
  [[ -n "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
}
trap cleanup_all EXIT

assert_deny() {
  local label="$1" output="$2" needle="${3:-USAGE REQUIRED}"
  if printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
    && printf '%s' "$output" | grep -qF "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected deny ($needle), got: $output"
    FAIL=$((FAIL + 1))
  fi
}

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

install_mock_leanctx() {
  MOCK_BIN="$(mktemp -d)"
  cat >"$MOCK_BIN/lean-ctx" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "lean-ctx 0.1.0"; exit 0; fi
exit 0
EOF
  chmod +x "$MOCK_BIN/lean-ctx"
  export PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
}

isolate_home() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME" SILVER_BULLET_RUNTIME=cursor
  export XDG_CONFIG_HOME="$TEST_HOME/.config"
  export XDG_STATE_HOME="$TEST_HOME/.local/state"
}

wire_mcp() {
  TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.cursor"
  TEST_MCP="${TEST_HOME}/.cursor/mcp.json"
  printf '{"mcpServers":{"leanctx":{"command":"lean-ctx","args":["mcp"]}}}\n' >"$TEST_MCP"
  export SB_LEANCTX_MCP_ARTIFACT="$TEST_MCP" SILVER_BULLET_RUNTIME=cursor
}

unwire_mcp() {
  rm -rf "${TEST_HOME:-}"
  unset TEST_HOME TEST_MCP SB_LEANCTX_MCP_ARTIFACT
}

setup() {
  [[ -n "${TMPDIR_TEST:-}" ]] && rm -rf "$TMPDIR_TEST"
  TMPDIR_TEST="$(mktemp -d)"
  TEST_RUN_ID="$$"
  TMPSTATE="${SB_RUNTIME_STATE_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPFILE="${TMPDIR_TEST}/src/app.js"
  USAGE_STATE="${SB_RUNTIME_STATE_DIR}/leanctx-usage-test-${TEST_RUN_ID}"
  rm -f "$USAGE_STATE" 2>/dev/null || true
  [[ -n "${MOCK_BIN:-}" ]] && rm -rf "$MOCK_BIN"
  MOCK_BIN=""
  [[ -n "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
  TEST_HOME=""
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  export HOME="$ORIGINAL_HOME"
  unset SB_LEANCTX_MCP_ARTIFACT 2>/dev/null || true
  mkdir -p "$(dirname "$TMPFILE")"
  touch "$TMPFILE"
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  git -C "$TMPDIR_TEST" init -q
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
  rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
}

write_cfg() {
  local enabled="${1:-true}" suspended="${2:-false}"
  cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "leanctx": {
      "enabled_by_user": ${enabled},
      "enforcement_suspended": ${suspended},
      "usage_ttl_seconds": 1800,
      "usage_state_file": "${USAGE_STATE}"
    }
  },
  "state": {
    "state_file": "${TMPSTATE}",
    "trivial_file": "${SB_RUNTIME_STATE_DIR}/trivial-test-${TEST_RUN_ID}"
  }
}
EOF
}

run_edit() {
  local input
  input=$(jq -n --arg f "$TMPFILE" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"aaaaaaaaaa", new_string:"bbbbbbbbbb"}}')
  (cd "$TMPDIR_TEST" && export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST" \
    HOME="${HOME:-${TEST_HOME:-$HOME}}" \
    SB_LEANCTX_MCP_ARTIFACT="${SB_LEANCTX_MCP_ARTIFACT:-}" \
    SILVER_BULLET_RUNTIME=cursor PATH="$PATH" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)
}

echo "=== leanctx-gate.sh tests ==="

setup
write_cfg false
install_mock_leanctx
wire_mcp
out="$(run_edit)"
assert_allow "opted out allows edit" "$out"

setup
write_cfg true
isolate_home
out="$(run_edit)"
assert_deny "opted in without CLI denies" "$out" "CLI not installed"

setup
write_cfg true
install_mock_leanctx
isolate_home
out="$(run_edit)"
assert_deny "opted in without MCP denies" "$out" "NOT WIRED"

setup
write_cfg true true
install_mock_leanctx
wire_mcp
out="$(run_edit)"
assert_allow "suspended bypasses gate" "$out"

setup
write_cfg true
install_mock_leanctx
wire_mcp
out="$(run_edit)"
assert_deny "stale usage denies substantive edit" "$out" "USAGE REQUIRED"

setup
write_cfg true
install_mock_leanctx
wire_mcp
# shellcheck source=hooks/lib/leanctx-gate.sh
source "$REPO_ROOT/hooks/lib/leanctx-gate.sh"
sb_leanctx_record_usage "$TMPCFG"
if sb_leanctx_usage_is_fresh "$TMPCFG"; then
  echo "  PASS: usage fresh before gate"
  PASS=$((PASS + 1))
else
  echo "  FAIL: usage fresh before gate"
  FAIL=$((FAIL + 1))
fi
out="$(run_edit)"
assert_allow "fresh usage allows edit" "$out"

setup
write_cfg true
install_mock_leanctx
wire_mcp
date +%s >"$USAGE_STATE"
input=$(jq -n --arg f "$TMPCFG" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
out="$(cd "$TMPDIR_TEST" && export HOME="$TEST_HOME" SB_LEANCTX_MCP_ARTIFACT="$TEST_HOME/.cursor/mcp.json" \
  SILVER_BULLET_RUNTIME=cursor PATH="$PATH" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)"
assert_allow "silver-bullet.json exempt" "$out"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
