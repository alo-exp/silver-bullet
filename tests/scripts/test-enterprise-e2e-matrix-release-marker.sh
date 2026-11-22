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
# everything staged here is git-ignored except dirty.txt, so the tree is clean until a test creates that file
printf '*\n!.gitignore\n!/dirty.txt\n' >"$R/.gitignore"
git -C "$R" add .gitignore
git -C "$R" -c user.email=t@example.com -c user.name=t commit -q -m "sb root"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
GATE_DIR="$HOME/.claude/.silver-bullet"
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
# the round ledger is the harness's own output: it never makes the tree "dirty" (declared harness outputs), and the
# documented flow works end to end: matrix -> ledger written -> marker written -> ledger + version bump committed -> gate accepts
mkdir -p "$R/.planning/enterprise-e2e"
printf '# ledger baseline\n' >"$R/.planning/enterprise-e2e/ROUND-1-LEDGER.md"; echo "[]" >"$R/.planning/enterprise-e2e/.row-pass-registry.json"
printf '!.planning/\n.planning/*\n!.planning/enterprise-e2e/\n.planning/enterprise-e2e/*\n!.planning/enterprise-e2e/ROUND-*-LEDGER.md\n!.planning/enterprise-e2e/.row-pass-registry.json\n' >>"$R/.gitignore"
printf '{"name":"sb","version":"1.0.0"}\n' >"$R/package.json"; printf '!package.json\n' >>"$R/.gitignore"
git -C "$R" add -A; git -C "$R" -c user.email=t@e.x -c user.name=t commit -q -m "ledger baseline"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
reset; rm -f "$MARKER"
agent <<'EOS'
mkdir -p "$WORK_DIR/$(dirname "$SB_E2E_MATRIX_EVIDENCE_PATH")"
[[ "$SB_E2E_MATRIX_EVIDENCE_PATH" == */ ]] && mkdir -p "$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH" || echo ev >"$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH"
echo "| row | pass |" >>"$SB_ROOT/.planning/enterprise-e2e/ROUND-1-LEDGER.md"
echo "{}" >"$SB_ROOT/.planning/enterprise-e2e/.row-pass-registry.json"
echo "SILVER BULLET ▸ ROUTING silver-feature"
EOS
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
assert_eq "a run that only rewrites the round ledger still writes the marker" "commit=$HEAD_SHA" "$(sed -n 2p "$MARKER")"
assert_contains "the ledger really changed during the run" "$(git -C "$R" status --porcelain)" "ROUND-1-LEDGER.md"
# the release commit: ledger + version bump
jq '.version="1.1.0"' "$R/package.json" >"$R/p.tmp" && mv "$R/p.tmp" "$R/package.json"
git -C "$R" add -A; git -C "$R" -c user.email=t@e.x -c user.name=t commit -q -m "release 1.1.0"
REL_SHA="$(git -C "$R" rev-parse HEAD)"
# the gate's marker check (the real functions of deploy-tier.sh; the full hook is exercised in test-completion-audit-release.sh)
# accepts the supervised marker for that release commit
GFN="$TL_TMP/gatefn/hooks/lib/completion-audit"; mkdir -p "$GFN" "$TL_TMP/gatefn/scripts/lib"
sed -n '/^ca_marker_commit_ok()/,/^}/p;/^ca_surface_change_ok()/,/^}/p;/^ca_json_equal_modulo()/,/^}/p' "$TL_REPO_ROOT/hooks/lib/completion-audit/deploy-tier.sh" >"$GFN/gate.sh"
cp "$TL_REPO_ROOT/scripts/lib/release-surface-allowlist.txt" "$TL_TMP/gatefn/scripts/lib/"
gate_rc() { ( source "$GFN/gate.sh"; ca_marker_commit_ok "$MARKER" "$R" "$REL_SHA" ) && echo 0 || echo $?; }
assert_eq "the gate accepts the supervised marker for the release commit (ledger + bump)" 0 "$(gate_rc)"
echo "hook" >"$R/dirty.txt"; git -C "$R" add -f dirty.txt; git -C "$R" -c user.email=t@e.x -c user.name=t commit -q -m "code after"
REL_SHA="$(git -C "$R" rev-parse HEAD)"
assert_eq "...but not once other files changed after the matrix ran" 1 "$(gate_rc)"
rm -f "$MARKER"
git -C "$R" reset -q --hard "$HEAD_SHA"

