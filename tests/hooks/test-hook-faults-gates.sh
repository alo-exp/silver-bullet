#!/usr/bin/env bash
# Fault injection for ci-status-check, roadmap-freshness, trivial-file-guard, pr-traceability,
# industry-tooling-hint, debug-dump, semantic-compress: failing helpers must degrade, not break.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset GH_STATUS_OVERRIDE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
R="$TL_REPO_ROOT/hooks"
RED='{"conclusion":"failure","status":"completed"}'

hook() { # script cwd payload [path-to-hook-copy]
  tl_run_stdin "$3" bash -c 'cd "$1" && exec bash "$2"' _ "$2" "${4:-$R/$1}"
}
pre() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
mkdir -p "$TL_TMP/plain"
ec_stage_hooks "$TL_TMP/nolib" -
ec_stage_hooks "$TL_TMP/noti" tool-input.sh

# ======== ci-status-check ======================================================
ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'ls')" "$TL_TMP/nolib/hooks/ci-status-check.sh"
assert_eq "ci: no lib dir, unrelated command: silent allow" "0:" "$TL_STATUS:$TL_OUT"

ec_fail jq '*".tool_name"*'
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')" "$TL_TMP/noti/hooks/ci-status-check.sh"
assert_contains "ci: tool name extraction failing is tolerated" "$TL_OUT" "CI FAILURE DETECTED"
ec_unfail jq
ec_fail jq '*".tool_input.command"*'
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')" "$TL_TMP/noti/hooks/ci-status-check.sh"
assert_eq "ci: command extraction failing means nothing to check" "" "$TL_OUT"
ec_unfail jq

# project cached, cwd outside any project: the hook's own walk finds nothing
sb_proj_cache() { printf '%s\n' "$EC_PROJ" >"$SD/project-root"; }
sb_proj_cache
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$TL_TMP/plain" "$(pre 'git push')"
assert_eq "ci: cached project but no config on the walk: silent" "" "$TL_OUT"
# initiated check that passes for the gate but fails for the hook
sb_project_active_or_exit() { return 0; }
export -f sb_project_active_or_exit
ec_flaky_fn sb_project_active 1
sb_proj_cache
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')"
unset -f sb_project_active sb_project_active_or_exit
assert_eq "ci: project check failing the second time: silent" "" "$TL_OUT"

ec_fail jq '*"state.trivial_file"*'
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')"
assert_contains "ci: unreadable trivial_file config falls back to the default" "$TL_OUT" "CI FAILURE DETECTED"
ec_unfail jq
ec_fail jq '*".conclusion"*'
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')"
assert_eq "ci: unreadable conclusion is not red" "" "$TL_OUT"
ec_unfail jq
ec_fail jq '*".status"*'
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')"
assert_contains "ci: unreadable status still blocks on a red conclusion" "$TL_OUT" "CI FAILURE DETECTED"
ec_unfail jq

tl_stub gh 'printf "%s\n" "$*" >>"$TL_TMP_GHLOG"; printf "[{\"conclusion\":\"failure\",\"status\":\"completed\"}]"'
export TL_TMP_GHLOG="$TL_TMP/gh.log"
: >"$TL_TMP_GHLOG"
ec_fail git '*"branch --show-current"*'
hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')"
ec_unfail git
assert_not_contains "ci: unknown branch means an unscoped lookup" "$(cat "$TL_TMP_GHLOG")" "--branch"
assert_contains "ci: still blocks on red" "$TL_OUT" "CI FAILURE DETECTED"
ec_fail jq '*".[0]"*'
hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')"
ec_unfail jq
assert_eq "ci: unparsable run list is silent" "" "$TL_OUT"
ec_unfail gh
# upstream configured but the diff cannot be computed: no bypass, so blocked
git -C "$EC_PROJ" commit -q --allow-empty -m 'plain'
git -C "$EC_PROJ" config remote.origin.url "$TL_TMP/no-remote"
git -C "$EC_PROJ" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C "$EC_PROJ" config branch.feature/test.remote origin
git -C "$EC_PROJ" config branch.feature/test.merge refs/heads/feature/test
git -C "$EC_PROJ" update-ref refs/remotes/origin/feature/test "$(git -C "$EC_PROJ" rev-parse HEAD~1)"
ec_fail git '*"diff"*'
GH_STATUS_OVERRIDE="$RED" hook ci-status-check.sh "$EC_PROJ" "$(pre 'git push')"
ec_unfail git
assert_contains "ci: failing git diff means no ci-fix bypass" "$TL_OUT" "CI FAILURE DETECTED"
git -C "$EC_PROJ" config --unset branch.feature/test.remote
git -C "$EC_PROJ" config --unset branch.feature/test.merge

