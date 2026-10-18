#!/usr/bin/env bash
# run-enterprise-e2e-{validation,pre-release}-overlay.sh and run-enterprise-e2e-live-test.sh: argument
# parsing, dry-run vs live, counters, JSON summary, exit status -- against a staged SB root whose
# overlay libraries are recording stubs (no matrix, no host CLI, no network).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f4-helpers.sh"
tl_init

R="$TL_TMP/root"
f4_stage "$R"
VAL="$R/scripts/run-enterprise-e2e-validation-overlay.sh"
PRE="$R/scripts/run-enterprise-e2e-pre-release-overlay.sh"
export F4_CALLS="$TL_TMP/calls"
: >"$F4_CALLS"

# stub libraries: each check records itself and bumps the counters the runner prints
rm -f "$R/scripts/lib/enterprise-e2e-validation-overlay.sh" "$R/scripts/lib/enterprise-e2e-pre-release-overlay.sh" \
  "$R/scripts/lib/enterprise-e2e-token-telemetry.sh"
cat >"$R/scripts/lib/enterprise-e2e-validation-overlay.sh" <<'EOS'
validation_overlay_check_registry() { echo "registry $1" >>"$F4_CALLS"; VALIDATION_OVERLAY_PASS=$((VALIDATION_OVERLAY_PASS + 1)); }
validation_overlay_check_evidence_gates_surface() { echo "evidence $1" >>"$F4_CALLS"; VALIDATION_OVERLAY_PASS=$((VALIDATION_OVERLAY_PASS + 1)); }
validation_overlay_check_help_ship_readiness_page() { echo "help $1" >>"$F4_CALLS"; VALIDATION_OVERLAY_SKIP=$((VALIDATION_OVERLAY_SKIP + 1)); }
validation_overlay_check_claims_audit() {
  echo "claims $1 rtk=${RTK_DISABLED:-} compat=$SB_RTK_COMPAT_MODE marker=$SB_E2E_VALIDATION_OVERLAY dry=$SB_E2E_VALIDATION_OVERLAY_DRY_RUN" >>"$F4_CALLS"
  [[ -z "${F4_VAL_FAIL:-}" ]] || VALIDATION_OVERLAY_FAIL=$((VALIDATION_OVERLAY_FAIL + 1))
}
validation_overlay_matrix_row_claims() { echo "rowclaims $1" >>"$F4_CALLS"; VALIDATION_OVERLAY_PASS=$((VALIDATION_OVERLAY_PASS + 1)); }
EOS
cat >"$R/scripts/lib/enterprise-e2e-token-telemetry.sh" <<'EOS'
enterprise_e2e_telemetry_append() { echo "telemetry $1" >>"$F4_CALLS"; }
EOS
cat >"$R/scripts/lib/enterprise-e2e-pre-release-overlay.sh" <<'EOS'
pre_release_overlay_pass() { echo "pass: $1" >>"$F4_CALLS"; VALIDATION_OVERLAY_PASS=$((VALIDATION_OVERLAY_PASS + 1)); }
pre_release_overlay_fail() { echo "fail: $1" >>"$F4_CALLS"; VALIDATION_OVERLAY_FAIL=$((VALIDATION_OVERLAY_FAIL + 1)); }
pre_release_overlay_run_feature_checks() { echo "features $1 dry=$SB_E2E_PRE_RELEASE_OVERLAY_DRY_RUN marker=$SB_E2E_PRE_RELEASE_OVERLAY" >>"$F4_CALLS"; VALIDATION_OVERLAY_PASS=$((VALIDATION_OVERLAY_PASS + 2)); }
pre_release_overlay_check_router_help_page() { echo "router-help $1" >>"$F4_CALLS"; VALIDATION_OVERLAY_SKIP=$((VALIDATION_OVERLAY_SKIP + 1)); }
pre_release_overlay_matrix_row_claims() { echo "rowclaims $1" >>"$F4_CALLS"; [[ -z "${F4_PRE_ROW_FAIL:-}" ]] || VALIDATION_OVERLAY_FAIL=$((VALIDATION_OVERLAY_FAIL + 1)); }
EOS
rm -f "$R/scripts/run-tri-host-install-smoke.sh"
cat >"$R/scripts/run-tri-host-install-smoke.sh" <<'EOS'
#!/usr/bin/env bash
echo "tri-host rtk=${RTK_DISABLED:-}" >>"$F4_CALLS"
[[ -z "${F4_TRI_FAIL:-}" ]]
EOS
chmod +x "$R/scripts/run-tri-host-install-smoke.sh"

# --- validation overlay ---
: >"$F4_CALLS"
tl_run timeout 30 bash "$VAL"
assert_eq "val default exits 0" "0" "$TL_STATUS"
assert_contains "val banner shows dry-run" "$TL_OUT" "mode=dry-run"
assert_contains "val banner shows staged root" "$TL_OUT" "SB_ROOT=$R"
assert_contains "val summary counts" "$TL_OUT" "Validation overlay: 2 passed, 0 failed, 1 skipped (3 checks)"
assert_contains "val exports verbatim RTK mode + marker + dry" "$(cat "$F4_CALLS")" "compat=verbatim marker=1 dry=1"
assert_not_contains "val dry-run skips row claims" "$(cat "$F4_CALLS")" "rowclaims"
assert_contains "val appends telemetry" "$(cat "$F4_CALLS")" "telemetry validation_overlay"
assert_not_contains "val no json by default" "$TL_OUT" '"overlay"'

