#!/usr/bin/env bash
# Kay agent adapter for live Silver Bullet tests.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/live/lib/kay-cli.sh
source "${SCRIPT_DIR}/../../lib/kay-cli.sh"

agent_name() {
  printf 'kay'
}

agent_cli_path() {
  local cli

  cli="$(resolve_kay_cli_path "${CODEX_BIN:-}" || true)"
  if [[ -z "$cli" ]]; then
    printf 'ERROR: Kay CLI not found or not working\n' >&2
    return 1
  fi
  if [[ "$(basename "$cli")" != "kay" ]]; then
    printf 'ERROR: SB live tests require Kay as the compatible agent\n' >&2
    return 1
  fi

  printf '%s\n' "$cli"
}

kay_session_catalog_path() {
  printf '%s\n' "${CODEX_SESSION_CATALOG_PATH:-${KAY_HOME:-${KAY_SB_TEST_HOME:-${SB_LIVE_CODEX_ISOLATION_DIR:-}}}/.kay/sessions/index/catalog.jsonl}"
}

codex_transcript_dir() {
  # Live-harness archive for captured Kay transcripts; separate from the
  # agent's official session store used by silver-scan.
  printf '%s\n' "${CODEX_TRANSCRIPT_DIR:-${SB_ROOT}/tests/live/agents/kay/transcripts}"
}

agent_transcript_dir() {
  codex_transcript_dir
}

agent_preflight() {
  local cli
  cli="$(agent_cli_path)"
  if [[ -z "$cli" ]] || ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: Kay CLI not found or not working in PATH\n' >&2
    return 1
  fi
}

kay_rotate_transcripts() {
  local transcript_dir="$1"
  local keep_archives="${2:-2}"

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

kay_resolve_session_archive() {
  local started_at="$1"
  local work_dir="$2"
  local catalog_path

  catalog_path="$(kay_session_catalog_path)"
  python3 - "$catalog_path" "$started_at" "$work_dir" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

catalog_path = Path(sys.argv[1])
started_at = sys.argv[2].strip()
work_dir = sys.argv[3].strip()
try:
    work_dir = str(Path(work_dir).resolve())
except Exception:
    pass

def parse_iso(value):
    if not value:
        return None
    value = value.strip()
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return datetime.fromisoformat(value)

if not catalog_path.exists():
    sys.exit(1)

started_dt = None
if started_at:
    try:
        started_dt = parse_iso(started_at)
    except Exception:
        started_dt = None

fallback = datetime.min.replace(tzinfo=timezone.utc)
candidates = []
for raw in catalog_path.read_text(encoding="utf-8").splitlines():
    if not raw.strip():
        continue
    try:
        row = json.loads(raw)
    except Exception:
        continue
    if row.get("deleted"):
        continue
    cwd_real = row.get("cwd_real")
    cwd_display = row.get("cwd_display")
    if cwd_real != work_dir and cwd_display != work_dir:
        continue
    rollout_path = row.get("rollout_path")
    if not rollout_path:
        continue
    created_at = row.get("created_at", "")
    try:
        created_dt = parse_iso(created_at) or fallback
    except Exception:
        created_dt = fallback
    if started_dt is not None and created_dt < started_dt:
        continue
    candidates.append((created_dt, row.get("session_id", ""), rollout_path, created_at))

if not candidates:
    sys.exit(2)

candidates.sort(key=lambda item: (item[0], item[1]))
session_id, rollout_path, created_at = candidates[-1][1], candidates[-1][2], candidates[-1][3]
print(f"{session_id}\t{rollout_path}\t{created_at}")
PY
}

kay_capture_transcript() {
  local transcript_source_file="$1"
  local prompt_file="$2"
  local started_at="$3"
  local work_dir="$4"
  local transcript_dir
  local transcript_info
  local work_dir_real
  local thread_id
  local session_id
  local rollout_path
  local created_at
  local transcript_dest
  local meta_dest

  transcript_dir="$(codex_transcript_dir)"
  mkdir -p "$transcript_dir"
  [[ -f "$transcript_source_file" ]] || return 1
  transcript_dest="${transcript_dir}/latest.jsonl"
  work_dir_real="$(python3 - "$work_dir" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
)"
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
  thread_id="$(python3 - "$transcript_source_file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    for raw in handle:
        raw = raw.strip()
        if not raw:
            continue
        try:
            row = json.loads(raw)
        except Exception:
            continue
        if row.get("type") == "thread.started":
            print(row.get("thread_id", ""))
            break
PY
)"

  session_id="${thread_id:-}"
  transcript_info="$(kay_resolve_session_archive "$started_at" "$work_dir_real" 2>/dev/null || true)"
  if [[ -n "$transcript_info" ]]; then
    IFS=$'\t' read -r session_id rollout_path created_at <<<"$transcript_info"
  fi
  meta_dest="${transcript_dir}/latest.meta.json"
  if [[ -n "$session_id" ]]; then
    cp -f -- "$transcript_dest" "${transcript_dir}/${session_id}.jsonl"
    kay_rotate_transcripts "$transcript_dir" 2
  fi
  jq -n \
    --arg session_id "$session_id" \
    --arg thread_id "$thread_id" \
    --arg rollout_path "$rollout_path" \
    --arg created_at "$created_at" \
    --arg captured_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg source "$transcript_source_file" \
    --arg work_dir "$work_dir" \
    --arg work_dir_real "$work_dir_real" \
    '{session_id:$session_id, thread_id:$thread_id, rollout_path:$rollout_path, created_at:$created_at, captured_at:$captured_at, source:$source, work_dir:$work_dir, work_dir_real:$work_dir_real}' \
    > "$meta_dest"
  printf '%s\n' "$transcript_dest"
  return 1
}

