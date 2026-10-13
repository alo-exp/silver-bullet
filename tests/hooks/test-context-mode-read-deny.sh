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
  local enabled="${1:-true}" suspended="${2:-false}" deny_bytes="${3:-5120}"
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
<!-- BEGIN context-mode hint (do not edit) -->
Use ctx_index and ctx_search for large files.
<!-- END context-mode hint (do not edit) -->
EOF
  cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "context_mode": {
      "enabled_by_user": ${enabled},
      "enforcement_suspended": ${suspended},
      "read_deny_bytes": ${deny_bytes}
    }
  },
  "skills": { "required_planning": ["silver-quality-gates"] },
  "state": {
    "state_file": "${TMPSTATE}",
    "trivial_file": "${SB_RUNTIME_STATE_DIR}/trivial-test-${TEST_RUN_ID}"
  }
}
EOF
}

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  TEST_RUN_ID="$$"
  TMPSTATE="${SB_RUNTIME_STATE_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  SMALL="${TMPDIR_TEST}/small.txt"
  BIG="${TMPDIR_TEST}/large.txt"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
  git -C "$TMPDIR_TEST" init -q
  printf 'x' >"$SMALL"
  python3 - "$BIG" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text("x" * 6000)
PY
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
}

run_read() {
  local target="$1"
  local input
  input=$(jq -n --arg f "$target" \
    '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:$f}}')
  (cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null)
}

run_grep() {
  local target="$1"
  local input
  input=$(jq -n --arg p "$target" \
    '{hook_event_name:"PreToolUse", tool_name:"Grep", tool_input:{pattern:"foo", path:$p}}')
  (cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null)
}

echo "=== context-mode-read-deny.sh tests ==="

setup
write_cfg false
out="$(run_read "$BIG")"
assert_allow "opted out allows large read" "$out"

setup
write_cfg true
out="$(run_read "$BIG")"
assert_deny "opted in denies large read" "$out"

setup
write_cfg true
export CONTEXT_MODE_READ_DENY_BYPASS=1
out="$(run_read "$BIG")"
unset CONTEXT_MODE_READ_DENY_BYPASS
assert_allow "CONTEXT_MODE_READ_DENY_BYPASS allows large read" "$out"

setup
write_cfg true false 0
out="$(run_read "$BIG")"
assert_allow "read_deny_bytes 0 disables deny" "$out"

setup
write_cfg true true
out="$(run_read "$BIG")"
assert_allow "suspended bypasses deny" "$out"

setup
write_cfg true
out="$(run_read "$SMALL")"
assert_allow "small file allowed" "$out"

setup
write_cfg true
out="$(run_read "$TMPCFG")"
assert_allow "config file exempt" "$out"

setup
write_cfg true
out="$(run_grep "$BIG")"
assert_deny "grep on large file denied" "$out"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
