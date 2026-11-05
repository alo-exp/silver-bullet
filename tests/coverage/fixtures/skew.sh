#!/usr/bin/env bash
# Records bash reports at another statement's line, and same-word statements
# that run in different processes. Every statement here runs across the modes.
set -uo pipefail
build() {
  local json
  json="$(jq -nc \
    --argjson a "$1" \
    '{
      a: $a,
      b: 1,
      c: 2,
      d: 3
    }' 2>/dev/null || true)"
  [[ -n "$json" ]] || return 1
  printf '%s\n' "$json"
}
clear_it() {
  local x=1
  : "$x"
  rm -- "$1" 2>/dev/null || true
}
field() {
  local json="$1" default="$2"
  case "$3" in
    ev) grep -q 'PreToolUse' <<<"$json" && printf 'PreToolUse' || printf '%s' "$default" ;;
    tn) printf '%s' "$json" | grep -oE '"tool_name"[^,]*' | sed -E 's/.*"([^"]+)"$/\1/' || printf '%s' "$default" ;;
  esac
}
case "$1" in
  build) build "$2" >/dev/null || : failed ;;
  clear) clear_it "${TMPDIR:-/tmp}/sbcov-skew-none" ;;
  field) field "$2" dflt "$3" >/dev/null ;;
esac