# ======== roadmap-freshness ====================================================
mkdir -p "$EC_PROJ/.planning/phases/27-demo"
printf -- '- [ ] **Phase 27: Demo**\n' >"$EC_PROJ/.planning/ROADMAP.md"
printf s >"$EC_PROJ/.planning/phases/27-demo/27-01-SUMMARY.md"
git -C "$EC_PROJ" add -f .planning
commit_in='{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
hook roadmap-freshness.sh "$EC_PROJ" "$commit_in" "$TL_TMP/nolib/hooks/roadmap-freshness.sh"
assert_eq "roadmap: no lib directory: exit 0" "0" "$TL_STATUS"
assert_contains "roadmap: no lib directory: the check still runs and flags the unticked phase" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
cd() {
  case "${1:-}" in
    */lib)
      n=$(cat "$TL_TMP/cd-count" 2>/dev/null || echo 0)
      echo $((n + 1)) >"$TL_TMP/cd-count"
      if [[ "$n" -lt 1 ]]; then return 1; fi
      ;;
  esac
  builtin cd "$@"
}
export -f cd
export TL_TMP
rm -f "$TL_TMP/cd-count"
hook roadmap-freshness.sh "$EC_PROJ" "$commit_in"
unset -f cd
assert_contains "roadmap: lib dir resolved on the second try" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
ec_stage_hooks "$TL_TMP/nogate" sb-project-gate.sh project-active.sh tool-input.sh jq-gate.sh
sb_proj_cache
hook roadmap-freshness.sh "$TL_TMP/plain" "$commit_in" "$TL_TMP/nogate/hooks/roadmap-freshness.sh"
assert_eq "roadmap: no config on the walk: silent" "" "$TL_OUT"
ec_fail git '*"diff --cached"*'
hook roadmap-freshness.sh "$EC_PROJ" "$commit_in"
ec_unfail git
assert_eq "roadmap: failing git diff means nothing staged" "" "$TL_OUT"
ec_fail grep '*"-oE"*'
hook roadmap-freshness.sh "$EC_PROJ" "$commit_in"
ec_unfail grep
assert_contains "roadmap: phase number unreadable: summary skipped, nothing flagged" "$TL_OUT" "ROADMAP freshness verified"
assert_not_contains "roadmap: nothing flagged" "$TL_OUT" "UNTICKED"
ec_stage_hooks "$TL_TMP/shellonly" tool-input.sh
printf '%s\n' 'sb_tool_name() { printf "%s" "Bash"; }' 'sb_tool_is_shell_like() { return 1; }' 'sb_tool_command_string() { printf "git commit"; }' >"$TL_TMP/shellonly/hooks/lib/tool-input.sh"
hook roadmap-freshness.sh "$EC_PROJ" "$commit_in" "$TL_TMP/shellonly/hooks/roadmap-freshness.sh"
assert_eq "roadmap: non-shell tools are ignored" "" "$TL_OUT"
# the missing-jq-gate message lives in the shared gate; with jq absent the hook warns
PATH="$(tl_path_without jq)" hook roadmap-freshness.sh "$EC_PROJ" "$commit_in"
assert_contains "roadmap: jq missing warns visibly" "$TL_OUT" "ENFORCEMENT INACTIVE"

