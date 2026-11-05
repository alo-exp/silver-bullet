#!/usr/bin/env bash
# matrix.sh with failing optional collaborators and degraded environments, against a staged SB root.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"


# ------------------------------------------------------------ optional collaborators
reset
evidence_agent
tl_stub graphify 'printf "graphify %s cwd=%s\n" "$*" "$PWD" >>"$F2_CALLS"; exit 1'
run bash "$MATRIX" 2
/bin/rm -f "$TL_BIN/graphify"
assert_eq "failing graphify query tolerated" "0" "$TL_STATUS"
assert_contains "graphify queried from the SB root" "$CALLS" "graphify query silver-deep-research routes hooks skills orchestrator cwd=$R"

reset
evidence_agent
run env F2_CHECKLIST_FAIL=1 bash "$MATRIX" 2
assert_eq "failing checklist writer tolerated" "0" "$TL_STATUS"

reset
evidence_agent
mkdir -p "$SB_RUNTIME_STATE_DIR/state"
run bash "$MATRIX" 2
assert_eq "unwritable routing state file tolerated" "0" "$TL_STATUS"
rmdir "$SB_RUNTIME_STATE_DIR/state"

reset
evidence_agent
: >"$TL_TMP/blocker"
run env SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/state" bash "$MATRIX" 2
assert_eq "uncreatable routing state dir tolerated" "0" "$TL_STATUS"

# codex adapter failing before a row is tolerated
reset
evidence_agent
run env SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex F2_ENSURE_FAIL_AT=3 bash "$MATRIX" 2
assert_eq "codex adapter failure tolerated" "0" "$TL_STATUS"
assert_contains "agent still launched" "$CALLS" "prompt#1"

# unavailable agent CLI is reported, not fatal
reset
evidence_agent
run env F2_AGENT_MISSING=1 bash "$MATRIX" 2
assert_contains "missing agent shown" "$TL_OUT" "Agent:      missing"

# skips with failing telemetry
reset
evidence_agent
bash "$MATRIX" 2 >/dev/null 2>&1 || true
run env F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_contains "install-pass skip with failing telemetry" "$TL_OUT" "ROW_ALREADY_PASSED_SAME_INSTALL"
rm -f "$REG"
run env F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_contains "evidence skip with failing telemetry" "$TL_OUT" "SKIP: evidence already present"

tl_results
