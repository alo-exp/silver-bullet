#!/usr/bin/env bash
# Matrix quiesce helpers: orchestrator queue clearing, workflow archiving, router evidence.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-matrix-quiesce.sh"
# shellcheck source=scripts/lib/enterprise-e2e-matrix-quiesce.sh
source "$LIB"

# --- orchestrator queue: fallback (no orchestrator-state.sh in the SB root) ----
bare="$TL_TMP/bare-root"
mkdir -p "$bare/hooks/lib"
for f in orchestrator.json orchestrator-directive.json orchestrator-worker-active.json keep.json; do
  : >"$SB_RUNTIME_STATE_DIR/$f"
done
enterprise_e2e_matrix_quiesce_orchestrator_queue "$bare"
assert_file_absent "fallback removes orchestrator.json" "$SB_RUNTIME_STATE_DIR/orchestrator.json"
assert_file_absent "fallback removes directive" "$SB_RUNTIME_STATE_DIR/orchestrator-directive.json"
assert_file_absent "fallback removes worker-active" "$SB_RUNTIME_STATE_DIR/orchestrator-worker-active.json"
assert_file_exists "fallback leaves unrelated state" "$SB_RUNTIME_STATE_DIR/keep.json"

# SB root defaults to $SB_ROOT; with neither lib present the call still succeeds
: >"$SB_RUNTIME_STATE_DIR/orchestrator.json"
SB_ROOT="$bare" enterprise_e2e_matrix_quiesce_orchestrator_queue
assert_file_absent "SB_ROOT default used when no arg" "$SB_RUNTIME_STATE_DIR/orchestrator.json"

# rm failing is tolerated in the fallback branch
tl_stub rm 'exit 1'
hash -r
rc=0
enterprise_e2e_matrix_quiesce_orchestrator_queue "$bare" || rc=$?
assert_eq "failing rm tolerated in fallback" "0" "$rc"
/bin/rm -f "$TL_BIN/rm"
hash -r

# --- orchestrator queue: libs present; failing helpers never abort the caller ----
libroot="$TL_TMP/lib-root"
mkdir -p "$libroot/hooks/lib"
cat >"$libroot/hooks/lib/orchestrator-state.sh" <<LIBEOF
sb_orchestrator_clear_queue() { echo cleared >"$TL_TMP/queue-cleared"; return 1; }
LIBEOF
cat >"$libroot/hooks/lib/e2e-matrix-routing.sh" <<LIBEOF
sb_e2e_matrix_clear_routing_row_marker() { echo cleared >"$TL_TMP/marker-cleared"; return 1; }
LIBEOF
rc=0
enterprise_e2e_matrix_quiesce_orchestrator_queue "$libroot" || rc=$?
assert_eq "failing clear helpers are tolerated" "0" "$rc"
assert_file_exists "queue clear helper ran" "$TL_TMP/queue-cleared"
assert_file_exists "routing marker helper ran" "$TL_TMP/marker-cleared"

# --- workflows --------------------------------------------------------------
export WORK_DIR="$TL_TMP/work"
wf="$WORK_DIR/.planning/workflows"

# missing workflow dir: no-op, no archive dir created
rc=0
matrix_quiesce_active_workflows || rc=$?
assert_eq "no workflows dir is a no-op" "0" "$rc"
assert_file_absent "no archive created without workflows dir" "$wf/.archive"

mkdir -p "$wf"
printf 'x\n' >"$wf/20260101T000000Z-aaa-silver-feature.md"
printf 'x\n' >"$wf/stale.md"
printf 'x\n' >"$wf/20260102T000000Z-bbb-silver-bugfix.md"

# SB root with an executable workflows.sh: completes dated workflows; on failure moves the file
sbroot="$TL_TMP/sb-with-workflows"
mkdir -p "$sbroot/scripts"
cat >"$sbroot/scripts/workflows.sh" <<WFEOF
#!/usr/bin/env bash
echo "\$1 \$2" >>"$TL_TMP/wf-calls"
[[ "\$2" == *bbb* ]] && exit 1
rm -f "$wf/\$2.md"
exit 0
WFEOF
chmod +x "$sbroot/scripts/workflows.sh"
SB_ROOT="$sbroot" matrix_quiesce_active_workflows
assert_contains "workflows.sh complete called for first id" "$(cat "$TL_TMP/wf-calls")" "complete 20260101T000000Z-aaa-silver-feature"
assert_contains "workflows.sh complete called for second id" "$(cat "$TL_TMP/wf-calls")" "complete 20260102T000000Z-bbb-silver-bugfix"
assert_file_absent "completed workflow removed by workflows.sh" "$wf/20260101T000000Z-aaa-silver-feature.md"
assert_file_exists "failed completion falls back to archive move" "$wf/.archive/20260102T000000Z-bbb-silver-bugfix.md"
assert_file_absent "failed workflow no longer active" "$wf/20260102T000000Z-bbb-silver-bugfix.md"
assert_file_exists "non-dated markdown archived" "$wf/.archive/stale.md"
assert_file_absent "non-dated markdown no longer active" "$wf/stale.md"

