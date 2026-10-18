#!/usr/bin/env bash
# Behaviour tests for scripts/lib/enterprise-e2e-validation-overlay.sh: every check is run against
# a throw-away SB tree under $TL_TMP, once green and once with the specific defect it guards.
# Collaborator scripts (claims-audit, validate-host-install-surface, check-apo-invariants) are stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-validation-overlay.sh"
NOJQ="$(tl_path_without jq)"

# vo FUNCTION ROOT [ENV-ARG...]: run one check with fresh counters; TL_OUT ends with "counts=P/F/S".
vo() {
  local fn="$1" root="$2"
  shift 2
  e2e_script "source '$LIB'
VALIDATION_OVERLAY_PASS=0; VALIDATION_OVERLAY_FAIL=0; VALIDATION_OVERLAY_SKIP=0
$fn '$root'
echo \"counts=\$VALIDATION_OVERLAY_PASS/\$VALIDATION_OVERLAY_FAIL/\$VALIDATION_OVERLAY_SKIP\"" \
    -u SB_E2E_LEDGER_FILE "$@"
}
counts() { sed -n 's/^counts=//p' <<<"$TL_OUT"; }

# --- pass / fail / skip / sb_root -------------------------------------------
e2e_script "source '$LIB'
VALIDATION_OVERLAY_PASS=0; VALIDATION_OVERLAY_FAIL=0; VALIDATION_OVERLAY_SKIP=0
validation_overlay_pass a; validation_overlay_pass b; validation_overlay_fail c; validation_overlay_skip d
echo \"counts=\$VALIDATION_OVERLAY_PASS/\$VALIDATION_OVERLAY_FAIL/\$VALIDATION_OVERLAY_SKIP\"" E2E_CALL=1
assert_eq "counters increment per outcome" "2/1/1" "$(counts)"
assert_contains "pass line" "$TL_OUT" "PASS: a"
assert_contains "fail line" "$TL_OUT" "FAIL: c"
assert_contains "skip line" "$TL_OUT" "SKIP: d"

e2e_call "$LIB" -u SB_ROOT -- validation_overlay_sb_root
assert_eq "sb_root: derived from the lib location" "$TL_REPO_ROOT" "$TL_OUT"
e2e_call "$LIB" "SB_ROOT=$TL_TMP/x" -- validation_overlay_sb_root
assert_eq "sb_root: SB_ROOT wins" "$TL_TMP/x" "$TL_OUT"

# --- wf_help_slug -----------------------------------------------------------
slug() { e2e_call "$LIB" -- validation_overlay_wf_help_slug "$1"; }
slug WF-SILVER-ROUTER; assert_eq "slug: router" "silver-router" "$TL_OUT"
slug WF-FEATURE; assert_eq "slug: feature without SILVER prefix" "silver-feature" "$TL_OUT"
slug WF-SILVER-BUGFIX; assert_eq "slug: bugfix" "silver-bugfix" "$TL_OUT"
slug WF-SILVER-POST_EXEC_GATES; assert_eq "slug: post-exec-gates has no help page" "" "$TL_OUT"
slug WF-SILVER-VALIDATE_SUBSTEP; assert_eq "slug: validate-substep has no help page" "" "$TL_OUT"
slug WF-SILVER-REVIEW_TRIAD; assert_eq "slug: review triad" "silver-review-triad" "$TL_OUT"
slug WF-SILVER-SHIP_READINESS; assert_eq "slug: ship readiness" "silver-ship-readiness" "$TL_OUT"
slug WF-SILVER-PROCESS_MAINTENANCE; assert_eq "slug: process maintenance" "silver-process-maintenance" "$TL_OUT"
slug WF-SILVER-Some_Other; assert_eq "slug: other ids are lower-cased and dashed" "silver-some-other" "$TL_OUT"

