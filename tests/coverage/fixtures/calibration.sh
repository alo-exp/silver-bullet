#!/usr/bin/env bash
# Calibration fixture for tests/coverage/test-sbcov.sh. Each construct below is
# one bash reports oddly under xtrace. Run with "hit" to take the main paths;
# statements on lines marked "MISS:" must be reported as not run.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/helper.sh
source "$here/lib/helper.sh"
mode="${1:-hit}"
echo "multi" \
  "line" \
  "continuation" >/dev/null
if [[ "$mode" == hit ]] &&
   [[ "$mode" != miss ]]; then
  : taken
else
  echo "MISS: else arm" >/dev/null
fi
x=$(
  echo inner1
)
y="$(printf '%s' \
  "z")"
for i in 1 2; do
  : "$i"
done
case "$mode" in
  hit) : one ;;
  never)
    echo "MISS: case arm" >/dev/null
    ;;
esac
cat >/dev/null <<EOT
heredoc ${x} ${y}
EOT
(( n = 1 ))
arr=(
  one
  two
)
declare -A m=(
  [k]=v
)
while read -r line; do
  : "$line"
done <<< "l1"
{ : grp; } >/dev/null
( : sub )
true || echo "MISS: or-fallback" >/dev/null
false || : or-taken
helper_used "${arr[0]}" "${m[k]}" "$n"
unused_fn() {
  echo "MISS: function body" >/dev/null
}
jq -n \
  --arg a b \
  '{a:$a}' >/dev/null
out=$(jq -n '
  {a: 1}
' | cat)
: "$out"
