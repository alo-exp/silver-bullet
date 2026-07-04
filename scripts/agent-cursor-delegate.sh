#!/usr/bin/env bash
# On-demand Cursor agent delegation wrapper for /silver:agent-cursor (not enterprise E2E matrix).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-delegate-common.sh
source "${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"

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

agent_delegate_validate_work_dir "$WORK_DIR" || exit 2
agent_delegate_clear_matrix_env

if [[ -n "$BRIEF_FILE" ]]; then
  BRIEF_FILE="$(agent_delegate_canonicalize_path "$BRIEF_FILE")"
fi
if [[ -n "$PROMPT_FILE" ]]; then
  PROMPT_FILE="$(agent_delegate_canonicalize_path "$PROMPT_FILE")"
fi
if [[ -n "$LOG_FILE" ]]; then
  LOG_FILE="$(agent_delegate_canonicalize_path "$LOG_FILE")"
fi

PROMPT_TEXT="$(agent_delegate_resolve_prompt "$BRIEF_FILE" "$PROMPT_FILE" "$PROMPT_TEXT")" || exit 2

AGENT_SH="${SB_ROOT}/tests/live/agents/cursor/agent.sh"
[[ -f "$AGENT_SH" ]] || {
  printf 'ERROR: missing Cursor live adapter at %s (full SB checkout required)\n' "$AGENT_SH" >&2
  exit 1
}

quota_retry_interval="${AGENT_CURSOR_QUOTA_RETRY_INTERVAL:-60}"
quota_retry_max="${AGENT_CURSOR_QUOTA_RETRY_MAX:-5}"
log_floor="${SB_AGENT_CURSOR_LOG_FLOOR:-2048}"
attempt=0

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
    agent_delegate_write_log_header "$LOG_FILE" "agent-cursor-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" \
      "model=${CURSOR_AGENT_MODEL:-composer-2.5}"
  fi

  final_output="$(agent_cursor_invoke_once)" && final_exit=0 || final_exit=$?

  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    agent_delegate_redact_log_file "$LOG_FILE"
    if ! agent_delegate_check_log_floor "$LOG_FILE" "$log_floor" "agent-cursor"; then
      final_exit=1
    fi
    agent_delegate_write_log_footer "$LOG_FILE" "$final_exit" "$attempt" "agent-cursor-delegate"
  fi

  if [[ "$final_exit" -eq 0 ]]; then
    break
  fi
  if ! agent_delegate_is_quota_error "$final_output"; then
    break
  fi
  if [[ "$attempt" -gt "$quota_retry_max" ]]; then
    printf '[agent-cursor] quota retries exhausted\n' >&2
    break
  fi
done

printf '%s' "$final_output"
exit "$final_exit"
