#!/usr/bin/env bash
# Tests for active delegation guard (block/advise tiers, scope, cleanup).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=hooks/lib/runtime-paths.sh
source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
# shellcheck source=hooks/lib/agent-delegation-state.sh
source "$REPO_ROOT/hooks/lib/agent-delegation-state.sh"

PASS=0
FAIL=0
TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/agent-delegation-guard-${TEST_RUN_ID}"
mkdir -p "$SB_RUNTIME_STATE_DIR"
export SB_AGENT_DELEGATE_V2=1
export SB_AGENT_DELEGATE_GUARD=1

cleanup() {
  sb_agent_delegation_deactivate 2>/dev/null || true
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

echo "=== agent-delegation guard tests ==="

WORK=$(mktemp -d)
echo test >"$WORK/owned.txt"
mkdir -p "$WORK/.planning/agent-cursor/task-1"
scopes='["'"$WORK"'"]'

sb_agent_delegation_activate cursor task-1 "$WORK" "$scopes" "$WORK/.planning/agent-cursor/task-1/delegate.log"
sb_agent_delegation_is_active && check "activate sets active state" pass || check "activate sets active state" fail

sb_agent_delegation_path_in_scope "$WORK/owned.txt" "$WORK" && check "owned path in scope" pass || check "owned path in scope" fail
! sb_agent_delegation_path_in_scope "$WORK/.planning/agent-cursor/task-1/brief.md" "$WORK" \
  && check "evidence path allowed" pass || check "evidence path allowed" fail

export SILVER_BULLET_RUNTIME=codex
[[ "$(sb_agent_delegation_parent_host_tier)" == "block" ]] && check "codex parent tier block" pass || check "codex parent tier block" fail
export SILVER_BULLET_RUNTIME=cursor
[[ "$(sb_agent_delegation_parent_host_tier)" == "advise" ]] && check "cursor parent tier advise" pass || check "cursor parent tier advise" fail

export SB_AGENT_DELEGATE_GUARD=0
sb_agent_delegation_activate cursor task-1 "$WORK" "$scopes" ""
! sb_agent_delegation_is_active && check "guard disabled treats as inactive" pass || check "guard disabled treats as inactive" fail
export SB_AGENT_DELEGATE_GUARD=1
sb_agent_delegation_deactivate
! sb_agent_delegation_is_active && check "deactivate clears state" pass || check "deactivate clears state" fail

# shellcheck source=scripts/lib/agent-delegate-common.sh
source "$REPO_ROOT/scripts/lib/agent-delegate-common.sh"
artifact_dir="$WORK/.planning/agent-codex/task-2"
agent_delegate_write_degraded_fallback_evidence "$artifact_dir" codex task-2 SB_AGENT_DELEGATE_DIRECT_FALLBACK "harness test"
[[ -f "$artifact_dir/degraded-fallback.jsonl" ]] && check "degraded fallback evidence written" pass || check "degraded fallback evidence written" fail
grep -q 'EV-DELEGATE-DEGRADED-FALLBACK' "$artifact_dir/degraded-fallback.jsonl" \
  && check "degraded evidence id present" pass || check "degraded evidence id present" fail

[[ -x "$REPO_ROOT/hooks/agent-delegation-guard.sh" ]] && check "guard hook executable" pass || check "guard hook executable" fail
grep -q 'agent-delegation-guard.sh' "$REPO_ROOT/hooks/hooks.json" && check "registered in hooks.json" pass || check "registered in hooks.json" fail
grep -q 'agent-delegation-guard.sh' "$REPO_ROOT/hooks/cursor-hooks.json" && check "registered in cursor-hooks.json" pass || check "registered in cursor-hooks.json" fail

bash -n "$REPO_ROOT/hooks/agent-delegation-guard.sh" && check "guard shell syntax" pass || check "guard shell syntax" fail

rm -rf "$WORK"
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
