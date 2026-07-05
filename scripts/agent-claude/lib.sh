#!/usr/bin/env bash
# Shared helpers for /silver:agent-claude harness scripts.
# shellcheck shell=bash

agent_claude_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

agent_claude_repo_root() {
  local script_dir
  script_dir="$(agent_claude_script_dir)"
  cd "${script_dir}/../.." && pwd
}

_agent_claude_source_common() {
  local script_dir repo_root common
  script_dir="$(agent_claude_script_dir)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
  common="${repo_root}/scripts/lib/agent-delegate-common.sh"
  # shellcheck source=scripts/lib/agent-delegate-common.sh
  [[ -f "$common" ]] && source "$common"
}

# RTK + interactive timeout defaults (invoke.sh and direct delegate.sh paths).
agent_claude_apply_runtime_env() {
  export RTK_DISABLED="${RTK_DISABLED:-1}"
  export CLAUDE_INTERACTIVE_READY_TIMEOUT="${CLAUDE_INTERACTIVE_READY_TIMEOUT:-${SB_AGENT_CLAUDE_MODEL_READY_TIMEOUT:-120}}"
  export CLAUDE_INTERACTIVE_IDLE_TIMEOUT="${CLAUDE_INTERACTIVE_IDLE_TIMEOUT:-3600}"
  export CLAUDE_INTERACTIVE_QUIET_TIMEOUT="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-120}"
  export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY="${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-arrow}"
}

# Default env for on-demand Claude delegation (not matrix).
agent_claude_apply_delegate_env() {
  _agent_claude_source_common
  agent_delegate_clear_matrix_env

  export SB_AGENT_CLAUDE_DELEGATE="${SB_AGENT_CLAUDE_DELEGATE:-1}"
  export SB_AGENT_CLAUDE_LIGHTWEIGHT="${SB_AGENT_CLAUDE_LIGHTWEIGHT:-1}"
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
  export CLAUDE_USE_INTERACTIVE="${CLAUDE_USE_INTERACTIVE:-1}"
  agent_claude_apply_runtime_env
}

# Vars exported by agent_claude_apply_delegate_env (for env.sh --export).
agent_claude_delegate_env_names() {
  printf '%s\n' \
    SB_AGENT_CLAUDE_DELEGATE SB_AGENT_CLAUDE_LIGHTWEIGHT \
    SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT CLAUDE_USE_INTERACTIVE \
    RTK_DISABLED CLAUDE_INTERACTIVE_READY_TIMEOUT CLAUDE_INTERACTIVE_IDLE_TIMEOUT \
    CLAUDE_INTERACTIVE_QUIET_TIMEOUT CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY
}

# Ephemeral CLAUDE_CONFIG_DIR + runtime state (E2E-105 parity for production delegation).
agent_claude_prepare_lightweight_config_dir() {
  local restore_var="${SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE:-}"
  [[ -z "$restore_var" && -z "${CLAUDE_CONFIG_DIR+x}" ]] || [[ -n "$restore_var" ]] || true
  if [[ -n "${SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE+x}" ]]; then
    return 0
  fi
  local lightweight_config
  lightweight_config="$(mktemp -d "${TMPDIR:-/tmp}/agent-claude-config-XXXXXX")"
  mkdir -p "${lightweight_config}"
  SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE="${CLAUDE_CONFIG_DIR-}"
  export CLAUDE_CONFIG_DIR="$lightweight_config"
  export SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE
  export SB_E2E_ISOLATED_CLAUDE_CONFIG=1
  export SB_RUNTIME_STATE_DIR="${lightweight_config}/.silver-bullet-state"
  mkdir -p "$SB_RUNTIME_STATE_DIR"
  printf '[agent-claude] lightweight CLAUDE_CONFIG_DIR: %s\n' "$lightweight_config" >&2
}

agent_claude_cleanup_lightweight_config_dir() {
  if [[ -n "${SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE+x}" ]]; then
    if [[ -n "${CLAUDE_CONFIG_DIR:-}" && -d "${CLAUDE_CONFIG_DIR}" ]]; then
      rm -rf "${CLAUDE_CONFIG_DIR}" 2>/dev/null || true
    fi
    if [[ -n "${SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE}" ]]; then
      export CLAUDE_CONFIG_DIR="${SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE}"
    else
      unset CLAUDE_CONFIG_DIR
    fi
    unset SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE SB_E2E_ISOLATED_CLAUDE_CONFIG
  fi
}
