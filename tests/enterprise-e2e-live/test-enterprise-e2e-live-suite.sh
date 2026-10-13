#!/usr/bin/env bash
# Structural validation for enterprise E2E live test wiring (no interactive Claude).
# Full live matrix requires SB_ENTERPRISE_E2E_LIVE=1 via scripts/run-enterprise-e2e-live-test.sh
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HARNESS_ROOT="${REPO_ROOT}/scripts/enterprise-e2e"
HARNESS_LIVE="${HARNESS_ROOT}/live-test.sh"
HARNESS_MATRIX="${HARNESS_ROOT}/matrix.sh"
HARNESS_CORE="${HARNESS_ROOT}/lib/core.sh"
HARNESS_HOST="${HARNESS_ROOT}/lib/host.sh"
HARNESS_CONFIG="${HARNESS_ROOT}/config/hosts.json"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in $file"
  fi
}

assert_not_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    fail "$desc — unexpected [$needle] in $file"
  else
    pass "$desc"
  fi
}

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

# --- Docs and entrypoints ---
assert_file_exists "${REPO_ROOT}/docs/ENTERPRISE-E2E-LIVE-TEST.md" "live test runbook exists"
assert_file_exists "${REPO_ROOT}/.planning/enterprise-e2e/SHARED-HARNESS.md" "SHARED-HARNESS architecture doc exists"
assert_file_exists "$HARNESS_CONFIG" "hosts.json config exists"
assert_file_exists "$HARNESS_CORE" "harness core lib exists"
assert_file_exists "$HARNESS_HOST" "harness host lib exists"
assert_executable "$HARNESS_LIVE" "harness live-test entry executable"
assert_executable "$HARNESS_MATRIX" "harness matrix runner executable"
assert_executable "${REPO_ROOT}/scripts/run-enterprise-e2e-live-test.sh" "live test wrapper executable"
assert_executable "${REPO_ROOT}/tests/enterprise-e2e-live/test-enterprise-e2e-triage-ladder-scenario.sh" "triage ladder scenario executable"
assert_contains "triage ladder scenario sources enterprise common" "${REPO_ROOT}/tests/enterprise-e2e-live/test-enterprise-e2e-triage-ladder-scenario.sh" "enterprise-e2e-live-common.sh"
assert_contains "live wrapper delegates to harness" "${REPO_ROOT}/scripts/run-enterprise-e2e-live-test.sh" "enterprise-e2e/live-test.sh"
assert_file_exists "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh" "live test common lib exists"
assert_contains "live-common sources harness core" "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh" "enterprise-e2e/lib/core.sh"
assert_executable "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" "matrix runner wrapper executable"
assert_contains "matrix wrapper delegates to harness" "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" "enterprise-e2e/matrix.sh"
assert_executable "${REPO_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh" "matrix monitor executable"
assert_executable "${REPO_ROOT}/scripts/watch-enterprise-e2e-tui.sh" "TUI watch executable"
assert_executable "${REPO_ROOT}/.planning/enterprise-e2e/round6-matrix-driver.sh" "round6 matrix driver executable"

DETACH_LIB="${REPO_ROOT}/tests/live/lib/detach-background.sh"
assert_contains "detach lib defines sb_run_detached_pty" "$DETACH_LIB" "sb_run_detached_pty"
assert_contains "detach lib script pty wrapper" "$DETACH_LIB" "script -q /dev/null"
ROUND6_DRIVER="${REPO_ROOT}/.planning/enterprise-e2e/round6-matrix-driver.sh"
assert_contains "round6 driver uses sb_run_detached_pty" "$ROUND6_DRIVER" "sb_run_detached_pty"