: >"$F4_CALLS"
tl_run timeout 30 bash "$VAL" --live --json
assert_eq "val live+json exits 0" "0" "$TL_STATUS"
assert_contains "val live mode label" "$TL_OUT" "mode=live-overlay"
assert_contains "val live runs row claims" "$(cat "$F4_CALLS")" "rowclaims $R"
assert_contains "val json mode" "$TL_OUT" '"mode": "live-overlay"'
assert_contains "val json overlay marker" "$TL_OUT" '"overlay": "SB_E2E_VALIDATION_OVERLAY=1"'
assert_contains "val json pass count" "$TL_OUT" '"pass": 3'

tl_run timeout 30 bash "$VAL" --dry-run --json
assert_contains "val --dry-run json mode" "$TL_OUT" '"mode": "dry-run"'

tl_run env SB_E2E_VALIDATION_OVERLAY_DRY_RUN=0 timeout 30 bash "$VAL"
assert_contains "val env dry-run=0 selects live" "$TL_OUT" "mode=live-overlay"

# --json without jq: summary line only, no JSON, still succeeds
tl_run env PATH="$(tl_path_without jq)" timeout 30 bash "$VAL" --json
assert_eq "val --json without jq exits 0" "0" "$TL_STATUS"
assert_not_contains "val --json without jq prints no JSON" "$TL_OUT" '"overlay"'
assert_contains "val --json without jq still prints summary" "$TL_OUT" "Validation overlay:"

tl_run env F4_VAL_FAIL=1 timeout 30 bash "$VAL"
assert_eq "val failing check exits 1" "1" "$TL_STATUS"
assert_contains "val failing check counted" "$TL_OUT" "1 failed"

tl_run timeout 30 bash "$VAL" --help
assert_eq "val help exits 0" "0" "$TL_STATUS"
assert_contains "val help text" "$TL_OUT" "Enterprise E2E validation overlay"
assert_contains "val help lists --json" "$TL_OUT" "--json"
tl_run timeout 30 bash "$VAL" --bogus
assert_eq "val unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "val unknown arg message" "$TL_ERR" "Unknown arg: --bogus"

# --- pre-release overlay ---
: >"$F4_CALLS"
tl_run timeout 30 bash "$PRE"
assert_eq "pre default exits 0" "0" "$TL_STATUS"
assert_contains "pre banner dry-run" "$TL_OUT" "mode=dry-run"
assert_contains "pre summary" "$TL_OUT" "Pre-release overlay: 2 passed, 0 failed, 1 skipped (3 checks)"
assert_contains "pre runs features with dry flag" "$(cat "$F4_CALLS")" "features $R dry=1 marker=1"
assert_contains "pre runs router help" "$(cat "$F4_CALLS")" "router-help $R"
assert_not_contains "pre dry-run skips row claims" "$(cat "$F4_CALLS")" "rowclaims"
assert_not_contains "pre skips tri-host by default" "$(cat "$F4_CALLS")" "tri-host"

: >"$F4_CALLS"
tl_run timeout 30 bash "$PRE" --live
assert_contains "pre live label" "$TL_OUT" "mode=live-overlay"
assert_contains "pre live row claims" "$(cat "$F4_CALLS")" "rowclaims $R"
assert_contains "pre live feature flag" "$(cat "$F4_CALLS")" "dry=0"

: >"$F4_CALLS"
tl_run timeout 30 bash "$PRE" --dry-run --with-tri-host-smoke
assert_eq "pre tri-host ok exits 0" "0" "$TL_STATUS"
assert_contains "pre tri-host banner" "$TL_OUT" "--- Tri-host install smoke ---"
assert_contains "pre tri-host ran with RTK disabled" "$(cat "$F4_CALLS")" "tri-host rtk=1"
assert_contains "pre tri-host pass recorded" "$(cat "$F4_CALLS")" "pass: tri-host install smoke green"

: >"$F4_CALLS"
tl_run env F4_TRI_FAIL=1 timeout 30 bash "$PRE" --with-tri-host-smoke
assert_eq "pre tri-host failure exits 1" "1" "$TL_STATUS"
assert_contains "pre tri-host fail recorded" "$(cat "$F4_CALLS")" "fail: tri-host install smoke failed"
assert_contains "pre tri-host fail counted" "$TL_OUT" "1 failed"

tl_run env SB_E2E_PRE_RELEASE_OVERLAY_DRY_RUN=0 timeout 30 bash "$PRE"
assert_contains "pre env dry-run=0 selects live" "$TL_OUT" "mode=live-overlay"

tl_run timeout 30 bash "$PRE" --help
assert_eq "pre help exits 0" "0" "$TL_STATUS"
assert_contains "pre help text" "$TL_OUT" "Enterprise E2E pre-release overlay"
assert_contains "pre help lists tri-host option" "$TL_OUT" "--with-tri-host-smoke"
tl_run timeout 30 bash "$PRE" -x
assert_eq "pre unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "pre unknown arg message" "$TL_ERR" "Unknown arg: -x"

# --- run-enterprise-e2e-live-test.sh delegates to enterprise-e2e/live-test.sh ---
rm -rf "$R/scripts/enterprise-e2e"
mkdir -p "$R/scripts/enterprise-e2e"
printf '#!/usr/bin/env bash\necho "live-test args=[$*]"\nexit 3\n' >"$R/scripts/enterprise-e2e/live-test.sh"
chmod +x "$R/scripts/enterprise-e2e/live-test.sh"
tl_run timeout 30 bash "$R/scripts/run-enterprise-e2e-live-test.sh" --resume 4 x
assert_eq "wrapper propagates delegate exit status" "3" "$TL_STATUS"
assert_contains "wrapper forwards arguments" "$TL_OUT" "live-test args=[--resume 4 x]"

tl_results
