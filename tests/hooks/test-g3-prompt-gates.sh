#!/usr/bin/env bash
# Review package G3 (R2-10 R2-11 R2-19 R2-22): prompt classifier, outcomes checklist, instruction ledger.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
source "$TL_REPO_ROOT/hooks/lib/prompt-classifier.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_STATE_FILE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
OC="$TL_REPO_ROOT/hooks/outcomes-check.sh"
LG="$TL_REPO_ROOT/hooks/instruction-ledger-gate.sh"
run() { # hook json
  tl_run_stdin "$2" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$1"
}
ups() { jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit",session_id:"s1",prompt:$p}'; }
ev() { jq -cn --arg e "$1" '{hook_event_name:$e}'; }
reason() { jq -r '.reason // ""' <<<"$TL_OUT"; }
reset() { rm -f "$SD"/outcomes-session.json* "$SD"/instruction-ledger.json "$SD"/stop-coalesce-block "$SD"/ups-coalesce-* "$SD/outcomes-tamper.log" "$SD/state"; }

# ---- R2-19: classifier table -------------------------------------------------------------
info() { if sb_prompt_is_informational_query "$1"; then tl_pass "informational: ${1//$'\n'/ / }"; else tl_fail "expected informational: $1"; fi; }
work() { if sb_prompt_is_informational_query "$1"; then tl_fail "expected work: $1"; else tl_pass "work: ${1//$'\n'/ / }"; fi; }
work $'Implement these:\n- add login form\n- add logout button\n- add session tests\nWhen finished, open a PR.'
work 'Fix the status of the checkout page and deploy it'
work 'Build the outstanding dashboard widgets and ship them'
work 'how about you refactor the auth module and add tests'
work 'what is the status? then deploy it'
work $'how does auth work?\nthen fix it'
work $'What are the remaining items?\n1. fix the build'
info 'What are the remaining deliverables?'
info 'How does this work'
info 'status of the migration'
info 'explain how to fix this'
info 'Why does the release build fail on CI?'
info 'recap'
info "what's next?"
fu() { if sb_prompt_is_orchestrator_followup "$1"; then tl_pass "follow-up: $1"; else tl_fail "expected follow-up: $1"; fi; }
nofu() { if sb_prompt_is_orchestrator_followup "$1"; then tl_fail "expected new request: $1"; else tl_pass "new request: $1"; fi; }
nofu 'now implement the payment API'
nofu 'stopwatch feature: add lap times'
nofu '3 bugs remain, fix them all'
nofu 'nothing else, ship it'
fu 'yes'; fu 'No, use option 2'; fu '2) the second'; fu '2.'; fu '3'; fu 'stop'; fu 'option 2 please'

# ---- R2-19: work prompts are seeded as work, not pre-completed ------------------------------
reset
run "$OC" "$(ups $'Implement these:\n- add login form\n- add logout button\n- add session tests\nWhen finished, open a PR.')"
assert_eq "bullet prompt: outcomes seeded pending" 3 "$(jq '[.outcomes[] | select(.status == "pending")] | length' "$SD/outcomes-session.json")"
run "$LG" "$(ups $'Implement these:\n- add login form\n- add logout button\n- add session tests\nWhen finished, open a PR.')"
assert_file_exists "bullet prompt: ledger seeded" "$SD/instruction-ledger.json"

# ---- R2-19: the checklist cannot be self-certified --------------------------------------------
reset
printf 'silver-context\n' >"$SD/state"
run "$OC" "$(ups 'Refactor the auth module and add tests')"
run "$OC" "$(ev Stop)"
assert_contains "pending outcomes block Stop" "$(reason)" "outcome checklist incomplete"
assert_not_contains "remedy no longer tells the agent to edit the JSON" "$(reason)" "mark outcomes done"
rm -f "$SD/stop-coalesce-block"
jq '.outcomes[].status = "done"' "$SD/outcomes-session.json" >"$SD/o.tmp" && mv "$SD/o.tmp" "$SD/outcomes-session.json"
run "$OC" "$(ev Stop)"
assert_contains "agent-written done statuses do not satisfy the gate" "$(reason)" "outcome checklist incomplete"
assert_file_exists "the tamper is logged" "$SD/outcomes-tamper.log"
rm -f "$SD/stop-coalesce-block"
rm -f "$SD/outcomes-session.json.sha256"
jq '.outcomes[].status = "done"' "$SD/outcomes-session.json" >"$SD/o.tmp" && mv "$SD/o.tmp" "$SD/outcomes-session.json"
run "$OC" "$(ev Stop)"
assert_contains "deleting the seal does not help either" "$(reason)" "outcome checklist incomplete"
rm -f "$SD/stop-coalesce-block"
# honest variant: hook-observed evidence completes the checklist
printf 'silver-feature\nsilver-verify\nsilver-execute\n' >"$SD/state"
run "$OC" "$(ev Stop)"
assert_eq "recorded skills complete the checklist: Stop allowed" "0:" "$TL_STATUS:$TL_OUT"
# no sha256 tool: cannot verify, never blocks honest work
reset
printf 'silver-feature\nsilver-verify\nsilver-execute\n' >"$SD/state"
run "$OC" "$(ups 'Refactor the auth module and add tests')"
NOSHA="$(tl_path_without sha256sum shasum openssl)"
tl_run_stdin "$(ev Stop)" env PATH="$NOSHA" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$OC"
assert_eq "no sha256 tool: tamper check skipped, evidence still decides" "0:" "$TL_STATUS:$TL_OUT"

# ---- R2-10: ordinary subagents are not held by the parent's gates ---------------------------------
reset
printf 'silver-context\n' >"$SD/state"
run "$OC" "$(ups 'Refactor the auth module and add tests')"
run "$OC" "$(ev SubagentStop)"
assert_eq "outcomes: SubagentStop of a research subagent" "0:" "$TL_STATUS:$TL_OUT"
run "$LG" "$(ups $'Do these:\n- one\n- two\n- three')"
run "$LG" "$(ev SubagentStop)"
assert_eq "ledger: SubagentStop of a research subagent" "0:" "$TL_STATUS:$TL_OUT"

# ---- R2-11: ledger remedy path, branch switch, distinct ids ---------------------------------------
reset
run "$LG" "$(ups $'Do these:\n- add login form\n- add logout button\n- add session tests')"
assert_eq "ledger ids are distinct for labels sharing a prefix" 3 "$(jq '[.intents[0].children[].id] | unique | length' "$SD/instruction-ledger.json")"
run "$LG" "$(ev Stop)"
resolver="$(grep -o '/[^ ]*resolve-instruction-ledger.sh' <<<"$(reason)" | head -1)"
assert_eq "Stop block names the resolver by an existing absolute path" "$TL_REPO_ROOT/scripts/resolve-instruction-ledger.sh" "$resolver"
assert_file_exists "the named resolver exists" "$resolver"
rm -f "$SD/stop-coalesce-block"
git -C "$EC_PROJ" checkout -q -b scratch
run "$LG" "$(ev Stop)"
assert_contains "a branch switch inside the worktree does not discard the user's items" "$(reason)" "unresolved items"
assert_file_exists "ledger kept" "$SD/instruction-ledger.json"
assert_eq "ledger re-stamped to the new branch" scratch "$(jq -r .scope.branch "$SD/instruction-ledger.json")"
git -C "$EC_PROJ" checkout -q feature/test

tl_results
