# shellcheck shell=bash
# SB project boundary gate — discover .silver-bullet.json at project root.
#
# Enforcement hooks stay inert until both .silver-bullet.json and silver-bullet.md
# are present (project boundary). Activation is file-presence based via project-active.sh.

_gate_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_gate_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=runtime-paths.sh
  source "$_gate_lib_dir/runtime-paths.sh"
fi

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

# Walk upward from start_dir only — no project-root cache fallback.
# Use for deny/guard decisions so stale cache cannot affect non-SB workspaces.
_sb_find_project_config_walk_from() {
  local search_dir="${1:-$PWD}"
  local root=""

  if [[ -n "${SILVER_BULLET_PROJECT_ROOT:-}" ]]; then
    root="${SILVER_BULLET_PROJECT_ROOT%/}"
    if [[ -f "$root/.silver-bullet.json" && -f "$root/silver-bullet.md" ]]; then
      printf '%s/.silver-bullet.json' "$root"
      return 0
    fi
  fi

  while [[ -n "$search_dir" ]]; do
    if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
      printf '%s/.silver-bullet.json' "$search_dir"
      return 0
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done

  return 1
}

sb_find_project_config_walk_only_from() {
  _sb_find_project_config_walk_from "$@"
}

sb_find_project_config_walk_only() {
  sb_find_project_config_walk_only_from "$PWD"
}

sb_find_project_root_walk_only() {
  local cfg
  cfg="$(sb_find_project_config_walk_only 2>/dev/null || true)"
  [[ -n "$cfg" ]] || return 1
  dirname "$cfg"
}

# Walk upward from start_dir; print .silver-bullet.json when boundary is satisfied.
sb_find_project_config_from() {
  local search_dir="${1:-$PWD}"
  local cfg root

  cfg="$(_sb_find_project_config_walk_from "$search_dir" 2>/dev/null || true)"
  if [[ -n "$cfg" ]]; then
    sb_project_root_cache_write "$(dirname "$cfg")"
    printf '%s' "$cfg"
    return 0
  fi

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

_pa_lib="$(dirname "${BASH_SOURCE[0]}")/project-active.sh"
if [[ -f "$_pa_lib" ]] && ! declare -f sb_project_active >/dev/null 2>&1; then
  # shellcheck source=project-active.sh
  source "$_pa_lib"
fi
