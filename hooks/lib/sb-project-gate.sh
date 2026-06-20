# shellcheck shell=bash
# SB-initiated project gate — enforcement hooks exit 0 unless sb_initiated is true.
#
# Set only by silver:init (Wave 0.1). Prevents SB activation in arbitrary repos
# that happen to contain .silver-bullet.json without running init.

SB_PROJECT_ROOT_CACHE_FILE="${SB_RUNTIME_STATE_DIR}/project-root"

# Persist a validated project root for CWD-independent hook resolution (#232).
sb_project_root_cache_write() {
  local root="${1%/}"
  [[ -n "$root" ]] || return 1
  [[ -f "$root/.silver-bullet.json" && -f "$root/silver-bullet.md" ]] || return 1
  [[ -n "${SB_RUNTIME_STATE_DIR:-}" ]] || return 0
  mkdir -p "${SB_RUNTIME_STATE_DIR}" 2>/dev/null || true
  local tmp="${SB_PROJECT_ROOT_CACHE_FILE}.$$"
  if printf '%s\n' "$root" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$SB_PROJECT_ROOT_CACHE_FILE" 2>/dev/null || rm -f -- "$tmp"
  fi
}

# Return cached project root when still valid.
sb_project_root_cache_read() {
  local cached=""
  [[ -f "$SB_PROJECT_ROOT_CACHE_FILE" ]] || return 1
  cached="$(sed -n '1p' "$SB_PROJECT_ROOT_CACHE_FILE" 2>/dev/null || true)"
  [[ -n "$cached" && -f "$cached/.silver-bullet.json" && -f "$cached/silver-bullet.md" ]] || return 1
  printf '%s' "$cached"
}

# Walk upward from start_dir; print .silver-bullet.json when boundary is satisfied.
sb_find_project_config_from() {
  local search_dir="${1:-$PWD}"
  local root=""

  if [[ -n "${SILVER_BULLET_PROJECT_ROOT:-}" ]]; then
    root="${SILVER_BULLET_PROJECT_ROOT%/}"
    if [[ -f "$root/.silver-bullet.json" && -f "$root/silver-bullet.md" ]]; then
      sb_project_root_cache_write "$root"
      printf '%s/.silver-bullet.json' "$root"
      return 0
    fi
  fi

  while [[ -n "$search_dir" ]]; do
    if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
      sb_project_root_cache_write "$search_dir"
      printf '%s/.silver-bullet.json' "$search_dir"
      return 0
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done

  root="$(sb_project_root_cache_read 2>/dev/null || true)"
  if [[ -n "$root" ]]; then
    printf '%s/.silver-bullet.json' "$root"
    return 0
  fi

  return 1
}

# Print absolute path to .silver-bullet.json when project boundary is satisfied.
sb_find_project_config() {
  sb_find_project_config_from "$PWD"
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
