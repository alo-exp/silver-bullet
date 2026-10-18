#!/usr/bin/env bash
# hooks/stop-check.sh: orchestrator, stall, branch-scope, anchor and fallback paths.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/stop-check.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SILVER_BULLET_UPDATE_CHECK_DISABLED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SB_E2E_ENTERPRISE_MATRIX

ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
STATE="$SD/state"
BASE_CFG='{"config_version":"0.40.0","sb_initiated":true,"project":{"src_pattern":"/src/","active_workflow":"full-dev-cycle"},"skills":{}}'

# run_stop [json] [hook]: run from $EC_RUN_DIR (default project root).
run_stop() {
  local json="${1:-}" hook="${2:-$HOOK}"
  [[ -n "$json" ]] || json='{"hook_event_name":"Stop"}'
  tl_run_stdin "$json" bash -c 'cd "$1" && exec bash "$2"' _ "${EC_RUN_DIR:-$EC_PROJ}" "$hook"
}
reset_state() {
  local f
  for f in orchestrator.json orchestrator-directive.json orchestrator-worker-active.json stall-block session-start-time branch trivial; do
    rm -f "${SD:?}/${f:?}"
  done
  printf 'silver-context\n' >"$STATE"
  ec_cfg "$BASE_CFG"
  EC_RUN_DIR="$EC_PROJ"
  : >"$EC_PROJ/dirty.txt"
}
reason() { jq -r '.reason // ""' <<<"$TL_OUT"; }

# ---- no tracked skills at all: nothing to gate ------------------------------
reset_state
: >"$STATE"
run_stop
assert_eq "empty state file: silent allow" "0:" "$TL_STATUS:$TL_OUT"
rm -f "$STATE"
run_stop
assert_eq "no state file: silent allow" "0:" "$TL_STATUS:$TL_OUT"

# ---- branch that cannot be determined: enforcement still applies ---------------
reset_state
ec_fail git '*"rev-parse --abbrev-ref"*'
run_stop
ec_unfail git
assert_contains "git failing for the branch: the planning floor still blocks" "$(reason)" "silver-quality-gates"

# ---- an active RFL run whose Policy C assertion fails blocks the stop ---------------
ec_stage_hooks "$TL_TMP/rfl" rfl-policy-c-assert.sh
cat >"$TL_TMP/rfl/hooks/lib/rfl-policy-c-assert.sh" <<'EOF'
sb_rfl_policy_c_gate_disabled() { return 1; }
sb_rfl_policy_c_has_active_run() { return 0; }
sb_rfl_policy_c_run_assert() { printf '{"ok":false,"why":"fake"}'; return 1; }
sb_rfl_policy_c_reason_from_json() { printf 'RFL-POLICY-C-MISSING'; }
EOF
reset_state
run_stop "" "$TL_TMP/rfl/hooks/stop-check.sh"
assert_eq "active RFL run, failing assertion: block decision" "block" "$(jq -r '.decision // ""' <<<"$TL_OUT")"
assert_eq "active RFL run, failing assertion: reason from the assertion" "RFL-POLICY-C-MISSING" "$(reason)"

# ---- baseline: missing planning skills block --------------------------------
reset_state
run_stop
assert_eq "baseline exit" "0" "$TL_STATUS"
assert_contains "baseline blocks on missing skills" "$(reason)" "silver-quality-gates"
assert_not_contains "recorded skill is not listed as missing" "$(reason)" "- silver-context"

# ---- SubagentStop of a worker clears the marker -----------------------------
reset_state
marker="$SD/orchestrator-worker-active.json"
jq -n --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{skill:"silver-execute",spawned_at:$at}' >"$marker"
run_stop '{"hook_event_name":"SubagentStop"}'
assert_eq "worker SubagentStop prints nothing" "" "$TL_OUT"
assert_file_absent "worker marker cleared" "$marker"

