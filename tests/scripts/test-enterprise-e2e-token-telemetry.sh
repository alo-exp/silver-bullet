#!/usr/bin/env bash
# Behaviour tests for scripts/lib/enterprise-e2e-token-telemetry.sh (append-only V-02 telemetry).
# rtk, pgrep and date are stubs; every write is redirected to $TL_TMP via SB_E2E_TELEMETRY_ROOT.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-token-telemetry.sh"
CLEAN=(-u SB_ROOT -u SB_E2E_TELEMETRY_ROOT -u SB_E2E_TELEMETRY_ROW -u SB_E2E_TELEMETRY_ROW_SLUG
  -u SB_E2E_TELEMETRY_ROW_RESULT -u SB_E2E_TELEMETRY_ROW_LOG -u SB_E2E_LEDGER_FILE -u CLAUDE_MODEL
  -u CURSOR_MODEL -u SB_E2E_VALIDATION_OVERLAY_DRY_RUN -u VALIDATION_OVERLAY_PASS
  -u VALIDATION_OVERLAY_FAIL -u VALIDATION_OVERLAY_SKIP)

# Frozen clock and no matrix driver unless a test installs one.
tl_stub date 'echo 2026-01-02T03:04:05Z'
tl_stub pgrep 'exit 1'

# --- enterprise_e2e_telemetry_file ------------------------------------------
ROOT="$TL_TMP/root"
e2e_call "$LIB" -- enterprise_e2e_telemetry_file "$ROOT"
assert_eq "file: primary path" "$ROOT/.planning/enterprise-e2e/token-telemetry.jsonl" "$TL_OUT"
assert_file_exists "file: mirror dir created" "$ROOT/docs/testing/telemetry/."
assert_file_exists "file: primary dir created" "$ROOT/.planning/enterprise-e2e/."
e2e_call "$LIB" "SB_ROOT=$TL_TMP/sbroot" -- enterprise_e2e_telemetry_file
assert_eq "file: defaults to SB_ROOT" "$TL_TMP/sbroot/.planning/enterprise-e2e/token-telemetry.jsonl" "$TL_OUT"

# --- enterprise_e2e_telemetry_extract_row_log_tokens ------------------------
tok() { e2e_call "$LIB" -- enterprise_e2e_telemetry_extract_row_log_tokens "$@"; }
printf 'a 120 tokens\nfoo\n  98765   tokens left\n9 tokens\nx 1000000000 tokens\n' >"$TL_TMP/row.log"
tok "$TL_TMP/row.log"
assert_eq "tokens: max of 1-9 digit numbers (10-digit run ignored as a whole match)" "98765" "$TL_OUT"
printf 'no numbers here\n12tokens\n' >"$TL_TMP/none.log"
tok "$TL_TMP/none.log"
assert_eq "tokens: nothing found prints nothing" "" "$TL_OUT"
assert_eq "tokens: nothing found succeeds" 0 "$TL_STATUS"
tok "$TL_TMP/missing.log"
assert_eq "tokens: missing log prints nothing" "" "$TL_OUT"
assert_eq "tokens: missing log succeeds" 0 "$TL_STATUS"
tok ""
assert_eq "tokens: empty arg succeeds" 0 "$TL_STATUS"
tok
assert_eq "tokens: no arg prints nothing" "" "$TL_OUT"

# --- enterprise_e2e_telemetry_rtk_snapshot ----------------------------------
snap() { e2e_call "$LIB" "$@" -- enterprise_e2e_telemetry_rtk_snapshot; }
snap "PATH=$(tl_path_without rtk)"
assert_eq "rtk: absent prints nothing" "" "$TL_OUT"
assert_eq "rtk: absent succeeds" 0 "$TL_STATUS"

tl_stub rtk 'printf "{\n  \"saved\": 5,\n  \"cmds\": [1, 2]\n}\n"; echo "disabled=${RTK_DISABLED:-} args=$*" >>"'"$TL_TMP"'/rtk.calls"'
snap
assert_eq "rtk: JSON compacted" '{"saved":5,"cmds":[1,2]}' "$TL_OUT"
assert_contains "rtk: stats run with RTK_DISABLED=1" "$(cat "$TL_TMP/rtk.calls")" "disabled=1 args=stats"

tl_stub rtk 'printf "Total  saved:   12\n  cmds:    3\n"'
snap
assert_eq "rtk: non-JSON flattened and whitespace collapsed" "Total saved: 12 cmds: 3" "$TL_OUT"

