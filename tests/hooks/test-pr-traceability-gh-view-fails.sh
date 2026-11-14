#!/usr/bin/env bash
# hooks/pr-traceability.sh when `gh` itself exits non-zero (not authenticated, offline): the hook tolerates it,
# exits 0, and never calls gh at all when the create command printed no PR URL (it failed).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/pr-traceability.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
export TL_GH_LOG="$TL_TMP/gh.log"
: >"$TL_GH_LOG"

tl_stub gh '
printf "%s\n" "$*" >>"$TL_GH_LOG"
echo "gh: no pull requests found" >&2
exit 1'

printf 'spec-version=1.0\njira-id=PROJ-1\n' >"$SD/spec-session"
PR_URL="https://example.test/o/r/pull/9"
FAILED='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title x"},"tool_response":{"stdout":"","stderr":"error"}}'
tl_run_stdin "$FAILED" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
assert_eq "failed create: exits 0" 0 "$TL_STATUS"
assert_eq "failed create: silent" "" "$TL_OUT"
assert_eq "failed create: gh never called" "" "$(cat "$TL_GH_LOG")"

PAYLOAD="$(jq -cn --arg o "$PR_URL" '{tool_name:"Bash",tool_input:{command:"gh pr create --title x"},tool_response:{stdout:$o}}')"
tl_run_stdin "$PAYLOAD" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
assert_eq "exits 0 when gh pr view fails" 0 "$TL_STATUS"
assert_contains "gh failures are tolerated" "$TL_OUT" "Spec traceability added"
assert_contains "the body lookup targets the created PR" "$(cat "$TL_GH_LOG")" "pr view $PR_URL --json body --jq .body"
assert_eq "gh stderr is not leaked" "" "$TL_ERR"

tl_results
