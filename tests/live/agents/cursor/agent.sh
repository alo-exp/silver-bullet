#!/usr/bin/env bash
# Cursor agent adapter for live Silver Bullet tests.
#
# Two invocation paths:
# 1. cursor-agent CLI (headless / CI) — requires login or CURSOR_API_KEY
# 2. In-session (Cursor IDE Composer) — file-based request/response protocol;
#    auto-detected via CURSOR_AGENT=1 or SB_LIVE_CURSOR_IN_SESSION=1

cursor_in_session_active() {
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" || "${SB_LIVE_CURSOR_FORCE_HEADLESS:-}" == "1" ]]; then
    return 1
  fi
  if [[ "${SB_LIVE_CURSOR_IN_SESSION:-}" == "1" ]]; then
    return 0
  fi
  if [[ "${CURSOR_AGENT:-}" == "1" ]]; then
    return 0
  fi
  if [[ -n "${CURSOR_CONVERSATION_ID:-}" && -n "${VSCODE_IPC_HOOK:-}" ]]; then
    return 0
  fi
  return 1
}

cursor_session_dir() {
  printf '%s\n' "${SB_LIVE_CURSOR_SESSION_DIR:-${WORK_DIR}/.cursor-live-session}"
}

agent_name() {
  printf 'cursor'
}

agent_cli_path() {
  local cli=""
  cli="$(command -v cursor-agent 2>/dev/null || true)"
  if [[ -z "$cli" ]]; then
    cli="$(command -v agent 2>/dev/null || true)"
  fi
  if [[ -z "$cli" ]]; then
    printf 'ERROR: cursor-agent CLI not found on PATH\n' >&2
    return 1
  fi
  printf '%s\n' "$cli"
}

agent_preflight() {
  if cursor_in_session_active; then
    printf 'NOTE: cursor in-session mode active (IDE Composer); skipping cursor-agent login check\n' >&2
    return 0
  fi

  local cli
  local status_out=""
  cli="$(agent_cli_path)" || return 1
  if ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: cursor-agent CLI not working at %s\n' "$cli" >&2
    return 1
  fi
  if [[ -n "${CURSOR_API_KEY:-}" ]]; then
    return 0
  fi
  status_out="$("$cli" status 2>&1 || true)"
  if printf '%s' "$status_out" | grep -qiE 'not logged in|authentication required'; then
    printf 'ERROR: cursor-agent is not logged in (run: cursor-agent login, or set CURSOR_API_KEY)\n' >&2
    printf '%s\n' "$status_out" >&2
    return 1
  fi
  if ! printf '%s' "$status_out" | grep -qiE 'logged in as|email:|account:'; then
    printf 'ERROR: cursor-agent login status unclear; expected logged-in account details\n' >&2
    printf '%s\n' "$status_out" >&2
    return 1
  fi
}

