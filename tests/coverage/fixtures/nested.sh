#!/usr/bin/env bash
# Command substitutions nested in loops, case arms and continuation lines:
# every statement here runs.
set -uo pipefail
lower() {
  local flow="$1"
  case "$flow" in
    *) printf 'silver-%s' "$(printf '%s' "$flow" | tr '[:upper:]' '[:lower:]')" ;;
  esac
}
join() {
  local line out="" tokens=(a '' b)
  for line in "${tokens[@]}"; do
    [[ -z "$line" ]] && continue
    line="$(echo "$line")"
    out="$out$line"
  done
  printf '%s' "$out"
}
held() {
  local held="$1"
  printf '%s' "$(printf '%s %s' \
    --held \
    "$([[ "$held" == true ]] && echo true || echo false)")"
}
drain() {
  local item
  while IFS= read -r item || [[ -n "$item" ]]; do
    : "$item"
  done < <(lower Feed)
}
both() {
  local name="$1"
  if [[ "$(lower "$name")" == "silver-x" \
     && "$(lower "$name")" == "silver-x" ]]; then
    : both
  fi
}
lower Shout >/dev/null
join >/dev/null
held true >/dev/null
held false >/dev/null
drain
both X