# ---- parent session with a pending flow queue -------------------------------
reset_state
jq -n --arg repo "$EC_PROJ" '{current_flow:"FLOW-EXECUTE",repo_root:$repo}' >"$SD/orchestrator.json"
run_stop
assert_contains "parent without directive derives skill from flow" "$(reason)" "/silver-execute"
assert_contains "parent without directive uses generic worker" "$(reason)" "(WORKER.md)"
assert_contains "parent names the flow" "$(reason)" "(FLOW-EXECUTE)"
jq -n '{next_skill:"silver-verify",next_worker_template:"VERIFY"}' >"$SD/orchestrator-directive.json"
run_stop
assert_contains "parent directive skill wins" "$(reason)" "/silver-verify"
assert_contains "parent directive template wins" "$(reason)" "(VERIFY.md)"

# ---- scheduler pending work blocks the parent -------------------------------
reset_state
jq -n --arg repo "$EC_PROJ" '{repo_root:$repo,scheduler:{join_gates:{"gate-7":"blocked"}}}' >"$SD/orchestrator.json"
run_stop
assert_contains "scheduler join gate blocks stop" "$(reason)" "join gate blocked for gate-7"
jq -n --arg repo "$EC_PROJ" '{repo_root:$repo,scheduler:{join_gates:{}}}' >"$SD/orchestrator.json"
run_stop
assert_not_contains "no pending scheduler work does not block as scheduler" "$(reason)" "Orchestrator scheduler"

# ---- autonomous stall flag --------------------------------------------------
reset_state
printf '120' >"$SD/stall-block"
run_stop
assert_contains "stall flag with no session start blocks" "$(reason)" "120 tool calls without workflow progress"
printf '%s' "$(( $(date +%s) + 3600 ))" >"$SD/session-start-time"
run_stop
assert_not_contains "stall flag older than this session is ignored" "$(reason)" "Autonomous stall"
printf '1' >"$SD/session-start-time"
run_stop
assert_contains "stall flag newer than session start blocks (session-start-time)" "$(reason)" "Autonomous stall"
rm -f "${SD:?}/session-start-time"
printf '%s' "$(( $(date +%s) + 3600 ))" >"$TL_TMP/ss-epoch"
SILVER_BULLET_SESSION_START_FILE="$TL_TMP/ss-epoch" run_stop
assert_not_contains "SILVER_BULLET_SESSION_START_FILE overrides" "$(reason)" "Autonomous stall"
printf 'garbage' >"$TL_TMP/ss-epoch"
SILVER_BULLET_SESSION_START_FILE="$TL_TMP/ss-epoch" run_stop
assert_contains "non-numeric session start still blocks" "$(reason)" "Autonomous stall"
# BSD stat flavour (Darwin branch)
REAL_STAT="$(command -v stat)"
tl_stub uname 'echo Darwin'
tl_stub stat "if [[ \"\$1\" == \"-f\" ]]; then shift 2; exec $REAL_STAT -c %Y \"\$@\"; fi; exec $REAL_STAT \"\$@\""
printf '%s' "$(( $(date +%s) + 3600 ))" >"$TL_TMP/ss-epoch"
SILVER_BULLET_SESSION_START_FILE="$TL_TMP/ss-epoch" run_stop
assert_not_contains "Darwin stat flavour: old flag ignored" "$(reason)" "Autonomous stall"
rm -f "${TL_BIN:?}/uname" "${TL_BIN:?}/stat"
rm -f "${SD:?}/stall-block"

# ---- branch name outside the safe charset is treated as unknown -------------
reset_state
git -C "$EC_PROJ" checkout -q -b 'feat+odd'
rm -f "${EC_PROJ:?}/dirty.txt"
run_stop
assert_contains "unsafe branch name falls through to enforcement on a clean tree" "$(reason)" "missing required skills"
git -C "$EC_PROJ" checkout -q feature/test