# ======== trivial-file-guard ===================================================
ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
w_in="$(jq -cn --arg p "$SD/trivial" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
hook trivial-file-guard.sh "$EC_PROJ" "$w_in" "$TL_TMP/nolib/hooks/trivial-file-guard.sh"
assert_eq "trivial: no lib directory: exit 0" "0" "$TL_STATUS"
assert_contains "trivial: no lib directory: the marker write is still blocked" "$TL_OUT" "BLOCKED"
assert_file_absent "trivial: no lib directory: no marker created" "$SD/trivial"
ec_fail jq '*"hook_event_name"*'
hook trivial-file-guard.sh "$EC_PROJ" "$w_in"
ec_unfail jq
assert_contains "trivial: unreadable event defaults to PreToolUse (still guards)" "$TL_OUT" "BLOCKED"
hook trivial-file-guard.sh "$TL_TMP/plain" '{"tool_name":"Bash","tool_input":{}}'
assert_eq "trivial: outside any project: silent allow" "0:" "$TL_STATUS:$TL_OUT"
ec_fail jq '*"tool_input.file_path"*'
hook trivial-file-guard.sh "$EC_PROJ" "$w_in" "$TL_TMP/noti/hooks/trivial-file-guard.sh"
assert_eq "trivial: unreadable file path means nothing to guard" "" "$TL_OUT"
ec_unfail jq
ec_fail jq '*"tool_input.command"*'
hook trivial-file-guard.sh "$EC_PROJ" "$(jq -cn --arg c "touch $SD/trivial" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}')" "$TL_TMP/noti/hooks/trivial-file-guard.sh"
ec_unfail jq
assert_eq "trivial: unreadable command means nothing to guard" "" "$TL_OUT"
ec_flaky_fn sb_project_active 1
sb_proj_cache
hook trivial-file-guard.sh "$EC_PROJ" "$w_in"
unset -f sb_project_active
assert_eq "trivial: failing project check: allowed" "" "$TL_OUT"

# ======== pr-traceability ======================================================
ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
printf 'spec-version=1.0\n' >"$SD/spec-session"
tl_stub gh 'case "$*" in "pr view --json url --jq .url") printf "https://x/pr/1";; esac'
mkdir -p "$EC_PROJ/.planning"
printf -- '<!-- Populated automatically -->\n' >"$EC_PROJ/.planning/SPEC.md"
pr_in='{"tool_name":"Bash","tool_input":{"command":"gh pr create"}}'
ec_fail git '*"add"*'
hook pr-traceability.sh "$EC_PROJ" "$pr_in"
ec_unfail git
assert_contains "pr: failing git add does not stop the update" "$TL_OUT" "Spec traceability added"
assert_contains "pr: SPEC.md still updated" "$(cat "$EC_PROJ/.planning/SPEC.md")" "https://x/pr/1"
rm -f "$EC_PROJ/.planning/SPEC.md"
printf 'no findings here\n' >"$EC_PROJ/.planning/VALIDATION.md"
hook pr-traceability.sh "$EC_PROJ" "$pr_in"
assert_contains "pr: VALIDATION.md without WARN findings: grep status tolerated" "$TL_OUT" "Spec traceability added"
printf 'FINDING [WARN] w\n' >"$EC_PROJ/.planning/VALIDATION.md"
ec_fail grep '*"FINDING"*'
hook pr-traceability.sh "$EC_PROJ" "$pr_in"
ec_unfail grep
assert_contains "pr: a grep that fails on VALIDATION.md is tolerated" "$TL_OUT" "Spec traceability added"
ec_unfail gh

# ======== industry-tooling-hint ================================================
ec_cfg '{"sb_initiated":true,"hooks":{"industry_tooling":{"enabled":true}}}'
printf '{}' >"$EC_PROJ/package.json"
npm_in='{"tool_name":"Bash","tool_input":{"command":"npm install"}}'
hook industry-tooling-hint.sh "$EC_PROJ" "$npm_in" "$TL_TMP/nolib/hooks/industry-tooling-hint.sh"
assert_eq "hint: no lib directory: silent" "" "$TL_OUT"
ec_fail jq '*".tool_name"*'
hook industry-tooling-hint.sh "$EC_PROJ" "$npm_in"
ec_unfail jq
assert_eq "hint: unreadable tool name: silent" "" "$TL_OUT"
ec_fail jq '*"industry_tooling.enabled"*'
hook industry-tooling-hint.sh "$EC_PROJ" "$npm_in"
ec_unfail jq
assert_eq "hint: unreadable enable flag means disabled" "" "$TL_OUT"
ec_fail jq '*".tool_input.command"*'
hook industry-tooling-hint.sh "$EC_PROJ" "$npm_in"
ec_unfail jq
assert_eq "hint: unreadable command: silent" "" "$TL_OUT"
sb_proj_cache
hook industry-tooling-hint.sh "$TL_TMP/plain" "$npm_in"
assert_eq "hint: cached project but no config on the walk: silent" "" "$TL_OUT"
PATH="$(tl_path_without jq)" hook industry-tooling-hint.sh "$EC_PROJ" "$npm_in"
assert_eq "hint: jq missing: silent" "" "$TL_OUT"
tl_run bash -c 'cd "$1" && exec bash "$2" <"$3"' _ "$EC_PROJ" "$R/industry-tooling-hint.sh" "$TL_TMP"
assert_eq "hint: unreadable stdin: silent" "" "$TL_OUT"

