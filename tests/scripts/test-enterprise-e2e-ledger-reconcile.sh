#!/usr/bin/env bash
# Ledger reconcile library: status classification, CLI exit codes, header and ref checks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-ledger-reconcile.sh"

HEADER='| # | WF slug | Workflow | Pass/Fail | graphify_query_ref | agentmemory_export_ref |'
SEP='|---|---|---|---|---|---|'

# mk_ledger FILE PASS_COUNT TOTAL [missing_ref_row]
mk_ledger() {
  local file="$1" pass="$2" total="$3" noref="${4:-0}" i status g a
  {
    printf '# Ledger\n\n%s\n%s\n' "$HEADER" "$SEP"
    for ((i = 1; i <= total; i++)); do
      if ((i <= pass)); then status='**Pass**'; else status='Fail'; fi
      g='graphify query x'; a='mem-1'
      if ((i == noref)); then a=''; fi
      printf '| %d | slug-%d | wf | %s | %s | %s |\n' "$i" "$i" "$status" "$g" "$a"
    done
    printf '\n**Pass count: %d/%d**\n| 99 | after | table | Pass | | |\n' "$pass" "$total"
  } >"$file"
}

# --- sourced function behaviour -------------------------------------------
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "$LIB"

# path resolution: SB_ROOT set vs derived from the library location
unset SB_E2E_LEDGER_FILE
assert_eq "ledger path under SB_ROOT" \
  "/some/root/.planning/enterprise-e2e/ROUND-1-LEDGER.md" "$(SB_ROOT=/some/root enterprise_e2e_ledger_file_path)"
unset SB_ROOT
assert_eq "ledger path derived from library location" \
  "$TL_REPO_ROOT/.planning/enterprise-e2e/ROUND-1-LEDGER.md" "$(enterprise_e2e_ledger_file_path)"
assert_eq "SB_E2E_LEDGER_FILE overrides default" "/x/y.md" "$(SB_E2E_LEDGER_FILE=/x/y.md enterprise_e2e_ledger_file_path)"

# normalisation
assert_eq "normalize strips emphasis and case" "pass" "$(enterprise_e2e_ledger_normalize_status '  **PASS** ')"
if enterprise_e2e_ledger_status_is_pass ' **Pass** '; then tl_pass "status_is_pass true for **Pass**"; else tl_fail "status_is_pass true for **Pass**"; fi
if enterprise_e2e_ledger_status_is_pass 'Fail'; then tl_fail "status_is_pass false for Fail"; else tl_pass "status_is_pass false for Fail"; fi

# header check
mk_ledger "$TL_TMP/full.md" 22 22
if enterprise_e2e_ledger_header_ok "$TL_TMP/full.md"; then tl_pass "header ok with all columns"; else tl_fail "header ok with all columns"; fi
printf '| # | WF slug | Pass/Fail |\n' >"$TL_TMP/nocols.md"
if enterprise_e2e_ledger_header_ok "$TL_TMP/nocols.md"; then tl_fail "header rejects missing ref columns"; else tl_pass "header rejects missing ref columns"; fi
printf 'no table here\n' >"$TL_TMP/notable.md"
if enterprise_e2e_ledger_header_ok "$TL_TMP/notable.md"; then tl_fail "header rejects missing header line"; else tl_pass "header rejects missing header line"; fi
if enterprise_e2e_ledger_header_ok "$TL_TMP/does-not-exist.md"; then tl_fail "header rejects unreadable ledger"; else tl_pass "header rejects unreadable ledger"; fi

# blank column names in the required list are skipped
enterprise_e2e_ledger_required_columns() { printf 'Pass/Fail\n\n'; }
if enterprise_e2e_ledger_header_ok "$TL_TMP/nocols.md"; then tl_pass "blank required column skipped"; else tl_fail "blank required column skipped"; fi
unset -f enterprise_e2e_ledger_required_columns
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "$LIB"

# matrix rows / summary
rows="$(enterprise_e2e_ledger_matrix_rows "$TL_TMP/full.md")"
assert_eq "22 matrix rows parsed (table ends at Pass count)" "22" "$(wc -l <<<"$rows" | tr -d ' ')"
assert_eq "row 1 is pass" "1 pass" "$(sed -n 1p <<<"$rows")"
mk_ledger "$TL_TMP/part.md" 20 22
assert_eq "summary lists failing rows" "20 22 21,22" "$(enterprise_e2e_ledger_pass_summary "$TL_TMP/part.md")"
assert_eq "summary of full ledger" "22 22 " "$(enterprise_e2e_ledger_pass_summary "$TL_TMP/full.md")"

# blank row numbers from the row emitter are ignored
enterprise_e2e_ledger_matrix_rows() { printf ' \n5 pass\n'; }
assert_eq "summary skips blank rows" "1 1 " "$(enterprise_e2e_ledger_pass_summary x)"
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "$LIB"

# rows without a Pass/Fail column are dropped
printf '| # | WF slug | other |\n|---|---|---|\n| 1 | a | b |\n' >"$TL_TMP/nopf.md"
assert_eq "no Pass/Fail column yields no rows" "" "$(enterprise_e2e_ledger_matrix_rows "$TL_TMP/nopf.md")"

