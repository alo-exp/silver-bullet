#!/usr/bin/env bash
# The REQUIREMENTS.md owner allowance follows the skill invoked LAST (sealed by record-skill.sh on every
# invocation, re-invocations included), not the last skill recorded for the first time.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"
GUARD=hooks/planning-file-guard.sh
REQ="$TG2_PROJ/.planning/REQUIREMENTS.md"
mkdir -p "$TG2_PROJ/.planning"
export SILVER_BULLET_BRANCH_FILE="$TL_TMP/branch"
printf 'main\n' >"$SILVER_BULLET_BRANCH_FILE"

write_req() { # tool [extra input json filter]
  tg2_run "$GUARD" "$(jq -cn --arg f "$REQ" --arg t "${1:-Write}" '{hook_event_name:"PreToolUse", tool_name:$t, tool_input:{file_path:$f}}')"
}
denied() { grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' <<<"$TL_OUT"; }
allowed_case() { write_req "${2:-Write}"; if denied; then tl_fail "$1 (denied: $TL_OUT)"; else tl_pass "$1"; fi; }
denied_case() { write_req "${2:-Write}"; if denied; then tl_pass "$1"; else tl_fail "$1 (allowed)"; fi; }
rec() { rs "$(skill_input "$1")"; }

reset; rec silver-plan; rec silver-spec
allowed_case "plan -> spec: REQUIREMENTS.md may be written"
allowed_case "plan -> spec: Edit too" Edit
rec silver-plan
denied_case "plan -> spec -> plan: re-running plan ends the allowance (state is unchanged by it)"
assert_eq "the state still lists each skill once" "silver-plan silver-spec" "$(tr '\n' ' ' <"$STATE" | sed 's/ $//')"
rec silver-spec
allowed_case "plan -> spec -> plan -> spec: a re-invoked spec restores the allowance"
rec silver-ingest
allowed_case "ingest invoked last may write too"
rec silver-quality-gates
denied_case "another skill invoked last: denied"

echo "--- forgery and staleness ---"
reset; rec silver-plan; rec silver-spec
cp "$STATE.last" "$TL_TMP/last.spec"; cp "$STATE.lasthwm" "$TL_TMP/lasthwm.spec"
rec silver-plan
denied_case "baseline: plan invoked last"
cp "$TL_TMP/last.spec" "$STATE.last"
denied_case "an older .last put back is refused (counter below the highest issued)"
cp "$TL_TMP/lasthwm.spec" "$STATE.lasthwm"; rec silver-plan
printf 'v1\nsilver-spec\n99\n-\nforged\n' >"$STATE.last"
denied_case "a forged .last without the key digest is refused"
rec silver-plan; rec silver-spec
printf 'silver-plan\nsilver-spec\n' >"$STATE"
sed -i 's/silver-spec/silver-plan/' "$STATE.last"
denied_case "an edited .last (skill changed under the digest) is refused"
reset; printf 'silver-plan\nsilver-spec\n' >"$STATE"
denied_case "an old state with no .last record gives no allowance"
rm -f "$STATE" "$STATE.last"
reset; rec silver-spec
rm -f "$STATE.last"; ln -s "$TL_TMP/forged-last" "$STATE.last"
printf 'v1\nsilver-spec\n1\n-\nx\n' >"$TL_TMP/forged-last"
denied_case "a symlinked .last is refused"
rm -f "$STATE.last"

echo "--- branch scope ---"
reset; rec silver-spec
allowed_case "same branch: allowed"
printf 'other-branch\n' >"$SILVER_BULLET_BRANCH_FILE"
denied_case "after a branch change the record no longer verifies"
printf 'main\n' >"$SILVER_BULLET_BRANCH_FILE"

echo "--- hard links, deletes, MCP ---"
reset; rec silver-spec
allowed_case "baseline allowed again"
mkdir -p "$TG2_PROJ/.planning"
printf 'x\n' >"$TG2_PROJ/.planning/ROADMAP.md"
ln "$TG2_PROJ/.planning/ROADMAP.md" "$REQ"
denied_case "REQUIREMENTS.md hard-linked to ROADMAP.md is denied"
rm -f "$REQ"
mcp="$(jq -cn --arg f "$REQ" '{hook_event_name:"PreToolUse", tool_name:"mcp__filesystem__delete_file", tool_input:{path:$f}}')"
tg2_run "$GUARD" "$mcp"; if denied; then tl_pass "an MCP delete of REQUIREMENTS.md is denied"; else tl_fail "MCP delete allowed"; fi
mcp="$(jq -cn --arg f "$REQ" '{hook_event_name:"PreToolUse", tool_name:"mcp__filesystem__write_file", tool_input:{path:$f, content:"x"}}')"
tg2_run "$GUARD" "$mcp"; if denied; then tl_pass "an MCP write of REQUIREMENTS.md gets no owner allowance"; else tl_fail "MCP write allowed"; fi
patch_in() { jq -cn --arg p "$1" '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{patch:$p}}'; }
tg2_run "$GUARD" "$(patch_in $'*** Begin Patch\n*** Update File: .planning/REQUIREMENTS.md\n@@\n+x\n*** End Patch')"
if denied; then tl_fail "apply_patch update denied"; else tl_pass "apply_patch Update File is allowed for the owner"; fi
tg2_run "$GUARD" "$(patch_in $'*** Begin Patch\n*** Delete File: .planning/REQUIREMENTS.md\n*** End Patch')"
if denied; then tl_pass "apply_patch Delete File of REQUIREMENTS.md is denied"; else tl_fail "apply_patch delete allowed"; fi
tg2_run "$GUARD" "$(patch_in $'*** Begin Patch\n*** Update File: x.md\n*** Move to: .planning/REQUIREMENTS.md\n@@\n+x\n*** End Patch')"
if denied; then tl_pass "apply_patch Move to REQUIREMENTS.md is denied"; else tl_fail "apply_patch move allowed"; fi

echo "--- the state-tamper guard refuses writes to the .last record ---"
reset; rec silver-spec
tg2_run hooks/dev-cycle-check.sh "$(jq -cn --arg f "$STATE.last" '{hook_event_name:"PreToolUse", tool_name:"Write", tool_input:{file_path:$f, content:"v1"}}')"
if grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' <<<"$TL_OUT"; then tl_pass "a file-tool write of .last is denied"; else tl_fail "write of .last not denied: $TL_OUT"; fi
tg2_run hooks/dev-cycle-check.sh "$(tg2_bash_input "printf 'v1' > $STATE.last")"
if grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' <<<"$TL_OUT"; then tl_pass "a shell write of .last is denied"; else tl_fail "shell write of .last not denied: $TL_OUT"; fi

echo "--- Codex receipts (silver-bullet invoke-skill) count the same ---"
mkdir -p "$RECEIPTS"
codex_rec() {
  jq -cn --arg s "$1" --arg cwd "$TG2_PROJ" --argjson ts "$(date +%s)" \
    '{channel:"silver-bullet.invoke-skill", status:"loaded", canonical_skill:$s, cwd:$cwd, timestamp_epoch:$ts, skill_file:"/x/SKILL.md", script:"/x/silver-bullet"}' >"$RECEIPTS/r-$2.json"
  rs "$(bash_input 'silver-bullet invoke-skill '"sb:${1#silver-}")"
}
reset; mkdir -p "$RECEIPTS"
codex_rec silver-plan 1; codex_rec silver-spec 2
allowed_case "codex: plan -> spec allowed"
rm -f "$RECEIPTS"/*.json; codex_rec silver-plan 3
denied_case "codex: spec -> plan denied"

tl_results
