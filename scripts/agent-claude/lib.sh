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
  if [[ "${SB_AGENT_CERT_RUN:-}" == "1" || "${SB_AGENT_CERT_RUN:-}" == "true" ]]; then
    export SB_AGENT_CERT_RUN=1
  fi
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

# Seed hasTrustDialogAccepted for work_dir so Quick safety check does not EOF
# before prompt submission. Claude reads project trust from ~/.claude.json;
# ephemeral CLAUDE_CONFIG_DIR/.claude.json is mirrored for isolated parity.
agent_claude_seed_folder_trust() {
  local work_dir="${1:-${CLAUDE_WORK_DIR:-${WORK_DIR:-}}}"
  local config_dir="${2:-${CLAUDE_CONFIG_DIR:-}}"
  [[ -n "$work_dir" ]] || return 0
  [[ "${SB_AGENT_CLAUDE_SEED_FOLDER_TRUST:-1}" == "1" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  _agent_claude_seed_folder_trust_json() {
    local json_path="$1"
    local target_dir="$2"
    [[ -n "$json_path" && -n "$target_dir" ]] || return 0
    mkdir -p "$(dirname "$json_path")"
    python3 - "$json_path" "$target_dir" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
raw = pathlib.Path(sys.argv[2])
resolved = raw.resolve()
paths = []
for candidate in (raw, resolved):
    text = str(candidate)
    if text not in paths:
        paths.append(text)

data = {}
if path.is_file():
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        data = {}

projects = data.setdefault("projects", {})
for project_path in paths:
    entry = projects.setdefault(project_path, {})
    entry["hasTrustDialogAccepted"] = True

path.write_text(json.dumps(data, indent=2) + "\n")
PY
    printf '[agent-claude] seeded folder trust for %s in %s\n' "$target_dir" "$json_path" >&2
  }

  if [[ -n "$config_dir" ]]; then
    _agent_claude_seed_folder_trust_json "${config_dir}/.claude.json" "$work_dir"
  fi
  if [[ "${SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL:-1}" == "1" && -n "${HOME:-}" ]]; then
    _agent_claude_seed_folder_trust_json "${HOME}/.codex.json" "$work_dir"
  fi
}

# Ephemeral CLAUDE_CONFIG_DIR + runtime state (E2E-105 parity for production delegation).
agent_claude_prepare_lightweight_config_dir() {
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
  agent_claude_seed_folder_trust "${CLAUDE_WORK_DIR:-${WORK_DIR:-}}" "$lightweight_config"
  agent_claude_seed_lightweight_settings "$lightweight_config"
  printf '[agent-claude] lightweight CLAUDE_CONFIG_DIR: %s\n' "$lightweight_config" >&2
}

# Copy global Claude settings into ephemeral config, stripping broken user hook refs.
agent_claude_seed_lightweight_settings() {
  local config_dir="${1:-${CLAUDE_CONFIG_DIR:-}}"
  local global_settings="${HOME}/.codex/settings.json"
  local dest_settings="${config_dir}/settings.json"
  [[ -n "$config_dir" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "$global_settings" "$dest_settings" <<'PY'
import json
import os
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1])
dest = pathlib.Path(sys.argv[2])
dest.parent.mkdir(parents=True, exist_ok=True)

doc = {}
if src.is_file():
    try:
        doc = json.loads(src.read_text())
    except json.JSONDecodeError:
        doc = {}

hook_re = re.compile(r'gsd-session-state|gsd-[a-z-]+\.sh', re.I)


def hook_command_broken(cmd):
    if not isinstance(cmd, str):
        return False
    if hook_re.search(cmd):
        return True
    m = re.search(r'(["\'])([^"\']+\.(?:sh|js|mjs))\1', cmd)
    if m:
        p = os.path.expanduser(m.group(2))
        if not os.path.isfile(p):
            return True
    return False


def filter_hooks(hooks):
    if not isinstance(hooks, list):
        return hooks
    kept = []
    for entry in hooks:
        if not isinstance(entry, dict):
            kept.append(entry)
            continue
        inner = entry.get("hooks") or []
        new_inner = [h for h in inner if not hook_command_broken((h or {}).get("command", ""))]
        if new_inner:
            entry = dict(entry)
            entry["hooks"] = new_inner
            kept.append(entry)
    return kept

hooks = doc.get("hooks")
if isinstance(hooks, dict):
    for event, groups in list(hooks.items()):
        if isinstance(groups, list):
            hooks[event] = filter_hooks(groups)

cert = os.environ.get("SB_AGENT_CERT_RUN", "")
if cert in ("1", "true"):
    doc.setdefault("env", {})["SB_AGENT_CERT_RUN"] = "1"

dest.write_text(json.dumps(doc, indent=2) + "\n")
PY
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

# Ensure Claude plugin cache current alias + hooks exist before delegation.
agent_claude_ensure_plugin_cache() {
  local repo_root="${1:-${SB_ROOT:-$(agent_claude_repo_root)}}"
  local plugin_lib="${repo_root}/scripts/lib/plugin-cache-version.sh"
  [[ -f "$plugin_lib" ]] || {
    printf 'WARN: plugin-cache-version helper missing — run install-claude.sh\n' >&2
    return 1
  }
  # shellcheck source=scripts/lib/plugin-cache-version.sh
  source "$plugin_lib"
  if sb_claude_ensure_plugin_cache_ready "$repo_root"; then
    printf 'OK: Claude plugin cache ready (current alias + hooks)\n' >&2
    return 0
  fi
  printf 'ERROR: Claude plugin cache not ready — run bash scripts/install-claude.sh\n' >&2
  return 1
}