# --- Operational learnings encoded in runbook ---
RUNBOOK="${REPO_ROOT}/docs/ENTERPRISE-E2E-LIVE-TEST.md"
for needle in \
  "SB_ENTERPRISE_E2E_LIVE=1" \
  "NO login" \
  "NO logout" \
  "API key" \
  "settings.json" \
  "SB_E2E_MATRIX_CLEAN_ENV=0" \
  "SB_E2E_MATRIX_DRY_RUN" \
  "600" \
  "429" \
  "dual-role" \
  "monitor-enterprise-e2e-matrix" \
  "watch-enterprise-e2e-tui" \
  "install-claude.sh" \
  "review-fix-ladder" \
  "run-all-tests.sh" \
  "graphify" \
  "agentmemory" \
  "Resume" \
  "RTK coexistence" \
  "SB_RTK_COMPAT_MODE=verbatim" \
  "provider restart" \
  "cursor-hook-bridge" \
  "2 consecutive clean rounds" \
  "/sb:" \
  "interactive Claude TUI"
do
  assert_contains "runbook documents: $needle" "$RUNBOOK" "$needle"
done

# --- Live entrypoint constraints ---
LIVE="$HARNESS_LIVE"
COMMON_LIB="$HARNESS_CORE"
assert_contains "live entrypoint requires SB_ENTERPRISE_E2E_LIVE" "$LIVE" "SB_ENTERPRISE_E2E_LIVE"
assert_contains "live entrypoint sets CLEAN_ENV=0" "$LIVE" "SB_E2E_MATRIX_CLEAN_ENV=0"
assert_contains "live entrypoint unsets DRY_RUN" "$LIVE" "env -u SB_E2E_MATRIX_DRY_RUN"
assert_contains "live entrypoint starts monitor" "$LIVE" "monitor-enterprise-e2e-matrix.sh"
assert_contains "live entrypoint starts tui watch" "$LIVE" "watch-enterprise-e2e-tui.sh"
assert_contains "live entrypoint resets tui offsets" "$LIVE" "enterprise_e2e_reset_tui_monitor_offsets"
assert_contains "common lib resets tui offsets" "$COMMON_LIB" "enterprise_e2e_reset_tui_monitor_offsets"
assert_contains "live entrypoint runs install-claude" "$LIVE" "install-claude.sh"
assert_contains "live entrypoint quota 60s default" "$COMMON_LIB" "SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-60"
assert_contains "live common defaults settings export on" "$COMMON_LIB" 'SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT="${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-0}"'
assert_contains "live common token gateway preflight" "$COMMON_LIB" "enterprise_e2e_preflight_claude_token_gateway"
assert_contains "live common sources test app branch module" "$COMMON_LIB" "test-app-branch.sh"
assert_contains "test app branch ensure helper" "${REPO_ROOT}/scripts/enterprise-e2e/lib/test-app-branch.sh" "enterprise_e2e_ensure_test_app_branch"
assert_contains "live entrypoint test app branch preflight" "$LIVE" "enterprise_e2e_assert_test_app_branch"
assert_contains "round8 driver pins test app branch" "${REPO_ROOT}/.planning/enterprise-e2e/round8-matrix-driver.sh" "SB_E2E_TEST_APP_BRANCH"
assert_contains "test app branch policy doc" "${REPO_ROOT}/.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md" "enterprise-e2e/round-1-cursor"
assert_contains "live entrypoint token gateway preflight" "$LIVE" "enterprise_e2e_preflight_host"
assert_contains "live entrypoint matrix forces settings export" "$LIVE" "SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0"
assert_contains "live entrypoint matrix arrow strategy" "$LIVE" "CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow"
assert_not_contains "live entrypoint forbids login" "$LIVE" "auth login"
assert_not_contains "live entrypoint forbids logout" "$LIVE" "auth logout"

