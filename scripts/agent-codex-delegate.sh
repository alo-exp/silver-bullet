#!/usr/bin/env bash
# On-demand Codex TUI delegation wrapper for /silver:agent-codex (not enterprise E2E matrix).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/codex-cli.sh
source "${REPO_ROOT}/scripts/lib/codex-cli.sh"
# shellcheck source=scripts/lib/agent-delegate-common.sh
source "${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
# shellcheck source=scripts/agent-codex/lib.sh
source "${REPO_ROOT}/scripts/agent-codex/lib.sh"

usage() {
  cat <<'EOF'
Usage: agent-codex-delegate.sh --work-dir PATH (--prompt TEXT | --brief-file PATH | --prompt-file PATH)
       [--log PATH] [--mode permissive|strict] [--sb-root PATH] [--use-exec]

Delegates a single task to Codex via tests/live/agents/codex/agent.sh (TUI or --use-exec).
Requires full SB checkout (agent adapter). Parent supervisors: see /silver:agent-codex.
EOF
}

WORK_DIR=""
PROMPT_TEXT=""
PROMPT_FILE=""
BRIEF_FILE=""
LOG_FILE=""
MODE="permissive"
SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
USE_EXEC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    --prompt) PROMPT_TEXT="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --brief-file) BRIEF_FILE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --sb-root) SB_ROOT="$2"; shift 2 ;;
    --use-exec) USE_EXEC=1; shift ;;
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

if ! agent_delegate_preflight_recommended_tools "$WORK_DIR" "$SB_ROOT" "codex"; then
  printf 'ERROR: recommended-tools preflight failed — fix Graphify/agentmemory before delegation\n' >&2
  exit 2
fi

AGENT_SH="${SB_ROOT}/tests/live/agents/codex/agent.sh"
[[ -f "$AGENT_SH" ]] || {
  printf 'ERROR: missing Codex live adapter at %s (full SB checkout required)\n' "$AGENT_SH" >&2
  exit 1
}

CLI="$(resolve_native_codex_cli_path "${CODEX_BIN:-}" || true)"
[[ -n "$CLI" ]] || {
  printf 'ERROR: native Codex CLI not found\n' >&2
  exit 1
}

quota_retry_interval="${AGENT_CODEX_QUOTA_RETRY_INTERVAL:-60}"
quota_retry_max="${AGENT_CODEX_QUOTA_RETRY_MAX:-5}"
log_floor="${SB_AGENT_CODEX_LOG_FLOOR:-512}"
attempt=0

agent_codex_apply_lightweight_env() {
  [[ "${SB_AGENT_CODEX_LIGHTWEIGHT:-1}" == "1" ]] || return 0

  export SB_AGENT_CODEX_DELEGATE=1
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
  export CODEX_AUTO_TRUST_HOOKS="${CODEX_AUTO_TRUST_HOOKS:-1}"
  export CODEX_BYPASS_HOOK_TRUST="${CODEX_BYPASS_HOOK_TRUST:-1}"

  if [[ "${SB_AGENT_CODEX_SKIP_MCP:-1}" == "1" && -z "${SB_AGENT_CODEX_CODEX_HOME_RESTORE:-}" ]]; then
    local lightweight_home
    lightweight_home="$(mktemp -d "${TMPDIR:-/tmp}/agent-codex-codex-home-XXXXXX")"
    agent_codex_prepare_lightweight_codex_home "${CODEX_HOME:-${HOME}/.codex}" "$lightweight_home"
    SB_AGENT_CODEX_CODEX_HOME_RESTORE="${CODEX_HOME:-}"
    export CODEX_HOME="$lightweight_home"
    export SB_AGENT_CODEX_CODEX_HOME_RESTORE
    printf '[agent-codex] lightweight CODEX_HOME (MCP stripped): %s\n' "$lightweight_home" >&2
  fi
}

agent_codex_cleanup_lightweight_env() {
  if [[ -n "${SB_AGENT_CODEX_CODEX_HOME_RESTORE+x}" ]]; then
    if [[ -n "${CODEX_HOME:-}" && -d "${CODEX_HOME}" ]]; then
      rm -rf "${CODEX_HOME}" 2>/dev/null || true
    fi
    if [[ -n "${SB_AGENT_CODEX_CODEX_HOME_RESTORE}" ]]; then
      export CODEX_HOME="${SB_AGENT_CODEX_CODEX_HOME_RESTORE}"
    else
      unset CODEX_HOME
    fi
    unset SB_AGENT_CODEX_CODEX_HOME_RESTORE
  fi
}

agent_codex_invoke_once() {
  agent_codex_apply_runtime_env
  agent_codex_apply_lightweight_env
  trap agent_codex_cleanup_lightweight_env RETURN
  export SB_ROOT
  export WORK_DIR="$WORK_DIR"
  export CODEX_BIN="$CLI"
  export SB_LIVE_CODEX_USE_EXEC="$USE_EXEC"
  export CLAUDE_INTERACTIVE_LOG_FILE="${LOG_FILE:-}"
  # shellcheck source=tests/live/agents/codex/agent.sh
  source "$AGENT_SH"
  agent_preflight
  agent_invoke "$MODE" "$PROMPT_TEXT"
}

final_output=""
final_exit=1

while [[ "$attempt" -le "$quota_retry_max" ]]; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -gt 1 ]]; then
    printf '[agent-codex] quota retry %s/%s after %ss\n' "$attempt" "$((quota_retry_max + 1))" "$quota_retry_interval" >&2
    sleep "$quota_retry_interval"
  fi

  if [[ -n "$LOG_FILE" ]]; then
    : >"$LOG_FILE"
    agent_delegate_write_log_header "$LOG_FILE" "agent-codex-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt"
  fi

  final_output="$(agent_codex_invoke_once)" && final_exit=0 || final_exit=$?

  if [[ -n "$LOG_FILE" && "$USE_EXEC" == "1" ]]; then
    agent_delegate_append_invoke_output "$LOG_FILE" "$final_output"
  fi

  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    agent_delegate_redact_log_file "$LOG_FILE"
    if ! agent_delegate_check_log_floor "$LOG_FILE" "$log_floor" "agent-codex"; then
      final_exit=1
    fi
    agent_delegate_write_log_footer "$LOG_FILE" "$final_exit" "$attempt" "agent-codex-delegate"
  elif [[ -n "$LOG_FILE" && ! -f "$LOG_FILE" ]]; then
    agent_delegate_write_fallback_log "$LOG_FILE" "agent-codex-delegate" "$WORK_DIR" "$SB_ROOT" "$attempt" "$final_exit" "$final_output"
    printf '[agent-codex] log written: %s\n' "$LOG_FILE" >&2
  fi

  if [[ "$final_exit" -eq 0 ]]; then
    break
  fi
  if ! agent_delegate_is_quota_error "$final_output"; then
    break
  fi
  if [[ "$attempt" -gt "$quota_retry_max" ]]; then
    printf '[agent-codex] quota retries exhausted\n' >&2
    break
  fi
done

printf '%s' "$final_output"
exit "$final_exit"
