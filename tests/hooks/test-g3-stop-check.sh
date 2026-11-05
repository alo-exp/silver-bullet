#!/usr/bin/env bash
# Review package G3 (R2-09 R2-10 R2-30 R2-36 R5-06 + R3-02 hand-off): hooks/stop-check.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
HOOK="$TL_REPO_ROOT/hooks/stop-check.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SB_E2E_ENTERPRISE_MATRIX SILVER_BULLET_STATE_FILE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
SESSION_FILE="$TL_TMP/session-start"
export SILVER_BULLET_SESSION_START_FILE="$SESSION_FILE"

reason() { jq -r '.reason // ""' <<<"$TL_OUT"; }
run_stop() { # [json]
  tl_run_stdin "${1:-{\"hook_event_name\":\"Stop\"\}}" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
}
reset() {
  rm -f "$SD/orchestrator.json" "$SD/branch" "$SD/stall-block" "$SD/files-written" "$SD/trivial" \
    "$SD/stop-loop-release.log" "$SD/e2e-matrix-routing-row"
  git -C "$EC_PROJ" reset -q --hard
  git -C "$EC_PROJ" clean -qfd
  git -C "$EC_PROJ" checkout -q feature/test 2>/dev/null || true
  printf 'silver-context\n' >"$SD/state"
  ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"project":{"src_pattern":"/src/","src_exclude_pattern":"__tests__"},"skills":{}}'
  date +%s >"$SESSION_FILE"
}

# ---- R2-30: REVIEW.md filter is anchored, no awk warnings -------------------------
reset
mkdir -p "$EC_PROJ/docs"
printf 'x\n' >"$EC_PROJ/docs/CODE-REVIEW.md"
run_stop
assert_contains "R2-30: docs/CODE-REVIEW.md alone is real work: planning floor applies" "$(reason)" "missing required skills"
assert_eq "R2-30: no awk escape warning on stderr" "" "$TL_ERR"
reset
printf 'x\n' >"$EC_PROJ/REVIEW.md"
run_stop
assert_eq "R2-30: a root REVIEW.md is still transient (honest variant)" "0:" "$TL_STATUS:$TL_OUT"
reset
mkdir -p "$EC_PROJ/.planning/workflows" "$EC_PROJ/.planning/phases/01-x"
printf 'w\n' >"$EC_PROJ/.planning/workflows/a.md"
printf 'r\n' >"$EC_PROJ/.planning/phases/01-x/01-REVIEW.md"
run_stop
assert_eq "R2-30: workflow and phase REVIEW files are still transient" "0:" "$TL_STATUS:$TL_OUT"

# ---- R2-09: stall flag clears once a skill is recorded after it --------------------
reset
printf 'x\n' >"$EC_PROJ/dirty.txt"
printf '100\n' >"$SD/stall-block"
printf '100\n' >"$SD/old-epoch"
date +%s >"$SESSION_FILE"
touch -t 202001010000 "$SD/state"
touch -t 202001020000 "$SD/stall-block"
printf '1\n' >"$SESSION_FILE"
run_stop
assert_contains "R2-09: stall flag newer than the state blocks Stop" "$(reason)" "Autonomous stall detected"
touch -t 202001030000 "$SD/state"
run_stop
assert_not_contains "R2-09: a skill recorded after the stall lifts it" "$TL_OUT" "Autonomous stall"
assert_file_absent "R2-09: stale stall flag removed" "$SD/stall-block"
assert_contains "R2-09: normal planning floor still evaluated after the stall lifts" "$(reason)" "missing required skills"

# ---- R2-10: unclearable branch-mismatch block releases on stop_hook_active ---------
reset
printf 'x\n' >"$EC_PROJ/dirty.txt"
printf 'main\n/some/other/worktree\n' >"$SD/branch"
printf 'silver-quality-gates\nsilver-context\nsilver-plan\n' >"$SD/state"
run_stop
assert_contains "R2-10: first Stop on a branch mismatch blocks" "$(reason)" "skill state is from branch 'main'"
run_stop '{"hook_event_name":"Stop","stop_hook_active":true}'
assert_not_contains "R2-10: stop_hook_active releases the mismatch block" "$TL_OUT" '"decision"'
assert_contains "R2-10: release is visible to the user" "$TL_OUT" "systemMessage"
assert_file_exists "R2-10: release is audited" "$SD/stop-loop-release.log"
# honest variant: a clearable block (missing skill) is NOT released by stop_hook_active
reset
printf 'x\n' >"$EC_PROJ/dirty.txt"
run_stop '{"hook_event_name":"Stop","stop_hook_active":true}'
assert_contains "R2-10: a clearable planning block still holds with stop_hook_active" "$(reason)" "missing required skills"

