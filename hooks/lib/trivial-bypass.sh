# shellcheck shell=bash
# Silver Bullet — trivial-session bypass guard (single source of truth)
# Sourced by: stop-check.sh, ci-status-check.sh
# If the trivial file exists (real file, not symlink), the session is trivial — caller should exit 0.

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi

sb_trivial_bypass() {
  local trivial_path="${1:-${SB_RUNTIME_STATE_DIR}/trivial}"
  if [[ -f "$trivial_path" && ! -L "$trivial_path" ]]; then
    exit 0
  fi
}

# sb_expand_state_config_path PATH: expand ~ and ${SB_RUNTIME_HOME_ROOT} the way the shipped config
# template spells its state paths (R1-32c), so a template-stamped config resolves to the host defaults.
sb_expand_state_config_path() {
  local path="${1:-}" root="${SB_RUNTIME_HOME_ROOT:-}"
  if [[ -n "$root" ]]; then
    path="${path//\$\{SB_RUNTIME_HOME_ROOT\}/$root}"
    path="${path//\$SB_RUNTIME_HOME_ROOT/$root}"
  fi
  printf '%s' "${path/#\~/$HOME}"
}

# sb_trivial_path_trusted PATH DEFAULT: PATH may stand for the trivial bypass file. A project config
# can name state.trivial_file, but pointing it at any other existing file (a runtime marker, /etc/hostname)
# would switch the delivery gates off for good (R3-02), so only the state directory's own `trivial` file
# (the default, or a state-scoped path whose name is `trivial`) is accepted.
sb_trivial_path_trusted() {
  local path="${1:-}" default="${2:-}"
  [[ -n "$path" && "$path" == "$default" ]] && return 0
  [[ "${path##*/}" == "trivial" ]] && sb_runtime_path_is_state_scoped "$path"
}