# --- apo catalog counts -----------------------------------------------------
mk_catalog() { # FILE WORKFLOWS ATOMIC
  mkdir -p "$(dirname "$1")"
  jq -n --argjson w "$2" --argjson a "$3" '{workflows: [range($w) | {id: "WF-\(.)"}], atomic_flows: [range($a) | {id: "AF-\(.)"}]}' >"$1"
}
R="$TL_TMP/t1"
vo validation_overlay_check_apo_catalog_counts "$R"
assert_eq "catalog: missing -> FAIL" "0/1/0" "$(counts)"
assert_contains "catalog: missing message" "$TL_OUT" "FAIL: apo-catalog.json missing"
mk_catalog "$R/docs/apo-catalog.json" 22 27
vo validation_overlay_check_apo_catalog_counts "$R"
assert_eq "catalog: 22/27 -> 2 PASS" "2/0/0" "$(counts)"
assert_contains "catalog: workflows pass line" "$TL_OUT" "PASS: apo-catalog has 22 workflows"
assert_contains "catalog: atomic pass line" "$TL_OUT" "PASS: apo-catalog has 27 atomic flows"
mk_catalog "$R/docs/apo-catalog.json" 21 28
vo validation_overlay_check_apo_catalog_counts "$R"
assert_eq "catalog: wrong counts -> 2 FAIL" "0/2/0" "$(counts)"
assert_contains "catalog: workflow mismatch reported" "$TL_OUT" "FAIL: apo-catalog workflows=21 (expected 22)"
assert_contains "catalog: atomic mismatch reported" "$TL_OUT" "FAIL: apo-catalog atomic_flows=28 (expected 27)"
vo validation_overlay_check_apo_catalog_counts "$R" "PATH=$NOJQ"
assert_eq "catalog: no jq -> SKIP" "0/0/1" "$(counts)"
assert_contains "catalog: no jq message" "$TL_OUT" "SKIP: apo-catalog counts (jq missing)"

# --- help version sync ------------------------------------------------------
R="$TL_TMP/t2"
mkdir -p "$R/site/help"
printf '{"version":"1.4.2"}\n' >"$R/package.json"
printf '<p>Silver Bullet v1.4.2 docs</p> v9.9.9\n' >"$R/site/help/index.html"
vo validation_overlay_check_help_version_sync "$R"
assert_eq "version sync: match" "1/0/0" "$(counts)"
assert_contains "version sync: first vX.Y.Z in the page is used" "$TL_OUT" "PASS: help center version matches package.json (1.4.2)"
printf '<p>v1.4.1</p>\n' >"$R/site/help/index.html"
vo validation_overlay_check_help_version_sync "$R"
assert_eq "version sync: mismatch" "0/1/0" "$(counts)"
assert_contains "version sync: mismatch message" "$TL_OUT" "FAIL: help center version 1.4.1 != package.json 1.4.2"
printf '<p>no version here</p>\n' >"$R/site/help/index.html"
vo validation_overlay_check_help_version_sync "$R"
assert_contains "version sync: no version in help page" "$TL_OUT" "FAIL: help version sync — could not read package (1.4.2) or help ()"
rm "$R/site/help/index.html"
vo validation_overlay_check_help_version_sync "$R"
assert_eq "version sync: help page missing -> FAIL (no abort)" "0/1/0" "$(counts)"
printf '<p>v1.4.2</p>\n' >"$R/site/help/index.html"
printf '{"name":"x"}\n' >"$R/package.json"
vo validation_overlay_check_help_version_sync "$R"
assert_contains "version sync: package without version" "$TL_OUT" "FAIL: help version sync — could not read package () or help (1.4.2)"
rm "$R/package.json"
vo validation_overlay_check_help_version_sync "$R"
assert_eq "version sync: package.json missing -> FAIL, not an abort" "0/1/0" "$(counts)"
assert_contains "version sync: package.json missing message" "$TL_OUT" "FAIL: help version sync — could not read package () or help (1.4.2)"
vo validation_overlay_check_help_version_sync "$R" "PATH=$NOJQ"
assert_eq "version sync: no jq -> SKIP" "0/0/1" "$(counts)"

