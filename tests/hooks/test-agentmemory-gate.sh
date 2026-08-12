#!/usr/bin/env bash
# Tests for hooks/agentmemory-gate.sh PreToolUse enforcement
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

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
MOCK_BIN=""

cleanup_all() {
  rm -rf "$TMPDIR_TEST" "${TEST_HOME:-}" "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/agentmemory-usage-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" "$MOCK_BIN"
}
trap cleanup_all EXIT

assert_deny() {
  local label="$1" output="$2"
  if printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected deny, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_allow() {
  local label="$1" output="$2"
  if [[ -z "$output" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
    return
  fi
  if printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    echo "  FAIL: $label — expected allow, got deny: $output"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  fi
}

install_mock_agentmemory() {
  MOCK_BIN="$(mktemp -d)"
  cat >"$MOCK_BIN/agentmemory" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
if printf '%s' "$*" | grep -q 'agentmemory/health'; then exit 0; fi
command -v /usr/bin/curl >/dev/null && exec /usr/bin/curl "$@" || exit 0
EOF
  chmod +x "$MOCK_BIN/agentmemory" "$MOCK_BIN/curl"
  export PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
}

write_cfg() {
  local enabled="${1:-true}"
  local initiated="${2:-true}"
  local suspended="${3:-false}"
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": ${initiated},
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "agentmemory": {
      "enabled_by_user": ${enabled},
      "enforcement_suspended": ${suspended},
      "usage_state_file": "${AM_STATE}",
      "export_root": ".agentmemory"
    }
  },
  "skills": { "required_planning": ["silver-quality-gates"] },
  "state": {
    "state_file": "${TMPSTATE}",
    "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  }
}
EOF
}

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  AM_STATE="${SB_TEST_DIR}/agentmemory-usage-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPFILE="${TMPDIR_TEST}/src/app.js"
  rm -f "$TMPSTATE" "$AM_STATE" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  mkdir -p "$(dirname "$TMPFILE")" "${TMPDIR_TEST}/.agentmemory/memory"
  touch "$TMPFILE"
  git -C "$TMPDIR_TEST" init -q
  git -C "$TMPDIR_TEST" config user.email "test@test.com"
  git -C "$TMPDIR_TEST" config user.name "Test"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
}

run_edit() {
  local input
  input=$(jq -n --arg f "$TMPFILE" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
  (cd "$TMPDIR_TEST" && export PATH="${PATH:-/usr/bin:/bin}" SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-cursor}" SILVER_BULLET_PROJECT_ROOT="${SILVER_BULLET_PROJECT_ROOT:-$TMPDIR_TEST}" HOME="${TEST_HOME:-$HOME}" SB_AGENTMEMORY_MCP_ARTIFACT="${SB_AGENTMEMORY_MCP_ARTIFACT:-}" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="${SB_TEST_DIR}" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)
}

wire_test_mcp() {
  TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.cursor"
  TEST_MCP="${TEST_HOME}/.cursor/mcp.json"
  printf '{"mcpServers":{"agentmemory":{"command":"npx","args":["-y","@agentmemory/mcp"]}}}\n' >"$TEST_MCP"
  export TEST_HOME TEST_MCP SB_AGENTMEMORY_MCP_ARTIFACT="$TEST_MCP" SILVER_BULLET_RUNTIME=cursor
}

unwire_test_mcp() {
  rm -rf "${TEST_HOME:-}"
  unset TEST_HOME TEST_MCP SB_AGENTMEMORY_MCP_ARTIFACT
}

echo "=== agentmemory-gate.sh tests ==="

setup
write_cfg false true
install_mock_agentmemory
out="$(run_edit)"
assert_allow "enabled_by_user false bypasses gate" "$out"

setup
write_cfg null true
install_mock_agentmemory
out="$(run_edit)"
assert_allow "consent pending bypasses gate" "$out"

setup
write_cfg true true true
install_mock_agentmemory
out="$(run_edit)"
assert_allow "enforcement_suspended bypasses gate" "$out"

setup
write_cfg true true
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
out="$(run_edit)"
assert_deny "no CLI blocks edit" "$out"

setup
write_cfg true true
install_mock_agentmemory
export SB_AGENTMEMORY_MCP_ARTIFACT="/no/such/agentmemory-mcp-${TEST_RUN_ID}.json"
out="$(run_edit)"
unset SB_AGENTMEMORY_MCP_ARTIFACT
assert_allow "CLI without MCP soft-allows edit (#259)" "$out"

setup
write_cfg true true
install_mock_agentmemory
# Force unhealthy server: mock curl fails health
cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
if printf '%s' "$*" | grep -q 'agentmemory/health'; then exit 1; fi
command -v /usr/bin/curl >/dev/null && exec /usr/bin/curl "$@" || exit 1
EOF
chmod +x "$MOCK_BIN/curl"
wire_test_mcp
rm -f "$AM_STATE"
out="$(run_edit)"
unwire_test_mcp
assert_allow "server down soft-allows edit (#259)" "$out"

setup
write_cfg true true
install_mock_agentmemory
wire_test_mcp
rm -f "$AM_STATE"
out="$(run_edit)"
unwire_test_mcp
assert_deny "MCP wired but no fresh usage blocks edit" "$out"

# RED-5: auto-scaffold export root on substantive Write when opted in.
setup
write_cfg true true
GF_STATE="${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}"
jq --arg gf "$GF_STATE" \
  '.recommended_tools.graphify = {"enabled_by_user": true, "query_state_file": $gf}' \
  "$TMPCFG" >"${TMPCFG}.tmp" && mv "${TMPCFG}.tmp" "$TMPCFG"
install_mock_agentmemory
wire_test_mcp
rm -rf "${TMPDIR_TEST}/.agentmemory"
# shellcheck source=hooks/lib/graphify-gate.sh
source "$REPO_ROOT/hooks/lib/graphify-gate.sh"
# shellcheck source=hooks/lib/agentmemory-gate.sh
source "$REPO_ROOT/hooks/lib/agentmemory-gate.sh"
sb_graphify_record_query "$TMPCFG" 2>/dev/null || true
sb_agentmemory_record_usage "$TMPCFG" 2>/dev/null || true
out="$(run_edit)"
unwire_test_mcp
assert_allow "RED-5: gate scaffolds export root and allows edit" "$out"
if [[ -d "${TMPDIR_TEST}/.agentmemory/memory" ]]; then
  echo "  PASS: RED-5: .agentmemory/memory scaffolded"
  PASS=$((PASS + 1))
else
  echo "  FAIL: RED-5: .agentmemory/memory scaffolded"
  FAIL=$((FAIL + 1))
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
