#!/usr/bin/env bash
# Native Codex CLI adapter for live Silver Bullet tests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/live/lib/codex-cli.sh
source "${SCRIPT_DIR}/../../lib/codex-cli.sh"

agent_name() {
  printf 'codex'
}

agent_cli_path() {
  local cli

  cli="$(resolve_native_codex_cli_path "${CODEX_BIN:-}" || true)"
  if [[ -z "$cli" ]]; then
    printf 'ERROR: native Codex CLI not found or not working\n' >&2
    return 1
  fi
  if [[ "$(basename "$cli")" != "codex" ]]; then
    printf 'ERROR: SB native Codex tests require the actual Codex CLI\n' >&2
    return 1
  fi

  printf '%s\n' "$cli"
}

agent_transcript_dir() {
  printf '%s\n' "${CODEX_TRANSCRIPT_DIR:-${SB_ROOT}/tests/live/agents/codex/transcripts}"
}

agent_preflight() {
  local cli
  cli="$(agent_cli_path)"
  if [[ -z "$cli" ]] || ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: native Codex CLI not found or not working\n' >&2
    return 1
  fi
}

codex_rotate_transcripts() {
  local transcript_dir="$1"
  local keep_archives="${2:-4}"

  python3 - "$transcript_dir" "$keep_archives" <<'PY'
import sys
from pathlib import Path

transcript_dir = Path(sys.argv[1])
keep_archives = int(sys.argv[2])

entries = []
for path in transcript_dir.glob("*.jsonl"):
    if path.name == "latest.jsonl":
        continue
    try:
        stat = path.stat()
    except FileNotFoundError:
        continue
    entries.append((stat.st_mtime, path.name, path))

entries.sort(key=lambda item: (item[0], item[1]), reverse=True)
for _, _, path in entries[keep_archives:]:
    try:
        path.unlink()
    except FileNotFoundError:
        pass
PY
}

codex_capture_transcript() {
  local transcript_source_file="$1"
  local prompt_file="$2"
  local transcript_dir
  local transcript_dest
  local archive_id
  local meta_dest

  transcript_dir="$(agent_transcript_dir)"
  mkdir -p "$transcript_dir"
  [[ -f "$transcript_source_file" ]] || return 1
  transcript_dest="${transcript_dir}/latest.jsonl"
  if [[ -f "$prompt_file" ]]; then
    python3 - "$transcript_source_file" "$prompt_file" "$transcript_dest" <<'PY'
import json
import shutil
import sys
from pathlib import Path

source = Path(sys.argv[1])
prompt_path = Path(sys.argv[2])
dest = Path(sys.argv[3])
prompt = prompt_path.read_text(encoding="utf-8")

with dest.open("w", encoding="utf-8") as out:
    out.write(json.dumps({"type": "prompt.submitted", "prompt": prompt}) + "\n")
    with source.open(encoding="utf-8", errors="replace") as inp:
        shutil.copyfileobj(inp, out)
PY
  else
    cp -f -- "$transcript_source_file" "$transcript_dest"
  fi
  archive_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  cp -f -- "$transcript_dest" "${transcript_dir}/${archive_id}.jsonl"
  codex_rotate_transcripts "$transcript_dir" 4
  meta_dest="${transcript_dir}/latest.meta.json"
  jq -n \
    --arg archive_id "$archive_id" \
    --arg captured_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "$transcript_source_file" \
    --arg work_dir "$WORK_DIR" \
    '{archive_id:$archive_id, captured_at:$captured_at, source:$source, work_dir:$work_dir}' \
    > "$meta_dest"
  printf '%s\n' "$transcript_dest"
  return 1
}

