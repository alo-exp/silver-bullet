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
write_as() { # agent id as a JSON literal ("w1", "\u0000" forms ok)
  tg2_run "$GUARD" "$(jq -cn --arg f "$REQ" --argjson a "$1" '{hook_event_name:"PreToolUse", tool_name:"Write", agent_id:$a, tool_input:{file_path:$f}}')"
}
sub_rec_as() { # agent id (plain string), skill
  rs "$(jq -c --arg a "$1" '. + {agent_id:$a}' <<<"$(skill_input "$2")")"
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

echo "--- helpers, near-names and subagents ---"
reset; rec silver-plan; rec silver-spec; rec artifact-reviewer
allowed_case "spec -> artifact-reviewer (untracked helper) -> Write allowed"
rec review-spec
allowed_case "spec -> artifact-reviewer -> review-spec -> Write allowed"
rec silver-plan
denied_case "spec -> silver-plan (tracked) -> Write denied"
rec silver-spec-evil
denied_case "a near-name (silver-spec-evil) does not count as spec"
rec x:silver-spec
denied_case "a foreign-namespace x:silver-spec does not count as spec"
rec silver-spec
rec silver-spec-evil; rec x:silver-spec; rec silver-bullet-evil:silver-plan
allowed_case "near-names do not displace spec"
rec silver-bullet:sb:spec
allowed_case "the plugin namespace prefix still resolves to spec"
reset; rec silver-spec; rs "$(jq -c '. + {agentId:"sub-2"}' <<<"$(skill_input silver-plan)")"
allowed_case "the agentId spelling is a subagent too"

echo "--- per-agent records: workers in a parent-mode project ---"
reset; tg2_cfg '{"sb_initiated":true,"orchestrator_mode":"parent"}'
write_as '"w1"'; if denied; then tl_pass "worker w1 before any skill: denied"; else tl_fail "w1 allowed with no record"; fi
sub_rec_as w1 silver-plan; sub_rec_as w1 silver-spec
write_as '"w1"'; if denied; then tl_fail "worker w1 after its own sb:spec denied"; else tl_pass "worker w1 invoked sb:spec: its Write is allowed"; fi
write_as '"w2"'; if denied; then tl_pass "worker w2 (no record) is denied"; else tl_fail "w2 allowed"; fi
denied_case "the main session after a worker's spec is denied"
sub_rec_as w1 silver-plan
write_as '"w1"'; if denied; then tl_pass "worker w1 then a tracked skill: denied"; else tl_fail "w1 allowed after plan"; fi
sub_rec_as w1 silver-spec
write_as '"w1"'; if denied; then tl_fail "w1 re-run denied"; else tl_pass "worker w1 re-running sb:spec is allowed again"; fi
sub_rec_as w2 silver-plan
write_as '"w1"'; if denied; then tl_fail "w2's skill displaced w1"; else tl_pass "another worker's skill does not displace w1"; fi
reset; rec silver-spec
allowed_case "main session spec: main Write allowed"
write_as '"w1"'; if denied; then tl_pass "a main-session sb:spec does not let a subagent write"; else tl_fail "subagent rode the main record"; fi
sub_rec_as w1 silver-plan
allowed_case "a worker's tracked skill leaves the main record alone"
reset; printf 'silver-plan\nsilver-spec\n' >"$STATE"
write_as '"w1"'; if denied; then tl_pass "an old state with no per-agent record gives a worker nothing"; else tl_fail "old state allowed a worker"; fi

echo "--- hostile agent ids ---"
reset; rec silver-spec
lastfiles() { ls "$STATE".last* "$STATE".lasthwm* 2>/dev/null | sort | tr '\n' ' '; }
before="$(lastfiles)"
for bad in '../x' 'a/b' '' "$(printf 'z%.0s' $(seq 1 200))" $'a\nb' 'a b' '.hidden' 'w1.tmp'; do
  sub_rec_as "$bad" silver-spec
done
rs "$(jq -c '. + {agent_id:"a\u0000b"}' <<<"$(skill_input silver-spec)")"
rs "$(jq -c '. + {agent_id:5}' <<<"$(skill_input silver-spec)")"
assert_eq "hostile agent ids create no record file" "$before" "$(lastfiles)"
assert_eq "and no file beside the state directory" "" "$(ls "$SB_RUNTIME_STATE_DIR"/../*.last* "$SB_RUNTIME_STATE_DIR"/../x* 2>/dev/null | tr '\n' ' ')"
assert_file_absent "nothing was written beside the state directory" "$SB_RUNTIME_STATE_DIR/../x.last"
for bad in '"../x"' '"a/b"' '""' '"a\nb"' '"a\u0000b"' 5 '["w1"]'; do
  write_as "$bad"; if denied; then tl_pass "hostile id $bad: Write denied even with a main record"; else tl_fail "hostile id $bad allowed"; fi
done
sub_rec_as w1 silver-spec
write_as '"w1"'; if denied; then tl_fail "valid id w1 denied"; else tl_pass "a valid id still works next to the hostile ones"; fi
tg2_run "$GUARD" "$(jq -cn --arg f "$REQ" '{hook_event_name:"PreToolUse", tool_name:"Write", agentId:"w1", tool_input:{file_path:$f}}')"
if denied; then tl_fail "agentId spelling denied"; else tl_pass "the agentId spelling reads the same record"; fi

echo "--- concurrent workers and pruning ---"
reset; rec silver-plan
( sub_rec_as wa silver-spec ) & ( sub_rec_as wb silver-spec ) & ( sub_rec_as wc silver-plan ) & wait
write_as '"wa"'; if denied; then tl_fail "wa denied"; else tl_pass "concurrent worker wa allowed"; fi
write_as '"wb"'; if denied; then tl_fail "wb denied"; else tl_pass "concurrent worker wb allowed"; fi
write_as '"wc"'; if denied; then tl_pass "concurrent worker wc (plan) denied"; else tl_fail "wc allowed"; fi
export SB_LAST_AGENT_RECORDS=3
for n in 1 2 3 4 5; do sub_rec_as "p$n" silver-spec; sleep 1; done
count="$(ls "$STATE".last.* 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "agent records are bounded (newest kept)" "3" "$count"
assert_eq "the pruned agents' counter files go too" "3" "$(ls "$STATE".lasthwm.* 2>/dev/null | wc -l | tr -d ' ')"
write_as '"p5"'; if denied; then tl_fail "newest agent pruned"; else tl_pass "the newest agent's record survives pruning"; fi
write_as '"p1"'; if denied; then tl_pass "the oldest agent's record was pruned"; else tl_fail "p1 survived"; fi
unset SB_LAST_AGENT_RECORDS

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

reset; rec silver-spec
allowed_case "baseline before the counter file is deleted"
rm -f "$STATE.lasthwm"
denied_case "deleting .lasthwm does not re-enable the record"
reset; rec silver-plan; rec silver-spec; cp "$STATE.last" "$TL_TMP/old.last"; cp "$STATE.lasthwm" "$TL_TMP/old.hwm"
rec silver-plan; rm -f "$STATE.lasthwm"; cp "$TL_TMP/old.last" "$STATE.last"
denied_case "an older valid .last with the counter file deleted is refused"

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
