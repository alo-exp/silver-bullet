#!/usr/bin/env bash
# Behaviour tests for scripts/lib/enterprise-e2e-row-pass-registry.sh: root/registry path
# resolution, surface hash and fingerprint, record/has_pass/pass_count/complete, and the pilot
# log slice parser. The registry lives under $TL_TMP; the clock is frozen.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-row-pass-registry.sh"
CLEAN=(-u SB_ROOT -u SB_E2E_ROW_PASS_REGISTRY -u SB_E2E_LIVE_RUNTIME -u SB_E2E_MATRIX_FORCE_ALL)
tl_stub date 'echo 2026-03-04T05:06:07Z'

APP="$TL_TMP/app"
e2e_git_app "$APP"
SHA="$(git -C "$APP" rev-parse --short=12 HEAD)"
REG="$APP/.planning/enterprise-e2e/.row-pass-registry.json"
call() { e2e_call "$LIB" "${CLEAN[@]}" "SB_ROOT=$APP" "SILVER_BULLET_RUNTIME=claude" "$@"; }

# --- root and registry path -------------------------------------------------
e2e_call "$LIB" "${CLEAN[@]}" -- enterprise_e2e_row_pass_registry_file
assert_eq "file: without SB_ROOT the repo root is derived from the lib location" \
  "$TL_REPO_ROOT/.planning/enterprise-e2e/.row-pass-registry.json" "$TL_OUT"
call -- enterprise_e2e_row_pass_registry_file
assert_eq "file: SB_ROOT based" "$REG" "$TL_OUT"
call "SB_E2E_ROW_PASS_REGISTRY=$TL_TMP/custom.json" -- enterprise_e2e_row_pass_registry_file
assert_eq "file: override wins" "$TL_TMP/custom.json" "$TL_OUT"

# --- surface hash -----------------------------------------------------------
mkdir -p "$TL_TMP/s-empty" "$TL_TMP/s-pkg" "$TL_TMP/s-badpkg" "$TL_TMP/s-both/hooks"
printf '{"version":"1.2.3"}' >"$TL_TMP/s-pkg/package.json"
printf 'not json' >"$TL_TMP/s-badpkg/package.json"
printf '{"name":"x"}' >"$TL_TMP/s-nover.json"
mkdir -p "$TL_TMP/s-nover"
cp "$TL_TMP/s-nover.json" "$TL_TMP/s-nover/package.json"
printf 'ab' >"$TL_TMP/s-both/hooks/hooks.json"
printf '{"version":"1.2.3"}' >"$TL_TMP/s-both/package.json"
sh_() { call -- enterprise_e2e_install_surface_hash "$1"; }
sh_ "$TL_TMP/s-empty"
assert_eq "surface hash: no inputs is sha256 of the empty string" "e3b0c44298fc" "$TL_OUT"
sh_ "$TL_TMP/s-pkg"
assert_eq "surface hash: package version only" "c47f5b18b8a4" "$TL_OUT"
sh_ "$TL_TMP/s-badpkg"
assert_eq "surface hash: unparsable package.json counts as 'unknown'" "b23a6a8439c0" "$TL_OUT"
sh_ "$TL_TMP/s-nover"
assert_eq "surface hash: package.json without version counts as 'unknown'" "b23a6a8439c0" "$TL_OUT"
sh_ "$TL_TMP/s-both"
expected="$(printf '%s' 'fb8e20fc2e4c3f24|1.2.3' | python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')"
assert_eq "surface hash: hooks digest[:16] joined with version" "$expected" "$TL_OUT"
call -- enterprise_e2e_install_surface_hash
assert_eq "surface hash: defaults to SB_ROOT" "$(sh_ "$APP" && echo "$TL_OUT")" "$TL_OUT"

# --- install fingerprint ----------------------------------------------------
call -- enterprise_e2e_install_surface_hash "$APP"
APP_SURFACE="$TL_OUT"
call -- enterprise_e2e_install_fingerprint
assert_eq "fingerprint: host from SILVER_BULLET_RUNTIME" "claude@${SHA}+${APP_SURFACE}" "$TL_OUT"
call "SB_E2E_LIVE_RUNTIME=codex" -- enterprise_e2e_install_fingerprint
assert_eq "fingerprint: SB_E2E_LIVE_RUNTIME wins" "codex@${SHA}+${APP_SURFACE}" "$TL_OUT"
tl_run env "${CLEAN[@]}" SB_ROOT="$APP" bash -c "set -euo pipefail; source '$LIB'; enterprise_e2e_matrix_host() { echo cursor; }; enterprise_e2e_install_fingerprint"
assert_eq "fingerprint: enterprise_e2e_matrix_host wins when defined" "cursor@${SHA}+${APP_SURFACE}" "$TL_OUT"
mkdir -p "$TL_TMP/nogit"
e2e_call "$LIB" "${CLEAN[@]}" "SB_ROOT=$TL_TMP/nogit" "SILVER_BULLET_RUNTIME=claude" -- enterprise_e2e_install_fingerprint
assert_eq "fingerprint: outside a git repo the sha is 'unknown'" "claude@unknown+e3b0c44298fc" "$TL_OUT"
FP="claude@${SHA}+${APP_SURFACE}"

