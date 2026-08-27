#!/usr/bin/env bash
# On-demand OpenCode delegation wrapper for /silver:agent-opencode (not enterprise E2E matrix).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/opencode-cli.sh
source "${REPO_ROOT}/scripts/lib/opencode-cli.sh"
# shellcheck source=scripts/lib/agent-delegate-common.sh
source "${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
# shellcheck source=scripts/agent-opencode/lib.sh
source "${REPO_ROOT}/scripts/agent-opencode/lib.sh"

usage() {
  cat <<'EOF'
Usage: agent-opencode-delegate.sh --work-dir PATH (--prompt TEXT | --brief-file PATH | --prompt-file PATH)
       [--log PATH] [--mode permissive|strict] [--interaction-mode auto|interactive|non-interactive]
       [--sb-root PATH] [--use-interactive] [--attach] [--no-escalate] [--allow-mode-fallback]
       [--delegation-mode default|multi-ai-worker-v1|multi-ai-pool-v1]
       [--multi-ai-profile PROFILE_ID] [--multi-ai-pool lite|regular]
       [--cohort-request PATH] [--cohort-output PATH]

Delegates a single task to OpenCode via tests/live/agents/opencode/agent.sh (opencode run primary).
Model policy: default opencode-go / mimo-v2.5. multi-ai-worker-v1 selects allowlisted OCG profiles only.
EOF
}

WORK_DIR=""
PROMPT_TEXT=""
PROMPT_FILE=""
BRIEF_FILE=""
LOG_FILE=""
MODE="permissive"
SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
USE_INTERACTIVE=0
DELEGATION_MODE="default"
MULTI_AI_PROFILE=""
MULTI_AI_POOL="lite"
COHORT_REQUEST=""
COHORT_OUTPUT=""

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
    --delegation-mode) DELEGATION_MODE="$2"; shift 2 ;;
    --multi-ai-profile) MULTI_AI_PROFILE="$2"; shift 2 ;;
    --multi-ai-pool) MULTI_AI_POOL="$2"; shift 2 ;;
    --cohort-request) COHORT_REQUEST="$2"; shift 2 ;;
    --cohort-output) COHORT_OUTPUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

WORK_DIR="$(agent_delegate_resolve_work_dir "$WORK_DIR")" || exit 2
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

if [[ "$DELEGATION_MODE" != "multi-ai-pool-v1" ]]; then
  PROMPT_TEXT="$(agent_delegate_resolve_prompt "$BRIEF_FILE" "$PROMPT_FILE" "$PROMPT_TEXT")" || exit 2
else
  PROMPT_TEXT="${PROMPT_TEXT:-OCG pool cohort dispatch}"
fi

agent_mode_run_delegate_resolver "opencode" "$WORK_DIR" "$PROMPT_TEXT" || exit $?
if agent_delegate_is_pinned_ni; then
  agent_delegate_exec_pinned_ni "opencode" "$WORK_DIR" "$PROMPT_TEXT" "$MODE"
fi
if [[ "$SB_AM_RESOLVED" == "interactive" ]]; then
  USE_INTERACTIVE=1
else
  USE_INTERACTIVE=0
fi

unset SB_AGENT_OPENCODE_DELEGATION_MODE SB_MULTI_AI_OCG_PROFILE SB_MULTI_AI_OCG_POOL SB_MULTI_AI_OCG_VALIDATED

case "$DELEGATION_MODE" in
  default|multi-ai-worker-v1|multi-ai-pool-v1) ;;
  *)
    printf 'ERROR: invalid --delegation-mode %s (expected default, multi-ai-worker-v1, or multi-ai-pool-v1)\n' "$DELEGATION_MODE" >&2
    exit 2
    ;;
esac

if [[ "$DELEGATION_MODE" == "multi-ai-pool-v1" ]]; then
  [[ -n "$COHORT_REQUEST" ]] || {
    printf 'ERROR: --cohort-request required for multi-ai-pool-v1\n' >&2
    exit 2
  }
  COHORT_REQUEST="$(agent_delegate_canonicalize_path "$COHORT_REQUEST")"
  if [[ -n "$COHORT_OUTPUT" ]]; then
    COHORT_OUTPUT="$(agent_delegate_canonicalize_path "$COHORT_OUTPUT")"
  fi