# --- Matrix runner learnings ---
MATRIX="$HARNESS_MATRIX"
assert_contains "matrix runner test app branch preflight" "$MATRIX" "enterprise_e2e_assert_test_app_branch"
assert_contains "matrix runner harness git branch assert" "$MATRIX" "enterprise_e2e_assert_host_git_branch"
assert_contains "hosts.json cursor test app branch" "$HARNESS_CONFIG" "enterprise-e2e/round-1-cursor"
assert_contains "hosts.json cursor harness git branch" "$HARNESS_CONFIG" "enterprise-e2e/cursor"
assert_contains "host lib harness git branch assert" "$HARNESS_HOST" "enterprise_e2e_assert_host_git_branch"
assert_contains "matrix exports settings env" "$MATRIX" "claude_matrix_export_settings_env"
assert_contains "matrix forces settings export on" "$MATRIX" 'export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0'
assert_not_contains "matrix auto-skips proxy settings export" "$MATRIX" "claude_matrix_settings_has_proxy_env"
assert_contains "matrix arrow strategy for api key disclaimer" "$MATRIX" 'CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY="${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-arrow}"'
assert_contains "matrix forces settings export on" "$MATRIX" 'export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0'
assert_contains "matrix quota retry 60" "$MATRIX" "SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-60"
assert_contains "matrix uses /sb slash prompts" "$MATRIX" "/sb"
assert_not_contains "matrix docs DRY_RUN as opt-in only" "$MATRIX" 'export SB_E2E_MATRIX_DRY_RUN=1'

# --- Monitor learnings ---
MONITOR="${REPO_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh"

# --- Auth mutation guard (ignores # comment lines) ---
if enterprise_e2e_assert_no_auth_mutations "$MATRIX"; then
  pass "auth mutation guard passes on matrix runner"
else
  fail "auth mutation guard should ignore comment lines (e.g. login wall note)"
fi
if enterprise_e2e_assert_no_auth_mutations "$MONITOR"; then
  pass "auth mutation guard passes on matrix monitor"
else
  fail "auth mutation guard should pass on monitor script"
fi
TMP_AUTH_GUARD="$(mktemp)"
{
  echo '# comment with /login must not trip guard'
  echo 'echo safe'
} >"$TMP_AUTH_GUARD"
if enterprise_e2e_assert_no_auth_mutations "$TMP_AUTH_GUARD"; then
  pass "auth mutation guard ignores /login in comments"
else
  fail "auth mutation guard must skip comment lines"
fi
printf '%s\n' 'claude auth login' >>"$TMP_AUTH_GUARD"
if enterprise_e2e_assert_no_auth_mutations "$TMP_AUTH_GUARD" 2>/dev/null; then
  fail "auth mutation guard must reject claude auth login"
else
  pass "auth mutation guard rejects claude auth login"
fi
rm -f "$TMP_AUTH_GUARD"

assert_contains "monitor resume incomplete rows" "$MONITOR" "incomplete_rows"
assert_contains "monitor 429 wait 600" "$MONITOR" "QUOTA_WAIT"
assert_contains "monitor network retry" "$MONITOR" "NETWORK_WAIT"
assert_contains "monitor forces CLEAN_ENV=0 on restart" "$MONITOR" "SB_E2E_MATRIX_CLEAN_ENV=0"
assert_contains "monitor forces settings export on restart" "$MONITOR" "SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0"
assert_contains "monitor passes arrow strategy on restart" "$MONITOR" "CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow"
assert_contains "monitor unsets DRY_RUN on restart" "$MONITOR" "-u SB_E2E_MATRIX_DRY_RUN"
assert_contains "monitor sources ledger reconcile helper" "$MONITOR" "enterprise-e2e-ledger-reconcile.sh"
assert_contains "monitor ledger mismatch guard" "$MONITOR" "LEDGER_MISMATCH"
assert_executable "${REPO_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh" "ledger reconcile helper exists"
assert_executable "${REPO_ROOT}/scripts/lib/matrix-failure-class.sh" "matrix failure_class helper exists"
assert_executable "${REPO_ROOT}/scripts/claims-audit.sh" "claims audit script exists"
assert_executable "${REPO_ROOT}/scripts/run-enterprise-e2e-validation-overlay.sh" "validation overlay script exists"
assert_file_exists "${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md" "validation plan exists"
assert_file_exists "${REPO_ROOT}/docs/testing/validation-claims-registry.json" "validation claims registry exists"
assert_file_exists "${REPO_ROOT}/docs/testing/claims-registry.json" "claims registry exists"
assert_file_exists "${REPO_ROOT}/docs/testing/outcome-criteria-registry.json" "outcome criteria registry exists"
assert_file_exists "${REPO_ROOT}/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md" "outcome assessment rubric exists"
assert_file_exists "${REPO_ROOT}/.planning/enterprise-e2e/ROUND-N-OUTCOMES.md" "ROUND-N-OUTCOMES template exists"
assert_file_exists "${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh" "outcome assessment lib exists"
assert_file_exists "${REPO_ROOT}/tests/scripts/test-outcome-assessment.sh" "outcome assessment test exists"
assert_file_exists "${REPO_ROOT}/docs/testing/host-certification-sources.json" "host certification sources registry exists"
assert_file_exists "${REPO_ROOT}/docs/testing/autonomous-enterprise-proof-baseline.json" "autonomous enterprise proof baseline exists"
assert_executable "${REPO_ROOT}/scripts/enterprise-e2e-certification-status.sh" "certification status generator executable"
assert_file_exists "${REPO_ROOT}/tests/scripts/test-enterprise-e2e-certification-status.sh" "certification status test exists"
assert_executable "${REPO_ROOT}/tests/tui-contract/test-bypass-disclaimer.sh" "bypass disclaimer contract test exists"

