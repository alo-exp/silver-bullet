#!/usr/bin/env bash
# Shared helpers for /silver:agent-codex harness scripts.
# shellcheck shell=bash

agent_codex_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

agent_codex_repo_root() {
  local script_dir
  script_dir="$(agent_codex_script_dir)"
  cd "${script_dir}/../.." && pwd
}

_agent_codex_source_common() {
  local script_dir repo_root common
  script_dir="$(agent_codex_script_dir)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
  common="${repo_root}/scripts/lib/agent-delegate-common.sh"
  # shellcheck source=scripts/lib/agent-delegate-common.sh
  [[ -f "$common" ]] && source "$common"
}

# RTK + interactive timeout defaults (invoke.sh and direct delegate.sh paths).
agent_codex_apply_runtime_env() {
  export RTK_DISABLED="${RTK_DISABLED:-1}"
  export CODEX_INTERACTIVE_READY_TIMEOUT="${CODEX_INTERACTIVE_READY_TIMEOUT:-${SB_AGENT_CODEX_MODEL_READY_TIMEOUT:-120}}"
  export CODEX_INTERACTIVE_IDLE_TIMEOUT="${CODEX_INTERACTIVE_IDLE_TIMEOUT:-3600}"
  export CODEX_EXEC_TAIL_IDLE_TIMEOUT="${CODEX_EXEC_TAIL_IDLE_TIMEOUT:-45}"
}

# Default env for on-demand Codex delegation (not matrix).
agent_codex_apply_delegate_env() {
  _agent_codex_source_common
  agent_delegate_clear_matrix_env

  export SB_AGENT_CODEX_DELEGATE="${SB_AGENT_CODEX_DELEGATE:-1}"
  export SB_AGENT_CODEX_LIGHTWEIGHT="${SB_AGENT_CODEX_LIGHTWEIGHT:-1}"
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
  export CODEX_AUTO_TRUST_HOOKS="${CODEX_AUTO_TRUST_HOOKS:-1}"
  export CODEX_BYPASS_HOOK_TRUST="${CODEX_BYPASS_HOOK_TRUST:-1}"
  agent_codex_apply_runtime_env
}

# Vars exported by agent_codex_apply_delegate_env (for env.sh --export).
agent_codex_delegate_env_names() {
  printf '%s\n' \
    SB_AGENT_CODEX_DELEGATE SB_AGENT_CODEX_LIGHTWEIGHT \
    SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT \
    CODEX_AUTO_TRUST_HOOKS CODEX_BYPASS_HOOK_TRUST RTK_DISABLED \
    CODEX_INTERACTIVE_READY_TIMEOUT CODEX_INTERACTIVE_IDLE_TIMEOUT \
    CODEX_EXEC_TAIL_IDLE_TIMEOUT
}