fi

if ! agent_delegate_preflight_recommended_tools "$WORK_DIR" "$SB_ROOT" "opencode"; then
  printf 'ERROR: recommended-tools preflight failed — fix Graphify/agentmemory before delegation\n' >&2
  exit 2
fi

AGENT_SH="${SB_ROOT}/tests/live/agents/opencode/agent.sh"
[[ -f "$AGENT_SH" ]] || {
  printf 'ERROR: missing OpenCode live adapter at %s (full SB checkout required)\n' "$AGENT_SH" >&2
  exit 1
}

CLI="$(resolve_native_opencode_cli_path "${OPENCODE_BIN:-}" || true)"
[[ -n "$CLI" ]] || {
  printf 'ERROR: native OpenCode CLI not found\n' >&2
  exit 1
}

quota_retry_interval="${AGENT_OPENCODE_QUOTA_RETRY_INTERVAL:-60}"
quota_retry_max="$(agent_delegate_quota_retry_max AGENT_OPENCODE_QUOTA_RETRY_MAX 5)"
log_floor="${SB_AGENT_OPENCODE_LOG_FLOOR:-512}"
attempt=0

agent_opencode_apply_delegation_mode() {
  if [[ "$DELEGATION_MODE" == "multi-ai-worker-v1" ]]; then
    [[ -n "$MULTI_AI_PROFILE" ]] || {
      printf 'ERROR: --multi-ai-profile required for multi-ai-worker-v1\n' >&2
      return 2
    }
    agent_opencode_apply_multi_ai_worker_env "$MULTI_AI_PROFILE" "$MULTI_AI_POOL" "$SB_ROOT" || return $?
  elif [[ "$DELEGATION_MODE" == "multi-ai-pool-v1" ]]; then
    export SB_AGENT_OPENCODE_DELEGATION_MODE="multi-ai-pool-v1"
    export SB_MULTI_AI_OCG_POOL="$MULTI_AI_POOL"
    export SB_MULTI_AI_OCG_VALIDATED=1
    agent_opencode_validate_multi_ai_pool_mode "$MULTI_AI_POOL" "$SB_ROOT" || return $?
    agent_opencode_pin_mimo_model_env || return $?
  else
    if [[ -n "$MULTI_AI_PROFILE" ]]; then
      printf 'ERROR: --multi-ai-profile requires --delegation-mode multi-ai-worker-v1\n' >&2
      return 2
    fi
    agent_opencode_pin_mimo_model_env || return $?
  fi
}

agent_opencode_invoke_pool_cohort() {
  agent_opencode_apply_delegation_mode || return $?
  agent_opencode_apply_lightweight_env || return $?
  agent_opencode_apply_runtime_env
  local cohort_script="${SB_ROOT}/skills/silver-multi-ai-task/scripts/ocg_pool_cohort.py"
  [[ -f "$cohort_script" ]] || {
    printf 'ERROR: missing OCG cohort script at %s\n' "$cohort_script" >&2
    return 1
  }
  local -a cohort_args=(python3 "$cohort_script" --request "$COHORT_REQUEST")
  if [[ -n "$COHORT_OUTPUT" ]]; then
    cohort_args+=(--output "$COHORT_OUTPUT")
  fi
  printf '{"type":"ocg.pool.cohort.start","pool":"%s","request":"%s"}\n' "$MULTI_AI_POOL" "$COHORT_REQUEST" >&2
  (cd "$WORK_DIR" && "${cohort_args[@]}")
}

agent_opencode_apply_lightweight_env() {
  [[ "${SB_AGENT_OPENCODE_LIGHTWEIGHT:-1}" == "1" ]] || return 0

  export SB_AGENT_OPENCODE_DELEGATE=1
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
}

