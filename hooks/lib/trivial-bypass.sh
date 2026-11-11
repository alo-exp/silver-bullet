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
  local trivial_path="${1:-${SB_RUNTIME_STATE_DIR}/trivial}" root
  if [[ -f "$trivial_path" && ! -L "$trivial_path" ]]; then
    if [[ "$trivial_path" == "${SB_RUNTIME_STATE_DIR}/trivial" ]] && declare -f sb_integrity_verify >/dev/null 2>&1; then
      root="$(sb_integrity_root "$PWD")"
      if [[ -n "$root" ]]; then
        sb_integrity_verify "$root" ""
        sb_integrity_restore_safe
        [[ "$SB_IV_TRIVIAL_OK" == true ]] || return 0
      fi
    fi
    exit 0
  fi
}