# --- help workflow coverage -------------------------------------------------
R="$TL_TMP/t3"
mkdir -p "$R/docs" "$R/site/help/workflows"
vo validation_overlay_check_help_workflow_coverage "$TL_TMP/t3-none"
assert_contains "coverage: missing catalog and dir" "$TL_OUT" "FAIL: help workflow coverage — missing catalog or help dir"
vo validation_overlay_check_help_workflow_coverage "$R"
assert_eq "coverage: missing catalog only -> FAIL" "0/1/0" "$(counts)"
jq -n '{workflows: [{id:"WF-SILVER-ROUTER"},{id:"WF-SILVER-POST_EXEC_GATES"},{id:"WF-SILVER-VALIDATE_SUBSTEP"},{id:"WF-SILVER-BUGFIX"},{id:""}]}' >"$R/docs/apo-catalog.json"
: >"$R/site/help/workflows/silver-router.html"
vo validation_overlay_check_help_workflow_coverage "$R"
assert_eq "coverage: one page missing" "3/1/0" "$(counts)"
assert_contains "coverage: present page" "$TL_OUT" "PASS: help page exists for WF-SILVER-ROUTER -> silver-router.html"
assert_contains "coverage: internal workflow exempt" "$TL_OUT" "PASS: help optional for internal workflow WF-SILVER-POST_EXEC_GATES"
assert_contains "coverage: other internal workflow exempt" "$TL_OUT" "PASS: help optional for internal workflow WF-SILVER-VALIDATE_SUBSTEP"
assert_contains "coverage: missing page named" "$TL_OUT" "FAIL: help page missing for WF-SILVER-BUGFIX (expected silver-bugfix.html)"
assert_not_contains "coverage: no all-good line while a page is missing" "$TL_OUT" "all user-facing catalog workflows"
: >"$R/site/help/workflows/silver-bugfix.html"
vo validation_overlay_check_help_workflow_coverage "$R"
assert_eq "coverage: all present" "5/0/0" "$(counts)"
assert_contains "coverage: summary line" "$TL_OUT" "PASS: all user-facing catalog workflows have help pages"
vo validation_overlay_check_help_workflow_coverage "$R" "PATH=$NOJQ"
assert_eq "coverage: no jq -> SKIP" "0/0/1" "$(counts)"

# --- host install surface ---------------------------------------------------
R="$TL_TMP/t4"
vo validation_overlay_check_host_install_surface "$R"
assert_contains "surface: script missing" "$TL_OUT" "FAIL: validate-host-install-surface.sh missing"
mkdir -p "$R/scripts"
printf '#!/usr/bin/env bash\n' >"$R/scripts/validate-host-install-surface.sh"
vo validation_overlay_check_host_install_surface "$R"
assert_eq "surface: present but not executable -> FAIL" "0/1/0" "$(counts)"
e2e_stage_override "$R" scripts/validate-host-install-surface.sh '[[ "$1" == "--repo-root" && "$2" == "'"$R"'" ]] && echo "$*" >>"'"$TL_TMP"'/surface.args"; exit 0'
vo validation_overlay_check_host_install_surface "$R"
assert_eq "surface: validator exits 0 -> PASS" "1/0/0" "$(counts)"
assert_eq "surface: validator invoked with --repo-root ROOT" "--repo-root $R" "$(cat "$TL_TMP/surface.args")"
e2e_stage_override "$R" scripts/validate-host-install-surface.sh 'exit 1'
vo validation_overlay_check_host_install_surface "$R"
assert_contains "surface: validator exits 1 -> FAIL" "$TL_OUT" "FAIL: host install surface isolation failed"