agent_opencode_invoke_once() {
  agent_opencode_apply_delegation_mode || return $?
  agent_opencode_apply_lightweight_env || return $?
  agent_opencode_apply_runtime_env
  export SB_ROOT
  export WORK_DIR="$WORK_DIR"
  export OPENCODE_WORK_DIR="$WORK_DIR"
  export OPENCODE_BIN="$CLI"
  export SB_LIVE_OPENCODE_USE_INTERACTIVE="$USE_INTERACTIVE"
  export CLAUDE_INTERACTIVE_LOG_FILE="${LOG_FILE:-}"
  # shellcheck source=tests/live/agents/opencode/agent.sh
  source "$AGENT_SH"
  agent_preflight
  agent_invoke "$MODE" "$PROMPT_TEXT"
}

final_output=""
final_exit=1

while [[ "$attempt" -le "$quota_retry_max" ]]; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -gt 1 ]]; then
    printf '[agent-opencode] quota retry %s/%s after %ss\n' "$attempt" "$((quota_retry_max + 1))" "$quota_retry_interval" >&2
    sleep "$quota_retry_interval"
  fi

  if [[ -n "$LOG_FILE" ]]; then
    : >"$LOG_FILE"
    log_model="opencode-go/mimo-v2.5"
    if [[ "$DELEGATION_MODE" == "multi-ai-worker-v1" ]]; then
      log_model="opencode-go/${MULTI_AI_PROFILE}"
    fi
    agent_delegate_write_log_header "$LOG_FILE" "agent-opencode-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" \
      "model=${log_model} mode=${DELEGATION_MODE}"
  fi

  if [[ "$DELEGATION_MODE" == "multi-ai-pool-v1" ]]; then
    final_output="$(agent_opencode_invoke_pool_cohort)" && final_exit=0 || final_exit=$?
  else
    final_output="$(agent_opencode_invoke_once)" && final_exit=0 || final_exit=$?
  fi

  if [[ -n "$LOG_FILE" ]]; then
    agent_delegate_append_invoke_output "$LOG_FILE" "$final_output"
    agent_delegate_append_workdir_evidence "$LOG_FILE" "$WORK_DIR" "$PROMPT_TEXT"
  fi

  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    agent_delegate_redact_log_file "$LOG_FILE"
    agent_delegate_write_log_footer "$LOG_FILE" "$final_exit" "$attempt" "agent-opencode-delegate"
    if ! agent_delegate_check_log_floor "$LOG_FILE" "$log_floor" "agent-opencode"; then
      final_exit=1
    fi
  elif [[ -n "$LOG_FILE" && ! -f "$LOG_FILE" ]]; then
    agent_delegate_write_fallback_log "$LOG_FILE" "agent-opencode-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" "$final_exit" "$final_output"
    printf '[agent-opencode] log written: %s\n' "$LOG_FILE" >&2
  fi

  if [[ "$final_exit" -eq 0 ]]; then
    break
  fi
  if ! agent_delegate_is_quota_error "$final_output"; then
    break
  fi
  if agent_delegate_quota_blocks_short_retry "$final_output"; then
    printf '[agent-opencode] quota window exhausted — skip short retry (RFL schedule)\n' >&2
    break
  fi
  if [[ "$attempt" -gt "$quota_retry_max" ]]; then
    printf '[agent-opencode] quota retries exhausted\n' >&2
    break
  fi
done

if [[ "$final_exit" -ne 0 ]]; then
  missing=0
  [[ -f "${SB_AM_TASK_DIR}/result.md" ]] || missing=1
  agent_mode_normalize_incomplete_result "$SB_AM_TASK_DIR" "$missing"
  if agent_mode_maybe_escalate "opencode" "$SB_AM_TASK_DIR" "${LOG_FILE:-}"; then
    agent_mode_apply_host_launch_env "opencode"
    USE_INTERACTIVE=1
    final_output="$(agent_opencode_invoke_once)" && final_exit=0 || final_exit=$?
  fi
fi

printf '%s' "$final_output"
exit "$final_exit"