# ======== debug-dump ===========================================================
: >"$SD/debug-dump"
hook debug-dump.sh "$EC_PROJ" '{"d":1}' "$TL_TMP/nolib/hooks/debug-dump.sh"
assert_eq "dump: no lib directory: still dumps through the env paths" '{"d":1}' "$(tail -1 "$SD/hook-dump.jsonl" 2>/dev/null)"
rm -f "$SD/hook-dump.jsonl"
tl_run bash -c 'exec bash "$1" <"$2"' _ "$R/debug-dump.sh" "$TL_TMP"
assert_file_absent "dump: unreadable stdin dumps nothing" "$SD/hook-dump.jsonl"
rm -f "$SD/debug-dump"
tl_run bash -c 'exec bash "$1" <"$2"' _ "$R/debug-dump.sh" "$TL_TMP"
assert_eq "dump: disabled and unreadable stdin: exit 0" "0" "$TL_STATUS"
assert_file_absent "dump: disabled and unreadable stdin: nothing dumped" "$SD/hook-dump.jsonl"
: >"$SD/debug-dump"
ec_fail mkdir '*"-p"*'
hook debug-dump.sh "$EC_PROJ" '{"d":2}'
ec_unfail mkdir
assert_eq "dump: a failing mkdir does not stop the append" '{"d":2}' "$(tail -1 "$SD/hook-dump.jsonl")"
rm -f "$SD/hook-dump.jsonl"
mkdir -p "$SD/hook-dump.jsonl"
hook debug-dump.sh "$EC_PROJ" '{"d":3}'
assert_eq "dump: an unwritable sink is tolerated, silently" "0:" "$TL_STATUS:$TL_OUT"
assert_eq "dump: an unwritable sink produces no diagnostics" "" "$TL_ERR"
if [[ -d "$SD/hook-dump.jsonl" ]]; then tl_pass "dump: the unwritable sink was left alone"; else tl_fail "dump: the unwritable sink was left alone"; fi
rmdir "$SD/hook-dump.jsonl"
hook debug-dump.sh "$EC_PROJ" '{"d":4}'
assert_eq "dump: once the sink is writable again the next payload is dumped" '{"d":4}' "$(tail -1 "$SD/hook-dump.jsonl")"
rm -f "$SD/hook-dump.jsonl"
rm -f "$SD/debug-dump"

# ======== semantic-compress ====================================================
sc_in='{"tool_input":{"skill":"x"}}'
PATH="$(tl_path_without jq)" hook semantic-compress.sh "$EC_PROJ" "$sc_in"
assert_eq "compress: jq missing: silent" "" "$TL_OUT"
tl_run bash -c 'cd "$1" && exec bash "$2" <"$3"' _ "$EC_PROJ" "$R/semantic-compress.sh" "$TL_TMP"
assert_eq "compress: unreadable stdin: silent exit 0" "0:" "$TL_STATUS:$TL_OUT"
ec_fail jq '*"tool_input.skill"*'
hook semantic-compress.sh "$EC_PROJ" "$sc_in"
ec_unfail jq
assert_eq "compress: unreadable skill: silent" "" "$TL_OUT"
hook semantic-compress.sh "$EC_PROJ" "$sc_in" "$TL_TMP/nolib/hooks/semantic-compress.sh"
assert_eq "compress: no lib directory: silent exit 0" "0:" "$TL_STATUS:$TL_OUT"
mkdir -p "$TL_TMP/nolib/scripts"
printf '#!/usr/bin/env bash\necho SC-RAN\n' >"$TL_TMP/nolib/scripts/semantic-compress.sh"
chmod +x "$TL_TMP/nolib/scripts/semantic-compress.sh"
hook semantic-compress.sh "$EC_PROJ" '{"tool_input":{"skill":"sb:plan"}}' "$TL_TMP/nolib/hooks/semantic-compress.sh"
assert_eq "compress: no lib directory: the compressor still runs" "SC-RAN" "$TL_OUT"

tl_results
