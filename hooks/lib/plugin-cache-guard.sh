# shellcheck shell=bash
# Allow deliberate third-party plugin uninstall cache cleanup when the host
# registry no longer references the target path (GitHub issue #222).

sb_plugin_cache_registry_file() {
  printf '%s/plugins/installed_plugins.json' "${SB_RUNTIME_HOME_ROOT}"
}

# Print installPath values from installed_plugins.json (one per line).
sb_plugin_cache_installed_paths() {
  local registry
  registry="$(sb_plugin_cache_registry_file)"
  [[ -f "$registry" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 1
  jq -r '
    .plugins // {} | to_entries[] | .value[]? | .installPath // empty
  ' "$registry" 2>/dev/null
}

# True when no installed plugin still references this cache path (uninstall cleanup).
sb_plugin_cache_path_is_uninstalled() {
  local target="$1"
  local cache_root="${2:-${SB_RUNTIME_PLUGIN_CACHE_ROOT}}"
  local install_path normalized_install
  local target_canon cache_canon install_canon

  [[ -n "$target" && -n "$cache_root" ]] || return 1
  [[ -f "$(sb_plugin_cache_registry_file)" ]] || return 1
  cache_root="${cache_root%/}"
  target_canon="$(sb_canonical_path "$target")"
  cache_canon="$(sb_canonical_path "$cache_root")"

  case "$target_canon" in
    "$cache_canon"|"$cache_canon"/*) ;;
    *) return 1 ;;
  esac

  while IFS= read -r install_path; do
    [[ -n "$install_path" ]] || continue
    normalized_install="${install_path/#\~/$HOME}"
    normalized_install="${normalized_install//\/\//\/}"
    install_canon="$(sb_canonical_path "$normalized_install")"
    case "$install_canon" in
      "$target_canon"|"$target_canon"/*)
        return 1
        ;;
      "$cache_canon"|"$cache_canon"/*)
        case "$target_canon" in
          "$install_canon"|"$install_canon"/*)
            return 1
            ;;
        esac
        ;;
    esac
  done < <(sb_plugin_cache_installed_paths 2>/dev/null || true)

  return 0
}

# True when the command is deliberate plugin-cache uninstall cleanup (#222).
# Only deletion-style writes qualify; cp/mv/install/tee/sed-in-place remain blocked.
sb_plugin_cache_command_is_uninstall_cleanup() {
  local command_str="$1"
  shift
  local cache_root="${SB_RUNTIME_PLUGIN_CACHE_ROOT}"
  local cache_root_canon
  [[ -n "$command_str" && -n "$cache_root" ]] || return 1

  cache_root_canon="$(sb_canonical_path "$cache_root")"
  if ! { printf '%s' "$command_str" | grep -qF "$cache_root" || \
        printf '%s' "$command_str" | grep -qF "$cache_root_canon"; }; then
    return 1
  fi

  if ! printf '%s' "$command_str" | grep -qE '\b(rm|rmdir)\b'; then
    return 1
  fi

  declare -f sb_plugin_cache_writes_are_uninstall_cleanup >/dev/null 2>&1 || return 1
  sb_plugin_cache_writes_are_uninstall_cleanup "$@"
}

# True when every write target under the plugin cache is uninstall cleanup.
sb_plugin_cache_writes_are_uninstall_cleanup() {
  local cache_root="${SB_RUNTIME_PLUGIN_CACHE_ROOT}"
  local target_path target_canon cache_canon
  local saw_cache_target=false

  [[ -n "$cache_root" ]] || return 1
  [[ -f "$(sb_plugin_cache_registry_file)" ]] || return 1
  cache_canon="$(sb_canonical_path "$cache_root")"

  for target_path in "$@"; do
    [[ -n "$target_path" ]] || continue
    target_canon="$(sb_canonical_path "$target_path")"
    case "$target_canon" in
      "$cache_canon"|"$cache_canon"/*) ;;
      *) continue ;;
    esac
    saw_cache_target=true
    if ! sb_plugin_cache_path_is_uninstalled "$target_path" "$cache_root"; then
      return 1
    fi
  done

  [[ "$saw_cache_target" == true ]]
}
