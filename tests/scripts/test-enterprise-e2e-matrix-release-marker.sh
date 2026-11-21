#!/usr/bin/env bash
# The Claude supervised matrix writes the release marker inline-e2e-matrix (matrix=inline-full-surface,
# commit=<SB HEAD>) ONLY after a complete real pass (R14-05/R14-16).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-matrix-setup.sh"

MARKER="$SB_RUNTIME_STATE_DIR/inline-e2e-matrix"
git -C "$R" init -q -b main
git -C "$R" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m "sb root"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
# every row's evidence is produced by the stub agent (a file or directory at the row's evidence path)
all_rows_agent() { agent <<'EOS'
mkdir -p "$WORK_DIR/$(dirname "$SB_E2E_MATRIX_EVIDENCE_PATH")"
[[ "$SB_E2E_MATRIX_EVIDENCE_PATH" == */ ]] && mkdir -p "$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH" || echo ev >"$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH"
echo "SILVER BULLET ▸ ROUTING silver-feature"
EOS
}

reset
rm -f "$MARKER"
all_rows_agent
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
assert_contains "full run reaches 22/22" "$TL_OUT" "Total: 22 / 22"
if [[ "$TL_STATUS" == 0 ]]; then
  assert_eq "marker names the inline surface" "matrix=inline-full-surface" "$(sed -n 1p "$MARKER")"
  assert_eq "marker is bound to the SB commit" "commit=$HEAD_SHA" "$(sed -n 2p "$MARKER")"
  assert_match "marker carries a timestamp" '^written_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(sed -n 3p "$MARKER")"
  assert_eq "marker names its writer" "source=claude-supervised-matrix" "$(sed -n 4p "$MARKER")"
  assert_eq "marker is mode 0600" 600 "$(stat -c %a "$MARKER")"
else
  tl_fail "full stubbed run passes (status $TL_STATUS): $(tail -5 <<<"$TL_OUT")"
fi

# a failing row: nothing is written
reset; rm -f "$MARKER"
all_rows_agent
run env SB_E2E_MATRIX_FORCE_ALL=1 F2_DELTA_FAIL_AT=3 SB_E2E_PRODUCT_WORK_GATE=1 bash "$MATRIX"
assert_file_absent "a failed row writes no marker" "$MARKER"

# a partial run (row arguments) and a dry run write nothing
reset; rm -f "$MARKER"
all_rows_agent
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX" 2
assert_file_absent "a partial run writes no marker" "$MARKER"
assert_contains "the partial-run reason is stated" "$TL_OUT" "inline-e2e-matrix not written: it needs a full"
run env SB_E2E_MATRIX_DRY_RUN=1 bash "$MATRIX"
assert_file_absent "a dry run writes no marker" "$MARKER"

# a skipped (install-pass) row means it was not run: nothing is written
reset; rm -f "$MARKER"
all_rows_agent
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX" 2
run bash "$MATRIX"
assert_file_absent "a run with skipped rows writes no marker" "$MARKER"

# no commit to bind to: nothing is written
reset; rm -f "$MARKER"
all_rows_agent
mv "$R/.git" "$TL_TMP/git.bak"
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
mv "$TL_TMP/git.bak" "$R/.git"
assert_file_absent "no git commit: no marker" "$MARKER"
assert_contains "no-commit reason is stated" "$TL_OUT" "has no commit to bind it to"
# the runner survives a ps that cannot describe its own pid (identity record skipped, tolerated)
reset; rm -f "$MARKER"
all_rows_agent
tl_stub ps 'exit 1'
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX" 2
/bin/rm -f "$TL_BIN/ps"
assert_eq "an unreadable ps does not abort the matrix runner" 0 "$TL_STATUS"
tl_results
