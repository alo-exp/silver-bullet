#!/usr/bin/env bash
# P0-4: Post-execution ordering and atomic table rows must match across
# silver-bullet.md, templates/silver-bullet.md.base, and composable-flows-contracts.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT_RULES="${REPO_ROOT}/silver-bullet.md"
TEMPLATE="${REPO_ROOT}/templates/silver-bullet.md.base"
CONTRACTS="${REPO_ROOT}/docs/composable-flows-contracts.md"
PASS=0
FAIL=0

extract_post_exec_block() {
  local file="$1"
  awk '
    /^\*\*Post-execution sequencing \(after FLOW 8\):\*\*/ { capture=1; next }
    capture && /^[0-9]+\./ { print }
    capture && /^$/ { exit }
    capture && /^[^0-9]/ && !/^   / { exit }
  ' "$file" | sed 's/^[[:space:]]*//'
}

assert_grep_all() {
  local desc="$1" pattern="$2"
  local ok=1
  for f in "$ROOT_RULES" "$TEMPLATE" "$CONTRACTS"; do
    if ! grep -qE "$pattern" "$f"; then
      echo "FAIL: $desc — missing in ${f#$REPO_ROOT/}"
      FAIL=$((FAIL + 1))
      ok=0
    fi
  done
  if [[ $ok -eq 1 ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

root_block="$(extract_post_exec_block "$ROOT_RULES")"
template_block="$(extract_post_exec_block "$TEMPLATE")"
contracts_block="$(awk '
  /^## Post-execution sequencing/ { capture=1; next }
  capture && /^[0-9]+\./ { print }
  capture && /^$/ { exit }
  capture && /^## / { exit }
' "$CONTRACTS" | sed 's/^[[:space:]]*//')"

if [[ "$root_block" == "$template_block" ]]; then
  echo "PASS: silver-bullet.md and template post-exec ordering match"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-bullet.md and template post-exec ordering differ"
  FAIL=$((FAIL + 1))
fi

# Contracts use the same numbered list text (FLOW 9 … FLOW 14) — compare line-by-line after normalizing FLOW refs.
normalize_post_line() {
  printf '%s' "$1" | sed -E 's/FLOW [0-9]+ \([^)]*\)/FLOW/g'
}

root_norm="$(while IFS= read -r l; do normalize_post_line "$l"; done <<< "$root_block")"
contracts_norm="$(while IFS= read -r l; do normalize_post_line "$l"; done <<< "$contracts_block")"

if [[ "$root_norm" == "$contracts_norm" ]]; then
  echo "PASS: silver-bullet.md and contracts post-exec ordering match"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-bullet.md and contracts post-exec ordering differ"
  FAIL=$((FAIL + 1))
fi

assert_grep_all "FLOW 3 CLARIFY in atomic tables" 'FLOW 3[[:space:]]*\| CLARIFY|FLOW 3 \| CLARIFY'
assert_grep_all "FLOW 18 RELEASE in atomic tables" 'FLOW 18[[:space:]]*\| RELEASE|FLOW 18 \| RELEASE'

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
