#!/usr/bin/env bash
# strict-clean-check.sh: ledger/outcome/registry eligibility verdicts against a staged SB root.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SRC="$TL_REPO_ROOT/scripts/enterprise-e2e/strict-clean-check.sh"
HEADER='| # | WF slug | Workflow | Pass/Fail | graphify_query_ref | agentmemory_export_ref |'
SEP='|---|---|---|---|---|---|'

# stage_root DIR: staged SB root with the real script and ledger-reconcile library and stub
# collaborators whose behaviour is steered by files under $DIR/ctl.
stage_root() {
  local root="$1"
  mkdir -p "$root/scripts/enterprise-e2e" "$root/scripts/lib" "$root/ctl" "$root/.planning/enterprise-e2e"
  cp "$SRC" "$root/scripts/enterprise-e2e/"
  cp "$TL_REPO_ROOT/scripts/lib/enterprise-e2e-ledger-reconcile.sh" "$root/scripts/lib/"
  : >"$root/scripts/lib/enterprise-e2e-live-common.sh"
  cat >"$root/scripts/lib/enterprise-e2e-outcome-assessment.sh" <<EOS
enterprise_e2e_outcome_row_passes() {
  # args: row fixture state_dir row_log ledger evidence
  printf '%s|%s|%s|%s\n' "\$1" "\$2" "\$3" "\$4" >>"$root/ctl/outcome-calls"
  [[ ! -f "$root/ctl/outcome-fail-\$1" ]]
}
EOS
  cat >"$root/scripts/lib/enterprise-e2e-row-pass-registry.sh" <<EOS
enterprise_e2e_row_attempt_log() {
  [[ -f "$root/ctl/no-attempt-log" ]] && return 1
  printf '%s\n' "$root/ctl/row-\$1.log"
}
EOS
  if [[ "${WITH_REGISTRY:-1}" == "1" ]]; then
    cat >>"$root/scripts/lib/enterprise-e2e-row-pass-registry.sh" <<EOS
enterprise_e2e_row_pass_registry_pass_count() { cat "$root/ctl/registry-count"; }
enterprise_e2e_install_fingerprint() { printf 'claude@abc+def\n'; }
EOS
  fi
}

# mk_ledger FILE PASS_COUNT
mk_ledger() {
  local file="$1" pass="$2" i status
  {
    printf '%s\n%s\n' "$HEADER" "$SEP"
    for ((i = 1; i <= 22; i++)); do
      if ((i <= pass)); then status='Pass'; else status='Fail'; fi
      printf '| %d | slug-%d | wf | %s | g | a |\n' "$i" "$i" "$status"
    done
    printf '\n**Pass count: %d/22**\n' "$pass"
  } >"$file"
}

R="$TL_TMP/root"
stage_root "$R"
CHECK="$R/scripts/enterprise-e2e/strict-clean-check.sh"
mk_ledger "$R/full.md" 22
mk_ledger "$R/partial.md" 20
echo 22 >"$R/ctl/registry-count"
unset SB_E2E_SURFACE_SKIP SB_E2E_LEDGER_FILE SB_TEST_ENTERPRISE_APP_ROOT

# help / bad args
tl_run bash "$CHECK" --help
assert_eq "help exit" "0" "$TL_STATUS"
assert_contains "help usage" "$TL_OUT" "Usage: strict-clean-check.sh [--ledger PATH]"
tl_run bash "$CHECK" -h
assert_eq "-h exit" "0" "$TL_STATUS"
tl_run bash "$CHECK" --nope
assert_eq "unknown arg exit" "2" "$TL_STATUS"
assert_contains "unknown arg message" "$TL_ERR" "Unknown arg: --nope"

# fully eligible
tl_run env SB_TEST_ENTERPRISE_APP_ROOT="$TL_TMP/app" bash "$CHECK" --ledger "$R/full.md"
assert_eq "eligible exit" "0" "$TL_STATUS"
assert_contains "ledger echoed" "$TL_OUT" "Strict-clean check — ledger=$R/full.md"
assert_contains "reconcile status COMPLETE" "$TL_OUT" "Ledger reconcile status: COMPLETE"
assert_contains "pass summary" "$TL_OUT" "Ledger Pass rows: 22/22"
assert_contains "outcome count" "$TL_OUT" "Outcome strict-clean rows: 22/22"
assert_contains "registry count" "$TL_OUT" "Install-version registry: 22/22 (install_fp=claude@abc+def)"
assert_contains "eligible banner" "$TL_OUT" "STRICT-CLEAN ELIGIBLE"
assert_eq "outcome scorer called for every row" "22" "$(wc -l <"$R/ctl/outcome-calls" | tr -d ' ')"
assert_contains "scorer gets fixture and default state dir" "$(sed -n 1p "$R/ctl/outcome-calls")" "1|$TL_TMP/app|$R/.planning/enterprise-e2e|"
rm -f "$R/ctl/outcome-calls"

