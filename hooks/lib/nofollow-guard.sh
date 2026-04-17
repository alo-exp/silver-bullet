# shellcheck shell=bash
# Silver Bullet — refuse writes that would traverse a symlink (SEC-02).
# Sourced by every hook that creates, replaces, or appends to a state file
# under ~/.claude/.silver-bullet/.
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