# --- tri-host install -------------------------------------------------------
R="$TL_TMP/t5"
vo validation_overlay_check_tri_host_install "$R"
assert_eq "tri-host: nothing present -> 4 FAIL, no summary" "0/4/0" "$(counts)"
mkdir -p "$R/scripts" "$R/hooks"
: >"$R/scripts/install-claude.sh"
chmod +x "$R/scripts/install-claude.sh"
: >"$R/scripts/install-codex.sh"
: >"$R/scripts/install-cursor.sh"
vo validation_overlay_check_tri_host_install "$R"
assert_eq "tri-host: bridge missing -> only the bridge fails" "3/1/0" "$(counts)"
assert_contains "tri-host: bridge message" "$TL_OUT" "FAIL: cursor-hook-bridge.sh missing under hooks/"
assert_contains "tri-host: non-executable script counts as present" "$TL_OUT" "PASS: tri-host script exists: install-codex.sh"
: >"$R/hooks/cursor-hook-bridge.sh"
vo validation_overlay_check_tri_host_install "$R"
assert_eq "tri-host: complete" "5/0/0" "$(counts)"
assert_contains "tri-host: summary line" "$TL_OUT" "PASS: tri-host install surface complete"
rm "$R/scripts/install-cursor.sh"
vo validation_overlay_check_tri_host_install "$R"
assert_contains "tri-host: missing script named" "$TL_OUT" "FAIL: tri-host script missing: install-cursor.sh"
assert_not_contains "tri-host: no summary when incomplete" "$TL_OUT" "install surface complete"

# --- hook surface -----------------------------------------------------------
R="$TL_TMP/t6"
vo validation_overlay_check_hook_surface "$R"
assert_contains "hooks: dir missing" "$TL_OUT" "FAIL: hooks/ directory missing"
mkdir -p "$R/hooks/lib" "$R/hooks/sub.sh"
for i in $(seq 1 11); do : >"$R/hooks/h$i.sh"; done
: >"$R/hooks/lib/nested.sh"
: >"$R/hooks/notes.md"
vo validation_overlay_check_hook_surface "$R"
assert_contains "hooks: 11 top-level files (nested, directories and non-.sh ignored) -> FAIL" "$TL_OUT" "FAIL: hooks/ has 11 scripts (expected >= 12)"
: >"$R/hooks/h12.sh"
vo validation_overlay_check_hook_surface "$R"
assert_contains "hooks: boundary of 12 passes" "$TL_OUT" "PASS: hooks/ has 12 top-level hook scripts (>= 12)"

# --- sb-diagnostics ---------------------------------------------------------
R="$TL_TMP/t7"
mkdir -p "$R/scripts"
vo validation_overlay_check_sb_diagnostics "$R"
assert_contains "diagnostics: missing" "$TL_OUT" "FAIL: sb-diagnostics.sh missing or not executable"
: >"$R/scripts/sb-diagnostics.sh"
vo validation_overlay_check_sb_diagnostics "$R"
assert_eq "diagnostics: not executable" "0/1/0" "$(counts)"
chmod +x "$R/scripts/sb-diagnostics.sh"
vo validation_overlay_check_sb_diagnostics "$R"
assert_contains "diagnostics: executable" "$TL_OUT" "PASS: sb-diagnostics.sh executable"

# --- help index checks ------------------------------------------------------
R="$TL_TMP/t8"
vo validation_overlay_check_help_catalog_sot "$R"
assert_contains "sot: missing index" "$TL_OUT" "FAIL: help index missing docs/apo-catalog.json reference"
mkdir -p "$R/site/help"
printf 'see docs/apo-catalog.json for the list\n' >"$R/site/help/index.html"
vo validation_overlay_check_help_catalog_sot "$R"
assert_contains "sot: referenced" "$TL_OUT" "PASS: help index references docs/apo-catalog.json"
printf 'see docsXapo-catalogXjson\n' >"$R/site/help/index.html"
vo validation_overlay_check_help_catalog_sot "$R"
assert_eq "sot: fixed-string match, not a regex" "0/1/0" "$(counts)"

vo validation_overlay_check_help_tri_host "$TL_TMP/t8-none"
assert_contains "tri-host help: no index" "$TL_OUT" "FAIL: help index tri-host mentions incomplete (0/3)"
printf 'Claude and Cursor only\n' >"$R/site/help/index.html"
vo validation_overlay_check_help_tri_host "$R"
assert_contains "tri-host help: 2 of 3" "$TL_OUT" "FAIL: help index tri-host mentions incomplete (2/3)"
printf 'Claude\nCodex\nCursor\n' >"$R/site/help/index.html"
vo validation_overlay_check_help_tri_host "$R"
assert_contains "tri-host help: all three" "$TL_OUT" "PASS: help index mentions Claude, Codex, and Cursor"

