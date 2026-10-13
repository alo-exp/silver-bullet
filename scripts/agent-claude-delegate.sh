#!/usr/bin/env bash
# On-demand Claude TUI delegation wrapper for /sb:agent-claude (not enterprise E2E matrix).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-delegate-common.sh
source "${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
# shellcheck source=scripts/agent-claude/lib.sh
source "${REPO_ROOT}/scripts/agent-claude/lib.sh"
# shellcheck source=hooks/lib/cert-bypass.sh
source "${REPO_ROOT}/hooks/lib/cert-bypass.sh"

usage() {
  cat <<'EOF'
Usage: agent-claude-delegate.sh --work-dir PATH (--prompt TEXT | --brief-file PATH | --prompt-file PATH)
       [--log PATH] [--mode permissive|strict] [--interaction-mode auto|interactive|non-interactive]
       [--sb-root PATH] [--use-print] [--attach] [--no-escalate] [--allow-mode-fallback]

Delegates a single task to Claude via tests/live/agents/claude/agent.sh (NI: claude --print; interactive: expect PTY).
Requires full SB checkout (agent adapter). Parent supervisors: see /sb:agent-claude.
EOF
}

WORK_DIR=""
PROMPT_TEXT=""
PROMPT_FILE=""
BRIEF_FILE=""
LOG_FILE=""
MODE="permissive"
SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
USE_PRINT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    --prompt) PROMPT_TEXT="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --brief-file) BRIEF_FILE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --mode)
      MODE="$2"; shift 2
      agent_mode_note_permission_mode "$MODE" || exit 2
      ;;
    --sb-root) SB_ROOT="$2"; shift 2 ;;
    --interaction-mode|--interactive|--non-interactive|--attach|--no-escalate|--allow-mode-fallback|--auto-policy|--control-dir|--max-turns|--max-wall-sec|--idle-sec|--task-id|--use-print|--use-exec|--use-interactive|--quota-retry|--skip-preflight)
      agent_mode_handle_flag "$1" "${2:-}" || exit 2
      shift "$SB_AM_SHIFT"
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

agent_delegate_validate_work_dir "$WORK_DIR" || exit 2
agent_delegate_clear_matrix_env

if [[ "${SB_AGENT_CERT_RUN:-0}" == "1" && -z "${CLAUDE_PERMISSION_MODE:-}" ]]; then
  export CLAUDE_PERMISSION_MODE=bypassPermissions
fi

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
agent_mode_run_delegate_resolver "claude" "$WORK_DIR" "$PROMPT_TEXT" || exit $?
if agent_delegate_is_pinned_ni; then
  agent_delegate_exec_pinned_ni "claude" "$WORK_DIR" "$PROMPT_TEXT" "$MODE"
fi
if [[ "$SB_AM_RESOLVED" == "non-interactive" ]]; then
  USE_PRINT=1
else
  USE_PRINT=0
fi

if ! agent_delegate_preflight_recommended_tools "$WORK_DIR" "$SB_ROOT" "claude"; then
  printf 'ERROR: recommended-tools preflight failed — fix Graphify/agentmemory before delegation\n' >&2
  exit 2
fi

AGENT_SH="${SB_ROOT}/tests/live/agents/claude/agent.sh"
[[ -f "$AGENT_SH" ]] || {
  printf 'ERROR: missing Claude live adapter at %s (full SB checkout required)\n' "$AGENT_SH" >&2
  exit 1
}

quota_retry_interval="${AGENT_CLAUDE_QUOTA_RETRY_INTERVAL:-60}"
quota_retry_max="$(agent_delegate_quota_retry_max AGENT_CLAUDE_QUOTA_RETRY_MAX 5)"
log_floor="${SB_AGENT_CLAUDE_LOG_FLOOR:-512}"
attempt=0