codex_live_guard_context() {
  local state_file="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state"
  local state_contents=""

  if [[ -f "$state_file" ]]; then
    state_contents="$(cat "$state_file")"
  fi
  if [[ -z "$state_contents" ]]; then
    state_contents="(empty)"
  fi

  cat <<EOF
Silver Bullet live Codex guard:
- This guard is the final release-gate policy for this turn and overrides the
  task text if the task asks for a direct edit before planning is complete.
- Read the current Silver Bullet state before any direct file edit.
- If the state does not contain silver-quality-gates, refuse the edit and say
  that planning is incomplete or blocked.
- In that blocked case, do not call any tool or shell command that can modify
  files. Reply with the refusal only.
- If silver-quality-gates is present, proceed with only the requested edit.
- For requested file edits, use the file patch/edit tool directly. Do not use
  exec_command, shell commands, or a command named apply_patch to perform or
  inspect the edit.

Current state file path: ${state_file}
Current state file contents:
${state_contents}

EOF
}

agent_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output
  local last_message_file
  local tmpdir
  local prompt_file
  local prompt_seed_file
  local transcript_file
  local codex_prompt
  local codex_model
  local codex_model_provider
  local codex_reasoning_effort
  local hook_trust_bypass
  local auto_trust_hooks

  cli="$(agent_cli_path)"
  [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]] || { printf 'ERROR: WORK_DIR required\n' >&2; return 1; }
  WORK_DIR="$(cd "$WORK_DIR" && pwd)" || return 1
  export WORK_DIR
  tmpdir="${TMPDIR:-/tmp}"
  last_message_file="$(mktemp "${tmpdir}/codex-live-last-message-XXXXXX")"
  prompt_file="$(mktemp "${tmpdir}/codex-live-prompt-XXXXXX")"
  prompt_seed_file="$(mktemp "${tmpdir}/codex-live-prompt-seed-XXXXXX")"
  transcript_file="$(mktemp "${tmpdir}/codex-live-transcript-XXXXXX")"
  codex_prompt="$prompt"
  codex_model="${CODEX_MODEL:-${SB_LIVE_CODEX_MODEL:-}}"
  codex_model_provider="${CODEX_MODEL_PROVIDER:-${SB_LIVE_CODEX_MODEL_PROVIDER:-}}"
  codex_reasoning_effort="${CODEX_REASONING_EFFORT:-${SB_LIVE_CODEX_REASONING_EFFORT:-}}"
  hook_trust_bypass="0"
  auto_trust_hooks="0"
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" == "1" || "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
    hook_trust_bypass="${SB_LIVE_CODEX_BYPASS_HOOK_TRUST:-1}"
    auto_trust_hooks="${SB_LIVE_CODEX_AUTO_TRUST_HOOKS:-1}"
  fi
  if [[ "${SB_AGENT_CODEX_LIGHTWEIGHT:-0}" == "1" || "${SB_AGENT_CODEX_DELEGATE:-0}" == "1" ]]; then
    hook_trust_bypass="${CODEX_BYPASS_HOOK_TRUST:-1}"
    auto_trust_hooks="${CODEX_AUTO_TRUST_HOOKS:-1}"
  fi
  if [[ "${CODEX_AUTO_TRUST_HOOKS:-}" == "1" ]]; then
    auto_trust_hooks=1
    hook_trust_bypass=1
  fi
  if [[ "${CODEX_BYPASS_HOOK_TRUST:-}" == "1" ]]; then
    hook_trust_bypass=1
  fi
  if [[ "${SB_LIVE_CODEX_GUARD:-0}" == "1" ]]; then
    codex_prompt="${codex_prompt}"$'\n\n'"$(codex_live_guard_context)"
  fi
  printf '%s' "$codex_prompt" > "$prompt_file"
  jq -n --arg p "$prompt" '{hook_event_name:"UserPromptSubmit", prompt:$p}' > "$prompt_seed_file"
  if [[ -x "${SB_ROOT}/hooks/record-requested-skill.sh" ]]; then
    printf '%s' "$(cat "$prompt_seed_file")" | bash "${SB_ROOT}/hooks/record-requested-skill.sh" >/dev/null 2>&1 || true
  fi

  if [[ "${SB_LIVE_CODEX_USE_EXEC:-0}" == "1" ]]; then
    local -a exec_args=()
    exec_args=(
      exec
      --cd "$WORK_DIR"
      --sandbox danger-full-access
      --color never
    )
    if [[ "$mode" == "permissive" ]]; then
      exec_args+=(--dangerously-bypass-approvals-and-sandbox)
    fi
    if [[ "$hook_trust_bypass" == "1" ]]; then
      exec_args+=(--dangerously-bypass-hook-trust)
    fi
    if [[ -n "$codex_model" ]]; then
      exec_args+=(--model "$codex_model")
    fi
    if [[ -n "$codex_model_provider" ]]; then
      exec_args+=(--config "model_provider=${codex_model_provider}")
    fi
    if [[ -n "$codex_reasoning_effort" ]]; then
      exec_args+=(--config "model_reasoning_effort=${codex_reasoning_effort}")
    fi
    exec_args+=("$codex_prompt")
    output="$(
      cd "$WORK_DIR" && \
        CODEX_EXEC_CLI="$cli" \
        CODEX_EXEC_TIMEOUT="${CODEX_INTERACTIVE_TIMEOUT:-300}" \
        CODEX_EXEC_TAIL_IDLE_TIMEOUT="${CODEX_EXEC_TAIL_IDLE_TIMEOUT:-45}" \
        SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-}" \
        SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-}" \
        SB_AGENT_CODEX_DELEGATE="${SB_AGENT_CODEX_DELEGATE:-}" \
        SB_AGENT_CODEX_LIGHTWEIGHT="${SB_AGENT_CODEX_LIGHTWEIGHT:-}" \
        CODEX_HOME="${CODEX_HOME:-}" \
        python3 - "${exec_args[@]}" <<'PY'
