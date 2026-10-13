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
WRAPPER="$REPO_ROOT/scripts/run-sb-live-tests-kay.sh"

echo "=== Kay-only SB live test wrapper checks ==="
assert_executable "wrapper is executable" "$WRAPPER"
assert_file_contains "wrapper enables direct MiniMax.io tests" "$WRAPPER" 'SB_DISABLE_MINIMAX_IO_TESTS="${SB_DISABLE_MINIMAX_IO_TESTS:-0}"'
assert_file_contains "wrapper pins MiniMax provider" "$WRAPPER" 'SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-minimax}"'
assert_file_contains "wrapper pins MiniMax M3" "$WRAPPER" 'SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-MiniMax-M3}"'
assert_file_contains "wrapper pins low reasoning" "$WRAPPER" 'SB_LIVE_CODEX_REASONING_EFFORT="${SB_LIVE_CODEX_REASONING_EFFORT:-low}"'
assert_file_contains "wrapper forwards low reasoning to Kay" "$WRAPPER" 'CODEX_REASONING_EFFORT="${CODEX_REASONING_EFFORT:-$SB_LIVE_CODEX_REASONING_EFFORT}"'
assert_file_contains "wrapper targets kay runtime for live suite" "$WRAPPER" 'SB_LIVE_RUNTIMES="${SB_LIVE_RUNTIMES:-kay}"'
assert_file_contains "wrapper targets kay runtime for todo-app suite" "$WRAPPER" 'SB_E2E_LIVE_RUNTIMES="${SB_E2E_LIVE_RUNTIMES:-kay}"'
assert_file_contains "wrapper runs live agent suite" "$WRAPPER" 'tests/live/run-live-tests.sh'
assert_file_contains "wrapper runs todo-app suite" "$WRAPPER" 'tests/e2e-live/run-e2e-live-tests.sh'
assert_file_not_contains "wrapper no longer pins OpenCode-Go provider" "$WRAPPER" 'SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-opencode-go}"'
assert_file_not_contains "wrapper no longer pins DeepSeek V4 Flash" "$WRAPPER" 'SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-deepseek-v4-flash}"'
assert_file_not_contains "wrapper has no Forge test toggle" "$WRAPPER" 'SB_DISABLE_FORGE_TESTS'

assert_file_not_contains "kay isolation helper does not fall back to codex" "$REPO_ROOT/tests/live/lib/kay-codex-isolation.sh" 'command -v codex'
assert_file_not_contains "kay agent adapter does not fall back to codex" "$REPO_ROOT/tests/live/agents/kay/agent.sh" 'command -v codex'
assert_file_contains "interactive launcher accepts kay runtime selector" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'CODEX_RUNTIME_AGENT'
assert_file_contains "interactive launcher exposes isolated hook auto-trust" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'CODEX_AUTO_TRUST_HOOKS'
assert_file_contains "interactive launcher rewires Kay config home for isolated runs" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'CODEX_KAY_HOME'
assert_file_contains "interactive launcher enforces exec-mode timeout" "$REPO_ROOT/scripts/codex-interactive-invoke.expect" 'timed out waiting for Codex exec to complete'
assert_file_contains "kay agent enables isolated hook auto-trust" "$REPO_ROOT/tests/live/agents/kay/agent.sh" 'CODEX_AUTO_TRUST_HOOKS="$auto_trust_hooks"'
assert_file_contains "kay agent points subprocess KAY_HOME at the isolated config dir" "$REPO_ROOT/tests/live/agents/kay/agent.sh" 'CODEX_KAY_HOME="${KAY_HOME}/.kay"'
assert_file_contains "live helpers source Kay isolation library in child shells" "$REPO_ROOT/tests/live/helpers.sh" 'source "$SB_ROOT/tests/live/lib/kay-codex-isolation.sh"'

if ! command -v expect >/dev/null 2>&1; then
  echo "SKIP: interactive launcher timeout probe requires expect"
else
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  mkdir -p "$tmpdir/bin" "$tmpdir/work"
  cat >"$tmpdir/bin/kay" <<'EOF'
#!/usr/bin/env bash
sleep 5
EOF
  chmod +x "$tmpdir/bin/kay"
  printf 'test prompt\n' >"$tmpdir/prompt.txt"
  set +e
  PATH="$tmpdir/bin:$PATH" \
    CODEX_RUNTIME_AGENT="kay" \
    CODEX_LAUNCH_MODE="exec" \
    CODEX_WORK_DIR="$tmpdir/work" \
    CODEX_PROMPT_FILE="$tmpdir/prompt.txt" \
    CODEX_INTERACTIVE_TIMEOUT="1" \
    expect "$REPO_ROOT/scripts/codex-interactive-invoke.expect" >"$tmpdir/stdout.txt" 2>"$tmpdir/stderr.txt"
  timeout_rc=$?
  set -e
  if [[ $timeout_rc -eq 124 ]] && grep -qF 'timed out waiting for Codex exec to complete' "$tmpdir/stderr.txt"; then
    echo "PASS: interactive launcher times out hung Kay exec mode"
    (( PASS++ )) || true
  else
    echo "FAIL: interactive launcher times out hung Kay exec mode — rc=$timeout_rc"
    sed 's/^/  stderr: /' "$tmpdir/stderr.txt"
    (( FAIL++ )) || true
  fi
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
