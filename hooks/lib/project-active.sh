# shellcheck shell=bash
# Shared SB project activation guard — enforcement activates when the project
# config (.silver-bullet.json) is discovered at the project root.

_pa_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -f sb_find_project_config >/dev/null 2>&1; then
  # shellcheck source=sb-project-gate.sh
  source "$_pa_lib_dir/sb-project-gate.sh"
fi

# Returns 0 when the project config file exists.
sb_project_active() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
}

# Fail-open: exit 0 when no project config; proceed when config is present.
sb_project_active_or_exit() {
  local config_file
  config_file="$(sb_find_project_config 2>/dev/null || true)"
  [[ -n "$config_file" ]] || exit 0
  sb_project_active "$config_file" || exit 0
}

# True when .silver-bullet.json exists and sb_initiated is explicitly true.
sb_config_marked_initiated() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  [[ "$(jq -r '.sb_initiated // false' "$config_file" 2>/dev/null || echo false)" == "true" ]]
}

# Back-compat aliases (Wave 0.1 naming).
sb_project_is_initiated() {
  sb_project_active "$@"
}

sb_project_gate_or_exit() {
  sb_project_active_or_exit
}