# ---- transient path patterns from config ------------------------------------
reset_state
mkdir -p "$EC_PROJ/sub"
rm -f "${EC_PROJ:?}/dirty.txt"
printf 'x' >"$EC_PROJ/sub/gen.txt"
EC_RUN_DIR="$EC_PROJ/sub"
run_stop
assert_contains "untracked file in subdir counts as dirty" "$(reason)" "missing required skills"
ec_cfg '{"sb_initiated":true,"hooks":{"stop_check":{"transient_path_ignore_patterns":["sub/gen\\.txt"]}}}'
run_stop
assert_eq "configured transient pattern lets a clean-tree session stop" "" "$TL_OUT"
ec_cfg '{"sb_initiated":true,"hooks":{"stop_check":{"transient_path_ignore_patterns":[".*"]}}}'
run_stop
assert_contains "overly broad pattern is reported" "$TL_OUT" "transient_path_ignore_patterns is too broad"
assert_contains "overly broad pattern is ignored (still dirty)" "$TL_OUT" "missing required skills"
EC_RUN_DIR="$EC_PROJ"
rm -rf "${EC_PROJ:?}/sub"

# ---- comparison anchors on a clean tree -------------------------------------
reset_state
rm -f "${EC_PROJ:?}/dirty.txt"
head_sha="$(git -C "$EC_PROJ" rev-parse HEAD)"
git -C "$EC_PROJ" update-ref refs/remotes/origin/feature/test "$head_sha"
git -C "$EC_PROJ" config remote.origin.url "$TL_TMP/no-such-remote"
git -C "$EC_PROJ" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C "$EC_PROJ" config branch.feature/test.remote origin
git -C "$EC_PROJ" config branch.feature/test.merge refs/heads/feature/test
run_stop
assert_eq "resolved upstream, nothing ahead: skip" "" "$TL_OUT"
git -C "$EC_PROJ" commit -q --allow-empty -m ahead
run_stop
assert_contains "resolved upstream, ahead: enforce" "$(reason)" "missing required skills"
git -C "$EC_PROJ" config --unset branch.feature/test.remote
git -C "$EC_PROJ" config --unset branch.feature/test.merge
git -C "$EC_PROJ" update-ref -d refs/remotes/origin/feature/test
git -C "$EC_PROJ" update-ref refs/remotes/origin/master "$(git -C "$EC_PROJ" rev-parse HEAD)"
run_stop
assert_eq "origin/master anchor, nothing ahead: skip" "" "$TL_OUT"
git -C "$EC_PROJ" commit -q --allow-empty -m ahead2
run_stop
assert_contains "origin/master anchor, ahead: enforce" "$(reason)" "missing required skills"
git -C "$EC_PROJ" update-ref -d refs/remotes/origin/master
git -C "$EC_PROJ" config branch.feature/test.remote origin
git -C "$EC_PROJ" config branch.feature/test.merge refs/heads/gone
run_stop
assert_contains "broken upstream fails closed" "$(reason)" "missing required skills"
git -C "$EC_PROJ" config --unset branch.feature/test.remote
git -C "$EC_PROJ" config --unset branch.feature/test.merge

# ---- branch / worktree scope ------------------------------------------------
reset_state
printf 'other-branch\n/elsewhere\n' >"$SD/branch"
run_stop
assert_contains "branch scope mismatch blocks" "$(reason)" "skill state is from branch 'other-branch'"
reset_state
printf 'feature/test\n%s\n' "$EC_PROJ" >"$SD/branch"
run_stop
assert_contains "matching scope proceeds to the skill check" "$(reason)" "missing required skills"
# branch file outside the state root is ignored
reset_state
mkdir -p "$TL_TMP/outside"
printf 'other-branch\n' >"$TL_TMP/outside/branch"
SILVER_BULLET_BRANCH_FILE="$TL_TMP/outside/branch" run_stop
assert_contains "out-of-scope branch file ignored" "$(reason)" "missing required skills"
assert_not_contains "out-of-scope branch file does not warn" "$(reason)" "other-branch"

# Without lib/branch-scope.sh the legacy single-line comparison applies.
STAGE="$TL_TMP/stage-nobranch"
ec_stage_hooks "$STAGE" branch-scope.sh
reset_state
printf 'other-branch\n' >"$SD/branch"
run_stop '' "$STAGE/hooks/stop-check.sh"
assert_contains "legacy branch comparison blocks" "$(reason)" "current branch is 'feature/test'"
printf 'feature/test\n' >"$SD/branch"
run_stop '' "$STAGE/hooks/stop-check.sh"
assert_contains "legacy branch comparison proceeds when equal" "$(reason)" "missing required skills"