# Ledger template includes failure_class column
assert_contains "ledger template failure_class column" "${REPO_ROOT}/.planning/enterprise-e2e/ROUND-N-LEDGER.md" "failure_class"

# Session 0 gate wiring
assert_contains "live entrypoint session0 gate" "$LIVE" "enterprise_e2e_assert_session0_or_skip"
assert_contains "common lib session0 skip env" "$COMMON_LIB" "SB_E2E_SESSION0_SKIP"
assert_contains "runbook documents session0 gate" "$RUNBOOK" "Session 0"
assert_contains "runbook documents failure_class" "$RUNBOOK" "failure_class"
assert_contains "rubric defines OUT-TAILOR-01" "${REPO_ROOT}/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md" "OUT-TAILOR-01"
assert_contains "rubric defines OUT-KM-01" "${REPO_ROOT}/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md" "OUT-KM-01"

# claims-audit in structural gate
if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/claims-audit.sh" >/dev/null 2>&1; then
  pass "claims-audit passes against site + registry"
else
  fail "claims-audit failed — run scripts/claims-audit.sh"
fi

# --- Expect harness: token gateway ignores OAuth banner ---
EXPECT="${REPO_ROOT}/scripts/claude-interactive-invoke.expect"
assert_contains "expect defines token gateway check" "$EXPECT" "token_gateway_configured"
assert_contains "expect ignores login banner for token gateway" "$EXPECT" "ignoring OAuth banner"
assert_contains "expect waits for input prompt before slash submit" "$EXPECT" "slash_route_pending"
assert_contains "expect gates slash submit on input prompt ready" "$EXPECT" "input_prompt_ready"
assert_contains "expect detects context exhaustion" "$EXPECT" "context_exhaustion_visible"
assert_contains "expect recovers from context exhaustion with /clear" "$EXPECT" "recover_from_context_exhaustion"
assert_contains "expect caps quiet timeout when context-full stalls" "$EXPECT" "context_full_stalled_at"
assert_not_contains "expect must not invoke /login" "$EXPECT" "/login\r"

# --- Watch: Not logged in is info not blocker ---
WATCH="${REPO_ROOT}/scripts/watch-enterprise-e2e-tui.sh"
assert_contains "watch restarts dead monitor" "$WATCH" "ensure_monitor_alive"
assert_contains "watch continuation offset scan" "$WATCH" "grew since last pass"
assert_contains "watch treats not logged in as info" "$WATCH" "Not logged in"

