#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$REPO_ROOT/scripts/check-apo-invariants.py" opted-in-tool-enforcement | awk -F'\t' '
  $1=="PASS"{pass++; print "PASS: "$2}
  $1=="FAIL"{fail++; print "FAIL: "$2($3?": "$3:"")}
  END{printf "\nResults: %d passed, %d failed\n", pass+0, fail+0; exit(fail?1:0)}
'
