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
