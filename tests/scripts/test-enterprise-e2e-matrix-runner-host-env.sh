#!/usr/bin/env bash
# matrix.sh host environment defaults seen by the agent (cursor, clean-env), against a staged SB root.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

# ----------------------------------------------------- host environment seen by the agent
reset
agent <<'EOS'
printf 'hostenv headless=%s cursor_id=%s cursor_agent=%s vscode=%s cred=%s anthropic=%s openai=%s\n' \
  "${SB_LIVE_CURSOR_FORCE_HEADLESS-unset}" "${CURSOR_CONVERSATION_ID-unset}" "${CURSOR_AGENT-unset}" \
  "${VSCODE_IPC_HOOK-unset}" "${AGENT_CLI_CREDENTIAL_STORE-unset}" "${ANTHROPIC_API_KEY-unset}" "${OPENAI_API_KEY-unset}" >>"$F2_CALLS"
EOS
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 \
  CURSOR_CONVERSATION_ID=c1 CURSOR_AGENT=a1 VSCODE_IPC_HOOK=h1 AGENT_CLI_CREDENTIAL_STORE=s1 bash "$MATRIX" 2
assert_contains "cursor strips host session variables and forces headless" "$CALLS" "hostenv headless=1 cursor_id=unset cursor_agent=unset vscode=unset cred=unset"
assert_contains "cursor raises the interactive timeout floor" "$CALLS" "timeout=1800 cursor_timeout=1800"
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 CLAUDE_INTERACTIVE_TIMEOUT=900 bash "$MATRIX" 2
assert_contains "cursor lifts a legacy 900s timeout" "$CALLS" "timeout=1800 cursor_timeout=1800"
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 CLAUDE_INTERACTIVE_TIMEOUT=3600 CURSOR_AGENT_TIMEOUT=4000 bash "$MATRIX" 2
assert_contains "cursor keeps a larger interactive timeout" "$CALLS" "timeout=3600 cursor_timeout=3600"
run env SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor SB_E2E_CURSOR_LOG_GROWTH_WAIT=0 CLAUDE_INTERACTIVE_TIMEOUT=3600 CURSOR_AGENT_TIMEOUT=1000 bash "$MATRIX" 2
assert_contains "cursor lifts a short agent timeout to the interactive timeout" "$CALLS" "timeout=3600 cursor_timeout=3600"

run env SB_E2E_MATRIX_CLEAN_ENV=1 ANTHROPIC_API_KEY=a OPENAI_API_KEY=o bash "$MATRIX" 2
assert_contains "clean-env mode strips conflicting API keys" "$CALLS" "anthropic=unset openai=unset"
run env ANTHROPIC_API_KEY=a OPENAI_API_KEY=o bash "$MATRIX" 2
assert_contains "default mode inherits the shell keys" "$CALLS" "anthropic=a openai=o"

tl_results
