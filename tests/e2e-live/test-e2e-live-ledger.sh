#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# These helpers are expected to exist once the inline full-surface live suite
# is implemented. Until then this test should fail loudly.
source "${SCRIPT_DIR}/lib/coverage-ledger.sh"

LEDGER_FILE="$(mktemp)"
trap 'rm -f "$LEDGER_FILE"' EXIT

init_coverage_ledger "$LEDGER_FILE"
ledger_append "$LEDGER_FILE" "sb:init" "scaffold created" "no" "init-files.json"
ledger_append "$LEDGER_FILE" "sb:feature" "clear-completed shipped" "no" "feature-diff"
ledger_append "$LEDGER_FILE" "sb:quality-gates" "pre-ship sweep passed" "no" "gate-log"
ledger_require_all "$LEDGER_FILE" "sb:init" "sb:feature" "sb:quality-gates"

tmp_missing="$(mktemp)"
trap 'rm -f "$LEDGER_FILE" "$tmp_missing"' EXIT
cp "$LEDGER_FILE" "$tmp_missing"
sed -i.bak '/^## sb:feature$/,/^$/d' "$tmp_missing"
rm -f "$tmp_missing.bak"

if ledger_require_all "$tmp_missing" "sb:init" "sb:feature" "sb:quality-gates"; then
  echo "FAIL: ledger_require_all should reject missing required surfaces"
  exit 1
fi

echo "PASS: coverage ledger helpers behave as expected"
