#!/usr/bin/env bash
# hooks/session-start: payload source, prompt replay, branch scope, workflow archive,
# trivial cleanup and library fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/session-start"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SILVER_BULLET_UPDATE_CHECK_DISABLED=1
unset SILVER_BULLET_SESSION_SOURCE SILVER_BULLET_PROMPT_FILE SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT

SD="${SB_RUNTIME_STATE_DIR:?}"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test"
ec_project
STATE="$SD/state"
BRANCH="$SD/branch"

# run_ss [payload] [hook]: cwd = $EC_RUN_DIR
run_ss() {
  local payload="${1-'{}'}" hook="${2:-$HOOK}"
  tl_run_stdin "$payload" bash -c 'cd "$1" && exec bash "$2"' _ "${EC_RUN_DIR:-$EC_PROJ}" "$hook"
}
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }
fresh() {
  local f
  for f in state branch trivial session-start-time stall-block orchestrator.json orchestrator-directive.json \
    orchestrator-worker-active.json project-root session-rules-injected graphify-query agentmemory-usage quality-gate-state; do
    rm -f "${SD:?}/${f:?}"
  done
  rm -rf "${SD:?}/branchdir" "${EC_PROJ:?}/.planning"
  EC_RUN_DIR="$EC_PROJ"
}

# ---- payload source ---------------------------------------------------------
fresh
printf 'old-branch\n/elsewhere\n' >"$BRANCH"
printf 'silver-plan\n' >"$STATE"
run_ss '{"source":"resume"}'
assert_file_exists "resume does not reset state" "$STATE"
run_ss '{"source":"compact"}'
assert_file_exists "compact does not reset state" "$STATE"
run_ss '{"source":"bogus"}'
assert_file_absent "unknown source behaves as startup (reset)" "$STATE"
assert_contains "reset banner shown" "$(ctx)" "git scope changed (old-branch@/elsewhere"
fresh
printf 'old-branch\n' >"$BRANCH"
printf 'silver-plan\n' >"$STATE"
SILVER_BULLET_SESSION_SOURCE=resume run_ss '{"source":"startup"}'
assert_file_exists "env source override wins over payload" "$STATE"

# ---- reset side effects -----------------------------------------------------
fresh
printf 'old-branch\n' >"$BRANCH"
printf 'x' >"$STATE"
for f in orchestrator.json orchestrator-directive.json stall-block graphify-query agentmemory-usage; do printf 'x' >"$SD/$f"; done
run_ss
for f in orchestrator.json orchestrator-directive.json stall-block graphify-query; do
  assert_file_absent "reset clears $f" "$SD/$f"
done
assert_eq "branch file rewritten" "feature/test" "$(sed -n 1p "$BRANCH")"

# gate libraries absent: plain file removal instead
ec_stage_hooks "$TL_TMP/nogates" graphify-gate.sh agentmemory-gate.sh branch-scope.sh
fresh
printf 'old-branch\n' >"$BRANCH"
printf 'x' >"$STATE"
printf 'q' >"$SD/graphify-query"
printf 'u' >"$SD/agentmemory-usage"
run_ss '' "$TL_TMP/nogates/hooks/session-start"
assert_file_absent "no graphify lib: query state removed" "$SD/graphify-query"
assert_file_absent "no agentmemory lib: usage state removed" "$SD/agentmemory-usage"
assert_eq "no branch-scope lib: branch written plainly" "feature/test" "$(sed -n 1p "$BRANCH")"
printf 'feature/test\n' >"$BRANCH"
printf 'keep' >"$STATE"
run_ss '' "$TL_TMP/nogates/hooks/session-start"
assert_file_exists "no branch-scope lib: same branch keeps state" "$STATE"
printf 'other\n' >"$BRANCH"
run_ss '' "$TL_TMP/nogates/hooks/session-start"
assert_file_absent "no branch-scope lib: different branch resets state" "$STATE"

# project config absent from the walk: graphify/agentmemory state removed directly
fresh
printf 'old-branch\n' >"$BRANCH"
printf 'q' >"$SD/graphify-query"
printf 'u' >"$SD/agentmemory-usage"
printf 'x' >"$STATE"
run_ss
assert_file_absent "reset removes graphify query state" "$SD/graphify-query"
assert_file_absent "reset removes agentmemory usage state" "$SD/agentmemory-usage"

# branch file that cannot be created: warns
fresh
SILVER_BULLET_BRANCH_FILE="$SD/no-such-dir/branch" run_ss
assert_contains "branch write failure is reported" "$TL_ERR" "branch file write failed"
printf 'old-branch\n' >"$BRANCH"
SILVER_BULLET_BRANCH_FILE="$SD/no-such-dir/branch" run_ss
assert_contains "branch write failure is reported (initialisation, no stored branch)" "$TL_ERR" "branch file write failed"
# unsafe branch name: no mutation
fresh
git -C "$EC_PROJ" checkout -q -b 'odd+branch'
printf 'old-branch\n' >"$BRANCH"
printf 'keep' >"$STATE"
run_ss
assert_file_exists "unsafe branch name leaves state alone" "$STATE"
git -C "$EC_PROJ" checkout -q feature/test

