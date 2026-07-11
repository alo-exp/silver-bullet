#!/usr/bin/env bash
# Shared helpers for /silver:agent-pi harness scripts.
# shellcheck shell=bash

agent_pi_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

agent_pi_repo_root() {
  local script_dir
  script_dir="$(agent_pi_script_dir)"
  cd "${script_dir}/../.." && pwd
}

_agent_pi_source_common() {
  local script_dir repo_root common
  script_dir="$(agent_pi_script_dir)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
  common="${repo_root}/scripts/lib/agent-delegate-common.sh"
  # shellcheck source=scripts/lib/agent-delegate-common.sh
  [[ -f "$common" ]] && source "$common"
}

_agent_pi_source_cli() {
  local script_dir repo_root cli_lib
  script_dir="$(agent_pi_script_dir)"
  repo_root="$(cd "${script_dir}/../.." && pwd)"
  cli_lib="${repo_root}/scripts/lib/pi-cli.sh"
  # shellcheck source=scripts/lib/pi-cli.sh
  [[ -f "$cli_lib" ]] && source "$cli_lib"
}

agent_pi_apply_runtime_env() {
  _agent_pi_source_cli
  agent_pi_pin_mimo_model_env || return $?
  export RTK_DISABLED="${RTK_DISABLED:-1}"
  export PI_RUN_TIMEOUT="${PI_RUN_TIMEOUT:-900}"
  export PI_RUN_TAIL_IDLE_TIMEOUT="${PI_RUN_TAIL_IDLE_TIMEOUT:-45}"
}

agent_pi_apply_delegate_env() {
  _agent_pi_source_common
  agent_delegate_clear_matrix_env

  export SB_AGENT_PI_DELEGATE="${SB_AGENT_PI_DELEGATE:-1}"
  export SB_AGENT_PI_LIGHTWEIGHT="${SB_AGENT_PI_LIGHTWEIGHT:-1}"
  export SB_ORCHESTRATOR_WORKER="${SB_ORCHESTRATOR_WORKER:-1}"
  export SB_ORCHESTRATOR_PARENT="${SB_ORCHESTRATOR_PARENT:-0}"
  agent_pi_apply_runtime_env
}

agent_pi_delegate_env_names() {
  printf '%s\n' \
    SB_AGENT_PI_DELEGATE SB_AGENT_PI_LIGHTWEIGHT \
    SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT \
    PI_PROVIDER PI_MODEL RTK_DISABLED PI_RUN_TIMEOUT PI_RUN_TAIL_IDLE_TIMEOUT
}
