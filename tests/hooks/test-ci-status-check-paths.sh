#!/usr/bin/env bash
# hooks/ci-status-check.sh: gh run lookup, CI-fix bypasses, value validation and fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/ci-status-check.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset GH_STATUS_OVERRIDE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"

pre() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
post() { jq -cn --arg c "$1" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
run_ci() { # payload [hook]  (cwd EC_RUN_DIR)
  tl_run_stdin "$1" bash -c 'cd "$1" && exec bash "$2"' _ "${EC_RUN_DIR:-$EC_PROJ}" "${2:-$HOOK}"
}
reset() {
  rm -f "${SD:?}/ci-red-override" "${SD:?}/trivial" "${SD:?}/project-root"
  ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
  EC_RUN_DIR="$EC_PROJ"
  unset GH_STATUS_OVERRIDE
}
RED='{"conclusion":"failure","status":"completed"}'

# ---- gating -----------------------------------------------------------------
reset
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push origin x')"
assert_contains "red CI blocks a push (PreToolUse deny)" "$TL_OUT" '"permissionDecision":"deny"'
GH_STATUS_OVERRIDE="$RED" run_ci "$(post 'git push origin x')"
assert_contains "red CI blocks a push (PostToolUse block)" "$TL_OUT" '"decision":"block"'
GH_STATUS_OVERRIDE='{"conclusion":"cancelled","status":"completed"}' run_ci "$(pre 'gh pr create')"
assert_contains "cancelled CI blocks too" "$TL_OUT" "conclusion=cancelled"
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git commit -m x')"
assert_eq "PreToolUse ignores git commit" "" "$TL_OUT"
GH_STATUS_OVERRIDE="$RED" run_ci "$(post 'git commit -m x')"
assert_contains "PostToolUse commit warns" "$TL_OUT" "CI FAILURE DETECTED"
assert_not_contains "PostToolUse commit does not block" "$TL_OUT" '"decision"'
GH_STATUS_OVERRIDE="$RED" run_ci "$(post 'git commit -m x && git push')"
assert_contains "commit+push is still blocked" "$TL_OUT" '"decision":"block"'
GH_STATUS_OVERRIDE="$RED" run_ci '{"tool_name":"Read","tool_input":{"file_path":"x"}}'
assert_eq "non-shell tool ignored" "" "$TL_OUT"
GH_STATUS_OVERRIDE="$RED" run_ci '{"tool_name":"Bash","tool_input":{"command":""}}'
assert_eq "empty command ignored" "" "$TL_OUT"
GH_STATUS_OVERRIDE="$RED" PATH="$(tl_path_without jq)" run_ci "$(pre 'git push')"
assert_eq "no jq: silent allow" "" "$TL_OUT"
mkdir -p "$TL_TMP/plain"
rm -f "${SD:?}/project-root"
EC_RUN_DIR="$TL_TMP/plain"
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_eq "outside an SB project: silent" "" "$TL_OUT"
EC_RUN_DIR="$EC_PROJ"
mkdir -p "$EC_PROJ/a/b"
EC_RUN_DIR="$EC_PROJ/a/b"
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_contains "config found by walking up" "$TL_OUT" "CI FAILURE DETECTED"
EC_RUN_DIR="$EC_PROJ"

# ---- overrides --------------------------------------------------------------
reset
: >"$SD/ci-red-override"
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_eq "ci-red-override allows" "" "$TL_OUT"
rm -f "$SD/ci-red-override"
: >"$SD/trivial"
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_contains "legacy trivial file used as override is announced" "$TL_OUT" "[deprecation]"
rm -f "$SD/trivial"
ec_cfg "$(jq -cn --arg t "$SD/custom-trivial" '{sb_initiated:true,state:{trivial_file:$t}}')"
: >"$SD/custom-trivial"
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_eq "configured trivial file bypasses" "" "$TL_OUT"
rm -f "$SD/custom-trivial"

# ---- value validation -------------------------------------------------------
reset
GH_STATUS_OVERRIDE='{"conclusion":"weird","status":"completed"}' run_ci "$(pre 'git push')"
assert_eq "unknown conclusion is treated as not red" "" "$TL_OUT"
GH_STATUS_OVERRIDE='{"conclusion":"","status":"weird"}' run_ci "$(pre 'git push')"
assert_eq "unknown status is silent" "" "$TL_OUT"
GH_STATUS_OVERRIDE='{"conclusion":"success","status":"completed"}' run_ci "$(pre 'git push')"
assert_eq "green CI is silent" "" "$TL_OUT"
GH_STATUS_OVERRIDE='{"conclusion":"","status":"in_progress"}' run_ci "$(pre 'git push')"
assert_contains "in-progress CI informs" "$TL_OUT" "CI in progress"

# ---- ci-fix bypasses (git push) ---------------------------------------------
reset
git -C "$EC_PROJ" commit -q --allow-empty -m 'fix(ci): repair pipeline'
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_contains "commit convention allows the push" "$TL_OUT" "matches ci-fix convention"
git -C "$EC_PROJ" commit -q --allow-empty -m 'work [CI-FIX] now'
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_contains "[ci-fix] marker allows the push" "$TL_OUT" "matches ci-fix convention"
git -C "$EC_PROJ" commit -q --allow-empty -m 'unrelated change'
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_contains "no upstream and no convention: blocked" "$TL_OUT" "CI FAILURE DETECTED"
# upstream configured: diff-based bypass
head_sha="$(git -C "$EC_PROJ" rev-parse HEAD)"
git -C "$EC_PROJ" config remote.origin.url "$TL_TMP/no-such-remote"
git -C "$EC_PROJ" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C "$EC_PROJ" config branch.feature/test.remote origin
git -C "$EC_PROJ" config branch.feature/test.merge refs/heads/feature/test
git -C "$EC_PROJ" update-ref refs/remotes/origin/feature/test "$head_sha"
mkdir -p "$EC_PROJ/tests"
printf 'x' >"$EC_PROJ/tests/t.sh"
git -C "$EC_PROJ" add tests/t.sh
git -C "$EC_PROJ" commit -q -m 'add a test'
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_contains "diff touching tests/ allows the push" "$TL_OUT" "suspected CI fix"
printf 'y' >"$EC_PROJ/other.txt"
git -C "$EC_PROJ" add other.txt
git -C "$EC_PROJ" commit -q -m 'something else'
git -C "$EC_PROJ" update-ref refs/remotes/origin/feature/test "$(git -C "$EC_PROJ" rev-parse HEAD)"
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')"
assert_contains "upstream with an empty diff: blocked" "$TL_OUT" "CI FAILURE DETECTED"
git -C "$EC_PROJ" config --unset branch.feature/test.remote
git -C "$EC_PROJ" config --unset branch.feature/test.merge

# ---- real gh lookups --------------------------------------------------------
tl_stub gh 'printf "%s\n" "$*" >>"$TL_TMP_GHLOG"; printf "%s" "$TL_TMP_GHOUT"'
export TL_TMP_GHLOG="$TL_TMP/gh.log"
reset
export TL_TMP_GHOUT='[{"conclusion":"failure","status":"completed","name":"ci","headBranch":"feature/test"}]'
: >"$TL_TMP_GHLOG"
run_ci "$(pre 'git push')"
assert_contains "gh run list result used" "$TL_OUT" "CI FAILURE DETECTED"
assert_contains "lookup scoped to the current branch" "$(cat "$TL_TMP_GHLOG")" "--branch feature/test"
export TL_TMP_GHOUT='[]'
run_ci "$(pre 'git push')"
assert_eq "no runs: silent" "" "$TL_OUT"
export TL_TMP_GHOUT=''
run_ci "$(pre 'git push')"
assert_eq "empty gh output: silent" "" "$TL_OUT"
git -C "$EC_PROJ" checkout -q --detach
export TL_TMP_GHOUT='[{"conclusion":"failure","status":"completed"}]'
: >"$TL_TMP_GHLOG"
run_ci "$(pre 'git push')"
assert_not_contains "detached HEAD: lookup is not branch-scoped" "$(cat "$TL_TMP_GHLOG")" "--branch"
assert_contains "detached HEAD: still blocks on red" "$TL_OUT" "CI FAILURE DETECTED"
git -C "$EC_PROJ" checkout -q feature/test
rm -f "${TL_BIN:?}/gh"
PATH="$(tl_path_without gh)" run_ci "$(pre 'git push')"
assert_eq "gh missing: silent allow" "" "$TL_OUT"

# ---- library fallbacks ------------------------------------------------------
ec_stage_hooks "$TL_TMP/nolibs" tool-input.sh sb-project-gate.sh project-active.sh
reset
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')" "$TL_TMP/nolibs/hooks/ci-status-check.sh"
assert_contains "no tool-input/project libs: jq extraction still blocks" "$TL_OUT" "CI FAILURE DETECTED"
GH_STATUS_OVERRIDE="$RED" run_ci '{"tool_name":"Bash","tool_input":{"command":"ls"}}' "$TL_TMP/nolibs/hooks/ci-status-check.sh"
assert_eq "no libs: unrelated command ignored" "" "$TL_OUT"
# An initiated-check function inherited from the environment (no project libs) is honoured.
sb_project_is_initiated() { return 1; }
export -f sb_project_is_initiated
GH_STATUS_OVERRIDE="$RED" run_ci "$(pre 'git push')" "$TL_TMP/nolibs/hooks/ci-status-check.sh"
assert_eq "inherited initiated check rejecting: silent" "" "$TL_OUT"
unset -f sb_project_is_initiated

tl_results