# ---- configured planning lists ---------------------------------------------
reset_state
CUR_VER="$(jq -r .config_version "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"
ec_cfg "$(jq -cn --arg v "$CUR_VER" '{config_version:$v,sb_initiated:true,project:{active_workflow:"devops-cycle"},skills:{required_planning_devops:["silver-verify","silver-verify"]}}')"
run_stop
assert_contains "devops list from config" "$(reason)" "silver-verify"
assert_eq "duplicate required skills are listed once" "1" "$(grep -o -- '- silver-verify' <<<"$(reason)" | wc -l | tr -d ' ')"

# Without required-skills.sh the configured list is used verbatim, then defaults.
STAGE="$TL_TMP/stage-noreq"
ec_stage_hooks "$STAGE" required-skills.sh
reset_state
ec_cfg '{"sb_initiated":true,"skills":{"required_planning":["silver-verify"]}}'
run_stop '' "$STAGE/hooks/stop-check.sh"
assert_contains "no required-skills lib: configured list used" "$(reason)" "- silver-verify"
assert_not_contains "no required-skills lib: configured list replaces defaults" "$(reason)" "silver-quality-gates"
ec_cfg '{"sb_initiated":true,"skills":{}}'
run_stop '' "$STAGE/hooks/stop-check.sh"
assert_contains "no required-skills lib: built-in defaults" "$(reason)" "silver-quality-gates"
assert_contains "no required-skills lib: unrecorded default listed" "$(reason)" "silver-plan"
assert_not_contains "no required-skills lib: grep fallback sees recorded skill" "$(reason)" "- silver-context"

# Without skill-discovery.sh every skill counts as installed.
STAGE="$TL_TMP/stage-nodisc"
ec_stage_hooks "$STAGE" skill-discovery.sh
reset_state
ec_cfg '{"sb_initiated":true,"skills":{"required_planning":["no-such-skill-anywhere"]}}'
run_stop '' "$STAGE/hooks/stop-check.sh"
assert_contains "no discovery lib: unknown skill is required" "$(reason)" "- no-such-skill-anywhere"
assert_not_contains "no discovery lib: nothing reported as uninstalled" "$(reason)" "not installed anywhere"

# Uninstalled required skills are reported separately.
reset_state
ec_cfg '{"sb_initiated":true,"skills":{"required_planning":["silver-context","no-such-skill-anywhere","silver-quality-gates"]}}'
SILVER_BULLET_SKILL_ROOTS="$TL_TMP/empty-roots" run_stop
assert_contains "uninstalled+missing: lists the missing installed skill" "$(reason)" "- silver-quality-gates"
assert_contains "uninstalled+missing: reports the uninstalled one" "$(reason)" "These required skills are not installed anywhere invocable"
reset_state
ec_cfg '{"sb_initiated":true,"skills":{"required_planning":["silver-context","no-such-skill-anywhere"]}}'
printf 'silver-context\nsilver-quality-gates\nsilver-plan\n' >"$STATE"
SILVER_BULLET_SKILL_ROOTS="$TL_TMP/empty-roots" run_stop
assert_contains "only uninstalled: warns" "$TL_OUT" "not installed anywhere invocable and were ignored"
assert_contains "only uninstalled: names the skill" "$TL_OUT" "- no-such-skill-anywhere"
assert_not_contains "only uninstalled: does not block" "$TL_OUT" '"decision"'
reset_state
ec_cfg '{"sb_initiated":true,"skills":{"required_planning":["silver-context","unlisted-extra"]}}'
printf 'silver-context\nsilver-quality-gates\nsilver-plan\nunlisted-extra\n' >"$STATE"
run_stop
assert_eq "everything recorded: silent allow" "" "$TL_OUT"

# ---- jq missing in an initiated project -------------------------------------
reset_state
NOJQ="$(tl_path_without jq)"
PATH="$NOJQ" run_stop
assert_contains "jq missing: block decision" "$TL_OUT" '"decision": "block"'
assert_contains "jq missing: explains" "$TL_OUT" "jq is required"
NOJQPY="$(tl_path_without jq python3)"
PATH="$NOJQPY" run_stop
assert_eq "jq and python missing: static block" '{"decision":"block","reason":"jq required for Silver Bullet enforcement"}' "$TL_OUT"

