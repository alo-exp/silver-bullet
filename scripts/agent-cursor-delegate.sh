#!/usr/bin/env bash
# On-demand Cursor agent delegation wrapper for /silver:agent-cursor (not enterprise E2E matrix).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: agent-cursor-delegate.sh --work-dir PATH (--prompt TEXT | --brief-file PATH | --prompt-file PATH)
       [--log PATH] [--mode permissive|strict] [--sb-root PATH]

Delegates a single task to cursor-agent via tests/live/agents/cursor/agent.sh (headless).
Requires full SB checkout (agent adapter). Parent supervisors: see /silver:agent-cursor.
EOF
}

WORK_DIR=""
PROMPT_TEXT=""
PROMPT_FILE=""
BRIEF_FILE=""
LOG_FILE=""
MODE="permissive"
SB_ROOT="${SB_ROOT:-$REPO_ROOT}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    --prompt) PROMPT_TEXT="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --brief-file) BRIEF_FILE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --sb-root) SB_ROOT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] || {
  printf 'ERROR: --work-dir must point to an existing directory\n' >&2
  exit 2
}

if [[ -n "$BRIEF_FILE" ]]; then
  [[ -f "$BRIEF_FILE" ]] || { printf 'ERROR: brief file not found: %s\n' "$BRIEF_FILE" >&2; exit 2; }
  [[ "$BRIEF_FILE" != /* ]] && BRIEF_FILE="$(cd "$(dirname "$BRIEF_FILE")" && pwd)/$(basename "$BRIEF_FILE")"
  PROMPT_TEXT="$(cat "$BRIEF_FILE")"
elif [[ -n "$PROMPT_FILE" ]]; then
  [[ -f "$PROMPT_FILE" ]] || { printf 'ERROR: prompt file not found: %s\n' "$PROMPT_FILE" >&2; exit 2; }
  [[ "$PROMPT_FILE" != /* ]] && PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
  PROMPT_TEXT="$(cat "$PROMPT_FILE")"
fi

[[ -n "$PROMPT_TEXT" ]] || {
  printf 'ERROR: provide --prompt, --prompt-file, or --brief-file\n' >&2
  exit 2
}

if [[ -n "$LOG_FILE" && "$LOG_FILE" != /* ]]; then
  LOG_FILE="$(cd "$(dirname "$LOG_FILE")" && pwd)/$(basename "$LOG_FILE")"
fi

AGENT_SH="${SB_ROOT}/tests/live/agents/cursor/agent.sh"
[[ -f "$AGENT_SH" ]] || {
  printf 'ERROR: missing Cursor live adapter at %s (full SB checkout required)\n' "$AGENT_SH" >&2
  exit 1
}

unset SB_E2E_ENTERPRISE_MATRIX SB_E2E_LEDGER_FILE SB_E2E_MATRIX_BATCH_PID 2>/dev/null || true

quota_retry_interval="${AGENT_CURSOR_QUOTA_RETRY_INTERVAL:-60}"
quota_retry_max="${AGENT_CURSOR_QUOTA_RETRY_MAX:-5}"
log_floor="${SB_AGENT_CURSOR_LOG_FLOOR:-2048}"
attempt=0

is_quota_error() {
  local blob="$1"
  grep -qiE '429|rate[[:space:]]*limit|token[[:space:]]*plan|quota' <<<"$blob"
}

redact_log_output() {
  local blob="$1"
  printf '%s' "$blob" | sed -E \
    -e 's/(api[_-]?key|token|password|secret|authorization)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1=[REDACTED]/gi' \
    -e 's/sk-[A-Za-z0-9_-]{8,}/sk-[REDACTED]/g' \
    -e 's/ghp_[A-Za-z0-9]{20,}/ghp_[REDACTED]/g'
}

redact_log_file() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/agent-cursor-log-XXXXXX")"
  redact_log_output "$(cat "$path")" >"$tmp"
  mv "$tmp" "$path"
}

agent_cursor_write_log_header() {
  [[ -n "$LOG_FILE" ]] || return 0
  mkdir -p "$(dirname "$LOG_FILE")"
  {
    printf '=== agent-cursor-delegate %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'work_dir=%s\nsb_root=%s\nattempt=%s\nmodel=%s\n\n' \
      "$WORK_DIR" "$SB_ROOT" "$attempt" "${CURSOR_AGENT_MODEL:-composer-2.5}"
  } >>"$LOG_FILE"
}

agent_cursor_apply_policy_env() {
  export SB_AGENT_CURSOR_DELEGATE=1
  export CURSOR_AGENT_MODEL="${CURSOR_AGENT_MODEL:-composer-2.5}"
  export CURSOR_MODEL="${CURSOR_MODEL:-composer-2.5}"

  if [[ -n "${CURSOR_API_KEY:-}" ]]; then
    printf '[agent-cursor] WARNING: unsetting CURSOR_API_KEY — use Keychain login (cursor-agent login)\n' >&2
    unset CURSOR_API_KEY
  fi

  if [[ "$CURSOR_AGENT_MODEL" == *fast* ]]; then
    printf '[agent-cursor] ERROR: composer-2.5-fast forbidden — use composer-2.5 only\n' >&2
    return 2
  fi
}

agent_cursor_apply_lightweight_env() {
  [[ "${SB_AGENT_CURSOR_LIGHTWEIGHT:-1}" == "1" ]] || return 0

  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
  export SB_LIVE_CURSOR_FORCE_HEADLESS="${SB_LIVE_CURSOR_FORCE_HEADLESS:-1}"
  export SB_LIVE_CURSOR_IN_SESSION=0
  export SB_AGENT_CURSOR_STREAM_JSON="${SB_AGENT_CURSOR_STREAM_JSON:-1}"
}

agent_cursor_invoke_once() {
  agent_cursor_apply_policy_env || return $?
  agent_cursor_apply_lightweight_env
  export SB_ROOT
  export WORK_DIR="$WORK_DIR"
  export CLAUDE_INTERACTIVE_LOG_FILE="${LOG_FILE:-}"
  export RTK_DISABLED=1
  export CURSOR_AGENT_TIMEOUT="${CURSOR_AGENT_TIMEOUT:-1800}"
  # shellcheck source=tests/live/agents/cursor/agent.sh
  source "$AGENT_SH"
  agent_preflight
  agent_invoke "$MODE" "$PROMPT_TEXT"
}

final_output=""
final_exit=1

while [[ "$attempt" -le "$quota_retry_max" ]]; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -gt 1 ]]; then
    printf '[agent-cursor] quota retry %s/%s after %ss\n' "$attempt" "$((quota_retry_max + 1))" "$quota_retry_interval" >&2
    sleep "$quota_retry_interval"
  fi

  if [[ -n "$LOG_FILE" ]]; then
    : >"$LOG_FILE"
    agent_cursor_write_log_header
  fi

  final_output="$(agent_cursor_invoke_once)" && final_exit=0 || final_exit=$?

  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    redact_log_file "$LOG_FILE"
    log_bytes="$(wc -c <"$LOG_FILE" | tr -d ' ')"
    printf '[agent-cursor] log: %s (%s B)\n' "$LOG_FILE" "$log_bytes" >&2
    if [[ "$log_bytes" -lt "$log_floor" ]]; then
      printf '[agent-cursor] ERROR: log below floor (%s B < %s B) — failure_class=log-floor\n' \
        "$log_bytes" "$log_floor" >&2
      final_exit=1
    fi
  fi

  if [[ "$final_exit" -eq 0 ]]; then
    break
  fi
  if ! is_quota_error "$final_output"; then
    break
  fi
  if [[ "$attempt" -gt "$quota_retry_max" ]]; then
    printf '[agent-cursor] quota retries exhausted\n' >&2
    break
  fi
done

if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
  {
    printf '\n=== agent-cursor-delegate complete exit=%s attempt=%s ===\n' "$final_exit" "$attempt"
  } >>"$LOG_FILE"
fi

printf '%s' "$final_output"
exit "$final_exit"