import os
import re
import select
import subprocess
import sys
import time

cli = os.environ["CODEX_EXEC_CLI"]
timeout = int(os.environ.get("CODEX_EXEC_TIMEOUT") or "300")
tail_idle = int(os.environ.get("CODEX_EXEC_TAIL_IDLE_TIMEOUT") or "45")
args = [cli, *sys.argv[1:]]
child_env = os.environ.copy()
for key in (
    "SB_ORCHESTRATOR_WORKER",
    "SB_ORCHESTRATOR_PARENT",
    "SB_AGENT_CODEX_DELEGATE",
    "SB_AGENT_CODEX_LIGHTWEIGHT",
    "CODEX_HOME",
):
    value = os.environ.get(key)
    if value is not None:
        child_env[key] = value


def exec_output_shows_product_evidence(text: str) -> bool:
    if re.search(r"(?i)the commit succeeded", text):
        return True
    if re.search(r"\[[^\]]+ [0-9a-f]{7,}\] .+", text):
        return True
    if "create mode " in text and "diff --git" in text:
        return True
    return False


def drain_stdout(proc: subprocess.Popen) -> str:
    chunks = []
    fd = proc.stdout.fileno()
    while True:
        ready, _, _ = select.select([fd], [], [], 0)
        if not ready:
            break
        data = os.read(fd, 65536)
        if not data:
            break
        chunks.append(data.decode(errors="replace"))
    return "".join(chunks)


def terminate_child(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=5)


proc = subprocess.Popen(
    args,
    env=child_env,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)
hard_deadline = time.monotonic() + timeout
stdout_parts = []
evidence_at = None
fd = proc.stdout.fileno()

while proc.poll() is None:
    now = time.monotonic()
    if now >= hard_deadline:
        break
    if evidence_at is not None and now - evidence_at >= tail_idle:
        break
    wait = 0.2
    if evidence_at is not None:
        wait = min(wait, max(0.05, tail_idle - (now - evidence_at)))
    ready, _, _ = select.select([fd], [], [], wait)
    if ready:
        data = os.read(fd, 65536)
        if not data:
            break
        chunk = data.decode(errors="replace")
        stdout_parts.append(chunk)
        combined = "".join(stdout_parts)
        if evidence_at is None and exec_output_shows_product_evidence(combined):
            evidence_at = time.monotonic()

