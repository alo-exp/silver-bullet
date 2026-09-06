#!/usr/bin/env bash
# Regression tests for Cursor stream completion and real timeout propagation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="$REPO_ROOT/tests/live/agents/cursor/agent.sh"
LIVE_HARNESS="$REPO_ROOT/tests/live/test-live-five-tool-stack-cursor.sh"
TMP="$(mktemp -d)"
FAKE_BIN="$TMP/bin"
mkdir -p "$FAKE_BIN"
cleanup() {
  pkill -TERM -f "$TMP" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

if grep -q 'command-timeout.sh' "$LIVE_HARNESS" \
  && grep -q 'sb_run_with_timeout' "$LIVE_HARNESS" \
  && grep -q -- '--no-escalate' "$LIVE_HARNESS" \
  && grep -q 'SB_AGENT_CURSOR_LIGHTWEIGHT=0' "$LIVE_HARNESS" \
  && grep -q 'CURSOR_CONFIG_DIR=' "$LIVE_HARNESS" \
   && grep -q 'CURSOR_DATA_DIR=' "$LIVE_HARNESS" \
   && grep -q 'cleanup_cursor_fixture_processes' "$LIVE_HARNESS" \
   && grep -q 'SB_AGENT_CURSOR_APPROVE_MCPS=1' "$LIVE_HARNESS" \
   && grep -q 'LEAN_CTX_EXTRA_ROOTS' "$LIVE_HARNESS" \
   && grep -q 'approve-mcps' "$ADAPTER" \
   && grep -q 'add-dir' "$ADAPTER" \
   && grep -q 'cursor_home=' "$LIVE_HARNESS" \
   && grep -q 'host_home=' "$LIVE_HARNESS" \
   && grep -q 'HOME=${host_home}' "$LIVE_HARNESS" \
   && grep -q 'config_name}" "${cursor_home}/.cursor/${config_name}' "$LIVE_HARNESS" \
   && grep -q 'LOG_ROOT=' "$LIVE_HARNESS" \
   && grep -q 'LOG_ROOT}/' "$LIVE_HARNESS" \
   && grep -q 'still-growing transcript' "$LIVE_HARNESS" \
   && grep -q 'Scenario root:' "$LIVE_HARNESS" \
   && grep -q 'do not search /Users' "$LIVE_HARNESS" \
   && grep -q 'recommended_tools' "$LIVE_HARNESS" \
   && grep -q 'enabledPlugins' "$LIVE_HARNESS" \
   && grep -q 'cursor_config_dir}/settings.json' "$LIVE_HARNESS" \
   && grep -q 'silver-bullet@alo-labs' "$LIVE_HARNESS" \
   && grep -q 'context-mode@context-mode' "$LIVE_HARNESS" \
   && grep -q 'cursor-hook-bridge.sh' "$LIVE_HARNESS" \
  && grep -q '/.cursor/plugins/' "$LIVE_HARNESS" \
  && grep -q 'lean-ctx hook (deny|redirect|rewrite)' "$LIVE_HARNESS" \
  && grep -q 'unset CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR' "$REPO_ROOT/scripts/agent-cursor-delegate.sh"; then
  printf 'PASS: Cursor live harness uses the portable outer watchdog\n'
else
  printf 'FAIL: Cursor live harness is missing the portable outer watchdog\n' >&2
  exit 1
fi

cat >"$FAKE_BIN/cursor-agent" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --version) printf 'fake-cursor-agent 1\n'; exit 0 ;;
  status) printf 'Logged in as test@example.com\n'; exit 0 ;;
esac
if [[ "${CURSOR_FAKE_MODE:-}" == "terminal" ]]; then
  (sleep 20) &
  printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":"done"}'
  exit 0
fi
sleep 20
FAKE
chmod +x "$FAKE_BIN/cursor-agent"

run_adapter() {
  local mode="$1"
  local work="$TMP/$mode"
  mkdir -p "$work"
  PATH="$FAKE_BIN:$PATH" WORK_DIR="$work" CURSOR_AGENT_TIMEOUT=2 \
    SB_AGENT_CURSOR_STREAM_JSON=1 SB_LIVE_CURSOR_FORCE_HEADLESS=1 \
    CURSOR_FAKE_MODE="$mode" CLAUDE_INTERACTIVE_LOG_FILE='' \
    CURSOR_AGENT_INTERACTIVE=0 SB_AGENT_CURSOR_SESSION=0 \
    SB_AGENT_RESOLVED_MODE=non-interactive \
    python3 - "$ADAPTER" "$work" "$mode" <<'PY'
import os
import signal
import subprocess
import sys

adapter, work_dir, mode = sys.argv[1:]
command = 'source "$1"; agent_invoke_cli permissive "cursor timeout regression"'
env = os.environ.copy()
proc = subprocess.Popen(
    ["bash", "-c", command, "cursor-adapter", adapter],
    cwd=work_dir,
    env=env,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    start_new_session=True,
)
try:
    output, _ = proc.communicate(timeout=6)
except subprocess.TimeoutExpired:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait()
    print(f"adapter hung in {mode} mode", file=sys.stderr)
    sys.exit(1)

if mode == "terminal":
    if proc.returncode != 0 or '"type":"result"' not in output:
        print(f"completed Cursor stream was not accepted: rc={proc.returncode} output={output!r}", file=sys.stderr)
        sys.exit(1)
else:
    if proc.returncode != 124 or "timed out waiting for cursor-agent after 2s" not in output:
        print(f"real Cursor timeout was not propagated: rc={proc.returncode} output={output!r}", file=sys.stderr)
        sys.exit(1)
PY
}

run_adapter terminal
run_adapter hang
printf 'PASS: Cursor completed streams return promptly and genuine timeouts remain 124\n'
printf 'Results: 2 passed, 0 failed\n'
