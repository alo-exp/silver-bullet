# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are consumed by the sourcing tests
# Shared setup for the matrix.sh runner tests: staged SB root, fixture repo, env, gate overrides and
# the reset/agent/run helpers. Source after tl_init and enterprise-e2e-f2-helpers.sh.
# shellcheck source=tests/e2e-live/lib/skill-prompt.sh
source "$TL_REPO_ROOT/tests/e2e-live/lib/skill-prompt.sh"

R="$TL_TMP/root"
f2_stage_matrix "$R"
cp "$TL_REPO_ROOT/scripts/enterprise-e2e/matrix.sh" "$R/scripts/enterprise-e2e/"
MATRIX="$R/scripts/enterprise-e2e/matrix.sh"
APP="$TL_TMP/app"
mkdir -p "$APP"
git -C "$APP" init -q -b main
git -C "$APP" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m baseline
BASE="$(git -C "$APP" rev-parse HEAD)"

export F2_CALLS="$TL_TMP/calls"
export F2_CTL="$TL_TMP/ctl"
mkdir -p "$F2_CTL"
REG="$TL_TMP/registry.json"
unset SB_E2E_LIVE_RUNTIME SB_E2E_MATRIX_DRY_RUN SB_E2E_MATRIX_FORCE SB_E2E_MATRIX_FORCE_ALL SB_E2E_MATRIX_FAIL_ON_SKIP \
  SB_E2E_MATRIX_CLEAN_ENV SB_E2E_MATRIX_OAUTH_ONLY CLAUDE_INTERACTIVE_TIMEOUT CURSOR_AGENT_TIMEOUT F2_OVERRIDES F2_FAIL_STEP \
  F2_HOSTBRANCH_FAIL SB_E2E_PRODUCT_WORK_GATE SB_E2E_TEST_APP_BASELINE_SHA SB_E2E_OUTCOME_ONLY_ROWS SB_E2E_PRODUCT_WORK_CUMULATIVE \
  F2_TELEMETRY_FAIL F2_ENSURE_FAIL_AT F2_LOCK_FAIL_AT F2_BASELINE_FAIL_AT F2_DELTA_FAIL_AT F2_CHECKLIST_FAIL F2_ATTEMPT_LOG_FAIL_FIRST F2_AGENT_MISSING F2_RUNTIME_STATE_FAIL F2_EVPATH_FAIL
export SILVER_BULLET_RUNTIME=claude
export SB_TEST_ENTERPRISE_APP_ROOT="$APP"
export SB_E2E_LEDGER_FILE="$TL_TMP/ledger.md"
export SB_E2E_ROW_PASS_REGISTRY="$REG"
export SB_E2E_MATRIX_BATCH_PID_FILE="$TL_TMP/batch.pid"
export SB_E2E_HOST_GIT_BRANCH_ENFORCE=0
export SB_E2E_TEST_APP_BRANCH_ENFORCE=0
export SB_E2E_FIXTURE_BRANCH_PIN=0
export SB_E2E_FIXTURE_BRANCH_LOCK=0
export SB_E2E_PRODUCT_WORK_GATE=0
export SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=7
export F2_RECORD_HEAVY=1

tl_stub sleep 'printf "sleep %s\n" "$*" >>"$F2_CALLS"'
# find fails when $F2_CTL/find-fail-<marker> exists and <marker> is among its arguments (simulates a workflow
# marker the search cannot see); the fake outcome scorer can remove the flag again (see f2_heal)
tl_stub find '[[ ! -f "$F2_CTL/find-slow" ]] || { printf "a.md\\n"; /bin/sleep 0.2; printf "b.md\\n"; exit 0; }
for f in "$F2_CTL"/find-fail-*; do [[ -e "$f" && " $* " == *"${f##*find-fail-}"* ]] && exit 1; done; exec /usr/bin/find "$@"'

# gate overrides, active only for the F2_*_FAIL_AT switch that is set: the Nth call fails
cat >"$TL_TMP/overrides.sh" <<'EOS'
_f2_count() { local f="$F2_CTL/count-$1" n; n=$(($(cat "$f" 2>/dev/null || echo 0) + 1)); echo "$n" >"$f"; printf '%s' "$n"; }
if [[ -n "${F2_ENSURE_FAIL_AT:-}" ]]; then
  enterprise_e2e_fixture_ensure_branch() { local n; n="$(_f2_count ensure)"; [[ "$n" != "$F2_ENSURE_FAIL_AT" ]]; }
fi
if [[ -n "${F2_LOCK_FAIL_AT:-}" ]]; then
  enterprise_e2e_fixture_assert_branch_lock() {
    local n; n="$(_f2_count lock)"
    printf 'branch-lock#%s %s\n' "$n" "${2:-}" >>"$F2_CALLS"
    [[ "$n" != "$F2_LOCK_FAIL_AT" ]]
  }
fi
if [[ -n "${F2_BASELINE_FAIL_AT:-}" ]]; then
  enterprise_e2e_assert_row_matrix_baseline_rev_increase() { local n; n="$(_f2_count baseline)"; [[ "$n" != "$F2_BASELINE_FAIL_AT" ]]; }
fi
if [[ -n "${F2_RUNTIME_STATE_FAIL:-}" ]]; then
  enterprise_e2e_runtime_state_dir() { return 1; }
fi
if [[ -n "${F2_ATTEMPT_LOG_FAIL_FIRST:-}" ]]; then
  eval "_f2_real_attempt_log() $(declare -f enterprise_e2e_row_attempt_log | tail -n +2)"
  enterprise_e2e_row_attempt_log() {
    local n; n="$(_f2_count attemptlog)"
    if ((n <= F2_ATTEMPT_LOG_FAIL_FIRST)); then return 1; fi
    _f2_real_attempt_log "$@"
  }
fi
if [[ -n "${F2_DELTA_FAIL_AT:-}" ]]; then
  enterprise_e2e_assert_row_product_commit_delta() { local n; n="$(_f2_count delta)"; [[ "$n" != "$F2_DELTA_FAIL_AT" ]]; }
fi
EOS
export F2_OVERRIDES="$TL_TMP/overrides.sh"

STATE="$SB_RUNTIME_STATE_DIR/state"
EVID2="$APP/docs/ADR-001-runtime.md"

reset() { # clean scenario state
  rm -rf "${F2_CTL:?}"/* "$REG" "$APP/docs" "$APP/.planning" "$STATE" "$SB_RUNTIME_STATE_DIR"/e2e-matrix-routing-row "$R"/.e2e-row*-attempt*.log
  : >"$F2_CALLS"
}
agent() { cat >"$F2_CTL/agent.sh"; }
run() { : >"$F2_CALLS"; tl_run "$@"; CALLS="$(cat "$F2_CALLS")"; }
evidence_agent() { agent <<'EOS'
mkdir -p "$WORK_DIR/docs"
echo "adr" >"$WORK_DIR/docs/ADR-001-runtime.md"
echo "agent said hello"
EOS
}