# --- RTK in SB scripts ---
assert_contains "rtk-compat supports verbatim mode" "${REPO_ROOT}/hooks/lib/rtk-compat.sh" "SB_RTK_COMPAT_MODE=verbatim"
assert_contains "matrix runner uses verbatim RTK mode" "$MATRIX" "SB_RTK_COMPAT_MODE=verbatim"
assert_contains "live entrypoint uses verbatim RTK mode" "$LIVE" "SB_RTK_COMPAT_MODE=verbatim"

# --- Code-intel preflight helpers ---
for fn in \
  enterprise_e2e_source_code_intel_libs \
  enterprise_e2e_code_intel_preflight \
  enterprise_e2e_preflight_graphify \
  enterprise_e2e_preflight_agentmemory \
  enterprise_e2e_preflight_rtk \
  enterprise_e2e_preflight_context_mode; do
  if grep -qE "^${fn}\(\)" "$COMMON_LIB" 2>/dev/null; then
    pass "common lib defines ${fn}"
  else
    fail "common lib missing ${fn}"
  fi
done

assert_contains "live entrypoint supports skip-code-intel-preflight" "$LIVE" "--skip-code-intel-preflight"
assert_contains "live entrypoint calls code_intel_preflight" "$LIVE" "enterprise_e2e_code_intel_preflight"
assert_contains "runbook documents skip-code-intel-preflight" "$RUNBOOK" "--skip-code-intel-preflight"
assert_contains "runbook documents RTK coexistence" "$RUNBOOK" "RTK coexistence"
assert_contains "runbook documents verbatim harness mode" "$RUNBOOK" "SB_RTK_COMPAT_MODE=verbatim"

# Dry-run path (no tool enforcement when configs pending or debug dry_run)
if enterprise_e2e_code_intel_preflight "$REPO_ROOT" "${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}" 1 >/dev/null 2>&1; then
  pass "code-intel preflight dry-run exits 0"
else
  fail "code-intel preflight dry-run should exit 0"
fi

# --- Resume helper ---
TMP_LOG="$(mktemp)"
LEDGER_FIXTURE=""
LEDGER_RESUME_FIXTURE=""
cleanup_tmp() { rm -f "$TMP_LOG" "$LEDGER_FIXTURE" "$LEDGER_RESUME_FIXTURE"; }
trap cleanup_tmp EXIT
{
  echo "=== Row 1: silver-router (/sb) ==="
  echo "  PASS: evidence at .planning/workflows/router-session.md"
  echo "=== Row 2: silver-deep-research (/sb:deep-research) ==="
  echo "  SKIP: evidence already present (set SB_E2E_MATRIX_FORCE=1 to re-run)"
} >"$TMP_LOG"
LEDGER_RESUME_FIXTURE="$(mktemp)"
cat >"$LEDGER_RESUME_FIXTURE" <<'LEDGER'
| # | WF slug | Session date | Claude model | Pass/Fail | Issues | SB fix commit | graphify_query_ref | agentmemory_export_ref |
|---|---------|--------------|--------------|-----------|--------|---------------|--------------------|------------------------|
| 1 | `silver-router` | 2026-06-28 | haiku | **Pass** | | | | |
| 2 | `silver-deep-research` | | | | | | | |
| 3 | `silver-feature` | | | Fail | | | | |
LEDGER
inc="$(enterprise_e2e_incomplete_rows "$TMP_LOG" "$LEDGER_RESUME_FIXTURE" | tr '\n' ' ' | xargs)"
if printf '%s\n' "$inc" | grep -qw 1; then
  fail "resume must not include row 1 when ledger Pass"
else
  pass "resume excludes row 1 when ledger Pass"
fi
if printf '%s\n' "$inc" | grep -qw 2; then
  pass "resume includes row 2 when ledger incomplete despite log SKIP"
else
  fail "resume includes row 2 when ledger incomplete — got [$inc]"
fi
if printf '%s\n' "$inc" | grep -qw 3; then
  pass "resume includes ledger Fail row 3"
else
  fail "resume includes ledger Fail row 3 — got [$inc]"