# --- claims audit -----------------------------------------------------------
R="$TL_TMP/t9"
mkdir -p "$R/scripts"
e2e_stage_override "$R" scripts/claims-audit.sh 'echo "rtk=${RTK_DISABLED:-}" >"'"$TL_TMP"'/claims.env"; exit 0'
vo validation_overlay_check_claims_audit "$R"
assert_contains "claims audit: green" "$TL_OUT" "PASS: claims-audit.sh green"
assert_eq "claims audit: run with RTK_DISABLED=1" "rtk=1" "$(cat "$TL_TMP/claims.env")"
e2e_stage_override "$R" scripts/claims-audit.sh 'echo noisy; exit 4'
vo validation_overlay_check_claims_audit "$R"
assert_contains "claims audit: failure" "$TL_OUT" "FAIL: claims-audit.sh failed"
assert_not_contains "claims audit: script output suppressed" "$TL_OUT" "noisy"
rm "$R/scripts/claims-audit.sh"
vo validation_overlay_check_claims_audit "$R"
assert_contains "claims audit: script absent counts as failure" "$TL_OUT" "FAIL: claims-audit.sh failed"

# --- apo invariants ---------------------------------------------------------
R="$TL_TMP/t10"
mkdir -p "$R/scripts"
vo validation_overlay_check_apo_invariants "$R"
assert_eq "invariants: checker missing -> SKIP" "0/0/1" "$(counts)"
assert_contains "invariants: skip message" "$TL_OUT" "SKIP: check-apo-invariants.py missing"
cat >"$R/scripts/check-apo-invariants.py" <<'PYEOF'
import os, sys
with open(os.environ["INV_LOG"], "a") as f:
    f.write(sys.argv[1] + "\n")
sys.exit(1 if sys.argv[1] == os.environ.get("INV_FAIL") else 0)
PYEOF
: >"$TL_TMP/inv.log"
vo validation_overlay_check_apo_invariants "$R" "INV_LOG=$TL_TMP/inv.log"
assert_eq "invariants: both pass" "2/0/0" "$(counts)"
assert_eq "invariants: both checks run in order" "site-doc-freshness apo-hierarchy-integrity" "$(tr '\n' ' ' <"$TL_TMP/inv.log" | sed 's/ $//')"
for f in site-doc-freshness apo-hierarchy-integrity; do
  vo validation_overlay_check_apo_invariants "$R" "INV_LOG=$TL_TMP/inv.log" "INV_FAIL=$f"
  assert_eq "invariants: $f failing is recorded and the check returns normally (no errexit abort)" "1/1/0" "$(counts)"
  assert_contains "invariants: $f failure message" "$TL_OUT" "FAIL: check-apo-invariants.py $f failed"
done

# --- claims registry --------------------------------------------------------
R="$TL_TMP/t11"
REGF="$R/docs/testing/validation-claims-registry.json"
vo validation_overlay_check_registry "$R"
assert_contains "registry: missing" "$TL_OUT" "FAIL: validation-claims-registry.json missing"
mkdir -p "$R/docs/testing"
echo '{"claims":[{},{"validation_scope":"gate"},{"status":"active"},{"validation_scope":"gate","status":"backlog"},{"validation_scope":"live","status":"backlog"},{"validation_scope":"gate","status":"excluded"},{"validation_scope":"telemetry_only"},{"validation_scope":"excluded"}]}' >"$REGF"
vo validation_overlay_check_registry "$R"
assert_eq "registry: counts" "3/0/0" "$(counts)"
assert_contains "registry: gate claims (scope default gate, excluded status dropped)" "$TL_OUT" "PASS: validation registry has 4 outcome claims (8 total incl. telemetry/backlog)"
assert_contains "registry: backlog counts gate and live scopes" "$TL_OUT" "PASS: validation registry gate backlog items: 2"
assert_contains "registry: out-of-gate scope" "$TL_OUT" "PASS: validation registry out-of-gate scope: telemetry_only=1 excluded=1"
echo '{"claims":[{},{},{}]}' >"$REGF"
vo validation_overlay_check_registry "$R"
assert_eq "registry: too few gate claims -> FAIL, no out-of-gate line" "1/1/0" "$(counts)"
assert_contains "registry: too few message" "$TL_OUT" "FAIL: validation registry outcome claims too few (3)"
assert_not_contains "registry: no out-of-gate line when none" "$TL_OUT" "out-of-gate"
echo '{"claims":[{},{},{},{},{"validation_scope":"telemetry_only"}]}' >"$REGF"
vo validation_overlay_check_registry "$R"
assert_contains "registry: only telemetry_only triggers the out-of-gate line" "$TL_OUT" "telemetry_only=1 excluded=0"
vo validation_overlay_check_registry "$R" "PATH=$NOJQ"
assert_eq "registry: no jq -> SKIP" "0/0/1" "$(counts)"