cursor_in_session_invoke() {
  local mode="$1"
  local prompt="$2"
  local session_dir
  local request_id
  local request_file
  local response_file
  local timeout_seconds
  local model
  local started_at
  local elapsed
  local response_text=""

  session_dir="$(cursor_session_dir)"
  request_id="${CURSOR_LIVE_REQUEST_ID:-$$-${RANDOM}-$(date +%s)}"
  request_file="${session_dir}/request-${request_id}.json"
  response_file="${session_dir}/response-${request_id}.json"
  timeout_seconds="${CURSOR_AGENT_TIMEOUT:-${CLAUDE_INTERACTIVE_TIMEOUT:-300}}"
  model="${CURSOR_AGENT_MODEL:-${CURSOR_MODEL:-}}"
  started_at="$(date +%s)"

  mkdir -p "$session_dir"

  python3 - "$request_file" "$mode" "$prompt" "$model" "$WORK_DIR" "$request_id" <<'PY'
import json
import sys
from datetime import datetime, timezone

request_path, mode, prompt, model, workspace, request_id = sys.argv[1:7]
payload = {
    "id": request_id,
    "mode": mode,
    "prompt": prompt,
    "model": model,
    "workspace": workspace,
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
with open(request_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY

  # Signal file for external drivers watching the session directory.
  ln -sf "$(basename "$request_file")" "${session_dir}/current-request.json"

  printf 'CURSOR_IN_SESSION_REQUEST id=%s dir=%s\n' "$request_id" "$session_dir" >&2

  while [[ ! -f "$response_file" ]]; do
    elapsed=$(( $(date +%s) - started_at ))
    if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
      printf 'ERROR: timed out waiting for in-session response after %ss (expected %s)\n' \
        "$timeout_seconds" "$response_file" >&2
      return 124
    fi
    sleep 1
  done

  response_text="$(python3 - "$response_file" "$request_id" <<'PY'
import json
import sys

response_path, request_id = sys.argv[1:3]
with open(response_path, encoding="utf-8") as handle:
    payload = json.load(handle)
if payload.get("id") != request_id:
    sys.stderr.write(
        f"ERROR: response id mismatch (expected {request_id}, got {payload.get('id')})\n"
    )
    sys.exit(1)
text = payload.get("text", "")
if payload.get("status") == "error":
    sys.stderr.write(text + "\n")
    sys.exit(int(payload.get("exit_code", 1)))
sys.stdout.write(text)
PY
  )" || return 1

  rm -f "$request_file" "$response_file" "${session_dir}/current-request.json"
  printf '%s' "$response_text"
}

agent_invoke_cli() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output
  local timeout_seconds
  local model

  cli="$(agent_cli_path)" || return 1
  timeout_seconds="${CURSOR_AGENT_TIMEOUT:-${CLAUDE_INTERACTIVE_TIMEOUT:-300}}"
  model="${CURSOR_AGENT_MODEL:-${CURSOR_MODEL:-}}"

  output=$(
    cd "$WORK_DIR" && \
      CURSOR_AGENT_CLI="$cli" \
      CURSOR_AGENT_PROMPT="$prompt" \
      CURSOR_AGENT_TIMEOUT="$timeout_seconds" \
      CURSOR_AGENT_MODEL="$model" \
      CURSOR_AGENT_MODE="$mode" \
      CLAUDE_INTERACTIVE_LOG_FILE="${CLAUDE_INTERACTIVE_LOG_FILE:-}" \
      python3 - <<'PY'
import json
import os
import shutil
import signal
import subprocess
import sys
import time

cli = os.environ["CURSOR_AGENT_CLI"]
prompt = os.environ["CURSOR_AGENT_PROMPT"]
timeout = int(os.environ.get("CURSOR_AGENT_TIMEOUT") or "300")
model = os.environ.get("CURSOR_AGENT_MODEL") or ""
mode = os.environ.get("CURSOR_AGENT_MODE") or "default"
log_path = os.environ.get("CLAUDE_INTERACTIVE_LOG_FILE") or ""
matrix_mode = os.environ.get("SB_E2E_ENTERPRISE_MATRIX") == "1"
delegate_stream = os.environ.get("SB_AGENT_CURSOR_STREAM_JSON") == "1"
output_format = "stream-json" if (matrix_mode or delegate_stream) else "text"

interactive = os.environ.get("CURSOR_AGENT_INTERACTIVE") == "1" or os.environ.get("SB_AGENT_CURSOR_SESSION") == "1" or os.environ.get("SB_AGENT_RESOLVED_MODE") == "interactive"
resume = os.environ.get("CURSOR_AGENT_RESUME") or ""
args = [
    cli,
    "--trust",
    "--force",
    "--workspace", os.getcwd(),
]
if not interactive:
    args.extend(["--print", "--output-format", output_format])
elif resume:
    args.extend(["--resume", resume])
if (not interactive) and (matrix_mode or delegate_stream):
    args.append("--stream-partial-output")
if model:
    args.extend(["--model", model])
if mode == "permissive":
    args.append("--yolo")
args.append(prompt)

if shutil.which("stdbuf"):
    args = ["stdbuf", "-oL", "-eL"] + args

# Preserve harness-seeded prefix (e.g. HARNESS graphify line) — never truncate.
if log_path and not os.path.exists(log_path):
    open(log_path, "a", encoding="utf-8").close()

text_chunks = []


def append_log(chunk: str) -> None:
    if not log_path or not chunk:
        return
    with open(log_path, "a", encoding="utf-8") as handle:
        handle.write(chunk)


def emit_line(line: str) -> None:
    global text_chunks
    sys.stdout.write(line)
    append_log(line)
    if output_format == "text":
        text_chunks.append(line)
        return
    stripped = line.strip()
    if not stripped:
        return
    try:
        payload = json.loads(stripped)
    except json.JSONDecodeError:
        text_chunks.append(line)
        return
    for key in ("text", "delta", "content", "message"):
        value = payload.get(key)
        if isinstance(value, str) and value:
            text_chunks.append(value)


proc = subprocess.Popen(
    args,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    bufsize=1,
    start_new_session=True,
)

started = time.time()


def timeout_handler(_signum, _frame):
    # A quiet child can block the iterator below without yielding a line, so
    # enforce the deadline with SIGALRM as well as the post-line check.
    raise subprocess.TimeoutExpired(args, timeout, output=None)


signal.signal(signal.SIGALRM, timeout_handler)
signal.setitimer(signal.ITIMER_REAL, max(1, timeout))
try:
    assert proc.stdout is not None
    for line in proc.stdout:
        emit_line(line)
        if time.time() - started >= timeout:
            raise subprocess.TimeoutExpired(args, timeout, output=None)
    rc = proc.wait(timeout=max(1, timeout - int(time.time() - started)))
    if log_path and text_chunks:
        summary = "".join(text_chunks)
        try:
            existing = open(log_path, encoding="utf-8").read()
        except OSError:
            existing = ""
        if summary and summary not in existing:
            append_log(summary if summary.endswith("\n") else summary + "\n")
    sys.exit(rc)
except subprocess.TimeoutExpired:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        proc.kill()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            proc.kill()
    sys.stdout.write(f"\nERROR: timed out waiting for cursor-agent after {timeout}s\n")
    append_log(f"\nERROR: timed out waiting for cursor-agent after {timeout}s\n")
    sys.exit(124)
finally:
    signal.setitimer(signal.ITIMER_REAL, 0)
PY
  ) || true

  if [[ -n "${CLAUDE_INTERACTIVE_LOG_FILE:-}" && -n "$output" ]]; then
    if [[ ! -f "${CLAUDE_INTERACTIVE_LOG_FILE}" ]] || ! grep -qF -- "$output" "${CLAUDE_INTERACTIVE_LOG_FILE}" 2>/dev/null; then
      printf '%s\n' "$output" >>"${CLAUDE_INTERACTIVE_LOG_FILE}"
    fi
  elif [[ -n "${CLAUDE_INTERACTIVE_LOG_FILE:-}" && ! -s "${CLAUDE_INTERACTIVE_LOG_FILE}" && -n "$output" ]]; then
    printf '%s' "$output" >"${CLAUDE_INTERACTIVE_LOG_FILE}"
  fi

  if [[ -z "$output" && -n "${CLAUDE_INTERACTIVE_LOG_FILE:-}" && -f "${CLAUDE_INTERACTIVE_LOG_FILE}" ]]; then
    output="$(cat "${CLAUDE_INTERACTIVE_LOG_FILE}")"
  fi

  printf '%s' "$output"
}

agent_invoke() {
  local mode="$1"
  local prompt="$2"

  if cursor_in_session_active; then
    cursor_in_session_invoke "$mode" "$prompt"
    return $?
  fi

  agent_invoke_cli "$mode" "$prompt"
}
