#!/usr/bin/env bash
# Tests for hooks/record-token-compression-usage.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

RECORD_HOOK="$REPO_ROOT/hooks/record-token-compression-usage.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" "${SB_TEST_DIR}/rtk-usage-${TEST_RUN_ID}"
}
trap cleanup_all EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  RTK_STATE="${SB_TEST_DIR}/rtk-usage-${TEST_RUN_ID}"
  rm -f "$RTK_STATE"
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat >"$TMPDIR_TEST/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "rtk": {
      "enabled_by_user": true,
      "install_status": "installed",
      "usage_state_file": "${RTK_STATE}"
    }
  },
  "state": { "state_file": "${SB_TEST_DIR}/state-${TEST_RUN_ID}" }
}
EOF
  git -C "$TMPDIR_TEST" init -q
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
  rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
}

run_bash_hook() {
  local cmd="$1" exit_code="${2:-0}"
  local input
  input=$(jq -n --arg c "$cmd" --argjson ec "$exit_code" \
    '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:$c}, tool_response:{exit_code:$ec}}')
  (cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$RECORD_HOOK" 2>/dev/null)
}

echo "=== record-token-compression-usage.sh tests ==="

setup
run_bash_hook 'rtk gain --help' 0
if [[ -f "$RTK_STATE" ]] && grep -qE '^[0-9]+$' "$RTK_STATE"; then
  pass "records epoch on successful rtk CLI usage"
else
  fail "records epoch on successful rtk CLI usage"
fi

setup
run_bash_hook 'rtk gain --help' 1
if [[ ! -f "$RTK_STATE" ]]; then
  pass "does not record on non-zero exit"
else
  fail "does not record on non-zero exit"
fi

setup
run_bash_hook 'git status' 0
if [[ ! -f "$RTK_STATE" ]]; then
  pass "ignores non-rtk commands"
else
  fail "ignores non-rtk commands"
fi

setup
cat >"$TMPDIR_TEST/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": { "rtk": { "enabled_by_user": false } }
}
EOF
run_bash_hook 'rtk gain --help' 0
if [[ ! -f "$RTK_STATE" ]]; then
  pass "enabled_by_user false skips recording"
else
  fail "enabled_by_user false skips recording"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
