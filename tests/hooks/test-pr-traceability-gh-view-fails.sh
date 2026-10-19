#!/usr/bin/env bash
# hooks/pr-traceability.sh when `gh pr view` itself exits non-zero (no PR, not authenticated):
# the hook degrades to the "Could not determine PR URL" advisory, edits nothing and exits 0.
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
PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title x"}}'
tl_run_stdin "$PAYLOAD" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
assert_eq "exits 0 when gh pr view fails" 0 "$TL_STATUS"
assert_contains "advisory names the missing PR URL" "$TL_OUT" "Could not determine PR URL"
assert_contains "advisory is hook JSON" "$TL_OUT" '"hookSpecificOutput"'
assert_not_contains "no success message" "$TL_OUT" "Spec traceability added"
assert_eq "only the URL lookup ran, no edit" "pr view --json url --jq .url" "$(cat "$TL_GH_LOG")"
assert_eq "gh stderr is not leaked" "" "$TL_ERR"

tl_results
