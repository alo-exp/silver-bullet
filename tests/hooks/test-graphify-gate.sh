#!/usr/bin/env bash
# Tests for hooks/graphify-gate.sh and hooks/lib/graphify-gate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE_HOOK="$REPO_ROOT/hooks/graphify-gate.sh"
LIB="$REPO_ROOT/hooks/lib/graphify-gate.sh"
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
  rm -rf "$TMPDIR_TEST" "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}" \
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

assert_contains() {
  local label="$1" output="$2" needle="$3"
  if printf '%s' "$output" | grep -F -- "$needle" >/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected [$needle] in: $output"
    FAIL=$((FAIL + 1))
  fi
}

install_mock_graphify() {
  MOCK_BIN="$(mktemp -d)"
  cat >"$MOCK_BIN/graphify" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/graphify"
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
    "graphify": {
      "enabled_by_user": ${enabled},
      "enforcement_suspended": ${suspended},
      "graph_path": "graphify-out/graph.json",
      "query_ttl_seconds": 1800,
      "query_state_file": "${GRAPHIFY_STATE}"
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
  GRAPHIFY_STATE="${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPFILE="${TMPDIR_TEST}/src/app.js"
  rm -f "$TMPSTATE" "$GRAPHIFY_STATE" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  mkdir -p "$(dirname "$TMPFILE")" "${TMPDIR_TEST}/graphify-out"
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
  (cd "$TMPDIR_TEST" && export PATH="${PATH:-/usr/bin:/bin}" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)
}

run_bash() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$c}}')
  (cd "$TMPDIR_TEST" && export PATH="${PATH:-/usr/bin:/bin}" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)
}

echo "=== graphify-gate.sh tests ==="

setup
unset SILVER_BULLET_PROJECT_ROOT
rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
out="$(run_edit)"
assert_allow "no silver-bullet.md config boundary" "$out"
export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"

setup
write_cfg true false
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
out="$(run_edit)"
assert_deny "config present enforces gate regardless of sb_initiated" "$out"

setup
write_cfg false true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
out="$(run_edit)"
assert_allow "enabled_by_user false bypasses gate" "$out"

setup
write_cfg null true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
out="$(run_edit)"
assert_allow "consent pending bypasses gate" "$out"

setup
write_cfg true true true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
out="$(run_edit)"
assert_allow "enforcement_suspended bypasses gate despite opt-in" "$out"

setup
write_cfg true true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out="$(run_edit)"
assert_allow "trivial bypass" "$out"

setup
write_cfg true true
touch "${TMPDIR_TEST}/graphify-out/graph.json"
input=$(jq -n --arg f "$TMPFILE" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"a", new_string:"b"}}')
out="$(cd "$TMPDIR_TEST" && export PATH="/usr/bin:/bin" HOME="$(mktemp -d)" && printf '%s' "$input" | bash "$GATE_HOOK" 2>/dev/null)"
assert_deny "CLI missing blocks when opted in" "$out"
assert_contains "CLI missing message" "$out" "GRAPHIFY REQUIRED"

setup
write_cfg true true
install_mock_graphify
out="$(run_edit)"
assert_deny "index missing blocks edit" "$out"
assert_contains "index missing reason" "$out" "GRAPHIFY INDEX MISSING"

setup
write_cfg true true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
out="$(run_edit)"
assert_deny "no fresh query blocks edit" "$out"
assert_contains "stale query reason" "$out" "GRAPHIFY QUERY REQUIRED"

setup
write_cfg true true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
date +%s >"$GRAPHIFY_STATE"
out="$(run_edit)"
assert_allow "fresh query allows edit" "$out"

setup
write_cfg true true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
printf '1\n' >"$GRAPHIFY_STATE"
out="$(run_edit)"
assert_deny "stale query blocks edit" "$out"

setup
write_cfg true true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
out="$(run_bash 'graphify query "hooks graphify-gate" --graph graphify-out/graph.json')"
assert_allow "graphify query command exempt" "$out"

setup
write_cfg true true
install_mock_graphify
GF="${TMPDIR_TEST}/graphify-out/graph.json"
touch "$GF"
out="$(jq -n --arg f "$GF" \
  '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f}}' | (cd "$TMPDIR_TEST" && bash "$GATE_HOOK" 2>/dev/null))"
assert_allow "graphify-out path exempt" "$out"

setup
write_cfg true true
install_mock_graphify
touch "${TMPDIR_TEST}/graphify-out/graph.json"
out="$(run_bash 'git commit -m "test"')"
assert_deny "git commit requires fresh query" "$out"

# shellcheck source=hooks/lib/graphify-gate.sh
source "$LIB"
if sb_graphify_command_is_retrieval 'graphify query "foo" --graph graphify-out/graph.json'; then
  echo "  PASS: retrieval command detected"
  PASS=$((PASS + 1))
else
  echo "  FAIL: retrieval command not detected"
  FAIL=$((FAIL + 1))
fi

if sb_graphify_command_is_exempt 'git status'; then
  echo "  PASS: git status exempt"
  PASS=$((PASS + 1))
else
  echo "  FAIL: git status should be exempt"
  FAIL=$((FAIL + 1))
fi

assert_contains "core-rules layer 13" "$(cat "$REPO_ROOT/hooks/core-rules.md")" "Graphify retrieval gate"
assert_contains "core-rules opt-in" "$(cat "$REPO_ROOT/hooks/core-rules.md")" "enabled_by_user"

if grep -q 'command -v jq' "$GATE_HOOK"; then
  echo "  PASS: jq guard present in graphify-gate.sh"
  PASS=$((PASS + 1))
else
  echo "  FAIL: jq guard missing in graphify-gate.sh"
  FAIL=$((FAIL + 1))
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
