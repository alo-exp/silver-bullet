#!/usr/bin/env bash
# Tests for SB_AGENT_CERT_RUN bypass across substantive PreToolUse gates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/graphify-query-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/agentmemory-usage-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
}
trap cleanup_all EXIT

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
  cat >"$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat >"$TMPCFG" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "recommended_tools": {
    "graphify": {
      "enabled_by_user": true,
      "usage_state_file": "${GRAPHIFY_STATE}",
      "graph_path": "graphify-out/graph.json"
    },
    "agentmemory": {
      "enabled_by_user": true,
      "usage_state_file": "${AM_STATE}",
      "export_root": ".agentmemory"
    },
    "alumnium": { "enabled_by_user": true },
    "leanctx": { "enabled_by_user": true },
    "context_mode": { "enabled_by_user": true },
    "rtk": { "enabled_by_user": true }
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
  AM_STATE="${SB_TEST_DIR}/agentmemory-usage-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPFILE="${TMPDIR_TEST}/src/app.js"
  rm -f "$TMPSTATE" "$GRAPHIFY_STATE" "$AM_STATE"
  mkdir -p "$(dirname "$TMPFILE")" "${TMPDIR_TEST}/graphify-out" "${TMPDIR_TEST}/.agentmemory/memory"
  touch "$TMPFILE"
  git -C "$TMPDIR_TEST" init -q
  git -C "$TMPDIR_TEST" config user.email "test@test.com"
  git -C "$TMPDIR_TEST" config user.name "Test"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
}

run_gate() {
  local gate_hook="$1"
  local input
  input=$(jq -n --arg f "$TMPFILE" --arg c 'git commit -m "cert test"' \
    '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$c, file_path:$f}}')
  (
    cd "$TMPDIR_TEST"
    export SB_AGENT_CERT_RUN=1
    export PATH="/usr/bin:/bin"
    printf '%s' "$input" | bash "$gate_hook" 2>/dev/null
  )
}

echo "=== cert-bypass gate tests ==="

GATES=(
  graphify-gate.sh
  agentmemory-gate.sh
  alumnium-gate.sh
  leanctx-gate.sh
  context-mode-gate.sh
  rtk-gate.sh
  token-compression-tools-gate.sh
  stack-compression-coordinator.sh
  workflow-chain-guard.sh
  completion-audit.sh
)

for gate in "${GATES[@]}"; do
  setup
  write_cfg
  out="$(run_gate "$REPO_ROOT/hooks/$gate")"
  assert_allow "SB_AGENT_CERT_RUN bypasses $gate" "$out"
done

setup
write_cfg
input=$(jq -n '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:"src/app.js", old_string:"a", new_string:"b"}}')
out="$(
  cd "$TMPDIR_TEST"
  export SB_AGENT_CERT_RUN=1
  export SB_ORCHESTRATOR_PARENT=0
  export SB_ORCHESTRATOR_WORKER=1
  export SILVER_BULLET_PROJECT_ROOT="$TMPDIR_TEST"
  printf '%s' "$input" | bash "$REPO_ROOT/hooks/orchestrator-directive-guard.sh" 2>/dev/null
)"
assert_allow "SB_AGENT_CERT_RUN bypasses orchestrator-directive-guard" "$out"

# shellcheck source=scripts/lib/agent-delegate-common.sh
source "$REPO_ROOT/scripts/lib/agent-delegate-common.sh"
export SB_AGENT_CERT_RUN=1
if agent_delegate_preflight_recommended_tools "$TMPDIR_TEST" "$REPO_ROOT" "claude"; then
  echo "  PASS: cert preflight skip in agent-delegate-common"
  PASS=$((PASS + 1))
else
  echo "  FAIL: cert preflight skip in agent-delegate-common"
  FAIL=$((FAIL + 1))
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
