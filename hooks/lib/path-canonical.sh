# shellcheck shell=bash
# Normalize filesystem paths for stable comparisons (macOS /var vs /private/var).

sb_canonical_path() {
  local path="$1"
  [[ -n "$path" ]] || return 0
  python3 -c 'import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))' "$path" 2>/dev/null || printf '%s' "$path"
}
