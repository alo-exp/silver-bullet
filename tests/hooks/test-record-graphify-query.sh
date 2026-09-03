#!/usr/bin/env bash
# Tests for hooks/record-graphify-query.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RECORD_HOOK="$REPO_ROOT/hooks/record-graphify-query.sh"
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

cleanup_all() {
  rm -rf "$TMPDIR_TEST" "${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}"
}
trap cleanup_all EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  GRAPHIFY_STATE="${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}"
  rm -f "$GRAPHIFY_STATE"
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat >"$TMPDIR_TEST/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "graphify": {
      "enabled_by_user": true,
      "query_state_file": "${GRAPHIFY_STATE}"
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

echo "=== record-graphify-query.sh tests ==="

setup
run_bash_hook 'graphify query "test context" --graph graphify-out/graph.json' 0
if [[ -f "$GRAPHIFY_STATE" ]] && grep -qE '^[0-9]+$' "$GRAPHIFY_STATE"; then
  pass "records epoch on successful graphify query"
else
  fail "records epoch on successful graphify query"
fi

setup
run_bash_hook 'graphify query "test" --graph graphify-out/graph.json' 1
if [[ ! -f "$GRAPHIFY_STATE" ]]; then
  pass "does not record on non-zero exit"
else
  fail "does not record on non-zero exit"
fi

setup
run_bash_hook 'git status' 0
if [[ ! -f "$GRAPHIFY_STATE" ]]; then
  pass "ignores non-graphify commands"
else
  fail "ignores non-graphify commands"
fi

setup
cat >"$TMPDIR_TEST/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": { "graphify": { "enabled_by_user": false } }
}
EOF
run_bash_hook 'graphify query "x" --graph graphify-out/graph.json' 0
if [[ ! -f "$GRAPHIFY_STATE" ]]; then
  pass "enabled_by_user false skips recording"
else
  fail "enabled_by_user false skips recording"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
