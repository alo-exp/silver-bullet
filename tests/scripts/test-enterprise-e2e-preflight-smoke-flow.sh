#!/usr/bin/env bash
# preflight-round.sh and smoke-matrix.sh: gate ordering, host handling and failure propagation
# against a staged SB root whose gate scripts are recording stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init

R="$TL_TMP/root"
f2_stage_root "$R"
cp "$TL_REPO_ROOT/scripts/enterprise-e2e/preflight-round.sh" "$TL_REPO_ROOT/scripts/enterprise-e2e/smoke-matrix.sh" "$R/scripts/enterprise-e2e/"
export F2_CALLS="$TL_TMP/calls"
for s in scripts/validate-host-install-surface.sh scripts/run-tri-host-install-smoke.sh scripts/sync-codex-package.sh \
         scripts/run-enterprise-e2e-matrix.sh scripts/run-enterprise-e2e-live-test.sh \
         tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh tests/scripts/test-outcome-assessment.sh \
         tests/scripts/test-enterprise-e2e-test-app-branch.sh tests/scripts/test-validate-host-install-surface.sh; do
  f2_stub_script "$R/$s" "$s"
done
PRE="$R/scripts/enterprise-e2e/preflight-round.sh"
SMOKE="$R/scripts/enterprise-e2e/smoke-matrix.sh"
export SB_E2E_TEST_APP_BRANCH_ENFORCE=0
export SB_TEST_ENTERPRISE_APP_ROOT="$TL_TMP/app"
unset SB_E2E_LIVE_RUNTIME SB_E2E_PREFLIGHT_SKIP_SURFACE SB_E2E_SURFACE_SKIP SB_E2E_MATRIX_DRY_RUN SB_ENTERPRISE_E2E_LIVE
export SILVER_BULLET_RUNTIME=claude

run() { : >"$F2_CALLS"; tl_run "$@"; CALLS="$(cat "$F2_CALLS")"; }

# ---------------------------------------------------------------- preflight-round.sh
run bash "$PRE" --help
assert_eq "preflight help exit" "0" "$TL_STATUS"
assert_contains "preflight help text" "$TL_OUT" "Gate 0: install contracts"
assert_eq "help runs no gates" "" "$CALLS"

run bash "$PRE" --bogus
assert_eq "preflight unknown arg exit" "2" "$TL_STATUS"
assert_contains "preflight unknown arg message" "$TL_ERR" "Unknown arg: --bogus"

# full run, claude
run bash "$PRE"
assert_eq "full preflight exit" "0" "$TL_STATUS"
assert_contains "full preflight banner" "$TL_OUT" "Enterprise E2E preflight — host=claude harness_only=0"
assert_contains "preflight ok line" "$TL_OUT" "PREFLIGHT OK — Gate 0+1 green for host=claude"
expected_calls="scripts/validate-host-install-surface.sh --repo-root $R --host claude
scripts/run-tri-host-install-smoke.sh --host claude
scripts/sync-codex-package.sh 
tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh 
tests/scripts/test-outcome-assessment.sh 
tests/scripts/test-enterprise-e2e-test-app-branch.sh 
tests/scripts/test-validate-host-install-surface.sh 
scripts/run-enterprise-e2e-matrix.sh 
scripts/run-enterprise-e2e-live-test.sh --preflight-only"
assert_eq "gates run in order" "$expected_calls" "$CALLS"
assert_contains "branch assert gate announced" "$TL_OUT" "=== Gate 1: test-app branch assert (before driver) ==="
assert_contains "branch assert ran (enforcement disabled)" "$TL_OUT" "Test-app branch preflight: skipped"