# --- ensure -----------------------------------------------------------------
call -- enterprise_e2e_row_pass_registry_ensure
assert_eq "ensure: status" 0 "$TL_STATUS"
assert_eq "ensure: skeleton" '{"schema_version":1,"installs":{}}' "$(jq -c '{schema_version, installs}' "$REG")"
# created_at comes from python's clock (not the date stub): check shape only
assert_match "ensure: created_at is a UTC timestamp" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$(jq -r .created_at "$REG")"
assert_eq "ensure: documents the fingerprint scheme" "host@sb_git_sha12+surface_hash12" "$(jq -r .fingerprint_scheme "$REG")"
echo '{"installs":{"keep":{}}}' >"$REG"
call -- enterprise_e2e_row_pass_registry_ensure
assert_eq "ensure: existing registry untouched" '{"installs":{"keep":{}}}' "$(jq -c . "$REG")"
rm -f "$REG"

# --- has_pass / pass_count / complete with no registry ----------------------
call -- enterprise_e2e_row_pass_registry_has_pass 1
assert_eq "has_pass: no registry file" 1 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_pass_count
assert_eq "pass_count: no registry prints 0" "0" "$TL_OUT"
assert_eq "pass_count: no registry succeeds" 0 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_complete
assert_eq "complete: no registry is incomplete" 1 "$TL_STATUS"

# --- record -----------------------------------------------------------------
call -- enterprise_e2e_row_pass_registry_record 3 "log3" true "unit"
assert_eq "record: status" 0 "$TL_STATUS"
assert_eq "record: install entry" "claude|${SHA}|${FP}" \
  "$(jq -r --arg fp "$FP" '.installs[$fp] | [.host, .sb_sha, .install_fp] | join("|")' "$REG")"
assert_eq "record: row entry" '{"passed_at":"2026-03-04T05:06:07Z","log_ref":"log3","outcome_pass":true,"source":"unit"}' \
  "$(jq -c --arg fp "$FP" '.installs[$fp].rows["3"]' "$REG")"
call -- enterprise_e2e_row_pass_registry_has_pass 3
assert_eq "has_pass: recorded row" 0 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_has_pass 03
assert_eq "has_pass: zero-padded row number" 0 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_has_pass 4
assert_eq "has_pass: other row" 1 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_has_pass 3 "claude@other+deadbeef0000"
assert_eq "has_pass: other install fingerprint" 1 "$TL_STATUS"

call -- enterprise_e2e_row_pass_registry_record 04
assert_eq "record: defaults log_ref empty, outcome true, source matrix" '{"passed_at":"2026-03-04T05:06:07Z","log_ref":"","outcome_pass":true,"source":"matrix"}' \
  "$(jq -c --arg fp "$FP" '.installs[$fp].rows["4"]' "$REG")"
for v in 1 YES False no 0 ""; do # empty falls back to the default (true)
  call -- enterprise_e2e_row_pass_registry_record 5 "l" "$v"
  want=false
  case "$v" in 1 | YES | "") want=true ;; esac
  assert_eq "record: outcome_pass '$v' -> $want" "$want" "$(jq -r --arg fp "$FP" '.installs[$fp].rows["5"].outcome_pass' "$REG")"
done
call -- enterprise_e2e_row_pass_registry_record 6 "l" no
call -- enterprise_e2e_row_pass_registry_has_pass 6
assert_eq "has_pass: row recorded with outcome_pass false is not a pass" 1 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_record 3 "log3b" true "again"
assert_eq "record: re-record overwrites the row" "log3b|again" "$(jq -r --arg fp "$FP" '.installs[$fp].rows["3"] | [.log_ref, .source] | join("|")' "$REG")"
assert_eq "record: other rows kept on re-record" "4" "$(jq -r --arg fp "$FP" '.installs[$fp].rows | length' "$REG")"
call -- enterprise_e2e_row_pass_registry_record notanumber
assert_eq "record: non-numeric row is rejected" 1 "$([[ $TL_STATUS -ne 0 ]] && echo 1 || echo 0)"
assert_eq "record: rejected row leaves the registry unchanged" "4" "$(jq -r --arg fp "$FP" '.installs[$fp].rows | length' "$REG")"
call -- enterprise_e2e_row_pass_registry_has_pass notanumber
assert_eq "has_pass: non-numeric row fails" 1 "$([[ $TL_STATUS -ne 0 ]] && echo 1 || echo 0)"

