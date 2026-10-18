#!/usr/bin/env bash
# Behaviour tests for scripts/lib/enterprise-e2e-pre-release-overlay.sh against a throw-away SB tree
# under $TL_TMP (registry, tri-host script, router help page, matrix-row claims, feature-check fan-out).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-pre-release-overlay.sh"
NOJQ="$(tl_path_without jq)"

# po FUNCTION ROOT [ENV-ARG...]: run one function with fresh counters; TL_OUT ends with "counts=P/F/S".
po() {
  local fn="$1" root="$2"
  shift 2
  e2e_script "source '$LIB'
VALIDATION_OVERLAY_PASS=0; VALIDATION_OVERLAY_FAIL=0; VALIDATION_OVERLAY_SKIP=0
$fn '$root'
echo \"counts=\$VALIDATION_OVERLAY_PASS/\$VALIDATION_OVERLAY_FAIL/\$VALIDATION_OVERLAY_SKIP\"" \
    -u SB_E2E_LEDGER_FILE "$@"
}
counts() { sed -n 's/^counts=//p' <<<"$TL_OUT"; }

# --- thin wrappers ----------------------------------------------------------
e2e_script "source '$LIB'
VALIDATION_OVERLAY_PASS=0; VALIDATION_OVERLAY_FAIL=0; VALIDATION_OVERLAY_SKIP=0
pre_release_overlay_pass p; pre_release_overlay_fail f; pre_release_overlay_fail g; pre_release_overlay_skip s
echo \"counts=\$VALIDATION_OVERLAY_PASS/\$VALIDATION_OVERLAY_FAIL/\$VALIDATION_OVERLAY_SKIP\"" E2E_CALL=1
assert_eq "wrappers feed the shared validation counters" "1/2/1" "$(counts)"
assert_contains "wrapper pass line" "$TL_OUT" "PASS: p"
assert_contains "wrapper fail line" "$TL_OUT" "FAIL: f"
assert_contains "wrapper skip line" "$TL_OUT" "SKIP: s"

# --- registry ---------------------------------------------------------------
R="$TL_TMP/t1"
REGF="$R/docs/testing/pre-release-claims-registry.json"
po pre_release_overlay_check_registry "$R"
assert_eq "registry: missing -> FAIL" "0/1/0" "$(counts)"
assert_contains "registry: missing message" "$TL_OUT" "FAIL: pre-release-claims-registry.json missing"
mkdir -p "$R/docs/testing" "$R/scripts"
: >"$R/scripts/smoke.sh"
jq -n '{claims: [range(10) | {id: .}], tri_host_smoke: {script: "scripts/smoke.sh"}}' >"$REGF"
po pre_release_overlay_check_registry "$R"
assert_eq "registry: 10 claims and wired smoke script" "2/0/0" "$(counts)"
assert_contains "registry: claim count line" "$TL_OUT" "PASS: pre-release registry has 10 feature claims"
assert_contains "registry: smoke wired line" "$TL_OUT" "PASS: tri-host smoke script wired: scripts/smoke.sh"
jq -n '{claims: [range(9) | {id: .}], tri_host_smoke: {script: "scripts/gone.sh"}}' >"$REGF"
po pre_release_overlay_check_registry "$R"
assert_eq "registry: 9 claims and missing script" "0/2/0" "$(counts)"
assert_contains "registry: too small message" "$TL_OUT" "FAIL: pre-release registry too small (9)"
assert_contains "registry: missing smoke script message" "$TL_OUT" "FAIL: tri-host smoke script missing: scripts/gone.sh"
jq -n '{claims: [range(10) | {id: .}]}' >"$REGF"
po pre_release_overlay_check_registry "$R"
assert_eq "registry: no tri_host_smoke entry fails the wiring check" "1/1/0" "$(counts)"
assert_contains "registry: empty smoke path message" "$TL_OUT" "FAIL: tri-host smoke script missing: "
echo 'not json' >"$REGF"
po pre_release_overlay_check_registry "$R"
assert_eq "registry: malformed JSON -> FAIL, no abort" "0/1/0" "$(counts)"
assert_contains "registry: malformed JSON message" "$TL_OUT" "FAIL: pre-release-claims-registry.json unreadable"
po pre_release_overlay_check_registry "$R" "PATH=$NOJQ"
assert_eq "registry: no jq -> SKIP" "0/0/1" "$(counts)"
assert_contains "registry: no jq message" "$TL_OUT" "SKIP: pre-release registry parse (jq missing)"

# --- router help page -------------------------------------------------------
R="$TL_TMP/t2"
po pre_release_overlay_check_router_help_page "$R"
assert_contains "router page: missing" "$TL_OUT" "FAIL: help page missing: silver-router.html"
mkdir -p "$R/site/help/workflows"
: >"$R/site/help/workflows/silver-router.html"
po pre_release_overlay_check_router_help_page "$R"
assert_contains "router page: present" "$TL_OUT" "PASS: help page exists: silver-router.html"

