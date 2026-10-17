#!/usr/bin/env bash
# matrix.sh live row execution: evidence/outcome verdicts, quota retries, skip rules, routing row,
# fixture gates, telemetry and registry recording, against a staged SB root with a fake agent.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude

source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

# ------------------------------------------------------------ happy path (row 2)
reset
evidence_agent
run bash "$MATRIX" 2
assert_eq "row 2 passes" "0" "$TL_STATUS"
assert_contains "row header" "$TL_OUT" "=== Row 2: silver-deep-research (/sb:deep-research) ==="
assert_contains "launch message" "$TL_OUT" "  launching interactive claude session..."
assert_contains "agent output tailed" "$TL_OUT" "agent said hello"
assert_contains "evidence pass" "$TL_OUT" "  PASS: evidence at docs/ADR-001-runtime.md"
assert_contains "outcome checklist reported" "$TL_OUT" "  OUTCOMES: checklist at .planning/enterprise-e2e/outcomes/row-2-outcomes.md"
assert_contains "outcomes pass" "$TL_OUT" "  OUTCOMES: all applicable criteria pass (OUT-WORLD-01 composite)"
assert_contains "summary pass" "$TL_OUT" "Pass:  1"
assert_contains "summary fail" "$TL_OUT" "Fail:  0"
assert_file_exists "outcome checklist written" "$APP/.planning/enterprise-e2e/outcomes/row-2-outcomes.md"
assert_contains "checklist args forwarded" "$CALLS" "checklist row=2 out=$APP/.planning/enterprise-e2e/outcomes/row-2-outcomes.md work=$APP state=$SB_RUNTIME_STATE_DIR log=$R/.e2e-row2-attempt.log ledger=$TL_TMP/ledger.md evidence=docs/ADR-001-runtime.md"
assert_contains "telemetry pass" "$CALLS" "telemetry matrix_row row=2 slug=silver-deep-research result=pass log=$R/.e2e-row2-attempt.log"
assert_contains "prompt carries slug route and evidence" "$CALLS" "prompt#1 /sb Should we use Postgres or SQLite for orders? Enterprise E2E matrix validation. Route this through the silver-deep-research workflow"
assert_contains "agent env: workflow quiet timeout" "$CALLS" "agent-env#1 quiet=600 timeout=900 cursor_timeout=900 evidence=docs/ADR-001-runtime.md routing=0"
assert_contains "attempt log header" "$(cat "$R/.e2e-row2-attempt.log")" 'HARNESS graphify: graphify query "silver-deep-research routes hooks skills orchestrator"'
assert_contains "agent output stored in attempt log" "$(cat "$R/.e2e-row2-attempt.log")" "agent said hello"
assert_contains "slug recorded in routing state" "$(cat "$STATE")" "silver-deep-research"
assert_eq "registry records the pass" "true" "$(jq -r '.installs | to_entries[0].value.rows["2"].outcome_pass' "$REG")"
assert_contains "workspace set up and cleaned" "$CALLS" "cleanup_workspace"
assert_file_absent "pid file removed" "$TL_TMP/batch.pid"

# the same install skips a passed row; FAIL_ON_SKIP tolerates install-pass skips
run bash "$MATRIX" 2
assert_eq "second run exit" "0" "$TL_STATUS"
assert_contains "install-pass skip message" "$TL_OUT" "  SKIP: ROW_ALREADY_PASSED_SAME_INSTALL (install_fp=claude@"
assert_contains "skip counts" "$TL_OUT" "Skip:  1 (install-pass: 1)"
assert_not_contains "agent not started on install-pass skip" "$CALLS" "prompt#"
assert_contains "install-pass skip telemetry" "$CALLS" "telemetry matrix_row_install_pass_skip row=2 slug=silver-deep-research result=skip_install_pass log=$R/.e2e-row2-attempt.log"
run env SB_E2E_MATRIX_FAIL_ON_SKIP=1 bash "$MATRIX" 2
assert_eq "FAIL_ON_SKIP allows install-pass skips" "0" "$TL_STATUS"

# FORCE_ALL re-runs a registry-passed row (matrix_force_rerun)
: >"$F2_CTL/prompt-count"; rm -f "$F2_CTL/prompt-count"
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX" 2
assert_contains "forced all re-runs row" "$CALLS" "prompt#1"