# --- should_skip ------------------------------------------------------------
call -- enterprise_e2e_row_pass_registry_should_skip 3
assert_eq "should_skip: passed row" 0 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_should_skip 9
assert_eq "should_skip: unpassed row" 1 "$TL_STATUS"
call "SB_E2E_MATRIX_FORCE_ALL=1" -- enterprise_e2e_row_pass_registry_should_skip 3
assert_eq "should_skip: FORCE_ALL=1 disables the skip" 1 "$TL_STATUS"
call "SB_E2E_MATRIX_FORCE_ALL=0" -- enterprise_e2e_row_pass_registry_should_skip 3
assert_eq "should_skip: FORCE_ALL=0 keeps the skip" 0 "$TL_STATUS"

# --- pass_count / complete --------------------------------------------------
call -- enterprise_e2e_row_pass_registry_pass_count
assert_eq "pass_count: counts only outcome_pass rows (3, 4 and the empty-default 5)" "3" "$TL_OUT"
call -- enterprise_e2e_row_pass_registry_pass_count "claude@other+deadbeef0000"
assert_eq "pass_count: unknown fingerprint is 0" "0" "$TL_OUT"
call -- enterprise_e2e_row_pass_registry_complete
assert_eq "complete: 3 of 22" 1 "$TL_STATUS"
for r in $(seq 1 21); do
  call -- enterprise_e2e_row_pass_registry_record "$r" "l$r" true
done
call -- enterprise_e2e_row_pass_registry_pass_count
assert_eq "pass_count: 21 rows" "21" "$TL_OUT"
call -- enterprise_e2e_row_pass_registry_complete
assert_eq "complete: 21 rows is still incomplete" 1 "$TL_STATUS"
call -- enterprise_e2e_row_pass_registry_record 22 "l22" true
call -- enterprise_e2e_row_pass_registry_complete
assert_eq "complete: 22 rows" 0 "$TL_STATUS"

# --- pilot log slice parser -------------------------------------------------
LOG="$TL_TMP/matrix.log"
cat >"$LOG" <<'LOGEOF'
=== Row 3: first attempt
  FAIL: stale failure
=== Row 4: other row
  PASS: evidence at /x
=== Row 3: second attempt
  PASS: evidence at /y
=== Row 5: mixed
  OUTCOMES: all applicable criteria pass
  FAIL: but a step failed
=== Row 6: outcomes only
  OUTCOMES: all applicable criteria pass
=== Row 7: nothing conclusive
  note
=== Row 8: pilot terminated
  noise
=== PILOT row 8 done
  PASS: evidence at /after-pilot
=== Row 10: prefix check
  PASS: evidence at /z
=== Row 12: last
  FAIL: broken
LOGEOF
pilot() { call -- enterprise_e2e_pilot_log_row_passed "$@"; }
pilot 3 "$LOG"
assert_eq "pilot: latest slice of a repeated row decides (earlier FAIL ignored)" 0 "$TL_STATUS"
pilot 4 "$LOG"
assert_eq "pilot: PASS: evidence at passes" 0 "$TL_STATUS"
pilot 5 "$LOG"
assert_eq "pilot: a FAIL line beats an OUTCOMES pass" 1 "$TL_STATUS"
pilot 6 "$LOG"
assert_eq "pilot: OUTCOMES all-pass line passes" 0 "$TL_STATUS"
pilot 7 "$LOG"
assert_eq "pilot: slice without verdict fails" 1 "$TL_STATUS"
pilot 8 "$LOG"
assert_eq "pilot: PILOT header ends the slice (later PASS not attributed)" 1 "$TL_STATUS"
pilot 1 "$LOG"
assert_eq "pilot: row 1 does not match row 10 or 12 (exact id)" 1 "$TL_STATUS"
pilot 10 "$LOG"
assert_eq "pilot: row 10 slice" 0 "$TL_STATUS"
pilot 12 "$LOG"
assert_eq "pilot: final slice FAIL" 1 "$TL_STATUS"
pilot 99 "$LOG"
assert_eq "pilot: row absent from log" 1 "$TL_STATUS"
pilot 3 "$TL_TMP/no-such.log"
assert_eq "pilot: missing log file fails closed" 1 "$TL_STATUS"
call -- enterprise_e2e_pilot_log_row_passed
assert_eq "pilot: row number is required" 1 "$([[ $TL_STATUS -ne 0 ]] && echo 1 || echo 0)"
assert_contains "pilot: missing row number is named" "$TL_ERR" "row number"
call -- enterprise_e2e_pilot_log_row_passed 3
assert_contains "pilot: log path is required" "$TL_ERR" "log path"

tl_results
