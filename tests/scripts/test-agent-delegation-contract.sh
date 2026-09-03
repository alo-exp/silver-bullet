#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$REPO_ROOT/scripts/check-apo-invariants.py" agent-delegation-contract | awk -F'\t' '
$1=="FAIL" { failed=1 }
{ print }
END { exit failed+0 }
'
