#!/usr/bin/env bash
# On-demand Codex TUI delegation wrapper for /silver:agent-codex (not enterprise E2E matrix).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/codex-cli.sh
source "${REPO_ROOT}/scripts/lib/codex-cli.sh"

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

[[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] || {
  printf 'ERROR: --work-dir must point to an existing directory\n' >&2
  exit 2
}

if [[ -n "$BRIEF_FILE" ]]; then
  [[ -f "$BRIEF_FILE" ]] || { printf 'ERROR: brief file not found: %s\n' "$BRIEF_FILE" >&2; exit 2; }
  PROMPT_TEXT="$(cat "$BRIEF_FILE")"
elif [[ -n "$PROMPT_FILE" ]]; then
  [[ -f "$PROMPT_FILE" ]] || { printf 'ERROR: prompt file not found: %s\n' "$PROMPT_FILE" >&2; exit 2; }
  PROMPT_TEXT="$(cat "$PROMPT_FILE")"
fi

[[ -n "$PROMPT_TEXT" ]] || {
  printf 'ERROR: provide --prompt, --prompt-file, or --brief-file\n' >&2
  exit 2
}

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

agent_codex_apply_lightweight_env() {
  [[ "${SB_AGENT_CODEX_LIGHTWEIGHT:-1}" == "1" ]] || return 0

  export SB_AGENT_CODEX_DELEGATE=1
  # Codex child must execute directly — not re-delegate via parent orchestrator hooks.
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
  agent_codex_apply_lightweight_env
  trap agent_codex_cleanup_lightweight_env RETURN
  export SB_ROOT
  export WORK_DIR="$WORK_DIR"
  export CODEX_BIN="$CLI"
  export SB_LIVE_CODEX_USE_EXEC="$USE_EXEC"
  export CLAUDE_INTERACTIVE_LOG_FILE="${LOG_FILE:-}"
  export RTK_DISABLED=1
  # Model/MCP boot can exceed the harness default ready timeout (20s).
  export CODEX_INTERACTIVE_READY_TIMEOUT="${CODEX_INTERACTIVE_READY_TIMEOUT:-${SB_AGENT_CODEX_MODEL_READY_TIMEOUT:-120}}"
  export CODEX_INTERACTIVE_IDLE_TIMEOUT="${CODEX_INTERACTIVE_IDLE_TIMEOUT:-3600}"
  export CODEX_EXEC_TAIL_IDLE_TIMEOUT="${CODEX_EXEC_TAIL_IDLE_TIMEOUT:-45}"
  # shellcheck source=tests/live/agents/codex/agent.sh
  source "$AGENT_SH"
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

  final_output="$(agent_codex_invoke_once)" && final_exit=0 || final_exit=$?

  if [[ "$final_exit" -eq 0 ]]; then
    break
  fi
  if ! is_quota_error "$final_output"; then
    break
  fi
  if [[ "$attempt" -gt "$quota_retry_max" ]]; then
    printf '[agent-codex] quota retries exhausted\n' >&2
    break
  fi
done

if [[ -n "$LOG_FILE" && ! -f "$LOG_FILE" ]]; then
  mkdir -p "$(dirname "$LOG_FILE")"
  {
    printf '=== agent-codex-delegate %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'work_dir=%s\nsb_root=%s\nattempt=%s\nexit=%s\n\n' "$WORK_DIR" "$SB_ROOT" "$attempt" "$final_exit"
    redact_log_output "$final_output"
    printf '\n'
  } >"$LOG_FILE"
  printf '[agent-codex] log written: %s\n' "$LOG_FILE" >&2
fi

printf '%s' "$final_output"
exit "$final_exit"
