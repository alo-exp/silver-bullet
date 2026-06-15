# shellcheck shell=bash
# SB-initiated project gate — enforcement hooks exit 0 unless sb_initiated is true.
#
# Set only by silver:init (Wave 0.1). Prevents SB activation in arbitrary repos
# that happen to contain .silver-bullet.json without running init.

# Print absolute path to .silver-bullet.json when project boundary is satisfied.
sb_find_project_config() {
  local search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
      printf '%s' "$search_dir/.silver-bullet.json"
      return 0
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir=$(dirname "$search_dir")
  done
  return 1
}

# Print project root directory when boundary is satisfied.
sb_find_project_root() {
  local cfg
  cfg="$(sb_find_project_config 2>/dev/null || true)"
  [[ -n "$cfg" ]] || return 1
  dirname "$cfg"
}

# Returns 0 when SB enforcement should activate for this project.
# - sb_initiated: true  → initiated
# - sb_initiated: false or absent → not initiated (run /silver:init or /silver:migrate)
sb_project_is_initiated() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1

  if command -v jq >/dev/null 2>&1 && printf '{}' | jq . >/dev/null 2>&1; then
    local flag
    flag=$(jq -r 'if has("sb_initiated") then (.sb_initiated | tostring) else "absent" end' "$config_file" 2>/dev/null || echo "absent")
    case "$flag" in
      true) return 0 ;;
      false|absent) return 1 ;;
      *) return 1 ;;
    esac
  fi

  grep -qE '"sb_initiated"[[:space:]]*:[[:space:]]*true' "$config_file" 2>/dev/null
}

# Exit 0 (inert) when project is absent or not SB-initiated.
sb_project_gate_or_exit() {
  local config_file
  config_file="$(sb_find_project_config 2>/dev/null || true)"
  [[ -n "$config_file" ]] || exit 0
  sb_project_is_initiated "$config_file" || exit 0
}