# --- ship-readiness page / evidence gates -----------------------------------
R="$TL_TMP/t12"
vo validation_overlay_check_help_ship_readiness_page "$R"
assert_contains "ship page: missing" "$TL_OUT" "FAIL: help page missing: silver-ship-readiness.html"
mkdir -p "$R/site/help/workflows"
: >"$R/site/help/workflows/silver-ship-readiness.html"
vo validation_overlay_check_help_ship_readiness_page "$R"
assert_contains "ship page: present" "$TL_OUT" "PASS: help page exists: silver-ship-readiness.html"
vo validation_overlay_check_evidence_gates_surface "$R"
assert_contains "evidence gates: no homepage" "$TL_OUT" "FAIL: homepage missing evidence-gates outcome copy"
printf 'Evidence gates blocks unsafe commits before merge\n' >"$R/site/index.html"
vo validation_overlay_check_evidence_gates_surface "$R"
assert_contains "evidence gates: copy present" "$TL_OUT" "PASS: homepage documents evidence-gates outcome"

# --- matrix row claims ------------------------------------------------------
R="$TL_TMP/t13"
mkdir -p "$R/docs/testing"
LEDGER="$TL_TMP/ledger.md"
printf '| 1 | wf | Pass |\n| 2 | wf | Fail |\n| 11 | wf | Pass |\n' >"$LEDGER"
echo '{"matrix_row_claim_map":{"1":["V-01"],"2":["V-02"],"3":["V-03"]}}' >"$R/docs/testing/validation-claims-registry.json"
vo validation_overlay_matrix_row_claims "$R"
assert_eq "rows: no ledger configured -> nothing" "0/0/0" "$(counts)"
vo validation_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$TL_TMP/absent.md"
assert_eq "rows: ledger file missing -> nothing" "0/0/0" "$(counts)"
vo validation_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER" "PATH=$NOJQ"
assert_eq "rows: no jq -> SKIP" "0/0/1" "$(counts)"
assert_contains "rows: no jq message" "$TL_OUT" "SKIP: matrix row claim overlay (jq missing)"
vo validation_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER"
assert_eq "rows: pass / fail / absent" "1/0/2" "$(counts)"
assert_contains "rows: Pass row satisfied" "$TL_OUT" "PASS: matrix row 1 Pass — linked validation claims satisfied by row evidence"
assert_contains "rows: failing row deferred" "$TL_OUT" "SKIP: matrix row 2 not Pass in ledger — claim overlay deferred"
assert_contains "rows: absent row deferred" "$TL_OUT" "SKIP: matrix row 3 not Pass in ledger — claim overlay deferred"
rm "$R/docs/testing/validation-claims-registry.json"
vo validation_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER"
assert_eq "rows: no registry -> nothing" "0/0/0" "$(counts)"
echo 'not json' >"$R/docs/testing/validation-claims-registry.json"
vo validation_overlay_matrix_row_claims "$R" "SB_E2E_LEDGER_FILE=$LEDGER"
assert_eq "rows: unparsable registry -> nothing" "0/0/0" "$(counts)"

tl_results
