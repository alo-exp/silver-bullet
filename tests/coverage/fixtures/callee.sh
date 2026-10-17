#!/usr/bin/env bash
# Same-word statements on one line separated by a function call, process
# substitution bodies, and a braced || group: every statement here runs.
set -uo pipefail
has() {
  [[ "$1" == x ]]
}
has x && has x
v=$(has x && printf '%s' y)
while read -r line; do
  : "$line"
done < <(printf '%s\n' a; printf '%s\n' b)
if ! { grep -q z <<<"$v" ||
  grep -q y <<<"$v"; }; then
  : unreachable-when-v-is-y
fi