fi

# --- Opt-in gate in run-all-tests ---
assert_contains "run-all-tests documents opt-in" "${REPO_ROOT}/tests/run-all-tests.sh" "SB_ENTERPRISE_E2E_LIVE"

# --- P0 effectiveness: ledger reconcile, tui-contract, claims-audit, failure_class, session0 ---
assert_file_exists "${REPO_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh" "ledger reconcile lib exists"
assert_file_exists "${REPO_ROOT}/scripts/lib/matrix-failure-class.sh" "matrix failure_class lib exists"
assert_executable "${REPO_ROOT}/scripts/claims-audit.sh" "claims-audit executable"
assert_file_exists "${REPO_ROOT}/docs/testing/claims-registry.json" "claims registry exists"
assert_contains "monitor ledger reconcile" "$MONITOR" "matrix_reconcile_state"
assert_contains "monitor sources ledger reconcile" "$MONITOR" "enterprise-e2e-ledger-reconcile.sh"
assert_contains "live entrypoint session0 gate" "$LIVE" "enterprise_e2e_assert_session0_or_skip"
assert_contains "common lib session0 gate" "$COMMON_LIB" "enterprise_e2e_assert_session0_or_skip"
assert_contains "runbook failure_class taxonomy" "$RUNBOOK" "failure_class"
assert_contains "runbook ledger reconcile" "$RUNBOOK" "ledger-reconcile"
assert_file_exists "${REPO_ROOT}/tests/tui-contract/test-bypass-disclaimer.sh" "tui-contract bypass test exists"
assert_executable "${REPO_ROOT}/tests/tui-contract/test-bypass-disclaimer.sh" "tui-contract bypass test executable"

if RTK_DISABLED=1 bash "${REPO_ROOT}/tests/tui-contract/test-bypass-disclaimer.sh" >/dev/null 2>&1; then
  pass "tui-contract bypass-disclaimer passes"
else
  fail "tui-contract bypass-disclaimer failed"
fi

assert_file_exists "${REPO_ROOT}/tests/tui-contract/test-blocking-decision-picker.sh" "tui-contract blocking picker test exists"
assert_executable "${REPO_ROOT}/tests/tui-contract/test-blocking-decision-picker.sh" "tui-contract blocking picker test executable"

if RTK_DISABLED=1 bash "${REPO_ROOT}/tests/tui-contract/test-blocking-decision-picker.sh" >/dev/null 2>&1; then
  pass "tui-contract blocking-decision-picker passes"
else
  fail "tui-contract blocking-decision-picker failed"
fi

if command -v jq >/dev/null 2>&1; then
  if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/claims-audit.sh" >/dev/null 2>&1; then
    pass "claims-audit passes"
  else
    fail "claims-audit failed"
  fi
else
  pass "claims-audit skipped (jq not installed)"
fi

# failure_class helper smoke
# shellcheck source=scripts/lib/matrix-failure-class.sh
source "${REPO_ROOT}/scripts/lib/matrix-failure-class.sh"
if [[ "$(matrix_failure_class_from_snippet 'API Error 429 weekly usage limit')" == "environmental" ]]; then
  pass "failure_class environmental for 429"
else
  fail "failure_class environmental for 429"
fi
if [[ "$(matrix_failure_class_from_snippet 'accept_bypass Permissions ANSI expect')" == "harness" ]]; then
  pass "failure_class harness for expect"
else
  fail "failure_class harness for expect"
fi

# ledger reconcile fixture
LEDGER_FIXTURE="$(mktemp)"
cat >"$LEDGER_FIXTURE" <<'LEDGER'
| # | WF slug | Pass/Fail | graphify_query_ref | agentmemory_export_ref |
|---|---------|-----------|--------------------|------------------------|
| 1 | `silver-router` | Pass | gq-1 | am-1 |
LEDGER
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
SB_E2E_LEDGER_FILE="$LEDGER_FIXTURE" reconcile_status="$(enterprise_e2e_ledger_reconcile_status)"
if [[ "$reconcile_status" == "STALE" ]]; then
  pass "ledger reconcile STALE when <22 rows"
