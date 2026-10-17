#!/usr/bin/env bash
# Process substitutions inside functions. bash traces their commands at the
# line of the last function definition it parsed, not their own line.
set -uo pipefail
emit() { printf '%s\n' "$@"; }
broken() { return 1; }
collect() {
  local item out=""
  while IFS= read -r item; do
    out+="$item"
  done < <(emit a b 2>/dev/null || true)
  while IFS= read -r item; do
    out+="$item"
  done < <(broken 2>/dev/null || true)
  helper() {
    :
  }
  printf '%s' "$out"
}
skipped() {
  local item
  while IFS= read -r item; do
    : "$item"
  done < <(emit never || true)
}
collect >/dev/null
