#!/usr/bin/env bash
# The shell analysis is bounded in cost, not only in steps (review F2 round 2, issue 2): a command built
# to make the analyzer expensive (a value that doubles, a run of "[", a quarter megabyte of ";") is judged as
# unseen code well inside the hosts' 15 s hook timeout, so completion-audit and dev-cycle-check still
# deny it instead of being killed and waved through.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-dc.sh"

CA_HOOK="$TL_REPO_ROOT/hooks/completion-audit.sh"
export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
export SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1
mkproj budgets
git -C "$PROJ" add -A >/dev/null 2>&1 && git -C "$PROJ" commit -qm init >/dev/null 2>&1 || true
GH_RUN_LIST_OVERRIDE="$(jq -cn --arg sha "$(git -C "$PROJ" rev-parse HEAD)" \
  '[{workflowName:"CI",status:"completed",conclusion:"success",headSha:$sha,createdAt:"2026-05-07T00:00:01Z"}]')"
export GH_RUN_LIST_OVERRIDE

# timed <hook> <command>: run the hook on a Bash command under the host's 15 s limit.
timed() {
  local hook="$1" cmd="$2" json
  json="$(printf '%s' "$cmd" | jq -Rsc '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:.}}')"
  SECONDS=0
  tl_run_stdin "$json" bash -c 'cd "$1" && exec timeout 15 bash "$2"' _ "$PROJ" "$hook"
  ELAPSED="$SECONDS"
}
repeat() { local out="" i; for ((i = 0; i < $2; i++)); do out+="$1"; done; printf '%s' "$out"; }

state
doubling="x=abcd; $(repeat 'x=$x$x; ' 25)gh pr create --fill"
timed "$CA_HOOK" "$doubling"
assert_eq "completion-audit: a doubling value is not a timeout" "deny" "$(decision)"
[[ "$TL_STATUS" -ne 124 && "$ELAPSED" -lt 14 ]] && tl_pass "completion-audit: doubling finished in ${ELAPSED}s" || tl_fail "completion-audit: doubling took ${ELAPSED}s (status $TL_STATUS)"

brackets="export '$(repeat '[' 40000)'; gh pr create --fill"
timed "$CA_HOOK" "$brackets"
assert_eq "completion-audit: a run of [ is not a timeout" "deny" "$(decision)"
[[ "$TL_STATUS" -ne 124 ]] && tl_pass "completion-audit: brackets finished in ${ELAPSED}s" || tl_fail "completion-audit: brackets timed out"

near="$(repeat 'true;' 48000) gh pr create --fill"       # 240 KB: heavy to parse, under the input cap
timed "$CA_HOOK" "$near"
assert_eq "completion-audit: a command near the input cap is denied" "deny" "$(decision)"
[[ "$TL_STATUS" -ne 124 ]] && tl_pass "completion-audit: near the cap finished in ${ELAPSED}s" || tl_fail "completion-audit: near the cap timed out"

# dev-cycle-check runs the analyzer for write paths, the invoked script and the read-only verdict
HOOK="$TL_REPO_ROOT/hooks/dev-cycle-check.sh"
state
hidden="if false; then x=abcd; $(repeat 'x=$x$x; ' 25)fi; sed -i s/x/y/ src/app.js"
timed "$HOOK" "$hidden"
assert_eq "dev-cycle-check: a doubling value inside 'if false' is not a timeout" "deny" "$(decision)"
[[ "$TL_STATUS" -ne 124 && "$ELAPSED" -lt 14 ]] && tl_pass "dev-cycle-check: doubling finished in ${ELAPSED}s" || tl_fail "dev-cycle-check: doubling took ${ELAPSED}s (status $TL_STATUS)"

brackets="export '$(repeat '[' 40000)'; sed -i s/x/y/ src/app.js"
timed "$HOOK" "$brackets"
assert_eq "dev-cycle-check: a run of [ is not a timeout" "deny" "$(decision)"
[[ "$TL_STATUS" -ne 124 ]] && tl_pass "dev-cycle-check: brackets finished in ${ELAPSED}s" || tl_fail "dev-cycle-check: brackets timed out"

near="$(repeat 'true;' 48000) sed -i s/x/y/ src/app.js"
timed "$HOOK" "$near"
assert_eq "dev-cycle-check: a command near the input cap is denied" "deny" "$(decision)"
[[ "$TL_STATUS" -ne 124 ]] && tl_pass "dev-cycle-check: near the cap finished in ${ELAPSED}s" || tl_fail "dev-cycle-check: near the cap timed out"

tl_results