# ---- R2-22: coalesce file does not survive into a later SubagentStop ---------------
reset
printf 'stale' >"$SD/stop-coalesce-block"
run_stop '{"hook_event_name":"SubagentStop"}'
assert_file_absent "R2-22: SubagentStop clears a stale coalesce file" "$SD/stop-coalesce-block"

# ---- R2-36: agent-written source with an empty state --------------------------------
reset
: >"$SD/state"
mkdir -p "$EC_PROJ/src"
printf 'a\n' >"$EC_PROJ/src/app.py"
run_stop
assert_eq "R2-36: user's own pending src edits, no agent writes: allowed" "0:" "$TL_STATUS:$TL_OUT"
: >"$SD/files-written"
run_stop
assert_contains "R2-36: agent wrote src this session, no skills: planning floor blocks" "$(reason)" "missing required skills"
rm -f "$EC_PROJ/src/app.py"
printf 'doc\n' >"$EC_PROJ/README.md"
run_stop
assert_eq "R2-36: agent wrote only docs: allowed" "0:" "$TL_STATUS:$TL_OUT"
mkdir -p "$EC_PROJ/src/__tests__"
printf 't\n' >"$EC_PROJ/src/__tests__/a.test.js"
run_stop
assert_eq "R2-36: excluded test paths do not count as source" "0:" "$TL_STATUS:$TL_OUT"
rm -rf "$EC_PROJ/src"
mkdir -p "$EC_PROJ/src"
printf 'a\n' >"$EC_PROJ/src/app.py"
touch -t 202001010000 "$SD/files-written"
run_stop
assert_eq "R2-36: a marker older than the session start is ignored" "0:" "$TL_STATUS:$TL_OUT"
: >"$SD/files-written"
rm -f "$SESSION_FILE"
run_stop
assert_eq "R2-36: unknown session start: marker not trusted" "0:" "$TL_STATUS:$TL_OUT"
printf 'junk\n' >"$SESSION_FILE"
run_stop
assert_eq "R2-36: non-numeric session start: marker not trusted" "0:" "$TL_STATUS:$TL_OUT"
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"project":{"src_pattern":".*","src_exclude_pattern":"$(x)"},"skills":{}}'
date +%s >"$SESSION_FILE"
: >"$SD/files-written"
run_stop
assert_contains "R2-36: invalid src_pattern falls back to /src/" "$(reason)" "missing required skills"
reset
: >"$SD/state"
rm -f "$SD/session-start-time"
unset SILVER_BULLET_SESSION_START_FILE
date +%s >"$SD/session-start-time"
mkdir -p "$EC_PROJ/src"
printf 'a\n' >"$EC_PROJ/src/app.py"
: >"$SD/files-written"
run_stop
assert_contains "R2-36: default session-start-time file is honoured" "$(reason)" "missing required skills"
rm -f "$SD/session-start-time"
export SILVER_BULLET_SESSION_START_FILE="$SESSION_FILE"

# ---- R3-02 hand-off: a forged trivial_file cannot bypass Stop ------------------------
reset
printf 'x\n' >"$EC_PROJ/dirty.txt"
printf 'marker\n' >"$SD/some-runtime-marker"
ec_cfg "{\"config_version\":\"0.40.0\",\"sb_initiated\":true,\"state\":{\"trivial_file\":\"$SD/some-runtime-marker\"},\"skills\":{}}"
run_stop
assert_contains "R3-02: trivial_file naming another runtime file does not bypass Stop" "$(reason)" "missing required skills"
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"skills":{}}'
: >"$SD/trivial"
run_stop
assert_eq "R3-02: the genuine trivial marker still bypasses (honest variant)" "0:" "$TL_STATUS:$TL_OUT"