agent_claude_apply_lightweight_env() {
  [[ "${SB_AGENT_CLAUDE_LIGHTWEIGHT:-1}" == "1" ]] || return 0

  export SB_AGENT_CLAUDE_DELEGATE=1
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"

  if [[ "${SB_AGENT_CERT_RUN:-}" == "1" || "${SB_AGENT_CERT_RUN:-}" == "true" ]]; then
    export SB_AGENT_CERT_RUN=1
    if declare -f sb_cert_run_touch_marker >/dev/null 2>&1; then
      sb_cert_run_touch_marker "${WORK_DIR:-${CLAUDE_WORK_DIR:-}}"
    else
      mkdir -p "${WORK_DIR:-}/.silver-bullet" 2>/dev/null || true
      : >"${WORK_DIR:-}/.silver-bullet/agent-cert-run" 2>/dev/null || true
    fi
    agent_claude_ensure_plugin_cache "$SB_ROOT" || true
  fi

  if [[ "$USE_PRINT" -eq 1 ]]; then
    export CLAUDE_USE_INTERACTIVE=0
  else
    export CLAUDE_USE_INTERACTIVE=1
  fi

  agent_claude_prepare_lightweight_config_dir
}

agent_claude_invoke_once() {
  agent_claude_apply_runtime_env
  agent_claude_apply_lightweight_env
  trap agent_claude_cleanup_lightweight_config_dir RETURN
  export SB_ROOT
  export WORK_DIR="$WORK_DIR"
  export CLAUDE_WORK_DIR="$WORK_DIR"
  export CLAUDE_INTERACTIVE_LOG_FILE="${LOG_FILE:-}"
  # shellcheck source=tests/live/agents/claude/agent.sh
  source "$AGENT_SH"
  agent_preflight
  agent_invoke "$MODE" "$PROMPT_TEXT"
}

final_output=""
final_exit=1

while [[ "$attempt" -le "$quota_retry_max" ]]; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -gt 1 ]]; then
    printf '[agent-claude] quota retry %s/%s after %ss\n' "$attempt" "$((quota_retry_max + 1))" "$quota_retry_interval" >&2
    sleep "$quota_retry_interval"
  fi

  if [[ -n "$LOG_FILE" ]]; then
    if [[ "$USE_PRINT" -eq 1 ]]; then
      agent_delegate_write_log_header "$LOG_FILE" "agent-claude-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" \
        "interactive=0"
    else
      : >"$LOG_FILE"
    fi
  fi

  final_output="$(agent_claude_invoke_once)" && final_exit=0 || final_exit=$?

  if [[ -n "$LOG_FILE" && "$USE_PRINT" -eq 1 ]]; then
    agent_delegate_append_invoke_output "$LOG_FILE" "$final_output"
  fi

  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    agent_delegate_redact_log_file "$LOG_FILE"
    if ! agent_delegate_check_log_floor "$LOG_FILE" "$log_floor" "agent-claude"; then
      final_exit=1
    fi
    if ! agent_delegate_check_workflow_markers "$LOG_FILE" "agent-claude"; then
      final_exit=1
    fi
    agent_delegate_write_log_footer "$LOG_FILE" "$final_exit" "$attempt" "agent-claude-delegate"
  elif [[ -n "$LOG_FILE" && ! -f "$LOG_FILE" ]]; then
    agent_delegate_write_fallback_log "$LOG_FILE" "agent-claude-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" "$final_exit" "$final_output"
    printf '[agent-claude] log written: %s\n' "$LOG_FILE" >&2
  fi

  if [[ "$final_exit" -eq 0 ]]; then
    break
  fi
  if ! agent_delegate_is_quota_error "$final_output"; then
    break
  fi
  if agent_delegate_quota_blocks_short_retry "$final_output"; then
    printf '[agent-claude] quota window exhausted — skip short retry (RFL schedule)\n' >&2
    break
  fi
  if [[ "$attempt" -gt "$quota_retry_max" ]]; then
    printf '[agent-claude] quota retries exhausted\n' >&2
    break
  fi
done

if [[ "$final_exit" -ne 0 ]]; then
  missing=0
  [[ -f "${SB_AM_TASK_DIR}/result.md" ]] || missing=1
  agent_mode_normalize_incomplete_result "$SB_AM_TASK_DIR" "$missing"
  if agent_mode_maybe_escalate "claude" "$SB_AM_TASK_DIR" "${LOG_FILE:-}"; then
    agent_mode_apply_host_launch_env "claude"
    USE_PRINT=0
    final_output="$(agent_claude_invoke_once)" && final_exit=0 || final_exit=$?
  fi
fi

printf '%s' "$final_output"
exit "$final_exit"
