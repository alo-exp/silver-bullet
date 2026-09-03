#!/usr/bin/env bash
# Structural contract for /silver:agent-claude skill and delegate wrapper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/silver-agent-claude/SKILL.md"
WRAPPER="${REPO_ROOT}/scripts/agent-claude-delegate.sh"

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

echo "=== agent-claude skill structural tests ==="

if [[ -f "$SKILL" ]]; then
  check "SKILL.md exists" pass
else
  check "SKILL.md exists" fail
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

grep -qE '^name: silver-agent-claude$' "$SKILL" && check "frontmatter name silver-agent-claude" pass || check "frontmatter name silver-agent-claude" fail
grep -q 'user-invocable: true' "$SKILL" && check "user-invocable" pass || check "user-invocable" fail
grep -q '/silver:agent-claude' "$SKILL" && check "route documented" pass || check "route documented" fail
grep -q 'claude-interactive-invoke.expect' "$SKILL" && check "references invoke harness" pass || check "references invoke harness" fail
grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$SKILL" && check "excludes matrix env" pass || check "excludes matrix env" fail
grep -q 'agent-claude-delegate.sh' "$SKILL" && check "references delegate wrapper" pass || check "references delegate wrapper" fail
grep -q 'agentmemory' "$SKILL" && check "documents agentmemory capture" pass || check "documents agentmemory capture" fail
grep -q 'graphify' "$SKILL" && check "documents graphify capture" pass || check "documents graphify capture" fail
grep -q 'AF-AGENT-DELEGATE' "$SKILL" && check "documents AF-AGENT-DELEGATE" pass || check "documents AF-AGENT-DELEGATE" fail
grep -q 'SB_AGENT_DELEGATE_V2' "$SKILL" && check "documents V2 default-on flag" pass || check "documents V2 default-on flag" fail
grep -q '/silver:agent-codex' "$SKILL" && check "documents codex tri-host sibling" pass || check "documents codex tri-host sibling" fail
grep -q '/silver:agent-cursor' "$SKILL" && check "documents cursor tri-host sibling" pass || check "documents cursor tri-host sibling" fail
grep -q 'E2E-081' "$SKILL" && check "R9 E2E-081 learning" pass || check "R9 E2E-081 learning" fail
grep -q 'E2E-110' "$SKILL" && check "E2E-110 auth policy" pass || check "E2E-110 auth policy" fail

[[ -x "$WRAPPER" ]] && check "delegate wrapper executable" pass || check "delegate wrapper executable" fail
grep -q 'tests/live/agents/claude/agent.sh' "$WRAPPER" && check "wrapper uses live agent adapter" pass || check "wrapper uses live agent adapter" fail
grep -q 'agent_preflight' "$WRAPPER" && check "wrapper calls agent_preflight" pass || check "wrapper calls agent_preflight" fail
grep -q 'agent_delegate_canonicalize_path' "$WRAPPER" && check "wrapper canonicalizes log/brief paths" pass || check "wrapper canonicalizes log/brief paths" fail
grep -q 'absolute' "$SKILL" && check "documents absolute path policy" pass || check "documents absolute path policy" fail
grep -q 'AGENT_CLAUDE_QUOTA_RETRY' "$WRAPPER" && check "wrapper quota retry env" pass || check "wrapper quota retry env" fail
grep -q 'SB_AGENT_CLAUDE_LIGHTWEIGHT' "$WRAPPER" && check "wrapper lightweight env default" pass || check "wrapper lightweight env default" fail
grep -q 'CLAUDE_USE_INTERACTIVE' "$WRAPPER" && check "wrapper forces interactive TUI" pass || check "wrapper forces interactive TUI" fail
grep -q 'SB_ORCHESTRATOR_WORKER' "$WRAPPER" && check "wrapper orchestrator worker bypass" pass || check "wrapper orchestrator worker bypass" fail
! grep -q 'SB_E2E_ENTERPRISE_MATRIX' "$WRAPPER" && check "wrapper omits matrix env" pass || check "wrapper omits matrix env" fail

LIB="${REPO_ROOT}/scripts/agent-claude/lib.sh"
grep -q 'SB_AGENT_CLAUDE_MODEL_READY_TIMEOUT' "$LIB" && check "harness model-ready timeout env" pass || check "harness model-ready timeout env" fail
grep -q 'agent_claude_apply_runtime_env' "$LIB" && check "harness disables RTK for logs" pass || check "harness disables RTK for logs" fail
grep -q 'agent_claude_prepare_lightweight_config_dir' "$LIB" && check "isolated CLAUDE_CONFIG_DIR helper" pass || check "isolated CLAUDE_CONFIG_DIR helper" fail

