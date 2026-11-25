#!/usr/bin/env bash
# registry-migrate-install.sh: copy passing rows between install fingerprints in the row-pass registry.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/enterprise-e2e/registry-migrate-install.sh"
REG="$TL_TMP/registry.json"
export SB_E2E_ROW_PASS_REGISTRY="$REG"
FROM="claude@aaaaaaaaaaaa+111111111111"
TO="claude@bbbbbbbbbbbb+111111111111"

seed() {
  jq -n --arg from "$FROM" '{
    schema_version: 1,
    installs: {
      ($from): {
        host: "claude", sb_sha: "aaaaaaaaaaaa", install_fp: $from,
        rows: {
          "1": {outcome_pass: true, source: "live", note: "r1"},
          "3": {outcome_pass: true, source: "live"},
          "6": {outcome_pass: false, source: "live"},
          "11": {outcome_pass: true, source: "live"}
        }
      },
      "nohost@cccccccccccc+222222222222": {rows: {"2": {outcome_pass: true}}}
    }
  }' >"$REG"
}
seed

# --- argument handling --------------------------------------------------------
tl_run bash "$SCRIPT" --help
assert_eq "help exit" "0" "$TL_STATUS"
assert_contains "help prints header comment" "$TL_OUT" "Migrate row-pass registry entries between install fingerprints"

tl_run bash "$SCRIPT" --bogus
assert_eq "unknown arg exit" "2" "$TL_STATUS"
assert_contains "unknown arg message" "$TL_ERR" "Unknown arg: --bogus"

tl_run bash "$SCRIPT" --from "$FROM"
assert_eq "missing --to exit" "2" "$TL_STATUS"
assert_contains "missing --to message" "$TL_ERR" "FAIL: --from and --to required"
tl_run bash "$SCRIPT" --to "$TO"
assert_eq "missing --from exit" "2" "$TL_STATUS"

# --- registry missing / source missing ---------------------------------------------
rm -f "$REG"
tl_run bash "$SCRIPT" --from "$FROM" --to "$TO"
assert_eq "missing registry exit" "1" "$TL_STATUS"
assert_contains "missing registry message" "$TL_ERR" "FAIL: registry missing: $REG"
seed
tl_run bash "$SCRIPT" --from "claude@nope+000000000000" --to "$TO"
assert_eq "unknown source install exit" "1" "$TL_STATUS"
assert_contains "unknown source install message" "$TL_ERR" "FAIL: source install not in registry: claude@nope+000000000000"

# --- dry run does not write -------------------------------------------------------
before="$(cat "$REG")"
tl_run bash "$SCRIPT" --from "$FROM" --to "$TO" --rows "1,3,6" --dry-run
assert_eq "dry run exit" "0" "$TL_STATUS"
assert_contains "dry run lists passing rows" "$TL_OUT" "DRY-RUN: would migrate rows 1,3 $FROM -> $TO"
assert_contains "row without outcome_pass skipped" "$TL_OUT" "SKIP row 6: no outcome_pass on $FROM"
assert_eq "dry run leaves registry untouched" "$before" "$(cat "$REG")"

# --- nothing to migrate ------------------------------------------------------------
tl_run bash "$SCRIPT" --from "$FROM" --to "$TO" --rows "6,9"
assert_eq "nothing to migrate exit" "1" "$TL_STATUS"
assert_contains "nothing to migrate message" "$TL_ERR" "FAIL: nothing to migrate"
assert_eq "no destination install created" "null" "$(jq -c --arg to "$TO" '.installs[$to]' "$REG")"

# non-numeric row list is rejected by the migrator
tl_run bash "$SCRIPT" --from "$FROM" --to "$TO" --rows "abc"
assert_eq "invalid rows exit" "1" "$TL_STATUS"
assert_eq "invalid rows leave registry unchanged" "$before" "$(cat "$REG")"

# --- real migration with source note ------------------------------------------------
tl_run bash "$SCRIPT" --from "$FROM" --to "$TO" --rows "1, 3 ,6" --source-note "gate3-resume-smoke"
assert_eq "migration exit" "0" "$TL_STATUS"
assert_contains "migration summary" "$TL_OUT" "OK: migrated 2 rows -> $TO: 1,3"
assert_eq "destination host copied from source" "claude" "$(jq -r --arg to "$TO" '.installs[$to].host' "$REG")"
assert_eq "destination sb_sha parsed from fingerprint" "bbbbbbbbbbbb" "$(jq -r --arg to "$TO" '.installs[$to].sb_sha' "$REG")"
assert_eq "destination install_fp set" "$TO" "$(jq -r --arg to "$TO" '.installs[$to].install_fp' "$REG")"
assert_eq "seed note carries source note" "gate3-resume-smoke:migrated from $FROM" "$(jq -r --arg to "$TO" '.installs[$to].seed_note' "$REG")"
assert_eq "migrated row ids" "1,3" "$(jq -r --arg to "$TO" '.installs[$to].rows | keys | join(",")' "$REG")"
assert_eq "migrated row source tag" "registry-migrate:$FROM" "$(jq -r --arg to "$TO" '.installs[$to].rows["1"].source' "$REG")"
assert_eq "migrated row keeps other fields" "r1" "$(jq -r --arg to "$TO" '.installs[$to].rows["1"].note' "$REG")"
assert_eq "source install untouched" "live" "$(jq -r --arg from "$FROM" '.installs[$from].rows["1"].source' "$REG")"

# --- no --rows migrates every passing row; existing destination is extended ---------
TO2="claude@dddddddddddd+111111111111"
tl_run bash "$SCRIPT" --from "$FROM" --to "$TO2"
assert_eq "all-rows migration exit" "0" "$TL_STATUS"
assert_contains "all passing rows migrated" "$TL_OUT" "OK: migrated 3 rows -> $TO2: 1,3,11"
assert_eq "no source note gives plain seed note" "migrated from $FROM" "$(jq -r --arg to "$TO2" '.installs[$to].seed_note' "$REG")"
tl_run bash "$SCRIPT" --from "$FROM" --to "$TO" --rows 11
assert_eq "second migration into existing install exit" "0" "$TL_STATUS"
assert_eq "existing destination rows merged" "1,11,3" "$(jq -r --arg to "$TO" '.installs[$to].rows | keys | join(",")' "$REG")"
assert_eq "plain note after merge" "migrated from $FROM" "$(jq -r --arg to "$TO" '.installs[$to].seed_note' "$REG")"

# --- source without recorded host: host taken from destination fingerprint ------------
TO3="codex@eeeeeeeeeeee+333333333333"
tl_run bash "$SCRIPT" --from "nohost@cccccccccccc+222222222222" --to "$TO3"
assert_eq "hostless source exit" "0" "$TL_STATUS"
assert_eq "host derived from destination fp" "codex" "$(jq -r --arg to "$TO3" '.installs[$to].host' "$REG")"

tl_results
