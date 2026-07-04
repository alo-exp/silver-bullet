#!/usr/bin/env bash
# Structural contract for /silver:agent-cursor skill and delegate wrapper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/silver-agent-cursor/SKILL.md"
WRAPPER="${REPO_ROOT}/scripts/agent-cursor-delegate.sh"
ADAPTER="${REPO_ROOT}/tests/live/agents/cursor/agent.sh"

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

echo "=== agent-cursor skill structural tests ==="

if [[ -f "$SKILL" ]]; then
  check "SKILL.md exists" pass
else
  check "SKILL.md exists" fail
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

grep -qE '^name: silver-agent-cursor$' "$SKILL" && check "frontmatter name silver-agent-cursor" pass || check "frontmatter name silver-agent-cursor" fail
grep -q 'user-invocable: true' "$SKILL" && check "user-invocable" pass || check "user-invocable" fail
grep -q '/silver:agent-cursor' "$SKILL" && check "route documented" pass || check "route documented" fail
grep -q 'tests/live/agents/cursor/agent.sh' "$SKILL" && check "references live adapter" pass || check "references live adapter" fail
grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$SKILL" && check "excludes matrix env" pass || check "excludes matrix env" fail
grep -q 'agent-cursor-delegate.sh' "$SKILL" && check "references delegate wrapper" pass || check "references delegate wrapper" fail
grep -q 'composer-2.5' "$SKILL" && check "documents composer-2.5 model policy" pass || check "documents composer-2.5 model policy" fail
grep -q 'CURSOR_API_KEY' "$SKILL" && check "documents Keychain auth policy" pass || check "documents Keychain auth policy" fail
grep -q 'stream-json' "$SKILL" && check "documents stream-json capture" pass || check "documents stream-json capture" fail
grep -q 'agentmemory' "$SKILL" && check "documents agentmemory capture" pass || check "documents agentmemory capture" fail
grep -q 'graphify' "$SKILL" && check "documents graphify capture" pass || check "documents graphify capture" fail
grep -q 'AF-AGENT-DELEGATE' "$SKILL" && check "documents AF-AGENT-DELEGATE" pass || check "documents AF-AGENT-DELEGATE" fail
grep -q 'SB_AGENT_DELEGATE_V2' "$SKILL" && check "documents V2 default-on flag" pass || check "documents V2 default-on flag" fail
grep -q 'AGENT-DELEGATE' "$SKILL" && check "documents native worker template" pass || check "documents native worker template" fail
grep -q 'SB_AGENT_CURSOR_LOG_FLOOR' "$SKILL" && check "documents log floor gate" pass || check "documents log floor gate" fail

[[ -x "$WRAPPER" ]] && check "delegate wrapper executable" pass || check "delegate wrapper executable" fail
grep -q 'tests/live/agents/cursor/agent.sh' "$WRAPPER" && check "wrapper uses live agent adapter" pass || check "wrapper uses live agent adapter" fail
grep -q 'AGENT_CURSOR_QUOTA_RETRY' "$WRAPPER" && check "wrapper quota retry env" pass || check "wrapper quota retry env" fail
grep -q 'SB_AGENT_CURSOR_STREAM_JSON' "$WRAPPER" && check "wrapper stream-json env" pass || check "wrapper stream-json env" fail
grep -q 'SB_ORCHESTRATOR_WORKER' "$WRAPPER" && check "wrapper orchestrator worker bypass" pass || check "wrapper orchestrator worker bypass" fail
grep -q 'RTK_DISABLED=1' "$WRAPPER" && check "wrapper disables RTK for logs" pass || check "wrapper disables RTK for logs" fail
grep -q 'composer-2.5' "$WRAPPER" && check "wrapper composer-2.5 default" pass || check "wrapper composer-2.5 default" fail
! grep -qE 'export SB_E2E_ENTERPRISE_MATRIX|SB_E2E_ENTERPRISE_MATRIX=1' "$WRAPPER" && check "wrapper omits matrix env export" pass || check "wrapper omits matrix env export" fail
grep -q 'agent_delegate_clear_matrix_env' "$WRAPPER" && check "wrapper clears inherited matrix env" pass || check "wrapper clears inherited matrix env" fail
grep -q 'SB_AGENT_CURSOR_LOG_FLOOR' "$WRAPPER" && check "wrapper log floor check" pass || check "wrapper log floor check" fail

grep -q 'SB_AGENT_CURSOR_STREAM_JSON' "$ADAPTER" && check "adapter stream-json delegate flag" pass || check "adapter stream-json delegate flag" fail

bash -n "$WRAPPER" && check "wrapper shell syntax" pass || check "wrapper shell syntax" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