# harness-only skips gate 0 and the branch assert
run bash "$PRE" --harness-only
assert_eq "harness-only exit" "0" "$TL_STATUS"
assert_contains "gate 0 skipped" "$TL_OUT" "Gate 0: SKIPPED"
assert_contains "branch assert skipped note" "$TL_OUT" "test-app branch assert skipped (--harness-only"
assert_not_contains "no surface validation in harness-only" "$CALLS" "scripts/validate-host-install-surface.sh"
assert_contains "dry-run matrix still runs" "$CALLS" "scripts/run-enterprise-e2e-matrix.sh"

# skip-surface env, surface-skip env (warns on stderr)
run env SB_E2E_PREFLIGHT_SKIP_SURFACE=1 bash "$PRE"
assert_contains "skip-surface env skips gate 0" "$TL_OUT" "Gate 0: SKIPPED"
run env SB_E2E_SURFACE_SKIP=1 bash "$PRE"
assert_contains "surface skip warns" "$TL_ERR" "WARN: SB_E2E_SURFACE_SKIP=1 — install surface bypassed"
assert_contains "surface skip skips gate 0" "$TL_OUT" "Gate 0: SKIPPED"

# --host exports runtime to children; dry-run matrix sees SB_E2E_MATRIX_DRY_RUN=1
cat >"$R/scripts/run-enterprise-e2e-matrix.sh" <<EOS
#!/usr/bin/env bash
printf 'matrix dry=%s live=%s rt=%s\n' "\${SB_E2E_MATRIX_DRY_RUN:-}" "\${SB_E2E_LIVE_RUNTIME:-}" "\${SILVER_BULLET_RUNTIME:-}" >>"\$F2_CALLS"
EOS
run bash "$PRE" --harness-only --host cursor
assert_contains "host banner" "$TL_OUT" "host=cursor"
assert_contains "dry-run matrix env" "$CALLS" "matrix dry=1 live=cursor rt=cursor"
run bash "$PRE" --host bogus --harness-only
assert_contains "unknown host falls back to claude" "$TL_OUT" "host=claude"
f2_stub_script "$R/scripts/run-enterprise-e2e-matrix.sh" scripts/run-enterprise-e2e-matrix.sh

# a failing gate stops the run with its status and no OK line
for step in scripts/validate-host-install-surface.sh scripts/run-tri-host-install-smoke.sh scripts/sync-codex-package.sh \
            tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh tests/scripts/test-outcome-assessment.sh \
            tests/scripts/test-enterprise-e2e-test-app-branch.sh tests/scripts/test-validate-host-install-surface.sh \
            scripts/run-enterprise-e2e-matrix.sh scripts/run-enterprise-e2e-live-test.sh; do
  run env F2_FAIL_STEP="$step" bash "$PRE"
  assert_eq "failure in $step propagates" "7" "$TL_STATUS"
  assert_not_contains "no OK line after $step failure" "$TL_OUT" "PREFLIGHT OK"
done
last_gate_calls="$(wc -l <<<"$CALLS" | tr -d ' ')"
assert_eq "live preflight failure is last step" "9" "$last_gate_calls"

# optional structural tests are skipped when absent
rm -f "$R/tests/scripts/test-enterprise-e2e-test-app-branch.sh" "$R/tests/scripts/test-validate-host-install-surface.sh"
run bash "$PRE" --harness-only
assert_eq "optional structural suites absent" "0" "$TL_STATUS"
assert_not_contains "branch structural skipped" "$CALLS" "test-enterprise-e2e-test-app-branch"
assert_not_contains "surface structural skipped" "$CALLS" "test-validate-host-install-surface"

# branch assert failure aborts before the dry-run matrix (enforced, missing fixture)
f2_stub_script "$R/tests/scripts/test-enterprise-e2e-test-app-branch.sh" tests/scripts/test-enterprise-e2e-test-app-branch.sh
run env SB_E2E_TEST_APP_BRANCH_ENFORCE=1 bash "$PRE"
assert_eq "missing fixture fails preflight" "1" "$TL_STATUS"
assert_not_contains "matrix not reached after branch assert failure" "$CALLS" "run-enterprise-e2e-matrix.sh"

