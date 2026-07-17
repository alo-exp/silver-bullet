#!/usr/bin/env bash
# Shared helpers for /silver:agent-opencode harness scripts.
# shellcheck shell=bash

agent_opencode_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

agent_opencode_repo_root() {
  local script_dir
  script_dir="$(agent_opencode_script_dir)"
  cd "${script_dir}/../.." && pwd
}

_agent_opencode_source_common() {
  local script_dir repo_root common
  script_dir="$(agent_opencode_script_dir)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
  common="${repo_root}/scripts/lib/agent-delegate-common.sh"
  # shellcheck source=scripts/lib/agent-delegate-common.sh
  [[ -f "$common" ]] && source "$common"
}

_agent_opencode_source_cli() {
  local script_dir repo_root cli_lib
  script_dir="$(agent_opencode_script_dir)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
  cli_lib="${repo_root}/scripts/lib/opencode-cli.sh"
  # shellcheck source=scripts/lib/opencode-cli.sh
  [[ -f "$cli_lib" ]] && source "$cli_lib"
}

agent_opencode_apply_runtime_env() {
  _agent_opencode_source_cli
  agent_opencode_enforce_invoke_model_policy "${SB_ROOT:-$(agent_opencode_repo_root)}" || return $?
  export RTK_DISABLED="${RTK_DISABLED:-1}"
  export OPENCODE_RUN_TIMEOUT="${OPENCODE_RUN_TIMEOUT:-900}"
  export OPENCODE_RUN_TAIL_IDLE_TIMEOUT="${OPENCODE_RUN_TAIL_IDLE_TIMEOUT:-45}"
}

agent_opencode_apply_delegate_env() {
  _agent_opencode_source_common
  agent_delegate_clear_matrix_env

  export SB_AGENT_OPENCODE_DELEGATE="${SB_AGENT_OPENCODE_DELEGATE:-1}"
  export SB_AGENT_OPENCODE_LIGHTWEIGHT="${SB_AGENT_OPENCODE_LIGHTWEIGHT:-1}"
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
  unset SB_AGENT_OPENCODE_DELEGATION_MODE SB_MULTI_AI_OCG_PROFILE SB_MULTI_AI_OCG_POOL SB_MULTI_AI_OCG_VALIDATED
  agent_opencode_apply_runtime_env
}

agent_opencode_delegate_env_names() {
  printf '%s\n' \
    SB_AGENT_OPENCODE_DELEGATE SB_AGENT_OPENCODE_LIGHTWEIGHT \
    SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT \
    OPENCODE_MODEL OPENCODE_MODEL_PROVIDER OPENCODE_RUN_MODEL \
    RTK_DISABLED OPENCODE_RUN_TIMEOUT OPENCODE_RUN_TAIL_IDLE_TIMEOUT
}