kay_live_guard_context() {
  local test_root="${KAY_HOME:-${KAY_SB_TEST_HOME:-${SB_LIVE_CODEX_ISOLATION_DIR:-}}}"
  local state_file="${test_root}/.codex/.silver-bullet/state"
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
  local transcript_started_at
  local transcript_file
  local transcript_path
  local kay_prompt
  local kay_model
  local kay_model_provider
  local kay_reasoning_effort
  local auto_trust_hooks

  cli="$(agent_cli_path)"
  tmpdir="${TMPDIR:-/tmp}"
  last_message_file="$(mktemp "${tmpdir}/codex-live-last-message-XXXXXX")"
  prompt_file="$(mktemp "${tmpdir}/codex-live-prompt-XXXXXX")"
  prompt_seed_file="$(mktemp "${tmpdir}/codex-live-prompt-seed-XXXXXX")"
  transcript_file="$(mktemp "${tmpdir}/codex-live-transcript-XXXXXX")"
  transcript_started_at="$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'))
PY
)"
  kay_prompt="$prompt"
  kay_model="${CODEX_MODEL:-${SB_LIVE_CODEX_MODEL:-}}"
  kay_model_provider="${CODEX_MODEL_PROVIDER:-${SB_LIVE_CODEX_MODEL_PROVIDER:-}}"
  kay_reasoning_effort="${CODEX_REASONING_EFFORT:-${SB_LIVE_CODEX_REASONING_EFFORT:-low}}"
  auto_trust_hooks="0"
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" == "1" ]]; then
    auto_trust_hooks="${SB_LIVE_CODEX_AUTO_TRUST_HOOKS:-1}"
  fi
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" == "1" && -n "${SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD:-}" ]]; then
    kay_prompt="${SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD}"$'\n\n'"${kay_prompt}"
  fi
  if [[ "${SB_LIVE_CODEX_GUARD:-0}" == "1" ]]; then
    kay_prompt="${kay_prompt}"$'\n\n'"$(kay_live_guard_context)"
  fi
  printf '%s' "$kay_prompt" > "$prompt_file"
  jq -n --arg p "$prompt" '{hook_event_name:"UserPromptSubmit", prompt:$p}' > "$prompt_seed_file"
  if [[ -x "${SB_ROOT}/hooks/record-requested-skill.sh" ]]; then
    printf '%s' "$(cat "$prompt_seed_file")" | bash "${SB_ROOT}/hooks/record-requested-skill.sh" >/dev/null 2>&1 || true
  fi

  output=$(
    cd "$SB_ROOT" && \
      TERM="xterm-256color" \
      CODEX_MODEL="$kay_model" \
      CODEX_MODEL_PROVIDER="$kay_model_provider" \
      CODEX_REASONING_EFFORT="$kay_reasoning_effort" \
      CODEX_RUNTIME_AGENT="kay" \
      CODEX_KAY_HOME="${KAY_HOME}/.kay" \
      CODEX_BIN="$cli" \
      CODEX_WORK_DIR="$WORK_DIR" \
      CODEX_PROMPT_FILE="$prompt_file" \
      SILVER_BULLET_PROMPT_FILE="$prompt_file" \
      CODEX_LAST_MESSAGE_FILE="$last_message_file" \
      CODEX_TRANSCRIPT_FILE="$transcript_file" \
      CODEX_JSON="1" \
      CODEX_COLOR="never" \
      CODEX_SANDBOX_MODE="danger-full-access" \
      CODEX_BYPASS=$([[ "$mode" == "permissive" ]] && printf '1' || printf '0') \
      CODEX_AUTO_TRUST_HOOKS="$auto_trust_hooks" \
      expect "$SB_ROOT/scripts/codex-interactive-invoke.expect" 2>&1
  ) || true
  if [[ -f "$last_message_file" ]]; then
    output="${output}"$'\n'"$(cat "$last_message_file")"
    rm -f -- "$last_message_file"
  fi
  if transcript_path="$(kay_capture_transcript "$transcript_file" "$prompt_file" "$transcript_started_at" "$WORK_DIR" 2>/dev/null || true)"; [[ -n "$transcript_path" ]]; then
    output="${output}"$'\n'"[kay transcript archived at ${transcript_path}]"
  fi
  rm -f -- "$transcript_file"
  rm -f -- "$prompt_file"
  rm -f -- "$prompt_seed_file"
  printf '%s' "$output"
}