# evidence-only skip (no registry entry), FAIL_ON_SKIP rejects it, FORCE re-runs
rm -f "$REG" "$F2_CTL/prompt-count"
run bash "$MATRIX" 2
assert_eq "evidence skip exit" "0" "$TL_STATUS"
assert_contains "evidence skip message" "$TL_OUT" "  SKIP: evidence already present (set SB_E2E_MATRIX_FORCE=1 or SB_E2E_MATRIX_FORCE_ALL=1 to re-run)"
assert_contains "evidence skip telemetry" "$CALLS" "telemetry matrix_row_skip row=2 slug=silver-deep-research result=skip"
assert_contains "evidence skip counted" "$TL_OUT" "Skip:  1 (install-pass: 0)"
run env SB_E2E_MATRIX_FAIL_ON_SKIP=1 bash "$MATRIX" 2
assert_eq "FAIL_ON_SKIP rejects evidence skip" "1" "$TL_STATUS"
assert_contains "FAIL_ON_SKIP message" "$TL_ERR" "SB_E2E_MATRIX_FAIL_ON_SKIP=1 — 1 evidence SKIP row(s) (install-pass skips allowed: 0)"
rm -f "$F2_CTL/prompt-count"
run env SB_E2E_MATRIX_FORCE=1 bash "$MATRIX" 2
assert_contains "FORCE re-runs row with evidence" "$CALLS" "prompt#1"

# ------------------------------------------------------------ failure verdicts
reset
agent <<'EOS'
echo "agent did nothing"
EOS
run bash "$MATRIX" 2
assert_eq "missing evidence fails" "1" "$TL_STATUS"
assert_contains "missing evidence message" "$TL_OUT" "  FAIL: missing evidence at docs/ADR-001-runtime.md"
assert_contains "fail summary" "$TL_OUT" "Fail:  1"
assert_contains "failure telemetry" "$CALLS" "telemetry matrix_row row=2 slug=silver-deep-research result=fail log=$R/.e2e-row2-attempt.log"
assert_file_absent "no registry record on failure" "$REG"

reset
evidence_agent
touch "$F2_CTL/outcome-fail-2"
printf 'OUT-PLAN-01 missing\n\nOUT-WORLD-01 no commits\n' >"$F2_CTL/outcome-failures"
run bash "$MATRIX" 2
assert_eq "outcome failure fails the row" "1" "$TL_STATUS"
assert_contains "outcome failure message" "$TL_OUT" "  FAIL: outcome assessment — mandatory criteria not all pass (evidence alone insufficient)"
assert_contains "outcome failure line 1" "$TL_OUT" "    OUTCOME-FAIL: OUT-PLAN-01 missing"
assert_contains "outcome failure line 2" "$TL_OUT" "    OUTCOME-FAIL: OUT-WORLD-01 no commits"
assert_eq "blank failure lines skipped" "2" "$(grep -c 'OUTCOME-FAIL' <<<"$TL_OUT")"
assert_file_absent "no registry record on outcome failure" "$REG"
assert_contains "outcome failure telemetry" "$CALLS" "telemetry matrix_row row=2 slug=silver-deep-research result=fail"

# no outcome scorer installed: evidence alone passes
reset
evidence_agent
mv "$R/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh" "$TL_TMP/oa.keep"
run bash "$MATRIX" 2
assert_eq "no scorer still passes" "0" "$TL_STATUS"
assert_not_contains "no outcomes output without scorer" "$TL_OUT" "OUTCOMES:"
mv "$TL_TMP/oa.keep" "$R/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"

# telemetry failures are tolerated
reset
evidence_agent
run env F2_TELEMETRY_FAIL=1 bash "$MATRIX" 2
assert_eq "failing telemetry tolerated" "0" "$TL_STATUS"

# agent failure does not abort the harness
reset
agent <<'EOS'
echo "boom"
return 3
EOS
run bash "$MATRIX" 2
assert_eq "agent crash is a row failure, not a harness crash" "1" "$TL_STATUS"
assert_contains "agent crash output kept" "$(cat "$R/.e2e-row2-attempt.log")" "boom"

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
run env SB_E2E_MATRIX_QUOTA_MAX_RETRIES=1 bash "$MATRIX" 2
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