tl_stub rtk 'exit 3'
snap
assert_eq "rtk: failing stats prints nothing" "" "$TL_OUT"
assert_eq "rtk: failing stats succeeds" 0 "$TL_STATUS"

tl_stub rtk 'printf "not json at all\n"'
snap "PATH=$(tl_path_without jq)"
assert_eq "rtk: without jq falls through to flattening" "not json at all" "$TL_OUT"
tl_stub rtk 'exit 0'

# --- enterprise_e2e_telemetry_matrix_driver_pid -----------------------------
e2e_call "$LIB" -- enterprise_e2e_telemetry_matrix_driver_pid
assert_eq "pid: none running prints nothing" "" "$TL_OUT"
assert_eq "pid: none running succeeds" 0 "$TL_STATUS"
tl_stub pgrep 'echo "$*" >"'"$TL_TMP"'/pgrep.args"; printf "900\n42\n7000\n"'
e2e_call "$LIB" -- enterprise_e2e_telemetry_matrix_driver_pid
assert_eq "pid: numerically lowest" "42" "$TL_OUT"
assert_contains "pid: matches the matrix runner command line" "$(cat "$TL_TMP/pgrep.args")" "bash scripts/run-enterprise-e2e-matrix.sh"
tl_stub pgrep 'exit 1'

# --- enterprise_e2e_telemetry_append ----------------------------------------
TR="$TL_TMP/tele"
PRIMARY="$TR/.planning/enterprise-e2e/token-telemetry.jsonl"
MIRROR="$TR/docs/testing/telemetry/token-telemetry.jsonl"
printf 'x 777 tokens\n' >"$TL_TMP/append.log"

# minimal: no row, no overlay counters, no rtk, no driver
e2e_call "$LIB" "${CLEAN[@]}" "SB_E2E_TELEMETRY_ROOT=$TR" "PATH=$(tl_path_without rtk)" -- enterprise_e2e_telemetry_append
assert_eq "append minimal: status" 0 "$TL_STATUS"
assert_eq "append minimal: one record in primary" 1 "$(wc -l <"$PRIMARY" | tr -d ' ')"
assert_eq "append minimal: mirror identical to primary" "$(cat "$PRIMARY")" "$(cat "$MIRROR")"
rec="$(cat "$PRIMARY")"
assert_eq "minimal: ts frozen" "2026-01-02T03:04:05Z" "$(jq -r .ts <<<"$rec")"
assert_eq "minimal: event source defaults to unknown" "unknown" "$(jq -r .event_source <<<"$rec")"
assert_eq "minimal: sb_root is the telemetry-root default (SB_ROOT unset => repo)" "$TL_REPO_ROOT" "$(jq -r .sb_root <<<"$rec")"
assert_eq "minimal: claim and gate fixed" "V-02/none/telemetry_only" "$(jq -r '[.claim_ref,.gate,.validation_scope]|join("/")' <<<"$rec")"
assert_eq "minimal: row null" "null" "$(jq -c .row <<<"$rec")"
assert_eq "minimal: ledger null" "null" "$(jq -c .ledger_file <<<"$rec")"
assert_eq "minimal: model unknown" "unknown" "$(jq -r .model <<<"$rec")"
assert_eq "minimal: tokens all null" '{"tui_max":null,"input":null,"output":null,"total":null}' "$(jq -c .tokens <<<"$rec")"
assert_eq "minimal: overlay null" "null" "$(jq -c .overlay <<<"$rec")"
assert_eq "minimal: rtk null" "null" "$(jq -c .rtk_stats <<<"$rec")"
assert_eq "minimal: driver pid null" "null" "$(jq -c .matrix_driver_pid <<<"$rec")"

# full: every field populated; dry-run overlay; CURSOR_MODEL fallback
rm -rf "$TR"
tl_stub rtk 'printf "{\"saved\": 9}\n"'
tl_stub pgrep 'echo 4321'
e2e_call "$LIB" "${CLEAN[@]}" "SB_E2E_TELEMETRY_ROOT=$TR" "SB_ROOT=$TL_TMP/sbr" \
  SB_E2E_TELEMETRY_ROW=11 SB_E2E_TELEMETRY_ROW_SLUG=wf-eleven SB_E2E_TELEMETRY_ROW_RESULT=Pass \
  "SB_E2E_TELEMETRY_ROW_LOG=$TL_TMP/append.log" "SB_E2E_LEDGER_FILE=$TL_TMP/ledger.md" \
  CURSOR_MODEL=cursor-m SB_E2E_VALIDATION_OVERLAY_DRY_RUN=1 \
  VALIDATION_OVERLAY_PASS=4 VALIDATION_OVERLAY_FAIL=1 VALIDATION_OVERLAY_SKIP=2 \
  -- enterprise_e2e_telemetry_append "matrix-row"