# a dirty tree (untracked file at start) writes nothing: that tree is what the nested sessions test
reset; rm -f "$MARKER"; all_rows_agent
echo x >"$R/dirty.txt"
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
assert_file_absent "a tree dirty at start writes no marker" "$MARKER"
assert_contains "the dirty-tree reason is stated" "$TL_OUT" "has uncommitted or untracked changes"
rm -f "$R/dirty.txt"
# a tree that becomes dirty during the run writes nothing
reset; rm -f "$MARKER"
agent <<'EOS'
mkdir -p "$WORK_DIR/$(dirname "$SB_E2E_MATRIX_EVIDENCE_PATH")"
[[ "$SB_E2E_MATRIX_EVIDENCE_PATH" == */ ]] && mkdir -p "$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH" || echo ev >"$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH"
echo x >"$SB_ROOT/dirty.txt"
echo "SILVER BULLET ▸ ROUTING silver-feature"
EOS
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
assert_file_absent "a tree dirtied during the run writes no marker" "$MARKER"
rm -f "$R/dirty.txt"
# a failing `git status` (corrupt index) is not a clean tree: fail closed, nothing is written
reset; rm -f "$MARKER"
agent <<'EOS'
mkdir -p "$WORK_DIR/$(dirname "$SB_E2E_MATRIX_EVIDENCE_PATH")"
[[ "$SB_E2E_MATRIX_EVIDENCE_PATH" == */ ]] && mkdir -p "$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH" || echo ev >"$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH"
printf 'not an index' >"$SB_ROOT/.git/index"
echo "SILVER BULLET ▸ ROUTING silver-feature"
EOS
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
assert_file_absent "git status failing at the end: no marker (fail closed)" "$MARKER"
assert_contains "the failed check is reported as an unclean tree" "$TL_OUT" "has uncommitted or untracked changes"
rm -f "$R/.git/index"; git -C "$R" reset -q
# HEAD moving during the run writes nothing
reset; rm -f "$MARKER"
agent <<'EOS'
mkdir -p "$WORK_DIR/$(dirname "$SB_E2E_MATRIX_EVIDENCE_PATH")"
[[ "$SB_E2E_MATRIX_EVIDENCE_PATH" == */ ]] && mkdir -p "$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH" || echo ev >"$WORK_DIR/$SB_E2E_MATRIX_EVIDENCE_PATH"
[[ -e "$F2_CTL/moved" ]] || { : >"$F2_CTL/moved"; git -C "$SB_ROOT" -c user.email=t@e.x -c user.name=t commit -q --allow-empty -m moved; }
echo "SILVER BULLET ▸ ROUTING silver-feature"
EOS
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
assert_file_absent "HEAD moved during the run: no marker" "$MARKER"
assert_contains "the HEAD-moved reason is stated" "$TL_OUT" "HEAD moved during the run"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"

# the nested sessions' SessionStart resets must not destroy the operator's evidence (full pass and failing run)
EVD="release-live-matrix quality-gate-state verify-tests-state e2e-live-matrix"
seed_evidence() { mkdir -p "$GATE_DIR"; for f in $EVD; do printf 'keep-%s\n' "$f" >"$GATE_DIR/$f"; done; }
resetting_agent() { agent <<EOS
for f in $EVD; do rm -f "$GATE_DIR/\$f"; done
mkdir -p "\$WORK_DIR/\$(dirname "\$SB_E2E_MATRIX_EVIDENCE_PATH")"
[[ "\$SB_E2E_MATRIX_EVIDENCE_PATH" == */ ]] && mkdir -p "\$WORK_DIR/\$SB_E2E_MATRIX_EVIDENCE_PATH" || echo ev >"\$WORK_DIR/\$SB_E2E_MATRIX_EVIDENCE_PATH"
echo "SILVER BULLET ▸ ROUTING silver-feature"
EOS
}
reset; rm -f "$MARKER"; seed_evidence; resetting_agent
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX"
for f in $EVD; do assert_eq "full pass keeps the operator's $f" "keep-$f" "$(cat "$GATE_DIR/$f")"; done
assert_eq "and still writes the marker" "matrix=inline-full-surface" "$(sed -n 1p "$MARKER")"
reset; rm -f "$MARKER"; seed_evidence; resetting_agent
run env SB_E2E_MATRIX_FORCE_ALL=1 F2_DELTA_FAIL_AT=3 SB_E2E_PRODUCT_WORK_GATE=1 bash "$MATRIX"
for f in $EVD; do assert_eq "a failing run keeps the operator's $f (EXIT trap)" "keep-$f" "$(cat "$GATE_DIR/$f")"; done
assert_file_absent "a failing run writes no marker" "$MARKER"

# isolated-config mode (agent-claude wrapper): the nested sessions use a throw-away state dir, but the marker goes
# where the GATE reads it (the releasing session's state dir), never into the isolated one
reset; rm -f "$MARKER"; all_rows_agent
ISO="$TL_TMP/isoconfig"; mkdir -p "$ISO/.silver-bullet-state"
run env SB_E2E_MATRIX_FORCE_ALL=1 SB_E2E_ISOLATED_CLAUDE_CONFIG=1 CLAUDE_CONFIG_DIR="$ISO" \
  SB_RUNTIME_STATE_DIR="$ISO/.silver-bullet-state" SB_RUNTIME_PRESERVE_STATE_DIR=1 bash "$MATRIX"
assert_eq "isolated mode: the marker is where the gate reads it" "matrix=inline-full-surface" "$(sed -n 1p "$GATE_DIR/inline-e2e-matrix")"
assert_file_absent "isolated mode: nothing in the isolated state dir" "$ISO/.silver-bullet-state/inline-e2e-matrix"
rm -f "$GATE_DIR/inline-e2e-matrix"

# the gate's state directory cannot be created (HOME/.claude is a regular file): nothing is written, the run still passes
reset; rm -f "$MARKER"; all_rows_agent
BAD="$TL_TMP/badhome"; mkdir -p "$BAD"; : >"$BAD/.claude"
run env SB_E2E_MATRIX_FORCE_ALL=1 SB_E2E_ISOLATED_CLAUDE_CONFIG=1 CLAUDE_CONFIG_DIR="$ISO" \
  SB_RUNTIME_STATE_DIR="$ISO/.silver-bullet-state" SB_RUNTIME_PRESERVE_STATE_DIR=1 HOME="$BAD" bash "$MATRIX"
assert_eq "an uncreatable gate state dir does not fail an otherwise passing run" 0 "$TL_STATUS"
assert_contains "the uncreatable-dir reason is stated" "$TL_OUT" "state directory cannot be resolved or created"
assert_file_absent "an uncreatable gate state dir writes no marker" "$BAD/.claude/.silver-bullet/inline-e2e-matrix"

# the runner survives a ps that cannot describe its own pid (identity record skipped, tolerated)
reset; rm -f "$MARKER"
all_rows_agent
tl_stub ps 'exit 1'
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$MATRIX" 2
/bin/rm -f "$TL_BIN/ps"
assert_eq "an unreadable ps does not abort the matrix runner" 0 "$TL_STATUS"
tl_results
