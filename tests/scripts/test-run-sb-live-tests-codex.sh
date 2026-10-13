#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_file_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF "$needle" "$path"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $path"
    (( FAIL++ )) || true
  fi
}

assert_file_not_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF "$needle" "$path"; then
    echo "FAIL: $desc — found unexpected [$needle] in $path"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

assert_executable() {
  local desc="$1" path="$2"
  if [[ -x "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — not executable: $path"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/run-sb-live-tests-codex.sh"

echo "=== Native Codex-only SB live test wrapper checks ==="
assert_executable "wrapper is executable" "$WRAPPER"
assert_file_contains "wrapper sets native codex live agent" "$WRAPPER" 'SB_LIVE_AGENT="${SB_LIVE_AGENT:-codex}"'
assert_file_contains "wrapper sets native codex e2e agent" "$WRAPPER" 'SB_E2E_LIVE_AGENT="${SB_E2E_LIVE_AGENT:-codex}"'
assert_file_contains "wrapper targets codex runtime for live suite" "$WRAPPER" 'SB_LIVE_RUNTIMES="${SB_LIVE_RUNTIMES:-codex}"'
assert_file_contains "wrapper targets codex runtime for todo-app suite" "$WRAPPER" 'SB_E2E_LIVE_RUNTIMES="${SB_E2E_LIVE_RUNTIMES:-codex}"'
assert_file_contains "wrapper preserves native model selection by default" "$WRAPPER" 'SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-}"'
assert_file_contains "wrapper preserves native provider selection by default" "$WRAPPER" 'SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-}"'
assert_file_contains "wrapper runs live agent suite" "$WRAPPER" 'tests/live/run-live-tests.sh'
assert_file_contains "wrapper runs todo-app suite" "$WRAPPER" 'tests/e2e-live/run-e2e-live-tests.sh'
assert_file_not_contains "wrapper does not pin Kay provider defaults" "$WRAPPER" 'opencode-go'
assert_file_contains "interactive launcher accepts codex runtime selector" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'CODEX_RUNTIME_AGENT'
assert_file_contains "interactive launcher exposes native hook trust bypass" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'CODEX_BYPASS_HOOK_TRUST'
assert_file_contains "interactive launcher exposes isolated hook auto-trust" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'CODEX_AUTO_TRUST_HOOKS'
assert_file_contains "native codex agent uses the PTY launcher" "$REPO_ROOT/tests/live/agents/codex/agent.sh" 'python3 "$SB_ROOT/scripts/codex-interactive-invoke.py"'
assert_file_contains "native codex agent enables hook trust bypass for isolated runs" "$REPO_ROOT/tests/live/agents/codex/agent.sh" 'CODEX_BYPASS_HOOK_TRUST="${CODEX_BYPASS_HOOK_TRUST:-$hook_trust_bypass}"'
assert_file_contains "native codex agent enables hook auto-trust for isolated runs" "$REPO_ROOT/tests/live/agents/codex/agent.sh" 'CODEX_AUTO_TRUST_HOOKS="${CODEX_AUTO_TRUST_HOOKS:-$auto_trust_hooks}"'
assert_file_contains "native codex PTY launcher answers terminal capability probes" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'answer_terminal_queries'
assert_file_contains "native codex PTY launcher recognizes the current Codex banner" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'openaicodex'
assert_file_contains "native codex PTY launcher clears inherited desktop thread ids" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'CODEX_THREAD_ID'
assert_file_contains "native codex PTY launcher clears inherited desktop originator overrides" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'CODEX_INTERNAL_ORIGINATOR_OVERRIDE'
assert_file_contains "native codex PTY launcher suppresses closed stdout tracebacks" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'except BrokenPipeError'
assert_file_contains "native codex PTY launcher keeps transcript capture before stdout forwarding" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'stdout_forwarding_enabled = forward_stdout(chunk, stdout_forwarding_enabled)'
assert_file_contains "native codex PTY launcher escalates hard timeout with SIGKILL" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'terminate_child(child_pid)'
assert_file_contains "native codex PTY launcher ignores spinner-only PTY noise" "$REPO_ROOT/scripts/codex-interactive-invoke.py" 'apply_terminal_overwrites'

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
