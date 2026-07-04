#!/usr/bin/env bash
# Structural contract for /silver:agent-codex skill and delegate wrapper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/silver-agent-codex/SKILL.md"
WRAPPER="${REPO_ROOT}/scripts/agent-codex-delegate.sh"

PASS=0
FAIL=0

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

echo "=== agent-codex skill structural tests ==="

if [[ -f "$SKILL" ]]; then
  check "SKILL.md exists" pass
else
  check "SKILL.md exists" fail
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

grep -qE '^name: silver-agent-codex$' "$SKILL" && check "frontmatter name silver-agent-codex" pass || check "frontmatter name silver-agent-codex" fail
grep -q 'user-invocable: true' "$SKILL" && check "user-invocable" pass || check "user-invocable" fail
grep -q '/silver:agent-codex' "$SKILL" && check "route documented" pass || check "route documented" fail
grep -q 'codex-interactive-invoke.py' "$SKILL" && check "references invoke harness" pass || check "references invoke harness" fail
grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$SKILL" && check "excludes matrix env" pass || check "excludes matrix env" fail
grep -q 'agent-codex-delegate.sh' "$SKILL" && check "references delegate wrapper" pass || check "references delegate wrapper" fail
grep -q 'agentmemory' "$SKILL" && check "documents agentmemory capture" pass || check "documents agentmemory capture" fail
grep -q 'graphify' "$SKILL" && check "documents graphify capture" pass || check "documents graphify capture" fail
grep -q 'AF-AGENT-DELEGATE' "$SKILL" && check "documents AF-AGENT-DELEGATE" pass || check "documents AF-AGENT-DELEGATE" fail
grep -q 'SB_AGENT_DELEGATE_V2' "$SKILL" && check "documents V2 opt-in flag" pass || check "documents V2 opt-in flag" fail
grep -q 'AGENT-DELEGATE' "$SKILL" && check "documents native worker template" pass || check "documents native worker template" fail

[[ -x "$WRAPPER" ]] && check "delegate wrapper executable" pass || check "delegate wrapper executable" fail
grep -q 'tests/live/agents/codex/agent.sh' "$WRAPPER" && check "wrapper uses live agent adapter" pass || check "wrapper uses live agent adapter" fail
grep -q 'scripts/lib/codex-cli.sh' "$WRAPPER" && check "wrapper sources scripts/lib codex-cli" pass || check "wrapper sources scripts/lib codex-cli" fail
grep -q 'AGENT_CODEX_QUOTA_RETRY' "$WRAPPER" && check "wrapper quota retry env" pass || check "wrapper quota retry env" fail
grep -q 'SB_AGENT_CODEX_MODEL_READY_TIMEOUT' "$WRAPPER" && check "wrapper model-ready timeout env" pass || check "wrapper model-ready timeout env" fail
grep -q 'CODEX_EXEC_TAIL_IDLE_TIMEOUT' "$WRAPPER" && check "wrapper exec tail idle timeout env" pass || check "wrapper exec tail idle timeout env" fail
grep -q 'CODEX_EXEC_TAIL_IDLE_TIMEOUT' "${REPO_ROOT}/tests/live/agents/codex/agent.sh" && check "adapter exec tail idle timeout" pass || check "adapter exec tail idle timeout" fail
grep -q 'exec_output_shows_product_evidence' "${REPO_ROOT}/tests/live/agents/codex/agent.sh" && check "adapter exec product evidence detection" pass || check "adapter exec product evidence detection" fail
grep -q 'SB_AGENT_CODEX_LIGHTWEIGHT' "$WRAPPER" && check "wrapper lightweight env default" pass || check "wrapper lightweight env default" fail
grep -q 'SB_ORCHESTRATOR_WORKER' "$WRAPPER" && check "wrapper orchestrator worker bypass" pass || check "wrapper orchestrator worker bypass" fail
grep -q 'RTK_DISABLED=1' "$WRAPPER" && check "wrapper disables RTK for logs" pass || check "wrapper disables RTK for logs" fail
! grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$WRAPPER" && check "wrapper omits matrix env" pass || check "wrapper omits matrix env" fail

bash -n "$WRAPPER" && check "wrapper shell syntax" pass || check "wrapper shell syntax" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