else
  fail "ledger reconcile expected STALE for partial fixture, got $reconcile_status"
fi

# --- Multi-host matrix wiring (M1–M6) ---
assert_contains "matrix honors SB_E2E_LIVE_RUNTIME" "$MATRIX" "enterprise_e2e_apply_matrix_host_defaults"
assert_contains "matrix host route translation" "$MATRIX" "enterprise_e2e_matrix_host_route"
assert_contains "matrix host row attempt log" "$MATRIX" "enterprise_e2e_row_attempt_log"
assert_not_contains "matrix hardcodes runtime overwrite" "$MATRIX" "export SB_E2E_LIVE_RUNTIME=claude"
assert_contains "live entrypoint --host flag" "$LIVE" "--host"
assert_contains "live entrypoint host install" "$LIVE" "enterprise_e2e_run_install_host"
assert_contains "helpers cursor runtime" "${REPO_ROOT}/tests/e2e-live/helpers.sh" "cursor/agent.sh"
assert_contains "common host lock file helper" "$HARNESS_CORE" "enterprise_e2e_live_test_lock_file"
assert_file_exists "${HARNESS_ROOT}/lib/adapters/claude.sh" "claude host adapter exists"
assert_file_exists "${HARNESS_ROOT}/lib/adapters/codex.sh" "codex host adapter exists"
assert_file_exists "${HARNESS_ROOT}/lib/adapters/cursor.sh" "cursor host adapter exists"
assert_executable "${HARNESS_ROOT}/lib/deterministic/consecutive-rounds.sh" "deterministic consecutive-rounds shim exists"
assert_contains "monitor detects harness matrix path" "$MONITOR" "enterprise-e2e/matrix.sh"
assert_contains "monitor detects live harness entry" "$MONITOR" "enterprise-e2e/live-test"
assert_file_exists "${REPO_ROOT}/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md" "ROUND-CODEX-1-LEDGER template exists"
assert_file_exists "${REPO_ROOT}/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md" "ROUND-CURSOR-1-LEDGER template exists"
assert_file_exists "${REPO_ROOT}/.planning/enterprise-e2e/CODEX-TUI-PROTOCOL.md" "CODEX-TUI-PROTOCOL exists"
assert_file_exists "${REPO_ROOT}/.planning/enterprise-e2e/CURSOR-TUI-PROTOCOL.md" "CURSOR-TUI-PROTOCOL exists"

export SB_ROOT="$REPO_ROOT"
export SB_E2E_LIVE_RUNTIME=codex
export SILVER_BULLET_RUNTIME=codex
enterprise_e2e_apply_matrix_host_defaults
codex_row_log="$(enterprise_e2e_row_attempt_log 6)"
if [[ "$codex_row_log" == *".e2e-row6-codex-attempt.log" ]]; then
  pass "codex row attempt log is host-prefixed"
else
  fail "codex row log expected host prefix, got $codex_row_log"
fi
codex_lock="$(enterprise_e2e_live_test_lock_file)"
if [[ "$codex_lock" == *".e2e-live-test-codex.lock" ]]; then
  pass "codex live-test lock is host-isolated"
else
  fail "codex lock expected .e2e-live-test-codex.lock, got $codex_lock"
fi
unset SB_E2E_LIVE_RUNTIME SILVER_BULLET_RUNTIME SB_E2E_LIVE_TEST_LOCK_FILE

