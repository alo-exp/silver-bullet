# Silver Bullet — canonical required-deploy skill list (reader-shim)
#
# Single source of truth: templates/silver-bullet.config.json.default
#   .skills.required_deploy        -> DEFAULT_REQUIRED
#   .skills.required_deploy_devops -> DEVOPS_DEFAULT_REQUIRED
#
# This file intentionally contains NO hardcoded skill literal. It discovers the
# default config alongside the plugin install and parses it with jq. If jq or
# the config file is missing, it falls back to a minimal safe list so hooks
# never fail-open silently — they enforce at least the quality-gate skills.
#
# Sourced by: stop-check.sh, completion-audit.sh, prompt-reminder.sh

__sb_rs_find_default_config() {
  # Candidate locations, in priority order:
  #   1. Env override (used by tests).
  #   2. Adjacent to this lib: ../../templates/silver-bullet.config.json.default
  #      (repo checkout or plugin install layout).
  #   3. Walk up from $PWD looking for .silver-bullet/config.json.default.
  if [ -n "${SB_DEFAULT_CONFIG:-}" ] && [ -f "${SB_DEFAULT_CONFIG}" ]; then
    printf '%s' "${SB_DEFAULT_CONFIG}"
    return 0
  fi
  local self_dir
  # shellcheck disable=SC2128
  self_dir="$(cd "$(dirname "${BASH_SOURCE:-$0}")" 2>/dev/null && pwd)"
  local candidate="${self_dir}/../../templates/silver-bullet.config.json.default"
  if [ -f "${candidate}" ]; then
    printf '%s' "${candidate}"
    return 0
  fi
  return 1
}

__sb_rs_load() {
  local field="$1"
  local cfg
  cfg="$(__sb_rs_find_default_config)" || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -r ".skills.${field} | .[]" "${cfg}" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
}

# Fallback used only when default config or jq unavailable. Keep minimal —
# hooks always enforce at least the planning/quality-gate floor.
__SB_RS_FALLBACK="silver-quality-gates verification-before-completion"

__sb_rs_populate() {
  local value
  value="$(__sb_rs_load required_deploy)"
  if [ -z "${value}" ]; then
    DEFAULT_REQUIRED="${__SB_RS_FALLBACK}"
  else
    DEFAULT_REQUIRED="${value}"
  fi
  value="$(__sb_rs_load required_deploy_devops)"
  if [ -z "${value}" ]; then
    DEVOPS_DEFAULT_REQUIRED="${__SB_RS_FALLBACK}"
  else
    DEVOPS_DEFAULT_REQUIRED="${value}"
  fi
}

__sb_rs_populate
