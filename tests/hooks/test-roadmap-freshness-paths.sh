#!/usr/bin/env bash
# hooks/roadmap-freshness.sh: discovery from subdirectories and library fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
HOOK="$TL_REPO_ROOT/hooks/roadmap-freshness.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
ec_project
mkdir -p "$EC_PROJ/.planning/phases/27-demo" "$EC_PROJ/sub/dir"
printf -- '- [ ] **Phase 27: Demo phase**\n' >"$EC_PROJ/.planning/ROADMAP.md"
printf 's' >"$EC_PROJ/.planning/phases/27-demo/27-01-SUMMARY.md"
git -C "$EC_PROJ" add -f .planning
PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
run_rf() { # cwd [hook] [payload]
  tl_run_stdin "${3:-$PAYLOAD}" bash -c 'cd "$1" && exec bash "$2"' _ "$1" "${2:-$HOOK}"
}

run_rf "$EC_PROJ/sub/dir"
assert_contains "violation found from a subdirectory" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
assert_contains "block is a PreToolUse deny" "$TL_OUT" '"permissionDecision":"deny"'
assert_contains "block names the unticked phase" "$TL_OUT" "Phase 27: Demo phase"

# the gate's cached project root keeps the hook active outside the project, but the hook itself finds no config
mkdir -p "$TL_TMP/elsewhere"
run_rf "$EC_PROJ"
run_rf "$TL_TMP/elsewhere"
assert_eq "cached project root but cwd outside: silent" "" "$TL_OUT"

# --- the usual commit shapes (R2-20) ---------------------------------------------
git -C "$EC_PROJ" reset -q
git -C "$EC_PROJ" rm -q --cached -r -f .planning >/dev/null 2>&1 || true
cmd() { jq -cn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
S27=".planning/phases/27-demo/27-01-SUMMARY.md"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -m x")"
assert_eq "nothing staged and nothing named: silent" "" "$TL_OUT"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git add -f $S27 && git commit -m 'phase 27 done'")"
assert_contains "git add <summary> && git commit is checked" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
assert_eq "the deny is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git add -f .planning && git -c user.name=x commit -m y")"
assert_contains "git add <dir> && git -c k=v commit is checked" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git -C . commit -m x $S27")"
assert_contains "git -C . commit <pathspec> is checked" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -m x -- $S27")"
assert_contains "commit -- <pathspec> is checked" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git add -A && git commit -m x")"
assert_contains "git add -A && git commit is checked" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git add . && git commit -m x")"
assert_contains "git add . && git commit is checked" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git add -f .planning; git commit -m x")"
assert_contains "a sequenced add and commit is checked" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git add README.md && git commit -m x")"
assert_eq "an unrelated add and commit is allowed" "" "$TL_OUT"
git -C "$EC_PROJ" add -f .planning
git -C "$EC_PROJ" commit -q -m seed
printf 'changed' >"$EC_PROJ/$S27"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -a -m x")"
assert_contains "commit -a picks up a modified tracked summary" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -am x")"
assert_contains "commit -am picks up a modified tracked summary" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git log --oneline && git status")"
assert_eq "commands that do not commit are ignored" "" "$TL_OUT"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "echo git commit is how you save")"
assert_eq "prose that mentions git commit is ignored" "" "$TL_OUT"
git -C "$EC_PROJ" checkout -q -- "$S27"

# zero-padded phase directories against "Phase 7:" roadmap entries, and decimal phases
mkdir -p "$EC_PROJ/.planning/phases/07-pad" "$EC_PROJ/.planning/phases/7.1-dec"
printf -- '- [ ] **Phase 7: Padded**\n- [ ] **Phase 7.1: Decimal**\n- [x] **Phase 27: Demo phase**\n' >"$EC_PROJ/.planning/ROADMAP.md"
printf s >"$EC_PROJ/.planning/phases/07-pad/07-02-SUMMARY.md"
printf s >"$EC_PROJ/.planning/phases/7.1-dec/7.1-01-SUMMARY.md"
git -C "$EC_PROJ" add -f .planning
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -m x")"
assert_contains "zero-padded 07-x dir against '**Phase 7:' is checked" "$TL_OUT" "Phase 7: Padded"
assert_contains "decimal phase 7.1 is checked" "$TL_OUT" "Phase 7.1: Decimal"
assert_not_contains "a ticked phase is not flagged" "$TL_OUT" "Phase 27"
assert_contains "the remedy points at the owning skill, not a direct edit" "$TL_OUT" "/sb:phase"
printf -- '- [x] **Phase 7: Padded**\n- [x] **Phase 7.1: Decimal**\n' >"$EC_PROJ/.planning/ROADMAP.md"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -m x")"
assert_contains "all ticked: verified notice" "$TL_OUT" "ROADMAP freshness verified"
assert_eq "the notice is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
printf 's' >"$EC_PROJ/.planning/phases/07-pad/07-02-03-SUMMARY.md"
git -C "$EC_PROJ" add -f .planning
rm -f "$EC_PROJ/.planning/ROADMAP.md"
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -m x")"
assert_eq "no ROADMAP.md: nothing to check" "" "$TL_OUT"

# a repository without any commit: `commit -a` has no HEAD to diff against
EMPTY="$TL_TMP/emptyrepo"; mkdir -p "$EMPTY"; git -C "$EMPTY" init -q -b main
printf '{"sb_initiated":true}\n' >"$EMPTY/.silver-bullet.json"; printf '# SB\n' >"$EMPTY/silver-bullet.md"
mkdir -p "$EMPTY/.planning"; printf -- '- [ ] **Phase 1: A**\n' >"$EMPTY/.planning/ROADMAP.md"
run_rf "$EMPTY" "$HOOK" "$(cmd "git commit -a -m x")"
assert_eq "commit -a in a repository without commits: nothing to diff, nothing flagged" "" "$TL_OUT"

# python3 missing / unparsable command: completion-audit's commit gate owns those
run_rf "$EC_PROJ" "$HOOK" "$(cmd "git commit -m 'unterminated")"
assert_eq "an unparsable command is left to the commit gate" "" "$TL_OUT"

tl_results
