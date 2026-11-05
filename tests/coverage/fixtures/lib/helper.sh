# shellcheck shell=bash
# Library sourced by calibration.sh.
helper_used() {
  local first="$1"
  [[ -n "$first" ]] || return 1
  printf '%s\n' "$@" >/dev/null
}
helper_unused() {
  echo "MISS: helper_unused" >/dev/null
}
