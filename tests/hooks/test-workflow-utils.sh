#!/usr/bin/env bash
# hooks/lib/workflow-utils.sh: Flow Log row counting.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# shellcheck source=../../hooks/lib/workflow-utils.sh
source "$TL_REPO_ROOT/hooks/lib/workflow-utils.sh"

wf="$TL_TMP/wf.md"
cat >"$wf" <<'EOF'
# Workflow

## Phase Iterations
| 01 | not a flow row | complete |

## Flow Log
| # | Flow | Status |
|---|------|--------|
| 1 | FLOW 1 | complete |
| 2 | FLOW 2 | skipped |
| 3 | FLOW 3 | in-progress |

## Autonomous Decisions
| 9 | decision | complete |
EOF

assert_eq "counts only Flow Log rows" "3" "$(count_flow_log_rows "$wf")"
assert_eq "counts complete and skipped rows" "2" "$(count_complete_flow_rows "$wf")"

empty="$TL_TMP/empty.md"
printf '# No flow log here\n' >"$empty"
assert_eq "no Flow Log section: one 0, not two" "0" "$(count_flow_log_rows "$empty")"
assert_eq "no Flow Log section: complete rows is a single 0" "0" "$(count_complete_flow_rows "$empty")"

norows="$TL_TMP/norows.md"
printf '## Flow Log\n| # | Flow | Status |\n|---|---|---|\n' >"$norows"
assert_eq "empty Flow Log table: single 0" "0" "$(count_flow_log_rows "$norows")"
assert_eq "empty Flow Log table: single 0 complete" "0" "$(count_complete_flow_rows "$norows")"

missing="$TL_TMP/missing.md"
assert_eq "missing file: single 0" "0" "$(count_flow_log_rows "$missing")"
n="$(count_flow_log_rows "$empty")"
if [[ "$n" -eq 0 ]]; then tl_pass "numeric test on empty count works"; else tl_fail "numeric test on empty count"; fi

tl_results
