#!/usr/bin/env bash
# On-demand Pi delegation wrapper for /silver:agent-pi (not enterprise E2E matrix).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/pi-cli.sh
source "${REPO_ROOT}/scripts/lib/pi-cli.sh"
# shellcheck source=scripts/lib/agent-delegate-common.sh
source "${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
# shellcheck source=scripts/agent-pi/lib.sh
source "${REPO_ROOT}/scripts/agent-pi/lib.sh"

usage() {
  cat <<'EOF'
Usage: agent-pi-delegate.sh --work-dir PATH (--prompt TEXT | --brief-file PATH | --prompt-file PATH)
       [--log PATH] [--mode permissive|strict] [--interaction-mode auto|interactive|non-interactive]
       [--sb-root PATH] [--attach] [--no-escalate] [--allow-mode-fallback]

Delegates a single task to Pi via tests/live/agents/pi/agent.sh.
NI: pi -p --provider opencode-go --model mimo-v2.5. Interactive: TUI probe or honest mode-unavailable.
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
agent_mode_run_delegate_resolver "pi" "$WORK_DIR" "$PROMPT_TEXT" || exit $?
if agent_delegate_is_pinned_ni; then
  # Expect-file NI returns (does not exec). Exit so named models never fall
  # through to pin_mimo. invoke.sh owns --continue / 401 fail-fast.
  agent_delegate_exec_pinned_ni "pi" "$WORK_DIR" "$PROMPT_TEXT" "$MODE"
  exit $?
fi

if ! agent_delegate_preflight_recommended_tools "$WORK_DIR" "$SB_ROOT" "pi"; then
  printf 'ERROR: recommended-tools preflight failed — fix Graphify/agentmemory before delegation\n' >&2
  exit 2
fi

AGENT_SH="${SB_ROOT}/tests/live/agents/pi/agent.sh"
[[ -f "$AGENT_SH" ]] || {
  printf 'ERROR: missing Pi live adapter at %s (full SB checkout required)\n' "$AGENT_SH" >&2
  exit 1
}

CLI="$(resolve_native_pi_cli_path "${PI_BIN:-}" || true)"
[[ -n "$CLI" ]] || {
  printf 'ERROR: native Pi CLI not found\n' >&2
  exit 1
}

quota_retry_interval="${AGENT_PI_QUOTA_RETRY_INTERVAL:-60}"
quota_retry_max="$(agent_delegate_quota_retry_max AGENT_PI_QUOTA_RETRY_MAX 5)"
log_floor="${SB_AGENT_PI_LOG_FLOOR:-512}"
attempt=0

agent_pi_apply_lightweight_env() {
  [[ "${SB_AGENT_PI_LIGHTWEIGHT:-1}" == "1" ]] || return 0

  export SB_AGENT_PI_DELEGATE=1
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
  agent_pi_pin_mimo_model_env || return $?
}

agent_pi_invoke_once() {
  agent_pi_apply_runtime_env
  agent_pi_apply_lightweight_env || return $?
  export SB_ROOT
  export WORK_DIR="$WORK_DIR"
  export PI_WORK_DIR="$WORK_DIR"
  export PI_BIN="$CLI"
  export CLAUDE_INTERACTIVE_LOG_FILE="${LOG_FILE:-}"
  # shellcheck source=tests/live/agents/pi/agent.sh
  source "$AGENT_SH"
  agent_preflight
  agent_invoke "$MODE" "$PROMPT_TEXT"
}

final_output=""
final_exit=1

while [[ "$attempt" -le "$quota_retry_max" ]]; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -gt 1 ]]; then
    printf '[agent-pi] quota retry %s/%s after %ss\n' "$attempt" "$((quota_retry_max + 1))" "$quota_retry_interval" >&2
    sleep "$quota_retry_interval"
  fi

  if [[ -n "$LOG_FILE" ]]; then
    : >"$LOG_FILE"
    agent_delegate_write_log_header "$LOG_FILE" "agent-pi-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" \
      "provider=opencode-go model=mimo-v2.5"
  fi

  final_output="$(agent_pi_invoke_once)" && final_exit=0 || final_exit=$?

  if [[ -n "$LOG_FILE" ]]; then
    agent_delegate_append_invoke_output "$LOG_FILE" "$final_output"
    agent_delegate_append_workdir_evidence "$LOG_FILE" "$WORK_DIR" "$PROMPT_TEXT"
  fi

  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    agent_delegate_redact_log_file "$LOG_FILE"
    agent_delegate_write_log_footer "$LOG_FILE" "$final_exit" "$attempt" "agent-pi-delegate"
    if ! agent_delegate_check_log_floor "$LOG_FILE" "$log_floor" "agent-pi"; then
      final_exit=1
    fi
  elif [[ -n "$LOG_FILE" && ! -f "$LOG_FILE" ]]; then
    agent_delegate_write_fallback_log "$LOG_FILE" "agent-pi-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" "$final_exit" "$final_output"
    printf '[agent-pi] log written: %s\n' "$LOG_FILE" >&2
  fi

  if [[ "$final_exit" -eq 0 ]]; then
    break
  fi
  if ! agent_delegate_is_quota_error "$final_output"; then
    break
  fi
  if agent_delegate_quota_blocks_short_retry "$final_output"; then
    printf '[agent-pi] quota window exhausted — skip short retry (RFL schedule)\n' >&2
    break
  fi
  if [[ "$attempt" -gt "$quota_retry_max" ]]; then
    printf '[agent-pi] quota retries exhausted\n' >&2
    break
  fi
done

if [[ "$final_exit" -ne 0 ]]; then
  missing=0
  [[ -f "${SB_AM_TASK_DIR}/result.md" ]] || missing=1
  agent_mode_normalize_incomplete_result "$SB_AM_TASK_DIR" "$missing"
  if agent_mode_maybe_escalate "pi" "$SB_AM_TASK_DIR" "${LOG_FILE:-}"; then
    agent_mode_apply_host_launch_env "pi"
    final_output="$(agent_pi_invoke_once)" && final_exit=0 || final_exit=$?
  fi
fi

printf '%s' "$final_output"
exit "$final_exit"
