#!/usr/bin/env bash
# Tests for sb_orchestrator_seed_delegation_directive standalone bootstrap.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=hooks/lib/runtime-paths.sh
source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
# shellcheck source=hooks/lib/orchestrator-directive.sh
source "$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
# shellcheck source=hooks/lib/orchestrator-parent.sh
source "$REPO_ROOT/hooks/lib/orchestrator-parent.sh"

PASS=0
FAIL=0
TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/delegation-directive-${TEST_RUN_ID}"
mkdir -p "$SB_RUNTIME_STATE_DIR"

cleanup() {
  sb_orchestrator_directive_clear 2>/dev/null || true
  rm -rf "$SB_RUNTIME_STATE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

check() {
  local desc="$1" result="$2"
  if [[ "$result" == pass ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== orchestrator delegation directive tests ==="

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

WORK=$(mktemp -d)
brief="$WORK/brief.md"
echo '## Task\ntest' >"$brief"
scopes='["'"$WORK"'"]'

sb_orchestrator_seed_delegation_directive cursor task-abc "$brief" "$scopes" && check "seed returns success" pass || check "seed returns success" fail

[[ -f "$(sb_orchestrator_directive_file)" ]] && check "directive file written" pass || check "directive file written" fail

skill="$(jq -r '.next_skill' "$(sb_orchestrator_directive_file)")"
template="$(jq -r '.next_worker_template' "$(sb_orchestrator_directive_file)")"
af="$(jq -r '.args' "$(sb_orchestrator_directive_file)" | jq -r '.atomic_flow_id // empty' 2>/dev/null || true)"

[[ "$skill" == "silver-agent-cursor" ]] && check "next_skill host cursor" pass || check "next_skill host cursor" fail
[[ "$template" == "AGENT-DELEGATE" ]] && check "worker template AGENT-DELEGATE" pass || check "worker template AGENT-DELEGATE" fail
[[ "$af" == "AF-AGENT-DELEGATE" ]] && check "args atomic_flow_id" pass || check "args atomic_flow_id" fail

[[ "$(sb_orchestrator_worker_template_for_skill silver-agent-codex)" == "AGENT-DELEGATE" ]] \
  && check "mapper codex AGENT-DELEGATE" pass || check "mapper codex AGENT-DELEGATE" fail
[[ "$(sb_orchestrator_worker_template_for_skill silver-agent-cursor)" == "AGENT-DELEGATE" ]] \
  && check "mapper cursor AGENT-DELEGATE" pass || check "mapper cursor AGENT-DELEGATE" fail
[[ "$(sb_orchestrator_worker_template_for_skill silver-agent-claude)" == "AGENT-DELEGATE" ]] \
  && check "mapper claude AGENT-DELEGATE" pass || check "mapper claude AGENT-DELEGATE" fail

sb_orchestrator_seed_delegation_directive claude task-claude "$brief" "$scopes" && check "seed claude returns success" pass || check "seed claude returns success" fail
skill_claude="$(jq -r '.next_skill' "$(sb_orchestrator_directive_file)")"
[[ "$skill_claude" == "silver-agent-claude" ]] && check "next_skill host claude" pass || check "next_skill host claude" fail

rm -rf "$WORK"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