# refs
if enterprise_e2e_ledger_pass_rows_have_refs "$TL_TMP/full.md"; then tl_pass "refs present"; else tl_fail "refs present"; fi
mk_ledger "$TL_TMP/noref.md" 22 22 7
if enterprise_e2e_ledger_pass_rows_have_refs "$TL_TMP/noref.md"; then tl_fail "empty agentmemory ref detected"; else tl_pass "empty agentmemory ref detected"; fi
mk_ledger "$TL_TMP/noref-fail.md" 20 22 22
if enterprise_e2e_ledger_pass_rows_have_refs "$TL_TMP/noref-fail.md"; then tl_pass "missing ref on non-pass row ignored"; else tl_fail "missing ref on non-pass row ignored"; fi
if enterprise_e2e_ledger_pass_rows_have_refs "$TL_TMP/nocols.md"; then tl_pass "no data rows means no missing refs"; else tl_fail "no data rows means no missing refs"; fi
printf '| # | WF slug | Pass/Fail |\n|---|---|---|\n| 1 | a | Pass |\n' >"$TL_TMP/nocolrow.md"
if enterprise_e2e_ledger_pass_rows_have_refs "$TL_TMP/nocolrow.md"; then tl_fail "row without ref columns is flagged"; else tl_pass "row without ref columns is flagged"; fi

# status classification
export SB_E2E_LEDGER_FILE="$TL_TMP/full.md"
assert_eq "status COMPLETE" "COMPLETE" "$(enterprise_e2e_ledger_reconcile_status)"
if enterprise_e2e_ledger_reconcile_ok; then tl_pass "reconcile_ok on COMPLETE"; else tl_fail "reconcile_ok on COMPLETE"; fi
assert_eq "status UNREADABLE" "UNREADABLE" "$(SB_E2E_LEDGER_FILE="$TL_TMP/missing.md" enterprise_e2e_ledger_reconcile_status)"
assert_eq "status STALE without columns" "STALE" "$(SB_E2E_LEDGER_FILE="$TL_TMP/nocols.md" enterprise_e2e_ledger_reconcile_status)"
mk_ledger "$TL_TMP/short.md" 10 10
assert_eq "status STALE with fewer than 22 rows" "STALE" "$(SB_E2E_LEDGER_FILE="$TL_TMP/short.md" enterprise_e2e_ledger_reconcile_status)"
assert_eq "status LEDGER_MISMATCH with failing rows" "LEDGER_MISMATCH" "$(SB_E2E_LEDGER_FILE="$TL_TMP/part.md" enterprise_e2e_ledger_reconcile_status)"
assert_eq "status LEDGER_MISMATCH with missing refs" "LEDGER_MISMATCH" "$(SB_E2E_LEDGER_FILE="$TL_TMP/noref.md" enterprise_e2e_ledger_reconcile_status)"
if SB_E2E_LEDGER_FILE="$TL_TMP/part.md" enterprise_e2e_ledger_reconcile_ok; then tl_fail "reconcile_ok false on mismatch"; else tl_pass "reconcile_ok false on mismatch"; fi

# --- CLI entry --------------------------------------------------------------
tl_run bash "$LIB" --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help usage text" "$TL_OUT" "Usage: enterprise-e2e-ledger-reconcile.sh"

export SB_E2E_LEDGER_FILE="$TL_TMP/full.md"
tl_run bash "$LIB" --status
assert_eq "--status COMPLETE exit" "0" "$TL_STATUS"
assert_eq "--status COMPLETE stdout" "COMPLETE" "$TL_OUT"

export SB_E2E_LEDGER_FILE="$TL_TMP/part.md"
tl_run bash "$LIB" --status
assert_eq "--status mismatch exit" "1" "$TL_STATUS"
assert_contains "--status mismatch stdout" "$TL_OUT" "LEDGER_MISMATCH"

export SB_E2E_LEDGER_FILE="$TL_TMP/missing.md"
tl_run bash "$LIB" --status
assert_eq "--status unreadable exit" "2" "$TL_STATUS"
assert_contains "--status unreadable stdout" "$TL_OUT" "UNREADABLE"

export SB_E2E_LEDGER_FILE="$TL_TMP/part.md"
tl_run bash "$LIB" --summary
assert_eq "--summary exit" "0" "$TL_STATUS"
assert_contains "--summary names ledger" "$TL_OUT" "ledger: $TL_TMP/part.md"
assert_contains "--summary has counts" "$TL_OUT" "20 22 21,22"

export SB_E2E_LEDGER_FILE="$TL_TMP/full.md"
tl_run bash "$LIB"
assert_eq "default complete exit" "0" "$TL_STATUS"
assert_contains "default complete message" "$TL_OUT" "ledger reconcile: COMPLETE 22/22"

export SB_E2E_LEDGER_FILE="$TL_TMP/part.md"
tl_run bash "$LIB"
assert_eq "default mismatch exit" "1" "$TL_STATUS"
assert_contains "default mismatch status on stderr" "$TL_ERR" "ledger reconcile: LEDGER_MISMATCH"
assert_contains "default mismatch counts on stderr" "$TL_ERR" "ledger pass count: 20/22 (need 22/22)"

export SB_E2E_LEDGER_FILE="$TL_TMP/missing.md"
tl_run bash "$LIB"
assert_eq "default unreadable exit" "2" "$TL_STATUS"
assert_contains "default unreadable on stderr" "$TL_ERR" "ledger reconcile: UNREADABLE"
assert_contains "default unreadable counts zero" "$TL_ERR" "ledger pass count: 0/0"

tl_results