# --- Consecutive strict-clean round pair (P2 harness) ---
CONSEC_CHECK="${HARNESS_ROOT}/lib/deterministic/consecutive-rounds.sh"
assert_executable "$CONSEC_CHECK" "consecutive rounds check script executable"
CONSEC_TMP="$(mktemp -d)"
cat >"${CONSEC_TMP}/round-a-gates.md" <<'GATES_A'
| Gate | Status |
|------|--------|
| Round strict-clean | **PASS** |
GATES_A
cat >"${CONSEC_TMP}/round-b-gates.md" <<'GATES_B'
| Gate | Status |
|------|--------|
| Round strict-clean | **PASS** |
GATES_B
if RTK_DISABLED=1 bash "$CONSEC_CHECK" "${CONSEC_TMP}/round-a-gates.md" "${CONSEC_TMP}/round-b-gates.md" >/dev/null 2>&1; then
  pass "consecutive rounds check PASS when both rounds strict-clean"
else
  fail "consecutive rounds check expected PASS for dual PASS fixtures"
fi
cat >"${CONSEC_TMP}/round-b-pending.md" <<'GATES_P'
| Gate | Status |
|------|--------|
| Round strict-clean | **PENDING** |
GATES_P
if RTK_DISABLED=1 bash "$CONSEC_CHECK" "${CONSEC_TMP}/round-a-gates.md" "${CONSEC_TMP}/round-b-pending.md" >/dev/null 2>&1; then
  fail "consecutive rounds check expected FAIL when round2 pending"
else
  pass "consecutive rounds check FAIL when round2 not strict-clean"
fi
cat >"${CONSEC_TMP}/claude-round5.md" <<'GATES_5'
| Gate | Status |
|------|--------|
| Round clean (zero new issues vs baseline) | **Pass** |
GATES_5
cat >"${CONSEC_TMP}/claude-round6.md" <<'GATES_6'
| Gate | Status |
|------|--------|
| Round clean (zero new issues vs baseline) | **PASS** |
GATES_6
if RTK_DISABLED=1 bash "$CONSEC_CHECK" "${CONSEC_TMP}/claude-round5.md" "${CONSEC_TMP}/claude-round6.md" --json | jq -e '.ok == true' >/dev/null 2>&1; then
  pass "consecutive rounds check JSON ok for claude-style round clean rows"
else
  fail "consecutive rounds JSON expected ok for claude-style fixtures"
fi
rm -rf "$CONSEC_TMP"
consec_host_out="$(RTK_DISABLED=1 bash "$CONSEC_CHECK" --host codex 2>&1 || true)"
if printf '%s\n' "$consec_host_out" | grep -q "${REPO_ROOT}/.planning/enterprise-e2e/ROUND-CODEX-1-GATES.md"; then
  pass "consecutive rounds --host resolves repo-root gate paths"
else
  fail "consecutive rounds --host must resolve gates under repo .planning/"
fi
assert_contains "rcs wires consecutive rounds env" "${REPO_ROOT}/scripts/enterprise-e2e-rcs.sh" "SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS"
assert_contains "live test wires consecutive rounds env" "$LIVE" "SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS"

# E2E-092: cursor matrix must enforce ≥1800s agent timeout (not inherit legacy 900s).
assert_contains "matrix cursor enforces 1800s minimum timeout" "$HARNESS_MATRIX" 'CLAUDE_INTERACTIVE_TIMEOUT}" -lt 1800'
assert_contains "matrix cursor syncs CURSOR_AGENT_TIMEOUT" "$HARNESS_MATRIX" 'CURSOR_AGENT_TIMEOUT'
assert_executable "${REPO_ROOT}/.planning/enterprise-e2e/cursor3-real-driver.sh" "cursor3 REAL live driver executable"
assert_contains "cursor3 driver exports 1800s timeout" "${REPO_ROOT}/.planning/enterprise-e2e/cursor3-real-driver.sh" "CLAUDE_INTERACTIVE_TIMEOUT=1800"
assert_contains "cursor3 driver resets tui offsets" "${REPO_ROOT}/.planning/enterprise-e2e/cursor3-real-driver.sh" "enterprise_e2e_reset_tui_monitor_offsets"
assert_contains "cursor3 pipeline driver resets tui offsets" "${REPO_ROOT}/.planning/enterprise-e2e/cursor3-real-pipeline-driver.sh" "enterprise_e2e_reset_tui_monitor_offsets"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