# ---- R5-06: the E2E routing marker is not a forgeable Stop exemption ------------------
reset
printf 'x\n' >"$EC_PROJ/dirty.txt"
jq -n --arg repo "$EC_PROJ" '{current_flow:"FLOW-EXECUTE",repo_root:$repo,workflow_id:"20260428T120000Z-abc123-silver-feature"}' >"$SD/orchestrator.json"
jq -n '{next_skill:"silver-execute",next_worker_template:"EXECUTE"}' >"$SD/orchestrator-directive.json"
touch "$SD/e2e-matrix-routing-row"
run_stop
assert_contains "R5-06: touch-created marker does not exempt Stop" "$(reason)" "Orchestrator parent"
export SB_E2E_ENTERPRISE_MATRIX=1
run_stop
assert_contains "R5-06: env without a valid marker still blocks" "$(reason)" "Orchestrator parent"
printf '%s\n' "$(($(date +%s) - 5))" >"$SD/e2e-matrix-routing-row"
run_stop
assert_contains "R5-06: an expired marker does not exempt" "$(reason)" "Orchestrator parent"
printf '%s\n' "$(($(date +%s) + 600))" >"$SD/e2e-matrix-routing-row"
unset SB_E2E_ENTERPRISE_MATRIX
run_stop
assert_contains "R5-06: marker without the harness environment does not exempt" "$(reason)" "Orchestrator parent"
export SB_E2E_ENTERPRISE_MATRIX=1
run_stop
assert_eq "R5-06: harness env + valid marker still exempts (E2E routing row)" "0:" "$TL_STATUS:$TL_OUT"
unset SB_E2E_ENTERPRISE_MATRIX

# ---- release log unwritable: the release still happens; trivial file named trivial elsewhere ----------------
reset
printf 'x\n' >"$EC_PROJ/dirty.txt"
printf 'main\n/some/other/worktree\n' >"$SD/branch"
printf 'silver-quality-gates\nsilver-context\nsilver-plan\n' >"$SD/state"
mkdir "$SD/stop-loop-release.log"
run_stop '{"hook_event_name":"Stop","stop_hook_active":true}'
assert_contains "R2-10: release survives an unwritable audit log" "$TL_OUT" "systemMessage"
rmdir "$SD/stop-loop-release.log"
reset
printf 'x\n' >"$EC_PROJ/dirty.txt"
mkdir -p "$SD/other"
ec_cfg "{\"config_version\":\"0.40.0\",\"sb_initiated\":true,\"state\":{\"trivial_file\":\"$SD/other/trivial\"},\"skills\":{}}"
: >"$SD/other/trivial"
run_stop
assert_eq "R3-02: a state-scoped file named trivial is honoured" "0:" "$TL_STATUS:$TL_OUT"
# trivial-file-clear leaves the files-written trace even when it cannot be refreshed
mkdir "$SD/files-written"
tl_run_stdin '{}' bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$TL_REPO_ROOT/hooks/trivial-file-clear.sh"
assert_eq "R2-36: an unwritable marker is tolerated" 0 "$TL_STATUS"
rmdir "$SD/files-written"
tl_run_stdin '{}' bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$TL_REPO_ROOT/hooks/trivial-file-clear.sh"
assert_file_exists "R2-36: Write/Edit leaves the files-written marker" "$SD/files-written"
reset

# ---- R3-02 hand-off helpers (shared with the delivery gates) ------------------------------------------
source "$TL_REPO_ROOT/hooks/lib/trivial-bypass.sh"
assert_eq "state config path: ~ expands" "$HOME/x/trivial" "$(sb_expand_state_config_path '~/x/trivial')"
assert_eq "state config path: \${SB_RUNTIME_HOME_ROOT} expands" "$SB_RUNTIME_HOME_ROOT/.silver-bullet/trivial" "$(sb_expand_state_config_path '${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial')"
assert_eq "state config path: \$SB_RUNTIME_HOME_ROOT expands" "$SB_RUNTIME_HOME_ROOT/t" "$(sb_expand_state_config_path '$SB_RUNTIME_HOME_ROOT/t')"
assert_eq "state config path: no root leaves it alone" '${SB_RUNTIME_HOME_ROOT}/t' "$(SB_RUNTIME_HOME_ROOT= sb_expand_state_config_path '${SB_RUNTIME_HOME_ROOT}/t')"

tl_results