# default fixture path and SB_E2E_LEDGER_FILE env (no --ledger flag)
tl_run env SB_E2E_LEDGER_FILE="$R/full.md" bash "$CHECK"
assert_eq "env ledger accepted" "0" "$TL_STATUS"
assert_contains "default fixture used" "$(sed -n 1p "$R/ctl/outcome-calls")" "1|/Users/shafqat/projects/enterprise-grade-test-app|"
rm -f "$R/ctl/outcome-calls"

# row attempt log is passed only when the file exists
echo "log" >"$R/ctl/row-3.log"
tl_run env SB_E2E_LEDGER_FILE="$R/full.md" bash "$CHECK"
assert_contains "existing attempt log forwarded" "$(grep '^3|' "$R/ctl/outcome-calls")" "|$R/ctl/row-3.log"
assert_eq "missing attempt log passed empty" "1|/Users/shafqat/projects/enterprise-grade-test-app|$R/.planning/enterprise-e2e|" "$(grep '^1|' "$R/ctl/outcome-calls")"
rm -f "$R/ctl/outcome-calls"
touch "$R/ctl/no-attempt-log"
tl_run env SB_E2E_LEDGER_FILE="$R/full.md" bash "$CHECK"
assert_eq "attempt-log lookup failure tolerated" "0" "$TL_STATUS"
rm -f "$R/ctl/no-attempt-log" "$R/ctl/outcome-calls"

# surface skip
tl_run env SB_E2E_SURFACE_SKIP=1 bash "$CHECK" --ledger "$R/full.md"
assert_eq "surface skip not eligible" "1" "$TL_STATUS"
assert_contains "surface skip reported" "$TL_ERR" "SB_E2E_SURFACE_SKIP=1 — install surface bypassed"
assert_contains "not strict-clean banner" "$TL_ERR" "NOT STRICT-CLEAN:"
rm -f "$R/ctl/outcome-calls"

# missing ledger
tl_run bash "$CHECK" --ledger "$R/absent.md"
assert_eq "missing ledger exit" "1" "$TL_STATUS"
assert_contains "missing ledger reported" "$TL_ERR" "ledger missing: $R/absent.md"
assert_not_contains "no verdict banner for missing ledger" "$TL_OUT" "STRICT-CLEAN ELIGIBLE"

# incomplete ledger + outcome failure + registry short
touch "$R/ctl/outcome-fail-4"
echo 21 >"$R/ctl/registry-count"
tl_run bash "$CHECK" --ledger "$R/partial.md"
assert_eq "incomplete exit" "1" "$TL_STATUS"
assert_contains "mismatch reported with count" "$TL_ERR" "ledger not COMPLETE — got LEDGER_MISMATCH (20/22 Pass with refs)"
assert_contains "matrix incomplete reported" "$TL_ERR" "matrix incomplete — 20/22 ledger Pass"
assert_contains "outcome incomplete reported" "$TL_ERR" "outcome incomplete — 19/22 strict-clean rows"
assert_contains "registry incomplete reported" "$TL_ERR" "install-version registry incomplete — 21/22 rows passed @ claude@abc+def"
assert_not_contains "failing ledger rows are not scored" "$(cat "$R/ctl/outcome-calls")" "21|"
rm -f "$R/ctl/outcome-calls"

# pass row whose outcome assessment fails
tl_run bash "$CHECK" --ledger "$R/full.md"
assert_eq "outcome failure exit" "1" "$TL_STATUS"
assert_contains "row 4 outcome failure reported" "$TL_ERR" "row 4 ledger Pass but outcome assessment FAIL"
assert_contains "outcome count reflects failure" "$TL_OUT" "Outcome strict-clean rows: 21/22"
rm -f "$R/ctl/outcome-fail-4" "$R/ctl/outcome-calls"

# registry helper absent: that gate is skipped
rm -rf "$TL_TMP/root2"
WITH_REGISTRY=0 stage_root "$TL_TMP/root2"
mk_ledger "$TL_TMP/root2/full.md" 22
tl_run bash "$TL_TMP/root2/scripts/enterprise-e2e/strict-clean-check.sh" --ledger "$TL_TMP/root2/full.md"
assert_eq "no registry helper still eligible" "0" "$TL_STATUS"
assert_not_contains "registry line absent" "$TL_OUT" "Install-version registry"

tl_results