assert_eq "append full: status" 0 "$TL_STATUS"
rec="$(cat "$PRIMARY")"
assert_eq "full: event source" "matrix-row" "$(jq -r .event_source <<<"$rec")"
assert_eq "full: sb_root from SB_ROOT" "$TL_TMP/sbr" "$(jq -r .sb_root <<<"$rec")"
assert_eq "full: row" "{\"num\":11,\"slug\":\"wf-eleven\",\"result\":\"Pass\",\"log\":\"$TL_TMP/append.log\"}" "$(jq -c .row <<<"$rec")"
assert_eq "full: ledger" "$TL_TMP/ledger.md" "$(jq -r .ledger_file <<<"$rec")"
assert_eq "full: model falls back to CURSOR_MODEL" "cursor-m" "$(jq -r .model <<<"$rec")"
assert_eq "full: tui tokens" "777" "$(jq -r .tokens.tui_max <<<"$rec")"
assert_eq "full: overlay dry-run" '{"mode":"dry-run","pass":4,"fail":1,"skip":2}' "$(jq -c .overlay <<<"$rec")"
assert_eq "full: rtk snapshot" '{"saved":9}' "$(jq -r .rtk_stats <<<"$rec")"
assert_eq "full: driver pid" "4321" "$(jq -r .matrix_driver_pid <<<"$rec")"

# appends rather than overwrites; CLAUDE_MODEL beats CURSOR_MODEL; live overlay mode
e2e_call "$LIB" "${CLEAN[@]}" "SB_E2E_TELEMETRY_ROOT=$TR" CLAUDE_MODEL=claude-m CURSOR_MODEL=cursor-m \
  VALIDATION_OVERLAY_PASS=1 VALIDATION_OVERLAY_FAIL=0 VALIDATION_OVERLAY_SKIP=0 SB_E2E_VALIDATION_OVERLAY_DRY_RUN=0 \
  -- enterprise_e2e_telemetry_append "second"
assert_eq "second call appends to primary" 2 "$(wc -l <"$PRIMARY" | tr -d ' ')"
assert_eq "second call appends to mirror" 2 "$(wc -l <"$MIRROR" | tr -d ' ')"
rec="$(tail -1 "$PRIMARY")"
assert_eq "second: CLAUDE_MODEL wins" "claude-m" "$(jq -r .model <<<"$rec")"
assert_eq "second: live overlay mode" "live-overlay" "$(jq -r .overlay.mode <<<"$rec")"
assert_eq "second: row without number stays null" "null" "$(jq -c .row <<<"$rec")"

# a row log with no token footer must not abort the record (extract helper returns non-zero)
rm -rf "$TR"
e2e_call "$LIB" "${CLEAN[@]}" "SB_E2E_TELEMETRY_ROOT=$TR" "SB_E2E_TELEMETRY_ROW_LOG=$TL_TMP/none.log" -- enterprise_e2e_telemetry_append "no-footer"
assert_eq "no token footer: status" 0 "$TL_STATUS"
assert_eq "no token footer: record still written" 1 "$(wc -l <"$PRIMARY" | tr -d ' ')"
assert_eq "no token footer: tui_max null" "null" "$(jq -c .tokens.tui_max "$PRIMARY")"

# jq missing: nothing recorded, but the call succeeds
rm -rf "$TR"
e2e_call "$LIB" "${CLEAN[@]}" "SB_E2E_TELEMETRY_ROOT=$TR" "PATH=$(tl_path_without jq)" -- enterprise_e2e_telemetry_append "nojq"
assert_eq "no jq: status" 0 "$TL_STATUS"
assert_file_absent "no jq: primary not written" "$PRIMARY"
assert_file_absent "no jq: mirror not written" "$MIRROR"

# jq present but the record cannot be built (non-numeric overlay counter): failure propagates, no partial line
rm -rf "$TR"
e2e_call "$LIB" "${CLEAN[@]}" "SB_E2E_TELEMETRY_ROOT=$TR" VALIDATION_OVERLAY_PASS=oops -- enterprise_e2e_telemetry_append "bad"
assert_eq "bad counter: status non-zero" 1 "$([[ $TL_STATUS -ne 0 ]] && echo 1 || echo 0)"
assert_file_absent "bad counter: primary not written" "$PRIMARY"

tl_results