# ---- non-SB workspace -------------------------------------------------------
fresh
printf 'x' >"$SD/orchestrator-directive.json"
printf 'x' >"$SD/project-root"
mkdir -p "$TL_TMP/plain"
EC_RUN_DIR="$TL_TMP/plain"
run_ss
assert_eq "non-SB workspace: silent" "" "$TL_OUT"
assert_file_absent "non-SB workspace: stale directive cleared" "$SD/orchestrator-directive.json"
assert_file_absent "non-SB workspace: stale project-root cleared" "$SD/project-root"
EC_RUN_DIR="$EC_PROJ"

# ---- prompt seed replay -----------------------------------------------------
ec_stage_hooks "$TL_TMP/recfarm"
rm -f "$TL_TMP/recfarm/hooks/record-requested-skill.sh"
printf '#!/usr/bin/env bash\ncat >"$RECORDED_TO"\n' >"$TL_TMP/recfarm/hooks/record-requested-skill.sh"
chmod +x "$TL_TMP/recfarm/hooks/record-requested-skill.sh"
export RECORDED_TO="$TL_TMP/recorded.json"
fresh
printf 'run /sb:init please\n' >"$EC_PROJ/.silver-bullet.prompt.json"
run_ss '' "$TL_TMP/recfarm/hooks/session-start"
assert_eq "prompt file in project replayed as UserPromptSubmit" "UserPromptSubmit" "$(jq -r .hook_event_name "$RECORDED_TO")"
assert_contains "prompt text forwarded" "$(jq -r .prompt "$RECORDED_TO")" "run /sb:init please"
rm -f "$RECORDED_TO" "$EC_PROJ/.silver-bullet.prompt.json"
printf 'from env\n' >"$TL_TMP/seed.txt"
SILVER_BULLET_PROMPT_FILE="$TL_TMP/seed.txt" run_ss '' "$TL_TMP/recfarm/hooks/session-start"
assert_contains "SILVER_BULLET_PROMPT_FILE replayed" "$(jq -r .prompt "$RECORDED_TO")" "from env"
rm -f "$RECORDED_TO"
SILVER_BULLET_SESSION_SOURCE=resume SILVER_BULLET_PROMPT_FILE="$TL_TMP/seed.txt" run_ss '' "$TL_TMP/recfarm/hooks/session-start"
assert_file_absent "resume does not replay the prompt" "$RECORDED_TO"
# seed present but no recorder: nothing happens
SILVER_BULLET_PROMPT_FILE="$TL_TMP/seed.txt" run_ss '' "$TL_TMP/nogates/hooks/session-start"
assert_file_absent "recorder missing from farm is tolerated" "$RECORDED_TO"
unset RECORDED_TO

# ---- stale workflow archive -------------------------------------------------
fresh
mkdir -p "$EC_PROJ/.planning/workflows"
printf 'old' >"$EC_PROJ/.planning/workflows/old.md"
printf 'new' >"$EC_PROJ/.planning/workflows/new.md"
touch -d '10 days ago' "$EC_PROJ/.planning/workflows/old.md"
ln -s "$EC_PROJ/.planning/workflows/new.md" "$EC_PROJ/.planning/workflows/link.md"
run_ss
assert_file_exists "stale workflow archived" "$EC_PROJ/.planning/workflows/.archive/old.md"
assert_file_absent "stale workflow moved" "$EC_PROJ/.planning/workflows/old.md"
assert_file_exists "fresh workflow kept" "$EC_PROJ/.planning/workflows/new.md"
assert_file_exists "symlinked workflow left alone" "$EC_PROJ/.planning/workflows/link.md"

# ---- trivial cleanup --------------------------------------------------------
fresh
printf 'x' >"$SD/trivial"
run_ss
assert_file_absent "default trivial file removed" "$SD/trivial"
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"state":{"trivial_file":"'"$SD"'/custom-trivial"}}'
printf 'x' >"$SD/custom-trivial"
mkdir -p "$EC_PROJ/sub/dir"
EC_RUN_DIR="$EC_PROJ/sub/dir"
run_ss
assert_file_absent "configured trivial file removed (config found by walking up)" "$SD/custom-trivial"
EC_RUN_DIR="$EC_PROJ"
ec_cfg '{"config_version":"0.40.0","sb_initiated":true,"state":{"trivial_file":"'"$SD"'/linked-trivial"}}'
printf 'precious' >"$TL_TMP/target"
ln -s "$TL_TMP/target" "$SD/linked-trivial"
printf 'x' >"$SD/trivial"
run_ss
assert_file_exists "symlink target untouched" "$TL_TMP/target"
assert_file_absent "symlinked trivial falls back to default trivial file" "$SD/trivial"
rm -f "${SD:?}/linked-trivial"

