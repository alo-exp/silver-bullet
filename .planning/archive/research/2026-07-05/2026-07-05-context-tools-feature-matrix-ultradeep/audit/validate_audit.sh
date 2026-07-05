#!/usr/bin/env bash
# Validate audit artifacts: HTML exists, all matrix ✓ cells have href links
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
MD="$DIR/feature-coverage-matrix.html"
HTML="$DIR/feature-coverage-matrix.html"
MATRIX="$DIR/feature-coverage-matrix.md"
EVIDENCE="$DIR/audit/audit-evidence.jsonl"
REPORT="$DIR/audit/audit-report.md"

errors=0
[[ -f "$HTML" ]] || { echo "FAIL: HTML missing"; errors=$((errors+1)); }
[[ -f "$MATRIX" ]] || { echo "FAIL: matrix MD missing"; errors=$((errors+1)); }
[[ -f "$EVIDENCE" ]] || { echo "FAIL: audit-evidence.jsonl missing"; errors=$((errors+1)); }
[[ -f "$REPORT" ]] || { echo "FAIL: audit-report.md missing"; errors=$((errors+1)); }

# Extract table body rows only (between first ### and ---)
TABLE=$(awk '/^### /,/^---$/' "$MATRIX" | grep '^| ' | grep -v '| Feature |' | grep -v '^|---' || true)
# Count ✓ cells without markdown links in table rows
UNLINKED=$(echo "$TABLE" | python3 -c "
import sys, re
unlinked = 0
total_ticks = 0
for line in sys.stdin:
    parts = [p.strip() for p in line.split('|')[1:-1]]
    for cell in parts[1:]:
        if '✓' in cell and not re.search(r'\[✓[^\]]*\]\(https?://', cell):
            unlinked += 1
            print('UNLINKED:', cell[:60])
        if '✓' in cell:
            total_ticks += 1
print(f'STATS: total_ticks={total_ticks} unlinked={unlinked}')
sys.exit(1 if unlinked else 0)
" 2>&1) || true

echo "$UNLINKED"
if echo "$UNLINKED" | grep -q 'unlinked=[1-9]'; then
  echo "FAIL: unlinked tick cells found"
  errors=$((errors+1))
else
  echo "PASS: all ✓ cells in matrix tables have href links"
fi

CELLS=$(wc -l < "$EVIDENCE" | tr -d ' ')
echo "Evidence entries: $CELLS"

if [[ $errors -eq 0 ]]; then
  echo "VALIDATION PASS"
  exit 0
else
  echo "VALIDATION FAIL ($errors errors)"
  exit 1
fi
