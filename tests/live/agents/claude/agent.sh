#!/usr/bin/env bash
# Claude agent adapter for live Silver Bullet tests.

agent_name() {
  printf 'claude'
}

agent_cli_path() {
  printf '%s\n' "${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "/Users/shafqat/.local/bin/claude")}"
}

agent_preflight() {
  local cli
  cli="$(agent_cli_path)"
  if ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: claude CLI not found or not working at %s\n' "$cli" >&2
    return 1
  fi
  if ! command -v node >/dev/null 2>&1; then
    printf 'ERROR: node is required on PATH for Claude hooks\n' >&2
    return 1
  fi
}

agent_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output
  local permission_mode
  local continue_flag
  local timeout_seconds

  cli="$(agent_cli_path)"
  permission_mode="${CLAUDE_PERMISSION_MODE:-default}"
  timeout_seconds="${CLAUDE_INTERACTIVE_TIMEOUT:-${CODEX_INTERACTIVE_TIMEOUT:-300}}"
  : "${CLAUDE_PROMPT_COUNT:=0}"
  if [[ "$mode" == "permissive" ]]; then
    permission_mode="bypassPermissions"
  fi

  continue_flag=0
  if [[ "${CLAUDE_PROMPT_COUNT:-0}" -gt 0 ]]; then
    continue_flag=1
  fi

  output=$(
    cd "$WORK_DIR" && \
      CLAUDE_LIVE_CLI="$cli" \
      CLAUDE_LIVE_PROMPT="$prompt" \
      CLAUDE_LIVE_PERMISSION_MODE="$permission_mode" \
      CLAUDE_LIVE_CONTINUE="$continue_flag" \
      CLAUDE_LIVE_TIMEOUT="$timeout_seconds" \
      python3 - <<'PY'
import os
import subprocess
import sys

cli = os.environ["CLAUDE_LIVE_CLI"]
prompt = os.environ["CLAUDE_LIVE_PROMPT"]
timeout = int(os.environ.get("CLAUDE_LIVE_TIMEOUT") or "300")
args = [
    cli,
    "--print",
    "--model",
    os.environ.get("CLAUDE_MODEL", "haiku"),
    "--effort",
    os.environ.get("CLAUDE_EFFORT", "low"),
    "--permission-mode",
    os.environ["CLAUDE_LIVE_PERMISSION_MODE"],
    "--verbose",
]
if os.environ.get("CLAUDE_LIVE_CONTINUE") == "1":
    args.append("--continue")
args.append(prompt)

try:
    result = subprocess.run(
        args,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )
    if result.stdout:
        sys.stdout.write(result.stdout)
    sys.exit(result.returncode)
except subprocess.TimeoutExpired as exc:
    if exc.stdout:
        sys.stdout.write(exc.stdout if isinstance(exc.stdout, str) else exc.stdout.decode(errors="replace"))
    sys.stdout.write(f"\nERROR: timed out waiting for Claude prompt to complete after {timeout}s\n")
    sys.exit(124)
PY
  ) || true

  printf '%s' "$output"

  CLAUDE_PROMPT_COUNT=$((CLAUDE_PROMPT_COUNT + 1))
}
