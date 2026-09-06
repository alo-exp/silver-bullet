#!/usr/bin/env bash
# Structural contract for /sb:agent-codex skill and delegate wrapper.
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
grep -q '/sb:agent-codex' "$SKILL" && check "route documented" pass || check "route documented" fail
grep -q 'codex-interactive-invoke.py' "$SKILL" && check "references invoke harness" pass || check "references invoke harness" fail
grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$SKILL" && check "excludes matrix env" pass || check "excludes matrix env" fail
grep -q 'agent-codex-delegate.sh' "$SKILL" && check "references delegate wrapper" pass || check "references delegate wrapper" fail
grep -q 'agentmemory' "$SKILL" && check "documents agentmemory capture" pass || check "documents agentmemory capture" fail
grep -q 'graphify' "$SKILL" && check "documents graphify capture" pass || check "documents graphify capture" fail
grep -q 'AF-AGENT-DELEGATE' "$SKILL" && check "documents AF-AGENT-DELEGATE" pass || check "documents AF-AGENT-DELEGATE" fail
grep -q 'SB_AGENT_DELEGATE_V2' "$SKILL" && check "documents V2 default-on flag" pass || check "documents V2 default-on flag" fail
grep -q 'AGENT-DELEGATE' "$SKILL" && check "documents native worker template" pass || check "documents native worker template" fail

[[ -x "$WRAPPER" ]] && check "delegate wrapper executable" pass || check "delegate wrapper executable" fail
grep -q 'tests/live/agents/codex/agent.sh' "$WRAPPER" && check "wrapper uses live agent adapter" pass || check "wrapper uses live agent adapter" fail
grep -q 'agent_preflight' "$WRAPPER" && check "wrapper calls agent_preflight" pass || check "wrapper calls agent_preflight" fail
grep -q 'agent_delegate_canonicalize_path' "$WRAPPER" && check "wrapper canonicalizes log/brief paths" pass || check "wrapper canonicalizes log/brief paths" fail
grep -q 'absolute' "$SKILL" && check "documents absolute path policy" pass || check "documents absolute path policy" fail
grep -q 'scripts/lib/codex-cli.sh' "$WRAPPER" && check "wrapper sources scripts/lib codex-cli" pass || check "wrapper sources scripts/lib codex-cli" fail
grep -q 'AGENT_CODEX_QUOTA_RETRY' "$WRAPPER" && check "wrapper quota retry env" pass || check "wrapper quota retry env" fail
LIB="${REPO_ROOT}/scripts/agent-codex/lib.sh"
grep -q 'SB_AGENT_CODEX_MODEL_READY_TIMEOUT' "$LIB" && check "harness model-ready timeout env" pass || check "harness model-ready timeout env" fail
grep -q 'CODEX_EXEC_TAIL_IDLE_TIMEOUT' "$LIB" && check "harness exec tail idle timeout env" pass || check "harness exec tail idle timeout env" fail
grep -q 'CODEX_EXEC_TAIL_IDLE_TIMEOUT' "${REPO_ROOT}/tests/live/agents/codex/agent.sh" && check "adapter exec tail idle timeout" pass || check "adapter exec tail idle timeout" fail
grep -q 'exec_output_shows_product_evidence' "${REPO_ROOT}/tests/live/agents/codex/agent.sh" && check "adapter exec product evidence detection" pass || check "adapter exec product evidence detection" fail
grep -q 'SB_AGENT_CODEX_LIGHTWEIGHT' "$WRAPPER" && check "wrapper lightweight env default" pass || check "wrapper lightweight env default" fail
grep -q 'SB_ORCHESTRATOR_WORKER' "$WRAPPER" && check "wrapper orchestrator worker bypass" pass || check "wrapper orchestrator worker bypass" fail
grep -q 'agent_codex_apply_runtime_env' "$LIB" && check "harness disables RTK for logs" pass || check "harness disables RTK for logs" fail
! grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$WRAPPER" && check "wrapper omits matrix env" pass || check "wrapper omits matrix env" fail

grep -q 'scripts/agent-codex/' "$SKILL" && check "references agent-codex harness dir" pass || check "references agent-codex harness dir" fail
grep -q 'SB_AGENT_CODEX_LOG_FLOOR' "$SKILL" && check "documents log floor" pass || check "documents log floor" fail
grep -q 'Security (delegation boundary)' "$SKILL" && check "security section" pass || check "security section" fail
grep -q 'E2E-081' "$SKILL" && check "R9 E2E-081 learning" pass || check "R9 E2E-081 learning" fail

AGENT_CODEX_DIR="${REPO_ROOT}/scripts/agent-codex"
for script in lib.sh env.sh preflight.sh monitor.sh invoke.sh; do
  path="${AGENT_CODEX_DIR}/${script}"
  if [[ -f "$path" ]]; then
    check "agent-codex/${script} exists" pass
    bash -n "$path" && check "agent-codex/${script} shell syntax" pass || check "agent-codex/${script} shell syntax" fail
  else
    check "agent-codex/${script} exists" fail
  fi
done

bash "${AGENT_CODEX_DIR}/preflight.sh" --dry-run >/dev/null 2>&1 && check "preflight dry-run" pass || check "preflight dry-run" fail
bash "${AGENT_CODEX_DIR}/env.sh" >/dev/null 2>&1 && check "env.sh runs" pass || check "env.sh runs" fail
TMP_LOG="$(mktemp "${TMPDIR:-/tmp}/agent-codex-monitor-XXXXXX")"
printf 'Submitted prompt\nactivity\n' >"$TMP_LOG"
monitor_out="$(bash "${AGENT_CODEX_DIR}/monitor.sh" --log "$TMP_LOG" --once 2>/dev/null || true)"
grep -q 'prompt submitted' <<<"$monitor_out" \
  && check "monitor --once smoke" pass || check "monitor --once smoke" fail
rm -f "$TMP_LOG"

grep -q 'agent-codex/invoke' "${REPO_ROOT}/hooks/lib/orchestrator-parent.sh" \
  && check "orchestrator allows invoke.sh" pass || check "orchestrator allows invoke.sh" fail

bash -n "$WRAPPER" && check "wrapper shell syntax" pass || check "wrapper shell syntax" fail

# Behavioral: direct delegate path (AGENT-DELEGATE worker) applies runtime env without invoke.sh
runtime_out="$(
  bash -c '
    set -euo pipefail
    source "'"${REPO_ROOT}"'/scripts/agent-codex/lib.sh"
    unset RTK_DISABLED CODEX_INTERACTIVE_READY_TIMEOUT CODEX_INTERACTIVE_IDLE_TIMEOUT CODEX_EXEC_TAIL_IDLE_TIMEOUT
    agent_codex_apply_runtime_env
    printf "RTK=%s READY=%s IDLE=%s TAIL=%s\n" \
      "${RTK_DISABLED:-}" "${CODEX_INTERACTIVE_READY_TIMEOUT:-}" \
      "${CODEX_INTERACTIVE_IDLE_TIMEOUT:-}" "${CODEX_EXEC_TAIL_IDLE_TIMEOUT:-}"
  '
)"
grep -q 'RTK=1' <<<"$runtime_out" && check "direct path RTK_DISABLED=1" pass || check "direct path RTK_DISABLED=1" fail
grep -q 'READY=120' <<<"$runtime_out" && check "direct path model-ready timeout default" pass || check "direct path model-ready timeout default" fail
grep -q 'agent_codex_apply_runtime_env' "$WRAPPER" \
  && check "delegate calls agent_codex_apply_runtime_env" pass || check "delegate calls agent_codex_apply_runtime_env" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
