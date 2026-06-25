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
trap 'rm -rf "$TMPDIR_TEST"' EXIT

TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
mkdir -p "${TMPDIR_TEST}/src"
touch "${TMPDIR_TEST}/src/app.js"
cat >"${TMPDIR_TEST}/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF

cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": {
    "rtk": {
      "enabled_by_user": true,
      "install_status": "installed",
      "cli_command": "rtk",
      "usage_state_file": "${SB_RUNTIME_STATE_DIR}/rtk-usage-test-$$"
    }
  },
  "state": { "state_file": "${SB_RUNTIME_STATE_DIR}/state-test-$$" }
}
EOF

git -C "$TMPDIR_TEST" init -q
MOCK_BIN="$(mktemp -d)"
cat >"$MOCK_BIN/rtk" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/rtk"
export PATH="$MOCK_BIN:$PATH"

# shellcheck source=hooks/lib/token-compression-tools-gate.sh
source "$REPO_ROOT/hooks/lib/token-compression-tools-gate.sh"

sb_token_tool_install_ready "$TMPCFG" rtk && pass "install_ready when installed" || fail "install_ready when installed"
! sb_token_tool_usage_is_fresh "$TMPCFG" rtk && pass "usage stale initially" || fail "usage stale initially"

date +%s >"$(sb_token_tool_usage_state_path "$TMPCFG" rtk)"
sb_token_tool_usage_is_fresh "$TMPCFG" rtk && pass "usage fresh after record" || fail "usage fresh after record"

GATE="$REPO_ROOT/hooks/token-compression-tools-gate.sh"
input=$(jq -n --arg f "${TMPDIR_TEST}/src/app.js" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
out="$(cd "$TMPDIR_TEST" && export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST" SILVER_BULLET_RUNTIME=cursor && printf '%s' "$input" | bash "$GATE" 2>/dev/null)"
if [[ -z "$out" ]] || ! printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "gate allows edit when rtk usage fresh"
else
  fail "gate allows edit when rtk usage fresh — got: $out"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