# ---- library directory absent: fail open with the visible warning -----------
ec_stage_hooks "$TL_TMP/bare" -
reset_state
run_stop '' "$TL_TMP/bare/hooks/stop-check.sh"
assert_eq "no lib dir: exit 0" "0" "$TL_STATUS"
assert_contains "no lib dir: visible warning" "$TL_OUT" "stop-check.sh: unexpected error"

# ---- jq missing and the jq-gate library absent: built-in message ------------
ec_stage_hooks "$TL_TMP/nogate" jq-gate.sh
reset_state
PATH="$NOJQ" run_stop '' "$TL_TMP/nogate/hooks/stop-check.sh"
assert_contains "jq missing, no jq-gate lib: fallback message" "$TL_OUT" "jq required for Silver Bullet enforcement"
PATH="$NOJQPY" run_stop '' "$TL_TMP/nogate/hooks/stop-check.sh"
assert_eq "jq+python missing, no jq-gate lib: static block" '{"decision":"block","reason":"jq required for Silver Bullet enforcement"}' "$TL_OUT"

# ---- a project gate that rejects the config makes the hook inert ------------
ec_stage_hooks "$TL_TMP/rejectgate" sb-project-gate.sh
printf '%s\n' 'sb_project_is_initiated() { return 1; }' >"$TL_TMP/rejectgate/hooks/lib/sb-project-gate.sh"
reset_state
run_stop '' "$TL_TMP/rejectgate/hooks/stop-check.sh"
assert_eq "gate rejects: silent allow" "" "$TL_OUT"
assert_eq "gate rejects: exit 0" "0" "$TL_STATUS"

# ---- unreadable stall flag falls back to the default count ------------------
reset_state
printf '7' >"$SD/stall-block"
REAL_CAT="$(command -v cat)"
tl_stub cat "for a in \"\$@\"; do case \"\$a\" in *stall-block) exit 1;; esac; done; exec $REAL_CAT \"\$@\""
run_stop
rm -f "${TL_BIN:?}/cat"
assert_contains "stall count unreadable: default 100" "$(reason)" "100 tool calls without workflow progress"
tl_stub stat 'exit 1'
run_stop
rm -f "${TL_BIN:?}/stat"
assert_contains "stat failing: stall flag still honoured" "$(reason)" "Autonomous stall"
rm -f "${SD:?}/stall-block"

# ---- unreadable stdin and unreadable session-start files -------------------------
reset_state
tl_run bash -c 'cd "$1" && exec bash "$2" <"$3"' _ "$EC_PROJ" "$HOOK" "$TL_TMP"
assert_contains "unreadable stdin (a directory): still enforces" "$(reason)" "missing required skills"
printf '7' >"$SD/stall-block"
printf '1' >"$SD/session-start-time"
tl_stub cat "for a in \"\$@\"; do case \"\$a\" in *session-start-time|*ss-epoch) exit 1;; esac; done; exec $REAL_CAT \"\$@\""
run_stop
assert_contains "session-start-time unreadable: treated as unknown, blocks" "$(reason)" "Autonomous stall"
printf '1' >"$TL_TMP/ss-epoch"
SILVER_BULLET_SESSION_START_FILE="$TL_TMP/ss-epoch" run_stop
assert_contains "session start file unreadable: treated as unknown, blocks" "$(reason)" "Autonomous stall"
rm -f "${TL_BIN:?}/cat"
tl_stub uname 'echo Darwin'
tl_stub stat 'exit 1'
printf '%s' "$(( $(date +%s) + 3600 ))" >"$SD/session-start-time"
run_stop
assert_not_contains "BSD stat failing: mtime 0 is older than session start" "$(reason)" "Autonomous stall"
rm -f "${TL_BIN:?}/uname" "${TL_BIN:?}/stat" "${SD:?}/stall-block" "${SD:?}/session-start-time"

tl_results
