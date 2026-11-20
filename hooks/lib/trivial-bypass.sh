# shellcheck shell=bash
# Silver Bullet — trivial-session bypass guard (single source of truth)
# Sourced by: stop-check.sh, ci-status-check.sh and the other Stop/delivery gates.
# If the trivial file exists (real file, not symlink), the session is trivial — caller should exit 0.
# The default marker (${SB_RUNTIME_STATE_DIR}/trivial) counts only while the integrity record blesses
# it (hooks/lib/integrity.sh): a marker nobody blessed is removed, whoever created it and however.

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi
if [[ -f "$_sb_runtime_paths_dir/integrity.sh" ]]; then
  # shellcheck source=lib/integrity.sh
  source "$_sb_runtime_paths_dir/integrity.sh"
fi

sb_trivial_bypass() {
  local trivial_path="${1:-${SB_RUNTIME_STATE_DIR}/trivial}" root="" verified=false
  if declare -f sb_integrity_verify >/dev/null 2>&1; then
    root="$(sb_integrity_root "$PWD")"
    if [[ -n "$root" ]]; then
      sb_integrity_verify "$root" ""
      # Once the project has a record (or is unbaselined) the marker is the default one and only while the
      # record blesses it: a path handed in (the config's) is ignored.
      if [[ "$SB_IV_STATUS" != none ]]; then
        trivial_path="${SB_RUNTIME_STATE_DIR}/trivial"
        verified=true
      fi
    fi
  fi
  if [[ -f "$trivial_path" && ! -L "$trivial_path" ]]; then
    if [[ "$verified" == true ]]; then
      sb_integrity_restore_safe
      [[ "$SB_IV_TRIVIAL_OK" == true ]] || return 0
    fi
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
