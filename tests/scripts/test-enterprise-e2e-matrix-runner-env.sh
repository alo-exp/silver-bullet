#!/usr/bin/env bash
# matrix.sh: host/env defaults, usage, argument routing and dry-run behaviour against a staged
# SB root (agent, auth and outcome scorer are recording stubs; nothing leaves the sandbox).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude

R="$TL_TMP/root"
f2_stage_matrix "$R"
cp "$TL_REPO_ROOT/scripts/enterprise-e2e/matrix.sh" "$R/scripts/enterprise-e2e/"
MATRIX="$R/scripts/enterprise-e2e/matrix.sh"
APP="$TL_TMP/app"
mkdir -p "$APP"
git -C "$APP" init -q -b main
git -C "$APP" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init

export F2_CALLS="$TL_TMP/calls"
export F2_CTL="$TL_TMP/ctl"
mkdir -p "$F2_CTL"
unset SB_E2E_LIVE_RUNTIME SB_E2E_MATRIX_DRY_RUN SB_E2E_MATRIX_FORCE SB_E2E_MATRIX_FORCE_ALL SB_E2E_MATRIX_FAIL_ON_SKIP \
  SB_E2E_MATRIX_CLEAN_ENV SB_E2E_MATRIX_OAUTH_ONLY CLAUDE_INTERACTIVE_TIMEOUT CURSOR_AGENT_TIMEOUT F2_OVERRIDES F2_FAIL_STEP \
  F2_HOSTBRANCH_FAIL F2_RECORD_HEAVY SB_E2E_PRODUCT_WORK_GATE SB_E2E_TEST_APP_BASELINE_SHA
export SILVER_BULLET_RUNTIME=claude
export SB_TEST_ENTERPRISE_APP_ROOT="$APP"
export SB_E2E_LEDGER_FILE="$TL_TMP/ledger.md"
export SB_E2E_ROW_PASS_REGISTRY="$TL_TMP/registry.json"
export SB_E2E_MATRIX_BATCH_PID_FILE="$TL_TMP/batch.pid"
export SB_E2E_HOST_GIT_BRANCH_ENFORCE=0
export SB_E2E_TEST_APP_BRANCH_ENFORCE=0
export SB_E2E_FIXTURE_BRANCH_PIN=0
export SB_E2E_FIXTURE_BRANCH_LOCK=0
export F2_RECORD_HEAVY=1

run() { : >"$F2_CALLS"; tl_run "$@"; CALLS="$(cat "$F2_CALLS")"; }

# --------------------------------------------------------------------- usage / bad environment
run bash "$MATRIX" --help
assert_eq "help exit" "0" "$TL_STATUS"
assert_contains "help usage line" "$TL_OUT" "Usage: matrix.sh [row_numbers...]"
assert_contains "help names host" "$TL_OUT" "(host: claude)"
assert_contains "help names fixture" "$TL_OUT" "Fixture: $APP"
assert_contains "help names ledger" "$TL_OUT" "Ledger:  $TL_TMP/ledger.md"
assert_contains "help documents dry run" "$TL_OUT" "SB_E2E_MATRIX_DRY_RUN=1"
run bash "$MATRIX" -h
assert_eq "-h exit" "0" "$TL_STATUS"

run env F2_HOSTBRANCH_FAIL=1 bash "$MATRIX" 2
assert_eq "host branch failure exits 1 before anything runs" "1" "$TL_STATUS"
assert_not_contains "no workspace setup after host branch failure" "$CALLS" "setup_workspace"

run env SB_TEST_ENTERPRISE_APP_ROOT="$TL_TMP/nofixture" bash "$MATRIX" 2
assert_eq "missing fixture exit" "1" "$TL_STATUS"
assert_contains "missing fixture message" "$TL_ERR" "ERROR: fixture not found at $TL_TMP/nofixture"

# fixture branch pin failure aborts the whole matrix
run env SB_E2E_FIXTURE_BRANCH_PIN=1 SB_E2E_TEST_APP_BRANCH=no-such-branch bash "$MATRIX" 2
assert_eq "branch pin failure exit" "1" "$TL_STATUS"
assert_contains "branch pin failure message" "$TL_ERR" "ERROR: cannot pin fixture branch before matrix"
# branch lock failure aborts the whole matrix
run env SB_E2E_FIXTURE_BRANCH_PIN=1 SB_E2E_FIXTURE_BRANCH_LOCK=1 SB_E2E_TEST_APP_BRANCH=main SB_E2E_TEST_APP_EXCLUDE_ANCESTOR="$(git -C "$APP" rev-parse HEAD)" bash "$MATRIX" 2
assert_eq "branch lock failure exit" "1" "$TL_STATUS"
assert_contains "branch lock failure message" "$TL_ERR" "ERROR: fixture branch lock failed before matrix"