grep -q 'scripts/agent-claude/' "$SKILL" && check "references agent-claude harness dir" pass || check "references agent-claude harness dir" fail
grep -q 'SB_AGENT_CLAUDE_LOG_FLOOR' "$SKILL" && check "documents log floor" pass || check "documents log floor" fail
grep -q 'Security (delegation boundary)' "$SKILL" && check "security section" pass || check "security section" fail

CURSOR_BUNDLE="${REPO_ROOT}/host-bundles/cursor/silver:agent-claude/SKILL.md"
if [[ -f "$CURSOR_BUNDLE" ]]; then
  grep -q 'when Claude Code TUI is the intended executor' "$CURSOR_BUNDLE" \
    && check "cursor bundle names Claude executor" pass || check "cursor bundle names Claude executor" fail
  ! grep -q 'when Cursor TUI is the intended executor' "$CURSOR_BUNDLE" \
    && check "cursor bundle no Cursor-as-executor typo" pass || check "cursor bundle no Cursor-as-executor typo" fail
else
  check "cursor bundle exists" fail
fi

AGENT_CLAUDE_DIR="${REPO_ROOT}/scripts/agent-claude"
for script in lib.sh env.sh preflight.sh monitor.sh invoke.sh; do
  path="${AGENT_CLAUDE_DIR}/${script}"
  if [[ -f "$path" ]]; then
    check "agent-claude/${script} exists" pass
    bash -n "$path" && check "agent-claude/${script} shell syntax" pass || check "agent-claude/${script} shell syntax" fail
  else
    check "agent-claude/${script} exists" fail
  fi
done

bash "${AGENT_CLAUDE_DIR}/preflight.sh" --dry-run >/dev/null 2>&1 && check "preflight dry-run" pass || check "preflight dry-run" fail
bash "${AGENT_CLAUDE_DIR}/env.sh" >/dev/null 2>&1 && check "env.sh runs" pass || check "env.sh runs" fail
TMP_LOG="$(mktemp "${TMPDIR:-/tmp}/agent-claude-monitor-XXXXXX")"
printf 'Submitted prompt\nactivity\n' >"$TMP_LOG"
monitor_out="$(bash "${AGENT_CLAUDE_DIR}/monitor.sh" --log "$TMP_LOG" --once 2>/dev/null || true)"
grep -q 'prompt submitted' <<<"$monitor_out" \
  && check "monitor --once smoke" pass || check "monitor --once smoke" fail
rm -f "$TMP_LOG"

grep -q 'agent-claude/invoke' "${REPO_ROOT}/hooks/lib/orchestrator-parent.sh" \
  && check "orchestrator allows invoke.sh" pass || check "orchestrator allows invoke.sh" fail
grep -q 'silver-agent-claude' "${REPO_ROOT}/hooks/lib/orchestrator-parent.sh" \
  && check "orchestrator skill allowlist" pass || check "orchestrator skill allowlist" fail

bash -n "$WRAPPER" && check "wrapper shell syntax" pass || check "wrapper shell syntax" fail

runtime_out="$(
  bash -c '
    set -euo pipefail
    source "'"${REPO_ROOT}"'/scripts/agent-claude/lib.sh"
    unset RTK_DISABLED CLAUDE_INTERACTIVE_READY_TIMEOUT CLAUDE_INTERACTIVE_IDLE_TIMEOUT CLAUDE_INTERACTIVE_QUIET_TIMEOUT
    agent_claude_apply_runtime_env
    printf "RTK=%s READY=%s IDLE=%s QUIET=%s\n" \
      "${RTK_DISABLED:-}" "${CLAUDE_INTERACTIVE_READY_TIMEOUT:-}" \
      "${CLAUDE_INTERACTIVE_IDLE_TIMEOUT:-}" "${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-}"
  '
)"
grep -q 'RTK=1' <<<"$runtime_out" && check "direct path RTK_DISABLED=1" pass || check "direct path RTK_DISABLED=1" fail
grep -q 'READY=120' <<<"$runtime_out" && check "direct path model-ready timeout default" pass || check "direct path model-ready timeout default" fail
grep -q 'agent_claude_apply_runtime_env' "$WRAPPER" \
  && check "delegate calls agent_claude_apply_runtime_env" pass || check "delegate calls agent_claude_apply_runtime_env" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
