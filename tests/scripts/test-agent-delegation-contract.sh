#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$REPO_ROOT/scripts/check-apo-invariants.py" agent-delegation-contract | awk -F'\t' '
$1=="PASS" { passed++ }
$1=="FAIL" { failed++ }
{ print }
END { printf "\nResults: %d passed, %d failed\n", passed, failed; exit (failed > 0) }
'
