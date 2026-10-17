#!/usr/bin/env bash
# Freshness check for docs/HOOKS.md, which scripts/generate-hook-reference.py
# generates from hooks/hooks.json. Fails when the file is stale, when a
# registered hook has no purpose entry, or when the generator describes a
# hook file that no longer exists.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

if output="$(python3 "$REPO_ROOT/scripts/generate-hook-reference.py" --check 2>&1)"; then
  pass "docs/HOOKS.md matches hooks/hooks.json"
else
  fail "docs/HOOKS.md is stale or the generator found a problem"
  printf '%s\n' "$output" | sed 's/^/  /'
fi

# shellcheck disable=SC2016  # literal backticks, not command substitution
banner='> Generated from `hooks/hooks.json`'
if grep -qF "$banner" "$REPO_ROOT/docs/HOOKS.md"; then
  pass "docs/HOOKS.md carries the generated-file banner"
else
  fail "docs/HOOKS.md is missing the generated-file banner"
fi

registered="$(jq '[.hooks[][] .hooks[]] | length' "$REPO_ROOT/hooks/hooks.json")"
if grep -q "registers \*\*${registered} hook commands\*\*" "$REPO_ROOT/docs/HOOKS.md"; then
  pass "docs/HOOKS.md states the current registration count (${registered})"
else
  fail "docs/HOOKS.md does not state ${registered} hook commands"
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
