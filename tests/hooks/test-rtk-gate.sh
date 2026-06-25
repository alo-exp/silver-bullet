#!/usr/bin/env bash
# Tests for hooks/rtk-gate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

ORIG_HOME="${HOME:-}"

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

GATE_HOOK="$REPO_ROOT/hooks/rtk-gate.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0
MOCK_BIN=""
TEST_HOME=""

cleanup_all() {
  rm -rf "$TMPDIR_TEST" "${SB_RUNTIME_STATE_DIR}/test-state-${TEST_RUN_ID}" \
    "${SB_RUNTIME_STATE_DIR}/trivial-test-${TEST_RUN_ID}" "$MOCK_BIN" "$TEST_HOME"
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

install_mock_rtk() {
  MOCK_BIN="$(mktemp -d)"
  cat >"$MOCK_BIN/rtk" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "rtk 0.42.4"; exit 0; fi
if [[ "${1:-}" == "gain" ]]; then [[ "${2:-}" == "--help" ]] && exit 0; exit 0; fi
exit 0
EOF
  chmod +x "$MOCK_BIN/rtk"
  export PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
}

isolate_home() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME" SILVER_BULLET_RUNTIME=cursor
}

wire_hook() {
  isolate_home
  mkdir -p "$TEST_HOME/.cursor"
  printf '{"hooks":[{"command":"rtk hook cursor"}]}\n' >"$TEST_HOME/.cursor/hooks.json"
}

write_cfg() {
  local enabled="${1:-true}" suspended="${2:-false}"
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "rtk": {
      "enabled_by_user": ${enabled},
      "enforcement_suspended": ${suspended}
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
  TMPFILE="${TMPDIR_TEST}/src/app.js"
  MOCK_BIN=""
  TEST_HOME=""
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  export HOME="$ORIG_HOME"
  unset SILVER_BULLET_RUNTIME SB_RTK_HOOK_ARTIFACT 2>/dev/null || true
  mkdir -p "$(dirname "$TMPFILE")"
  touch "$TMPFILE"
  git -C "$TMPDIR_TEST" init -q
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
  rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
}

run_edit() {
  local input
  input=$(jq -n --arg f "$TMPFILE" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
  (cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)
}

echo "=== rtk-gate.sh tests ==="

setup
write_cfg false
install_mock_rtk
wire_hook
out="$(run_edit)"
assert_allow "opted out allows edit" "$out"

setup
write_cfg true
isolate_home
out="$(run_edit)"
assert_deny "opted in without CLI denies" "$out"

setup
write_cfg true
install_mock_rtk
isolate_home
out="$(run_edit)"
assert_deny "opted in without hook denies" "$out"

setup
write_cfg true true
install_mock_rtk
wire_hook
out="$(run_edit)"
assert_allow "suspended bypasses gate" "$out"

setup
write_cfg true
install_mock_rtk
wire_hook
out="$(run_edit)"
assert_allow "fully wired allows edit" "$out"

setup
write_cfg true
install_mock_rtk
wire_hook
input=$(jq -n --arg f "$TMPCFG" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
out="$(cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)"
assert_allow "silver-bullet.json exempt" "$out"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