# --------------------------------------------------------------------- dry run
mkdir -p "$APP/docs"
printf 'adr\n' >"$APP/docs/ADR-001-runtime.md"
run env SB_E2E_MATRIX_DRY_RUN=1 bash "$MATRIX" 2
assert_eq "dry-run with evidence passes row" "0" "$TL_STATUS"
assert_contains "dry-run row header" "$TL_OUT" "=== Row 2: silver-deep-research (/sb:deep-research) ==="
assert_contains "dry-run graphify line" "$TL_OUT" '  graphify: graphify query "silver-deep-research routes hooks skills orchestrator"'
assert_contains "dry-run evidence line" "$TL_OUT" "  evidence: docs/ADR-001-runtime.md"
assert_contains "dry-run pass" "$TL_OUT" "  DRY RUN PASS: evidence present"
assert_contains "dry-run summary" "$TL_OUT" "Pass:  1"
assert_contains "dry-run total" "$TL_OUT" "Total: 1 / 22"
assert_contains "dry-run telemetry pass" "$CALLS" "telemetry matrix_row_dry_run row=2 slug=silver-deep-research result=pass log="
assert_not_contains "dry-run does not set up a workspace" "$CALLS" "setup_workspace"
assert_file_absent "dry-run writes no batch pid file" "$TL_TMP/batch.pid"
assert_contains "banner shows agent" "$TL_OUT" "Agent:      /stub/agent-cli"

run env SB_E2E_MATRIX_DRY_RUN=1 F2_TELEMETRY_FAIL=1 bash "$MATRIX" 3 2
assert_eq "dry-run with a missing row fails" "1" "$TL_STATUS"
assert_contains "dry-run missing evidence" "$TL_OUT" "  DRY RUN FAIL: missing evidence"
assert_contains "dry-run honours argv order" "$(grep -n '=== Row' <<<"$TL_OUT" | sed 's/^[0-9]*://' | paste -sd'|' -)" "=== Row 3: silver-feature (/sb:feature) ===|=== Row 2: silver-deep-research (/sb:deep-research) ==="
assert_contains "dry-run fail summary" "$TL_OUT" "Fail:  1"
assert_contains "failing telemetry tolerated" "$CALLS" "telemetry matrix_row_dry_run row=3 slug=silver-feature result=fail"

# no rows: every matrix row in definition order, plus internal rows 21 and 22
run env SB_E2E_MATRIX_DRY_RUN=1 bash "$MATRIX"
assert_eq "full dry-run fails on missing evidence" "1" "$TL_STATUS"
assert_eq "all 20 explicit rows visited" "20" "$(grep -cE '^=== Row [0-9]+: [a-z-]+ \(' <<<"$TL_OUT" | tr -d ' ')"
assert_contains "row 1 first" "$(grep '^=== Row' <<<"$TL_OUT" | head -1)" "=== Row 1: silver-router (/sb) ==="
assert_contains "row 20 last explicit row" "$(grep -E '^=== Row [0-9]+: [a-z-]+ \(' <<<"$TL_OUT" | tail -1)" "=== Row 20: process-maintenance (/sb:process-maintenance) ==="
assert_contains "row 21 internal pass" "$TL_OUT" "=== Row 21: post-exec-gates (internal) PASS ==="
assert_contains "row 22 internal pass" "$TL_OUT" "=== Row 22: validate-substep (internal) PASS ==="
assert_contains "internal markers seeded in the fixture" "$(cat "$APP/.planning/workflows/feature-currency.md")" "post-exec-gates"
assert_contains "total counts 22" "$TL_OUT" "Total: 22 / 22"

# an unknown row number runs nothing
run env SB_E2E_MATRIX_DRY_RUN=1 bash "$MATRIX" 99
assert_eq "unknown row exits 0" "0" "$TL_STATUS"
assert_not_contains "unknown row visits nothing" "$TL_OUT" "=== Row"

# --------------------------------------------------------------------- live setup per host
run bash "$MATRIX" 99
assert_eq "live setup with no matching rows" "0" "$TL_STATUS"
assert_contains "workspace set up" "$CALLS" "setup_workspace"
assert_contains "workspace cleaned up on exit" "$CALLS" "cleanup_workspace"
assert_file_absent "batch pid file removed on exit" "$TL_TMP/batch.pid"
assert_contains "claude auth env exported" "$CALLS" "claude_matrix_export_settings_env skipexport=0 strategy=arrow anthropic_key=unset"
assert_contains "mcp env prepared with fixture" "$CALLS" "mcp-env $APP"

run env SB_E2E_MATRIX_OAUTH_ONLY=1 ANTHROPIC_API_KEY=secret ANTHROPIC_BASE_URL=http://x bash "$MATRIX" 99
assert_contains "oauth-only skips settings export and unsets API key" "$CALLS" "claude_matrix_export_settings_env skipexport=1 strategy=recommended anthropic_key=unset"
run env SB_E2E_MATRIX_OAUTH_ONLY=1 CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=custom bash "$MATRIX" 99
assert_contains "oauth-only keeps an explicit strategy" "$CALLS" "strategy=custom"

# without the optional batch pid helper the EXIT trap only cleans the workspace
cat >"$TL_TMP/no-pid-helper.sh" <<'EOS'
unset -f enterprise_e2e_matrix_batch_pid_file
EOS
run env F2_OVERRIDES="$TL_TMP/no-pid-helper.sh" bash "$MATRIX" 99
assert_eq "no pid helper still runs" "0" "$TL_STATUS"
assert_contains "workspace cleaned up without pid helper" "$CALLS" "cleanup_workspace"
assert_file_absent "no pid file without helper" "$TL_TMP/batch.pid"

# non-claude hosts skip the claude auth block
run env SILVER_BULLET_RUNTIME=codex SB_E2E_LIVE_RUNTIME=codex bash "$MATRIX" 99
assert_eq "codex live setup exit" "0" "$TL_STATUS"
assert_not_contains "no claude auth for codex" "$CALLS" "claude_matrix_export_settings_env"
assert_contains "banner host codex" "$TL_OUT" "Host:       codex"

tl_results
