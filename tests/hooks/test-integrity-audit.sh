#!/usr/bin/env bash
# The protected-read audit: no gate reads a protected value outside the verified record (docs/PROTECTED-READS.md).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
export PYTHONDONTWRITEBYTECODE=1
AUDIT="$TL_REPO_ROOT/scripts/audit-protected-reads.py"
FX="$TL_REPO_ROOT/tests/fixtures/integrity-audit.json"

out="$(python3 "$AUDIT" --check "$FX" 2>&1)" && rc=0 || rc=$?
assert_eq "the tree reads protected values only through the record (no N, no unknown, no stale row)" "0" "$rc"
assert_eq "and says nothing" "" "$out"
assert_eq "the fixture has no N row" "0" "$(jq '[.rows[] | select(.record == "N")] | length' "$FX")"
assert_eq "the fixture counts agree with its rows" "$(jq '.rows | length' "$FX")" "$(jq '[.counts[]] | add' "$FX")"
assert_eq "the rows the previous head had are recorded" "52" "$(jq '.before.counts.N' "$FX")"
assert_eq "every X row says why" "0" "$(jq '[.rows[] | select(.record == "X" and (.reason | length) < 10)] | length' "$FX")"

# the table in the docs is the scanner's output
doc_rows="$(grep -c '^| [a-z].*:[0-9]* |' "$TL_REPO_ROOT/docs/PROTECTED-READS.md" || true)"
assert_eq "docs/PROTECTED-READS.md lists every row" "$(jq '.rows | length' "$FX")" "$doc_rows"
assert_eq "and is current" "" "$(python3 "$AUDIT" --markdown | diff - <(sed -n '/^| file:line/,$p' "$TL_REPO_ROOT/docs/PROTECTED-READS.md") || true)"

# the scanner itself: a planted live read is found, a verified one is not
T="$TL_TMP/tree"
mkdir -p "$T/hooks" "$T/scripts"
cp "$AUDIT" "$T/scripts/"
printf 'x=$(jq -r ".a" "$config_file")\n' >"$T/hooks/new-gate.sh"
printf 'y=$(sb_iv_jq -r ".a")\n' >"$T/hooks/ok-gate.sh"
planted="$(python3 "$T/scripts/audit-protected-reads.py" | grep -c '^N .*new-gate.sh' || true)"
assert_eq "a gate that reads the config live is an N row" "1" "$planted"
assert_eq "a gate that reads through the record is not" "0" "$(python3 "$T/scripts/audit-protected-reads.py" | grep -c 'ok-gate.sh' || true)"
out="$(python3 "$T/scripts/audit-protected-reads.py" --check "$FX" 2>&1)" && rc=0 || rc=$?
assert_eq "--check fails on it" "1" "$rc"
assert_contains "and names it" "$out" "new-gate.sh"

tl_results
