# shellcheck shell=bash
# Silver Bullet — refuse writes that would traverse a symlink (SEC-02).
# Sourced by every hook that creates, replaces, or appends to a state file
# under the active host runtime state directory.
#
# Load runtime-specific paths so hooks can choose the correct host root.

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi
#
# Usage:
#   source "${_lib_dir}/nofollow-guard.sh"
#   sb_guard_nofollow "$path"   # exit 1 if $path is a symlink
#   sb_safe_write    "$path"    # unlink if $path is a symlink; caller writes normally

sb_guard_nofollow() {
  local path="$1"
  if [[ -L "$path" ]]; then
    printf 'ERROR: refusing to write through symlink: %s\n' "$path" >&2
    exit 1
  fi
}

sb_safe_write() {
  local path="$1"
  if [[ -L "$path" ]]; then
    rm -f -- "$path"
  fi
}

# sb_atomic_write_file TARGET < content
# Replace TARGET with the content on stdin: a temp file in TARGET's own directory (never a
# predictable name), the original mode kept, then a rename. Returns 1, writing nothing, when TARGET
# is a symlink or the temp file cannot be made. Callers decide whether that is fatal; it never exits.
sb_atomic_write_file() {
  local target="${1:-}" dir tmp mode=""
  [[ -n "$target" && ! -L "$target" ]] || return 1
  dir="$(dirname "$target")"
  tmp="$(mktemp "${dir}/.sb-write.XXXXXX" 2>/dev/null)" || return 1
  if ! cat >"$tmp" 2>/dev/null; then
    rm -f -- "$tmp"
    return 1
  fi
  mode="$(stat -c %a "$target" 2>/dev/null || stat -f %Lp "$target" 2>/dev/null || true)"
  # A new file gets 644 (mktemp makes 600): these are project files, not private state.
  chmod "${mode:-644}" "$tmp"
  if ! mv -f -- "$tmp" "$target" 2>/dev/null; then
    rm -f -- "$tmp"
    return 1
  fi
  return 0
}