# --- run_feature_checks fans out to the registry and every shared check ------
R="$TL_TMP/t3"
mkdir -p "$R"
CALLS="$TL_TMP/fanout.calls"
: >"$CALLS"
e2e_script "source '$LIB'
for fn in pre_release_overlay_check_registry validation_overlay_check_apo_catalog_counts \
  validation_overlay_check_help_version_sync validation_overlay_check_help_workflow_coverage \
  validation_overlay_check_help_catalog_sot validation_overlay_check_help_tri_host \
  validation_overlay_check_tri_host_install validation_overlay_check_host_install_surface \
  validation_overlay_check_hook_surface validation_overlay_check_sb_diagnostics \
  validation_overlay_check_apo_invariants; do
  eval \"\$fn() { echo \$fn \\\"\\\$1\\\" >>'$CALLS'; }\"
done
pre_release_overlay_run_feature_checks '$R'" E2E_CALL=1
assert_eq "feature checks: status" 0 "$TL_STATUS"
assert_eq "feature checks: registry first, then the ten shared checks in order, all given the root" \
  "pre_release_overlay_check_registry $R
validation_overlay_check_apo_catalog_counts $R
validation_overlay_check_help_version_sync $R
validation_overlay_check_help_workflow_coverage $R
validation_overlay_check_help_catalog_sot $R
validation_overlay_check_help_tri_host $R
validation_overlay_check_tri_host_install $R
validation_overlay_check_host_install_surface $R
validation_overlay_check_hook_surface $R
validation_overlay_check_sb_diagnostics $R
validation_overlay_check_apo_invariants $R" "$(cat "$CALLS")"

# end-to-end on an empty tree: every real check runs and records an outcome (nothing aborts)
po pre_release_overlay_run_feature_checks "$R" "PATH=$NOJQ"
assert_eq "feature checks on an empty tree (no jq): all complete" 0 "$TL_STATUS"
assert_contains "feature checks: registry reported" "$TL_OUT" "FAIL: pre-release-claims-registry.json missing"
assert_contains "feature checks: catalog counts reported" "$TL_OUT" "FAIL: apo-catalog.json missing"
assert_contains "feature checks: last check reported" "$TL_OUT" "SKIP: check-apo-invariants.py missing"
assert_match "feature checks: counters add up" '^counts=0/[0-9]+/[0-9]+$' "$(sed -n '/^counts=/p' <<<"$TL_OUT")"

# --- matrix row claims ------------------------------------------------------
R="$TL_TMP/t4"
mkdir -p "$R/docs/testing"
REGF="$R/docs/testing/pre-release-claims-registry.json"
LEDGER="$TL_TMP/ledger.md"
printf '| 1 | wf | Pass |\n| 2 | wf | Fail |\n| 11 | wf | Pass |\n' >"$LEDGER"
echo '{"matrix_row_claim_map":{"1":["C-1"],"2":["C-2"],"3":["C-3"],"11":["C-11"]}}' >"$REGF"
po pre_release_overlay_matrix_row_claims "$R"
assert_eq "rows: no ledger configured -> nothing" "0/0/0" "$(counts)"
po pre_release_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$TL_TMP/absent.md"
assert_eq "rows: ledger file missing -> nothing" "0/0/0" "$(counts)"
po pre_release_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER" "PATH=$NOJQ"
assert_eq "rows: no jq -> SKIP" "0/0/1" "$(counts)"
assert_contains "rows: no jq message" "$TL_OUT" "SKIP: pre-release matrix row overlay (jq missing)"
po pre_release_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER"
assert_eq "rows: 1 and 11 pass; 2 fails; 3 absent" "2/0/2" "$(counts)"
assert_contains "rows: Pass row 1" "$TL_OUT" "PASS: pre-release matrix row 1 Pass — feature claims satisfied"
assert_contains "rows: Pass row 11 (row 1 pattern does not shadow it)" "$TL_OUT" "PASS: pre-release matrix row 11 Pass — feature claims satisfied"
assert_contains "rows: failing row deferred" "$TL_OUT" "SKIP: pre-release matrix row 2 not Pass — deferred"
assert_contains "rows: absent row deferred" "$TL_OUT" "SKIP: pre-release matrix row 3 not Pass — deferred"
rm "$REGF"
po pre_release_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER"
assert_eq "rows: no registry -> nothing" "0/0/0" "$(counts)"
echo 'not json' >"$REGF"
po pre_release_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER"
assert_eq "rows: unparsable registry -> nothing" "0/0/0" "$(counts)"

tl_results