# ---- jq missing -------------------------------------------------------------
fresh
ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
PATH="$(tl_path_without jq)" run_ss
assert_contains "no jq: prerequisite message" "$TL_OUT" "prerequisites missing"
ec_stage_hooks "$TL_TMP/noprobe" prerequisite-probe.sh
PATH="$(tl_path_without jq)" run_ss '' "$TL_TMP/noprobe/hooks/session-start"
assert_contains "no jq, no probe: DISABLED notice" "$TL_OUT" "Silver Bullet DISABLED"

# ---- core rules integrity ---------------------------------------------------
ec_stage_hooks "$TL_TMP/nopin"
rm -f "$TL_TMP/nopin/hooks/core-rules.sha256"
cp "$TL_REPO_ROOT/hooks/core-rules.md" "$TL_TMP/nopin/hooks/core-rules.md.tmp"
rm -f "$TL_TMP/nopin/hooks/core-rules.md"
mv "$TL_TMP/nopin/hooks/core-rules.md.tmp" "$TL_TMP/nopin/hooks/core-rules.md"
fresh
run_ss '' "$TL_TMP/nopin/hooks/session-start"
assert_contains "unverifiable core rules: integrity warning, rules not injected" "$(ctx)" "core-rules.md"
assert_not_contains "unverifiable core rules: no rules digest" "$(ctx)" "Non-Negotiable Rules"
ec_stage_hooks "$TL_TMP/nointegrity" core-rules-integrity.sh
fresh
run_ss '' "$TL_TMP/nointegrity/hooks/session-start"
assert_contains "no integrity lib: unavailable notice" "$(ctx)" "integrity check unavailable"
ec_stage_hooks "$TL_TMP/nocore" core-rules.md
fresh
run_ss '' "$TL_TMP/nocore/hooks/session-start"
assert_not_contains "no core-rules.md: nothing injected for rules" "$(ctx)" "integrity"

# ---- bare tree: nothing to inject -------------------------------------------
ec_stage_hooks "$TL_TMP/bare" -
rm -f "$TL_TMP/bare/hooks/core-rules.md"
fresh
run_ss '' "$TL_TMP/bare/hooks/session-start"
assert_eq "no libs and no rules: silent" "" "$TL_OUT"
assert_eq "no libs and no rules: exit 0" "0" "$TL_STATUS"
assert_file_exists "session-rules-injected still stamped" "$SD/session-rules-injected"

# ---- fallback symlink guard -------------------------------------------------
ec_stage_hooks "$TL_TMP/noguard" nofollow-guard.sh
fresh
run_ss '' "$TL_TMP/noguard/hooks/session-start"
assert_contains "fallback guard: hook still injects rules" "$(ctx)" "Silver Bullet"
fresh
ln -s "$TL_TMP/target" "$SD/session-rules-injected"
run_ss '' "$TL_TMP/noguard/hooks/session-start"
assert_eq "fallback guard refuses a symlinked marker (exit 1)" "1" "$TL_STATUS"
rm -f "${SD:?}/session-rules-injected"
assert_eq "symlink target untouched by fallback guard" "precious" "$(cat "$TL_TMP/target")"

# ---- project-local recommended-tools scripts (no paths.sh) -------------------
fresh
RT="$EC_PROJ/scripts/lib/recommended-tools"
mkdir -p "$RT"
printf '%s\n' 'rt_heartbeat_write() { printf "%s %s\n" "$1" "$2" >"$SB_RUNTIME_STATE_DIR/hb-written"; }' >"$RT/heartbeat.sh"
printf '%s\n' 'rt_session_verify_block() { printf "VERIFY-BLOCK for %s" "$2"; }' >"$RT/session-verify.sh"
ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
run_ss
assert_file_exists "heartbeat written from project-local script" "$SD/hb-written"
assert_contains "heartbeat gets project root" "$(cat "$SD/hb-written")" "$EC_PROJ"
assert_contains "verify block injected" "$(ctx)" "VERIFY-BLOCK for"
rm -f "${SD:?}/hb-written"
ec_cfg '{"config_version":"0.40.0","sb_initiated":false}'
run_ss
assert_file_absent "uninitiated project: no heartbeat" "$SD/hb-written"

# ---- cursor host below tier 2 gets the hooks-manifest note ----------------------
fresh
mkdir -p "$HOME/.cursor/plugins/cache/alo-labs/silver-bullet/test"
env -u SILVER_BULLET_TEST_HOOK_ENFORCED SILVER_BULLET_RUNTIME=cursor bash -c 'cd "$1" && exec bash "$2" <<<"{}"' _ "$EC_PROJ" "$HOOK" >"$TL_TMP/cursor.out" 2>/dev/null || true
assert_contains "cursor below tier 2: merge-hooks note" "$(jq -r '.hookSpecificOutput.additionalContext // ""' "$TL_TMP/cursor.out")" "Task host: merge host hooks manifest"

tl_results
