#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SILVER_BULLET_RUNTIME=cursor

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST" "$MOCK_MCP"' EXIT

TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
mkdir -p "${TMPDIR_TEST}/src"
touch "${TMPDIR_TEST}/src/app.js"
cat >"${TMPDIR_TEST}/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF

MOCK_MCP="${TMPDIR_TEST}/mcp.json"
printf '{"mcpServers":{"alumnium":{"command":"npx","args":["-y","alumnium","mcp"]}}}\n' >"$MOCK_MCP"
export SB_ALUMNIUM_MCP_ARTIFACT="$MOCK_MCP"

cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": {
    "alumnium": {
      "enabled_by_user": true,
      "install_status": "installed",
      "mcp_server_name": "alumnium"
    }
  },
  "state": { "state_file": "${SB_RUNTIME_STATE_DIR}/state-test-$$" }
}
EOF

git -C "$TMPDIR_TEST" init -q

GATE="$REPO_ROOT/hooks/alumnium-gate.sh"
input=$(jq -n --arg f "${TMPDIR_TEST}/src/app.js" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
out="$(cd "$TMPDIR_TEST" && export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST" SILVER_BULLET_RUNTIME=cursor && printf '%s' "$input" | bash "$GATE" 2>/dev/null)"
if [[ -z "$out" ]] || ! printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "gate allows edit when alumnium MCP wired"
else
  fail "gate allows edit when alumnium MCP wired — got: $out"
fi

rm -f "$MOCK_MCP"
export SB_ALUMNIUM_MCP_ARTIFACT="${TMPDIR_TEST}/missing-mcp.json"
out="$(cd "$TMPDIR_TEST" && export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST" SILVER_BULLET_RUNTIME=cursor && printf '%s' "$input" | bash "$GATE" 2>/dev/null)"
if [[ -z "$out" ]] || ! printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "gate allows non-browser Edit when MCP missing"
else
  fail "gate allows non-browser Edit when MCP missing — got: $out"
fi

plan_input=$(jq -n --arg f "${TMPDIR_TEST}/docs/plan.md" \
  '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f, contents:"# plan"}}')
plan_out="$(cd "$TMPDIR_TEST" && export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST" SILVER_BULLET_RUNTIME=cursor && printf '%s' "$plan_input" | bash "$GATE" 2>/dev/null)"
if [[ -z "$plan_out" ]] || ! printf '%s' "$plan_out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "gate allows non-browser Write when MCP missing"
else
  fail "gate allows non-browser Write when MCP missing — got: $plan_out"
fi

browser_input=$(jq -n --arg f "${TMPDIR_TEST}/e2e/login.spec.ts" \
  '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f, contents:"test"}}')
browser_out="$(cd "$TMPDIR_TEST" && export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST" SILVER_BULLET_RUNTIME=cursor && printf '%s' "$browser_input" | bash "$GATE" 2>/dev/null)"
if printf '%s' "$browser_out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "gate denies e2e browser Write when MCP missing"
else
  fail "gate denies e2e browser Write when MCP missing — got: $browser_out"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
