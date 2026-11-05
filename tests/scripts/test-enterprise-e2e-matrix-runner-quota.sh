#!/usr/bin/env bash
# matrix.sh quota retries and per-row timeouts, against a staged SB root with a fake agent.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude

source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

# ------------------------------------------------------------ quota handling
reset
agent <<'EOS'
if [[ "$1" == 1 ]]; then echo "HTTP 429 Token Plan exceeded"; else mkdir -p "$WORK_DIR/docs"; echo ok >"$WORK_DIR/docs/ADR-001-runtime.md"; fi
EOS
run bash "$MATRIX" 2
assert_eq "quota retry then pass" "0" "$TL_STATUS"
assert_contains "quota wait message" "$TL_OUT" "  QUOTA: API 429 / Token Plan limit — waiting 7s before retry 1..."
assert_contains "retry banner" "$TL_OUT" "  retry attempt 2 (quota retry #1)..."
assert_contains "quota success message" "$TL_OUT" "  PASS: succeeded after 1 quota retry(ies)"
assert_contains "slept the retry interval" "$CALLS" "sleep 7"
assert_file_exists "second attempt log" "$R/.e2e-row2-attempt2.log"

reset
agent <<'EOS'
echo "rate limit hit"
EOS
run env SB_E2E_MATRIX_QUOTA_MAX_RETRIES=1 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "quota exhaustion fails" "1" "$TL_STATUS"
assert_contains "quota exhausted message" "$TL_OUT" "  FAIL: quota retries exhausted (1) — missing evidence at docs/ADR-001-runtime.md"
assert_eq "one sleep before giving up" "1" "$(grep -c '^sleep 7$' <<<"$CALLS")"
assert_contains "exhausted telemetry" "$CALLS" "telemetry matrix_row row=2 slug=silver-deep-research result=fail"

# ------------------------------------------------------------ timeouts per row
reset
agent <<'EOS'
echo noop
EOS
run env SB_E2E_ROW8_TIMEOUT=111 SB_E2E_WORKFLOW_QUIET_TIMEOUT=22 bash "$MATRIX" 8
assert_contains "row 8 agent timeout" "$CALLS" "agent-env#1 quiet=22 timeout=111 cursor_timeout=111"
reset
agent <<'EOS'
echo noop
EOS
run env SB_E2E_ROW11_TIMEOUT=222 bash "$MATRIX" 11
assert_contains "row 11 agent timeout" "$CALLS" "timeout=222 cursor_timeout=222"
reset
agent <<'EOS'
echo noop
EOS
run env SB_E2E_ROW1_QUIET_TIMEOUT=33 bash "$MATRIX" 1
assert_contains "row 1 quiet timeout and routing flag" "$CALLS" "quiet=33 timeout=900 cursor_timeout=900 evidence=.planning/workflows/router-session.md routing=1"
reset
agent <<'EOS'
echo noop
EOS
run env SB_E2E_ROW3_QUIET_TIMEOUT=44 SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex bash "$MATRIX" 3
assert_contains "codex row 3 quiet timeout and trust env" "$CALLS" "agent-env#1 quiet=44 timeout=900 cursor_timeout=900 evidence=.planning/workflows/feature-currency.md routing=0 codex_trust=1 bypass=1"
assert_contains "codex adapter seeded hook trust before the row" "$CALLS" "scripts/install-codex.sh --hook-trust-seed-only"

tl_results
