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

# no jq-gate / tool-input / project-gate libraries: raw jq extraction and a self-located lib dir
ec_stage_hooks "$TL_TMP/minimal" tool-input.sh jq-gate.sh sb-project-gate.sh project-active.sh
run_rf "$EC_PROJ" "$TL_TMP/minimal/hooks/roadmap-freshness.sh"
assert_contains "no helper libs: still blocks" "$TL_OUT" "ROADMAP FRESHNESS VIOLATION"
run_rf "$EC_PROJ" "$TL_TMP/minimal/hooks/roadmap-freshness.sh" '{"tool_name":"Bash","tool_input":{"command":""}}'
assert_eq "no helper libs: empty command ignored" "" "$TL_OUT"
run_rf "$EC_PROJ" "$TL_TMP/minimal/hooks/roadmap-freshness.sh" '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
assert_eq "no helper libs: non-commit ignored" "" "$TL_OUT"

ec_stage_hooks "$TL_TMP/nolib" -
run_rf "$EC_PROJ" "$TL_TMP/nolib/hooks/roadmap-freshness.sh"
assert_eq "lib directory missing: fails open" "0" "$TL_STATUS"

tl_results
