# shellcheck shell=bash
# Shared SB project activation guard — enforcement stays inert until /silver:init
# sets sb_initiated: true in .silver-bullet.json.

_pa_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -f sb_find_project_config >/dev/null 2>&1; then
  # shellcheck source=sb-project-gate.sh
  source "$_pa_lib_dir/sb-project-gate.sh"
fi

# Returns 0 when config exists and sb_initiated is true.
sb_project_active() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1

  if command -v jq >/dev/null 2>&1 && printf '{}' | jq . >/dev/null 2>&1; then
    local flag
    # Test harness: legacy fixtures omit sb_initiated; honor explicit values in config.
    if [[ "${SILVER_BULLET_TEST_HOOK_ENFORCED:-}" == "1" ]] \
      && ! jq -e 'has("sb_initiated")' "$config_file" >/dev/null 2>&1; then
      return 0
    fi
    flag=$(jq -r 'if has("sb_initiated") then (.sb_initiated | tostring) else "absent" end' "$config_file" 2>/dev/null || echo "absent")
    case "$flag" in
      true) return 0 ;;
      false|absent) return 1 ;;
      *) return 1 ;;
    esac
  fi

  grep -qE '"sb_initiated"[[:space:]]*:[[:space:]]*true' "$config_file" 2>/dev/null
}

# Fail-open: exit 0 with no side effects when project is absent or not SB-initiated.
sb_project_active_or_exit() {
  local config_file
  config_file="$(sb_find_project_config 2>/dev/null || true)"
  [[ -n "$config_file" ]] || exit 0
  sb_project_active "$config_file" || exit 0
}

# Back-compat aliases (Wave 0.1 naming).
sb_project_is_initiated() {
  sb_project_active "$@"
}

sb_project_gate_or_exit() {
  sb_project_active_or_exit
}
