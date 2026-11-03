#!/usr/bin/env bash
# matrix.sh host environment defaults seen by the agent (timeouts, clean-env), against a staged SB root.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

# ----------------------------------------------------- host environment seen by the agent
reset
agent <<'EOS'
echo noop
EOS
run env CLAUDE_INTERACTIVE_TIMEOUT=900 bash "$MATRIX" 2
assert_contains "the interactive timeout is kept as given" "$CALLS" "timeout=900 evidence="
run env CLAUDE_INTERACTIVE_TIMEOUT=3600 bash "$MATRIX" 2
assert_contains "a larger interactive timeout is kept" "$CALLS" "timeout=3600 evidence="
run bash "$MATRIX" 2
assert_contains "the default interactive timeout is 900s" "$CALLS" "timeout=900 evidence="

reset
agent <<'EOS'
printf 'hostenv anthropic=%s openai=%s\n' "${ANTHROPIC_API_KEY-unset}" "${OPENAI_API_KEY-unset}" >>"$F2_CALLS"
EOS

run env SB_E2E_MATRIX_CLEAN_ENV=1 ANTHROPIC_API_KEY=a OPENAI_API_KEY=o bash "$MATRIX" 2
assert_contains "clean-env mode strips conflicting API keys" "$CALLS" "anthropic=unset openai=unset"
run env ANTHROPIC_API_KEY=a OPENAI_API_KEY=o bash "$MATRIX" 2
assert_contains "default mode inherits the shell keys" "$CALLS" "anthropic=a openai=o"

tl_results