# without workflows.sh dated files are archived directly
printf 'x\n' >"$wf/20260103T000000Z-ccc-silver-fast.md"
printf 'x\n' >"$wf/other.md"
SB_ROOT="$bare" matrix_quiesce_active_workflows
assert_file_exists "dated file archived directly" "$wf/.archive/20260103T000000Z-ccc-silver-fast.md"
assert_file_exists "other file archived directly" "$wf/.archive/other.md"

# empty SB_ROOT behaves like no workflows.sh available
printf 'x\n' >"$wf/20260104T010203Z-x.md"
SB_ROOT="" matrix_quiesce_active_workflows
assert_file_exists "no SB root: dated file archived" "$wf/.archive/20260104T010203Z-x.md"

# The non-dated sweep skips real workflow ids (YYYYMMDDTHHMMSSZ-...): a "completed" workflow
# that stays on disk is left in place by the second pass.
rm -rf "${wf:?}"/* "$wf/.archive"
printf 'x\n' >"$wf/20260105T000000Z-ddd-silver-test.md"
printf '#!/usr/bin/env bash\nexit 0\n' >"$sbroot/scripts/workflows.sh"
SB_ROOT="$sbroot" matrix_quiesce_active_workflows
assert_file_exists "completed-but-present dated workflow left in place" "$wf/20260105T000000Z-ddd-silver-test.md"

# failing mv is tolerated everywhere
printf 'x\n' >"$wf/plain.md"
tl_stub mv 'exit 1'
hash -r
rc=0
SB_ROOT="$bare" matrix_quiesce_active_workflows || rc=$?
assert_eq "failing mv tolerated" "0" "$rc"
assert_file_exists "file stays when mv fails" "$wf/plain.md"
printf '#!/usr/bin/env bash\nexit 1\n' >"$sbroot/scripts/workflows.sh"
rc=0
SB_ROOT="$sbroot" matrix_quiesce_active_workflows || rc=$?
assert_eq "failing completion plus failing mv tolerated" "0" "$rc"
/bin/rm -f "$TL_BIN/mv"
hash -r

# --- router session evidence ---------------------------------------------------
evidence=".planning/workflows/router-session.md"
# fallback state path (routing helper not defined)
mkdir -p "$HOME/.claude/.silver-bullet"
printf 'silver-feature\n\nsilver-fast\n' >"$HOME/.claude/.silver-bullet/state"
matrix_write_router_session_evidence "$evidence"
body="$(cat "$WORK_DIR/$evidence")"
assert_contains "evidence header" "$body" "# Router session evidence (matrix row 1 — routing-only)"
assert_match "evidence has UTC timestamp" 'Routing validated via interactive TUI on [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z\.' "$body"
assert_contains "evidence lists skills from fallback state file" "$body" "- silver-feature"
assert_contains "evidence lists second skill" "$body" "- silver-fast"
assert_not_contains "blank state lines dropped" "$body" "- "$'\n'

# routing helper defined: its state file is used; absent state file omits the skills list
enterprise_e2e_routing_state_file() { printf '%s' "$TL_TMP/custom-state"; }
rm -f "$HOME/.claude/.silver-bullet/state"
matrix_write_router_session_evidence "nested/dir/evidence.md"
body="$(cat "$WORK_DIR/nested/dir/evidence.md")"
assert_not_contains "no skills section without state file" "$body" "Skills in"
printf 'silver-quality-gates\n' >"$TL_TMP/custom-state"
matrix_write_router_session_evidence "nested/dir/evidence.md"
body="$(cat "$WORK_DIR/nested/dir/evidence.md")"
assert_contains "custom state file named" "$body" "Skills in $TL_TMP/custom-state:"
assert_contains "custom state skill listed" "$body" "- silver-quality-gates"

tl_results