# ---------------------------------------------------------------- smoke-matrix.sh
run bash "$SMOKE" --help
assert_eq "smoke help exit" "0" "$TL_STATUS"
assert_contains "smoke help rows" "$TL_OUT" "Smoke rows: 1 3 6 11 21 22"
run bash "$SMOKE" --bogus
assert_eq "smoke unknown arg exit" "2" "$TL_STATUS"
assert_contains "smoke unknown arg message" "$TL_ERR" "Unknown arg: --bogus"
assert_contains "smoke unknown arg shows usage" "$TL_OUT" "Usage: smoke-matrix.sh"

run bash "$SMOKE" --harness-only
assert_eq "smoke harness-only exit" "0" "$TL_STATUS"
assert_contains "smoke harness-only banner" "$TL_OUT" "=== Enterprise E2E smoke matrix (rows 1 3 6 11 21 22) host=claude ==="
assert_contains "smoke harness-only message" "$TL_OUT" "Smoke matrix: harness-only — live rows skipped"
assert_contains "preflight got --harness-only" "$CALLS" "scripts/run-enterprise-e2e-live-test.sh --preflight-only"
assert_not_contains "no live matrix in harness-only" "$CALLS" "scripts/run-enterprise-e2e-matrix.sh 1"

run bash "$SMOKE" --host codex --harness-only
assert_contains "smoke host passed to preflight" "$TL_OUT" "host=codex"

run bash "$SMOKE"
assert_eq "live opt-in required" "2" "$TL_STATUS"
assert_contains "live opt-in message" "$TL_ERR" "set SB_ENTERPRISE_E2E_LIVE=1 for live smoke rows"

run env SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_SURFACE_SKIP=1 bash "$SMOKE"
assert_eq "surface skip refused for live smoke" "2" "$TL_STATUS"
assert_contains "surface skip message" "$TL_ERR" "SB_E2E_SURFACE_SKIP=1 — smoke live requires install surface"

# live run: exec's the matrix with the smoke rows and exported runtime
cat >"$R/scripts/run-enterprise-e2e-matrix.sh" <<EOS
#!/usr/bin/env bash
printf 'matrix args=%s live=%s rt=%s rtk=%s dry=%s\n' "\$*" "\${SB_E2E_LIVE_RUNTIME:-}" "\${SILVER_BULLET_RUNTIME:-}" "\${RTK_DISABLED:-}" "\${SB_E2E_MATRIX_DRY_RUN:-}" >>"\$F2_CALLS"
exit 0
EOS
chmod +x "$R/scripts/run-enterprise-e2e-matrix.sh"
run env SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_LIVE_RUNTIME=codex bash "$SMOKE" --host codex
assert_eq "live smoke exit" "0" "$TL_STATUS"
assert_contains "live rows header" "$TL_OUT" "=== Live smoke rows 1 3 6 11 21 22 ==="
assert_contains "matrix execed with smoke rows and host" "$CALLS" "matrix args=1 3 6 11 21 22 live=codex rt=codex rtk=1 dry="
run env SB_ENTERPRISE_E2E_LIVE=1 RTK_DISABLED=0 bash "$SMOKE"
assert_contains "explicit RTK_DISABLED preserved" "$CALLS" "rtk=0"
assert_contains "host defaults to SILVER_BULLET_RUNTIME" "$CALLS" "live=claude rt=claude"

# a failing preflight stops the smoke run
f2_stub_script "$R/scripts/run-enterprise-e2e-live-test.sh" scripts/run-enterprise-e2e-live-test.sh
run env SB_ENTERPRISE_E2E_LIVE=1 F2_FAIL_STEP=scripts/run-enterprise-e2e-live-test.sh bash "$SMOKE"
assert_eq "smoke stops on preflight failure" "7" "$TL_STATUS"
assert_not_contains "no live rows after failed preflight" "$TL_OUT" "Live smoke rows"

tl_results