combined = "".join(stdout_parts)
remainder = drain_stdout(proc)
if remainder:
    combined += remainder

if combined:
    sys.stdout.write(combined)

if proc.poll() is None:
    if evidence_at is not None:
        terminate_child(proc)
        sys.exit(0)
    terminate_child(proc)
    if exec_output_shows_product_evidence(combined):
        sys.exit(0)
    sys.stdout.write(f"\nERROR: timed out waiting for codex exec after {timeout}s\n")
    sys.exit(124)

sys.exit(proc.returncode or 0)
PY
    )" || true
    rm -f -- "$last_message_file" "$prompt_file" "$prompt_seed_file" "$transcript_file"
    printf '%s' "$output"
    return 0
  fi

  output=$(
    cd "$SB_ROOT" && \
      TERM="xterm-256color" \
      CODEX_RUNTIME_AGENT="codex" \
      CODEX_LAUNCH_MODE="${CODEX_LAUNCH_MODE:-interactive}" \
      CODEX_MODEL="$codex_model" \
      CODEX_MODEL_PROVIDER="$codex_model_provider" \
      CODEX_REASONING_EFFORT="$codex_reasoning_effort" \
      CODEX_BIN="$cli" \
      CODEX_WORK_DIR="$WORK_DIR" \
      CODEX_PROMPT_FILE="$prompt_file" \
      SILVER_BULLET_PROMPT_FILE="$prompt_file" \
      CODEX_LAST_MESSAGE_FILE="$last_message_file" \
      CODEX_TRANSCRIPT_FILE="$transcript_file" \
      CODEX_JSON="1" \
      CODEX_COLOR="never" \
      CODEX_INTERACTIVE_PROMPT_INPUT="1" \
      CODEX_SANDBOX_MODE="danger-full-access" \
      CODEX_INTERACTIVE_TIMEOUT="${CODEX_INTERACTIVE_TIMEOUT:-${CLAUDE_INTERACTIVE_TIMEOUT:-900}}" \
      CODEX_INTERACTIVE_QUIET_TIMEOUT="${CODEX_INTERACTIVE_QUIET_TIMEOUT:-${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-120}}" \
      CODEX_INTERACTIVE_READY_TIMEOUT="${CODEX_INTERACTIVE_READY_TIMEOUT:-${CLAUDE_INTERACTIVE_READY_TIMEOUT:-20}}" \
      CODEX_BYPASS=$([[ "$mode" == "permissive" ]] && printf '1' || printf '0') \
      CODEX_BYPASS_HOOK_TRUST="${CODEX_BYPASS_HOOK_TRUST:-$hook_trust_bypass}" \
      CODEX_AUTO_TRUST_HOOKS="${CODEX_AUTO_TRUST_HOOKS:-$auto_trust_hooks}" \
      python3 "$SB_ROOT/scripts/codex-interactive-invoke.py"
  ) || true
  if [[ -f "$last_message_file" ]]; then
    output="${output}"$'\n'"$(cat "$last_message_file")"
    rm -f -- "$last_message_file"
  fi
  if transcript_path="$(codex_capture_transcript "$transcript_file" "$prompt_file" 2>/dev/null || true)"; [[ -n "$transcript_path" ]]; then
    output="${output}"$'\n'"[codex transcript archived at ${transcript_path}]"
  fi
  if [[ -n "${CLAUDE_INTERACTIVE_LOG_FILE:-}" ]]; then
    printf '%s' "$output" >"${CLAUDE_INTERACTIVE_LOG_FILE}"
  fi
  rm -f -- "$transcript_file"
  rm -f -- "$prompt_file"
  rm -f -- "$prompt_seed_file"
  printf '%s' "$output"
}
