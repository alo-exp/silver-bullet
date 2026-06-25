#!/usr/bin/env bash
# Tests for hooks/context-mode-read-deny.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$REPO_ROOT/hooks/context-mode-read-deny.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

cleanup_all() {
  rm -rf "$TMPDIR_TEST" "${SB_RUNTIME_STATE_DIR}/test-state-${TEST_RUN_ID}" \
    "${SB_RUNTIME_STATE_DIR}/trivial-test-${TEST_RUN_ID}"
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

write_cfg() {
  local enabled="${1:-true}" suspended="${2:-false}"
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'MD'
# Silver Bullet
MD
  cat >"$TMPCFG" <<JSON
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "context_mode": {
      "enabled_by_user": ${enabled},
      "enforcement_suspended": ${suspended},
      "read_deny_bytes": 5120
    }
  },
  "skills": { "required_planning": ["silver-quality-gates"] },
  "state": {
    "state_file": "${TMPSTATE}",
    "trivial_file": "${SB_RUNTIME_STATE_DIR}/trivial-test-${TEST_RUN_ID}"
  }
}
JSON
}

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  TEST_RUN_ID="$$"
  TMPSTATE="${SB_RUNTIME_STATE_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  LARGE="${TMPDIR_TEST}/large.bin"
  SMALL="${TMPDIR_TEST}/small.bin"
  python3 -c "open('${LARGE}','wb').write(b'0'*6000)"
  printf 'x' >"$SMALL"
  git -C "$TMPDIR_TEST" init -q
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
}

run_read() {
  local target="$1"
  local input
  input=$(jq -n --arg f "$target" '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:$f}}')
  (cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null)
}

echo "=== context-mode-read-deny.sh tests ==="

setup
write_cfg false
out="$(run_read "$LARGE")"
assert_allow "opted out allows large read" "$out"

setup
write_cfg true
out="$(run_read "$LARGE")"
assert_deny "opted in denies large read" "$out"

setup
write_cfg true
out="$(run_read "$SMALL")"
assert_allow "opted in allows small read" "$out"

setup
write_cfg true true
out="$(run_read "$LARGE")"
assert_allow "suspended allows large read" "$out"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
