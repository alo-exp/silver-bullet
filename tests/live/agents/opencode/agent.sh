#!/usr/bin/env bash
# Native OpenCode CLI adapter for live Silver Bullet tests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/opencode-cli.sh
source "${SCRIPT_DIR}/../../../../scripts/lib/opencode-cli.sh"

agent_name() {
  printf 'opencode'
}

agent_cli_path() {
  local cli
  cli="$(resolve_native_opencode_cli_path "${OPENCODE_BIN:-}" || true)"
  if [[ -z "$cli" ]]; then
    printf 'ERROR: native OpenCode CLI not found — install via https://opencode.ai/install\n' >&2
    return 1
  fi
  if [[ "$cli" == *OpenCode.app* ]]; then
    printf 'ERROR: Desktop OpenCode.app is not the automation CLI\n' >&2
    return 1
  fi
  printf '%s\n' "$cli"
}

agent_preflight() {
  local cli
  cli="$(agent_cli_path)" || return 1
  if ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: OpenCode CLI not working at %s\n' "$cli" >&2
    return 1
  fi
  agent_opencode_pin_mimo_model_env || return 1
}

agent_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli work_dir model run_model output log_file timeout tail_idle
  local -a args=()

  cli="$(agent_cli_path)" || return 1
  agent_opencode_pin_mimo_model_env || return 1

  work_dir="${OPENCODE_WORK_DIR:-${WORK_DIR:-}}"
  [[ -n "$work_dir" ]] || { printf 'ERROR: OPENCODE_WORK_DIR or WORK_DIR required\n' >&2; return 1; }

  run_model="${OPENCODE_RUN_MODEL:-opencode-go/mimo-v2.5}"
  timeout="${OPENCODE_RUN_TIMEOUT:-900}"
  tail_idle="${OPENCODE_RUN_TAIL_IDLE_TIMEOUT:-45}"
  log_file="${CLAUDE_INTERACTIVE_LOG_FILE:-${OPENCODE_RUN_LOG_FILE:-}}"

  args=(run --dir "$work_dir" -m "$run_model" --auto)
  if [[ "$mode" == "permissive" ]]; then
    args+=(--auto)
  fi
  args+=("$prompt")

  printf '{"type":"prompt.submitted","model":"%s","work_dir":"%s"}\n' "$run_model" "$work_dir" >&2

  output="$(
    cd "$work_dir" && \
      SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-}" \
      SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-}" \
      SB_AGENT_OPENCODE_DELEGATE="${SB_AGENT_OPENCODE_DELEGATE:-}" \
      OPENCODE_MODEL="${OPENCODE_MODEL:-mimo-v2.5}" \
      OPENCODE_MODEL_PROVIDER="${OPENCODE_MODEL_PROVIDER:-opencode-go}" \
      python3 - "$cli" "$timeout" "$tail_idle" "${args[@]}" <<'PY'
import os
import select
import subprocess
import sys
import time

cli = sys.argv[1]
timeout = int(sys.argv[2])
tail_idle = int(sys.argv[3])
args = [cli, *sys.argv[4:]]
child_env = os.environ.copy()

proc = subprocess.Popen(
    args,
    env=child_env,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    cwd=os.getcwd(),
)
hard_deadline = time.monotonic() + timeout
stdout_parts = []
activity_at = None
fd = proc.stdout.fileno()

while proc.poll() is None:
    now = time.monotonic()
    if now >= hard_deadline:
        break
    if activity_at is not None and now - activity_at >= tail_idle:
        break
    ready, _, _ = select.select([fd], [], [], 0.2)
    if ready:
        data = os.read(fd, 65536)
        if not data:
            break
        chunk = data.decode(errors="replace")
        stdout_parts.append(chunk)
        if chunk.strip():
            activity_at = time.monotonic()

combined = "".join(stdout_parts)
if combined:
    sys.stdout.write(combined)

if proc.poll() is None:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=5)
    if not combined.strip():
        sys.stdout.write(f"\nERROR: timed out waiting for opencode run after {timeout}s\n")
        sys.exit(124)

sys.exit(proc.returncode or 0)
PY
  )" || true

  if [[ -n "$log_file" && "${SB_AGENT_OPENCODE_DELEGATE:-}" != "1" ]]; then
    printf '%s' "$output" >"$log_file"
  fi
  printf '%s' "$output"
}
