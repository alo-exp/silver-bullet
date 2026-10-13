#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_json_eq() {
  local desc="$1" expected="$2" actual="$3"
  if diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >/dev/null; then
    pass "$desc"
  else
    fail "$desc"
    echo "expected:"
    printf '%s\n' "$expected"
    echo "actual:"
    printf '%s\n' "$actual"
  fi
}

assert_jq_true() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    pass "$desc"
  else
    fail "$desc"
    printf '%s\n' "$json"
  fi
}

assert_jq_false() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    fail "$desc"
    printf '%s\n' "$json"
  else
    pass "$desc"
  fi
}

assert_file_exists "$RESOLVER" "review-fix-ladder.py exists"

cat > "$WORKDIR/models_cache.json" <<'EOF'
{
  "models": [
    {
      "slug": "gpt-5.4-mini",
      "visibility": "list",
      "priority": 23,
      "supported_reasoning_levels": [
        {"effort": "low"},
        {"effort": "medium"},
        {"effort": "high"},
        {"effort": "xhigh"}
      ]
    },
    {
      "slug": "gpt-5.4",
      "visibility": "list",
      "priority": 16,
      "supported_reasoning_levels": [
        {"effort": "low"},
        {"effort": "medium"},
        {"effort": "high"},
        {"effort": "xhigh"}
      ]
    },
    {
      "slug": "gpt-5.5",
      "visibility": "list",
      "priority": 9,
      "supported_reasoning_levels": [
        {"effort": "low"},
        {"effort": "medium"},
        {"effort": "high"},
        {"effort": "xhigh"}
      ]
    }
  ]
}
EOF

dynamic_json="$(python3 "$RESOLVER" --host codex --codex-home "$WORKDIR" --json)"
assert_jq_true "Codex dynamic resolves host" '.host == "codex"' "$dynamic_json"
assert_jq_true "Codex dynamic uses cache source" '.source == "dynamic"' "$dynamic_json"
assert_jq_true "Codex dynamic starts at gpt-5.4 low" '.rungs[0] == {"model":"gpt-5.4","reasoning":"low"}' "$dynamic_json"
assert_jq_false "Codex dynamic excludes gpt-5.4-mini" '[.rungs[].model] | index("gpt-5.4-mini")' "$dynamic_json"

fallback_json="$(python3 "$RESOLVER" --host codex --codex-home "$WORKDIR/missing" --json)"
assert_jq_true "Codex fallback resolves host" '.host == "codex"' "$fallback_json"
assert_jq_true "Codex fallback uses fallback source" '.source == "fallback"' "$fallback_json"
assert_jq_true "Codex fallback includes gpt-5.4 low" '.rungs[0] == {"model":"gpt-5.4","reasoning":"low"}' "$fallback_json"
assert_jq_true "Codex fallback includes gpt-5.5 xhigh" '.rungs[-1] == {"model":"gpt-5.5","reasoning":"xhigh"}' "$fallback_json"
assert_jq_false "Codex fallback excludes gpt-5.4-mini" '[.rungs[].model] | index("gpt-5.4-mini")' "$fallback_json"

claude_json="$(python3 "$RESOLVER" --host claude --json)"
assert_jq_true "Claude fallback model chain" '
  .rungs == [
    {"model":"claude-sonnet-4-6","reasoning":"medium"},
    {"model":"claude-sonnet-4-6","reasoning":"high"},
    {"model":"claude-sonnet-4-6","reasoning":"xhigh"},
    {"model":"claude-opus-4-7","reasoning":"medium"},
    {"model":"claude-opus-4-7","reasoning":"high"},
    {"model":"claude-opus-4-7","reasoning":"xhigh"},
    {"model":"claude-opus-4-8","reasoning":"medium"},
    {"model":"claude-opus-4-8","reasoning":"high"},
    {"model":"claude-opus-4-8","reasoning":"xhigh"}
  ]
' "$claude_json"

cursor_json="$(SB_CURSOR_SB_AGENTS_SKIP_PROBE=1 python3 "$RESOLVER" --host cursor --json --project-root "$REPO_ROOT")"
cursor_rungs="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["rungs"]))' <<<"$cursor_json")"
if [[ "$cursor_rungs" -ge 6 ]]; then
  pass "Cursor sb_agents ladder has at least 6 rungs"
else
  fail "Cursor sb_agents ladder has at least 6 rungs — got $cursor_rungs"
fi
assert_jq_true "Cursor source cursor_sb_agents" '.source == "cursor_sb_agents"' "$cursor_json"
assert_jq_true "Cursor rung 1 custom-subagent" '.rungs[0].delegation == "custom-subagent"' "$cursor_json"
assert_jq_true "Cursor rung 1 subagent_name" '.rungs[0].subagent_name == "sb-composer-2-5-medium"' "$cursor_json"
assert_jq_false "Cursor zero agent-cursor" '[.rungs[].delegation] | any(. == "agent-cursor")' "$cursor_json"

phase_json="$(SB_CURSOR_SB_AGENTS_SKIP_PROBE=1 python3 "$RESOLVER" --host cursor --json --project-root "$REPO_ROOT" --rung 2 --phase verify_1)"
assert_jq_true "Phase routing custom-subagent" '.delegation == "custom-subagent"' "$phase_json"
assert_jq_true "Phase subagent_name rung2" '.subagent_name == "sb-composer-2-5-high"' "$phase_json"

cursor_text="$(SB_CURSOR_SB_AGENTS_SKIP_PROBE=1 python3 "$RESOLVER" --host cursor --project-root "$REPO_ROOT")"
printf '%s' "$cursor_text" | grep 'custom-subagent' >/dev/null && pass "Cursor text custom-subagent" || fail "Cursor text custom-subagent"
printf '%s' "$cursor_text" | grep 'agent-cursor' >/dev/null && fail "Cursor text no agent-cursor" || pass "Cursor text no agent-cursor"

override_json="$(python3 "$RESOLVER" --host cursor --json)"
assert_jq_true "Host override without env selects cursor" '.host == "cursor"' "$override_json"

SKILL="${REPO_ROOT}/skills/silver-review-fix-ladder/SKILL.md"
assert_file_exists "$SKILL" "review-fix-ladder SKILL.md exists"
if grep -qF 'Incorporate every finding that is not wrong' "$SKILL"; then
  pass "SKILL Policy A: incorporate every finding that is not wrong"
else
  fail "SKILL Policy A: incorporate every finding that is not wrong"
fi
if grep -qF 'Forbidden reject reasons' "$SKILL" && grep -qE 'advisory|doc-only|non-gating' "$SKILL"; then
  pass "SKILL forbids advisory/doc-only reject reasons"
else
  fail "SKILL forbids advisory/doc-only reject reasons"
fi
if grep -qF 'After each rung’s review, the agent that launched the RFL applies ACCEPT fixes' "$SKILL" \
  || grep -qF "After each rung's review, the agent that launched the RFL applies ACCEPT fixes" "$SKILL"; then
  pass "SKILL Policy B: launcher applies ACCEPT fixes"
else
  fail "SKILL Policy B: launcher applies ACCEPT fixes"
fi
if grep -qF 'The rung model does not implement' "$SKILL"; then
  pass "SKILL Policy B: rung model does not implement"
else
  fail "SKILL Policy B: rung model does not implement"
fi
if grep -qF '### Policy C — launcher reports after every rung' "$SKILL"; then
  pass "SKILL Policy C heading"
else
  fail "SKILL Policy C heading"
fi
if grep -qF "After each rung's review is in (CLEAN or NOT CLEAN), the launcher (the agent that started the RFL) must message the user with a severity-grouped update." "$SKILL"; then
  pass "SKILL Policy C: launcher messages user after each rung review"
else
  fail "SKILL Policy C: launcher messages user after each rung review"
fi
if grep -qF 'Do this after every rung, not only at family or ladder end.' "$SKILL"; then
  pass "SKILL Policy C: after every rung"
else
  fail "SKILL Policy C: after every rung"
fi
if grep -qF 'Do not dump raw review.md.' "$SKILL"; then
  pass "SKILL Policy C: do not dump raw review.md"
else
  fail "SKILL Policy C: do not dump raw review.md"
fi
if grep -qF '**Blockers / Highs / Mediums**' "$SKILL"; then
  pass "SKILL Policy C: Blockers / Highs / Mediums grouping"
else
  fail "SKILL Policy C: Blockers / Highs / Mediums grouping"
fi
if grep -qF 'CLEAN with no findings still gets the three **none** lines.' "$SKILL"; then
  pass "SKILL Policy C: CLEAN still reports none"
else
  fail "SKILL Policy C: CLEAN still reports none"
fi
if grep -qiE 'reject.{0,40}advisory|advisory.{0,20}findings may be ignored' "$SKILL" \
  && ! grep -qF 'Forbidden reject reasons' "$SKILL"; then
  fail "SKILL must not treat advisory as an allowed reject"
else
  pass "SKILL does not allow advisory reject"
fi
if grep -qF 'parent orchestrator never implements' "$SKILL" \
  && grep -qF 'RFL session exception' "$SKILL"; then
  pass "SKILL records RFL exception to parent-never-implements"
else
  fail "SKILL records RFL exception to parent-never-implements"
fi
if grep -qF 'Do not skip Extra High/Max when those slugs exist' "$SKILL"; then
  pass "SKILL does not skip Extra High/Max"
else
  fail "SKILL does not skip Extra High/Max"
fi
if grep -qF 'Launch fix subagent(s) at **host model**' "$SKILL"; then
  fail "SKILL must not tell the rung/host-model subagent to apply fixes"
else
  pass "SKILL does not spawn rung/host-model fix subagents"
fi
if grep -qF 'APPLY ACCEPT completeness (HARD)' "$SKILL" \
  && grep -qF 'Low, deferred, nitpicks, and minor' "$SKILL" \
  && grep -qF 'CLEAN for ladder purposes' "$SKILL" \
  && grep -qF 'non-blocking nit' "$SKILL" \
  && grep -qF 'do not reopen KEEP REJECT' "$SKILL"; then
  pass "SKILL APPLY ACCEPT lands all non-wrong nits"
else
  fail "SKILL APPLY ACCEPT lands all non-wrong nits"
fi
if grep -qF 'The fix step is launcher APPLY ACCEPT, not a fixer rung' "$SKILL"; then
  pass "SKILL fix step is launcher APPLY ACCEPT"
else
  fail "SKILL fix step is launcher APPLY ACCEPT"
fi
if grep -qF '### Policy F — two consecutive CLEAN reviews per rung (HARD)' "$SKILL" \
  && grep -qF 'two consecutive review passes' "$SKILL" \
  && grep -qF 'consecutive_clean_reviews == 2' "$SKILL" \
  && grep -qF -- '--assert-consecutive-clean' "$SKILL" \
  && grep -qF -- '--record-rung-review-outcome' "$SKILL" \
  && grep -qF 'Parent MUST NOT launch the next ladder model' "$SKILL"; then
  pass "SKILL Policy F: two consecutive CLEAN reviews per rung"
else
  fail "SKILL Policy F: two consecutive CLEAN reviews per rung"
fi
if grep -qF '### Policy G — hop review (pack-ledger) (HARD)' "$SKILL" \
  && grep -qF 'do not re-report ledger rows' "$SKILL" \
  && grep -qF 'file only one new ID' "$SKILL" \
  && grep -qF 'all severities' "$SKILL" \
  && grep -qF 'Valid nits must be filed' "$SKILL" \
  && grep -qF -- '--issue-ledger' "$SKILL" \
  && grep -qF -- '--write-review-brief' "$SKILL" \
  && grep -qF '{issue_ledger}' "$SKILL" \
  && grep -qF 'as a pack' "$SKILL" \
  && grep -qF 'only legal review brief' "$SKILL"; then
  pass "SKILL Policy G: pack-ledger hop review, all severities"
else
  fail "SKILL Policy G: pack-ledger hop review, all severities"
fi
if grep -qF 'Policy map (A–G)' "$SKILL" \
  && grep -qF 'Canonical verify overlay (HARD)' "$SKILL" \
  && grep -qF 'verify_2 is skipped on already-triaged' "$SKILL" \
  && grep -qF '`verify_1` is **required** on already-triaged **NOT CLEAN**' "$SKILL"; then
  pass "SKILL A–G map + canonical verify overlay"
else
  fail "SKILL A–G map + canonical verify overlay"
fi
if grep -qF '### Policy E — rung-prompt user-approval (HARD)' "$SKILL" \
  && grep -qF 'concise bullet list of only the key tasks and instructions' "$SKILL" \
  && grep -qF 'Do **not** dump the entire prompt' "$SKILL" \
  && grep -qF 'Until approved:' "$SKILL" \
  && grep -qF 'do not spawn reviewer Tasks / Pi invoke' "$SKILL" \
  && grep -qF 'RUNG-PROMPT-APPROVAL.md' "$SKILL" \
  && grep -qF 'approved: pending|yes' "$SKILL" \
  && grep -qF '5–12 bullets' "$SKILL" \
  && grep -qF 'materially change' "$SKILL" \
  && grep -qF 'out of scope for the reviewer' "$SKILL" \
  && grep -qF 'KEEP REJECT' "$SKILL"; then
  pass "SKILL Policy E: rung-prompt user-approval gate"
else
  fail "SKILL Policy E: rung-prompt user-approval gate"
fi

WORKER="${REPO_ROOT}/templates/orchestrator-workers/REVIEW-TRIAGE.md"
assert_file_exists "$WORKER" "REVIEW-TRIAGE worker template exists"
if grep -qF 'The rung model does not implement' "$WORKER" \
  && grep -qF 'Forbidden reject reasons' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes RFL triage and fix-owner policy"
else
  fail "REVIEW-TRIAGE worker encodes RFL triage and fix-owner policy"
fi
if grep -qF 'APPLY ACCEPT completeness (HARD)' "$WORKER" \
  && grep -qF 'Low, deferred, nitpicks, and minor' "$WORKER" \
  && grep -qF 'The fix step is launcher APPLY ACCEPT, not a fixer rung' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes APPLY ACCEPT lands all non-wrong nits"
else
  fail "REVIEW-TRIAGE worker encodes APPLY ACCEPT lands all non-wrong nits"
fi
if grep -qF 'Policy C — launcher reports after every rung' "$WORKER" \
  && grep -qF "the launcher (the agent that started the RFL) must message the user with a severity-grouped update" "$WORKER" \
  && grep -qF 'Do this after every rung, not only at family or ladder end.' "$WORKER" \
  && grep -qF 'Do not dump raw review.md.' "$WORKER" \
  && grep -qF 'Blockers / Highs / Mediums' "$WORKER" \
  && grep -qF 'CLEAN with no findings still gets the three none lines' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes Policy C per-rung reporting"
else
  fail "REVIEW-TRIAGE worker encodes Policy C per-rung reporting"
fi
if grep -qF 'rung-prompt user-approval' "$WORKER" \
  && grep -qF 'concise bullet list of only the key tasks and instructions' "$WORKER" \
  && grep -qF 'Do not dump the entire prompt' "$WORKER" \
  && grep -qF 'Until approved: do not spawn reviewer Tasks / Pi invoke' "$WORKER" \
  && grep -qF 'RUNG-PROMPT-APPROVAL.md' "$WORKER" \
  && grep -qF 'approved: pending|yes' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes Policy E rung-prompt user-approval"
else
  fail "REVIEW-TRIAGE worker encodes Policy E rung-prompt user-approval"
fi

SCENARIO="${REPO_ROOT}/tests/skill-scenarios/silver-review-fix-ladder.md"
assert_file_exists "$SCENARIO" "review-fix-ladder skill scenario exists"
if grep -qF 'APPLY ACCEPT completeness (HARD)' "$SCENARIO" \
  && grep -qF 'Low, deferred, nitpicks, and minor' "$SCENARIO" \
  && grep -qF 'The fix step is launcher APPLY ACCEPT, not a fixer rung' "$SCENARIO"; then
  pass "Skill scenario encodes APPLY ACCEPT lands all non-wrong nits"
else
  fail "Skill scenario encodes APPLY ACCEPT lands all non-wrong nits"
fi
if grep -qF 'Hop review / pack-ledger (Policy G)' "$SCENARIO" \
  && grep -qF 'do not re-report ledger rows' "$SCENARIO" \
  && grep -qF 'all severities' "$SCENARIO" \
  && grep -qF -- '--issue-ledger' "$SCENARIO" \
  && grep -qF 'as a pack' "$SCENARIO" \
  && grep -qF 'only legal review brief' "$SCENARIO"; then
  pass "Skill scenario encodes Policy G pack-ledger hop review"
else
  fail "Skill scenario encodes Policy G pack-ledger hop review"
fi
if grep -qF 'Per-Rung Launcher Reporting (Policy C)' "$SCENARIO" \
  && grep -qF 'Do this after every rung, not only at family or ladder end' "$SCENARIO" \
  && grep -qF 'Do not dump raw review.md' "$SCENARIO" \
  && grep -qF 'Blockers / Highs / Mediums' "$SCENARIO" \
  && grep -qF 'CLEAN with no findings still gets the three none lines' "$SCENARIO"; then
  pass "Skill scenario encodes Policy C per-rung reporting"
else
  fail "Skill scenario encodes Policy C per-rung reporting"
fi
if grep -qF 'Rung-prompt user-approval (Policy E)' "$SCENARIO" \
  && grep -qF 'concise bullet list of only the key tasks and instructions' "$SCENARIO" \
  && grep -qF 'Do not dump the entire prompt' "$SCENARIO" \
  && grep -qF 'Until approved: do not spawn reviewer Tasks / Pi invoke' "$SCENARIO" \
  && grep -qF 'RUNG-PROMPT-APPROVAL.md' "$SCENARIO" \
  && grep -qF 'approved: pending|yes' "$SCENARIO" \
  && grep -qF 'materially change' "$SCENARIO"; then
  pass "Skill scenario encodes Policy E rung-prompt user-approval"
else
  fail "Skill scenario encodes Policy E rung-prompt user-approval"
fi

if grep -qF 'Anti-stall (Policy B leftover loop — HARD)' "$SKILL" \
  && grep -qF 'Corpus sweep, not one-line cycles' "$SKILL" \
  && grep -qF 'Empty / "Let" nested Tasks' "$SKILL" \
  && grep -qF 'Quota STOP (once)' "$SKILL" \
  && grep -qF 'Cap residual loops' "$SKILL" \
  && grep -qF 'nested GLM under Grok dies after "Let"' "$SKILL"; then
  pass "SKILL encodes anti-stall leftover loop"
else
  fail "SKILL encodes anti-stall leftover loop"
fi
if grep -qF 'Launch/timeout retry then skip (HARD)' "$SKILL" \
  && grep -qF 'retry **once immediately**' "$SKILL" \
  && grep -qF 'SKIPPED.md' "$SKILL" \
  && grep -qF 'failed to produce a verdict' "$SKILL" \
  && grep -qF 'Endpoint is unavailable' "$SKILL" \
  && grep -qF 'Do **not** skip because of a CLEAN/NOT CLEAN review' "$SKILL" \
  && grep -qF 'skip does not change the next rung' "$SKILL" \
  && grep -qF 'Never Fast' "$SKILL" \
  && grep -qF 'not a Fast/family substitute' "$SKILL" \
  && grep -qF 'retry skipped rungs once more' "$SKILL" \
  && grep -qF 'previous rung was skipped after launch/timeout retry-once-then-skip with `SKIPPED.md` recorded' "$SKILL" \
  && grep -qF 'Quota STOP (once)' "$SKILL"; then
  pass "SKILL encodes launch/timeout retry-once-then-skip"
else
  fail "SKILL encodes launch/timeout retry-once-then-skip"
fi
if grep -qF 'Anti-Stall leftover loop (Policy B)' "$SCENARIO" \
  && grep -qF 'Corpus sweep, not one-line cycles' "$SCENARIO" \
  && grep -qF 'Cap residual loops' "$SCENARIO"; then
  pass "Skill scenario encodes anti-stall leftover loop"
else
  fail "Skill scenario encodes anti-stall leftover loop"
fi
if grep -qF 'Skip after launch/timeout retry-once-then-skip' "$SCENARIO" \
  && grep -qF 'Retry once immediately' "$SCENARIO" \
  && grep -qF 'SKIPPED.md' "$SCENARIO" \
  && grep -qF 'failed to produce a verdict' "$SCENARIO" \
  && grep -qF 'Do not skip because of a CLEAN/NOT CLEAN review' "$SCENARIO" \
  && grep -qF "skip does not change the next rung's required model" "$SCENARIO" \
  && grep -qF 'Never Fast' "$SCENARIO" \
  && grep -qF 'Quota STOP once still applies' "$SCENARIO" \
  && grep -qF 'Sequential rung advance is allowed if the previous rung has SKIPPED.md' "$SCENARIO" \
  && grep -qF 'Empty/"Let" after re-spawn counts toward the launch/timeout retry-once-then-skip policy' "$SCENARIO"; then
  pass "Skill scenario encodes launch/timeout retry-once-then-skip"
else
  fail "Skill scenario encodes launch/timeout retry-once-then-skip"
fi
if grep -qF 'Anti-stall (Policy B leftover loop)' "$WORKER" \
  && grep -qF 'Corpus sweep if the same defect class fails verify more than twice' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes anti-stall leftover loop"
else
  fail "REVIEW-TRIAGE worker encodes anti-stall leftover loop"
fi
if grep -qF 'retry once immediately' "$WORKER" \
  && grep -qF 'SKIPPED.md' "$WORKER" \
  && grep -qF 'Launch/timeout retry-once-then-skip (HARD)' "$WORKER" \
  && grep -qF 'Do not skip because of CLEAN/NOT CLEAN' "$WORKER" \
  && grep -qF "Mixed-host skip does not change the next rung's required model" "$WORKER" \
  && grep -qF 'Never Fast' "$WORKER" \
  && grep -qF 'empty Let' "$WORKER" \
  && grep -qF 'Sequential rung advance is allowed if the previous rung has SKIPPED.md' "$WORKER" \
  && grep -qF 'Quota STOP once' "$WORKER" \
  && grep -qF 'retry skipped rungs once more' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes launch/timeout retry-once-then-skip"
else
  fail "REVIEW-TRIAGE worker encodes launch/timeout retry-once-then-skip"
fi

LIVE_COMMON="${REPO_ROOT}/tests/live/lib/review-fix-ladder-common.sh"
LIVE_TRIAGE="${REPO_ROOT}/tests/live/lib/review-fix-ladder-triage-scenario.sh"
assert_file_exists "$LIVE_COMMON" "live review-fix-ladder common harness exists"
assert_file_exists "$LIVE_TRIAGE" "live review-fix-ladder triage harness exists"
if grep -qE 'OR fix divide\(\)|Fix divide\(\) minimally' "$LIVE_COMMON" "$LIVE_TRIAGE"; then
  fail "live harness must not tell the rung to fix"
else
  pass "live harness must not tell the rung to fix"
fi
if grep -q 'review_fix_ladder_launcher_apply_accept' "$LIVE_COMMON" \
  && grep -q 'APPLY ACCEPT' "$LIVE_COMMON" "$LIVE_TRIAGE"; then
  pass "launcher APPLY ACCEPT"
else
  fail "launcher APPLY ACCEPT"
fi
if grep -qF 'Low, deferred, nitpicks, and minor' "$LIVE_TRIAGE" \
  && grep -qF 'every finding that is not wrong' "$LIVE_TRIAGE" \
  && grep -qF 'Low/deferred/nitpicks/minor' "$LIVE_COMMON"; then
  pass "live harness APPLY ACCEPT lands all non-wrong nits"
else
  fail "live harness APPLY ACCEPT lands all non-wrong nits"
fi
if grep -q '/sb:triage' "$LIVE_COMMON"; then
  fail "live rung harness must not invoke /sb:triage as the rung"
else
  pass "live rung harness must not invoke /sb:triage as the rung"
fi

# --- Subscription-first GPT/Claude gate ---
GATE_ROOT="$WORKDIR/gate-project"
mkdir -p "$GATE_ROOT"
cat > "$GATE_ROOT/.silver-bullet.json" <<'EOF'
{
  "cursor_sb_agents": {
    "enabled": true,
    "selected_models": ["composer-2.5", "grok-4.6", "gpt-5.6-sol", "opus-5", "glm-5.2", "kimi-k3", "gemini-3.7-flash"],
    "effort_levels": ["high", "xhigh"],
    "agent_name_prefix": "sb"
  }
}
EOF

gate_json="$(SB_CURSOR_SB_AGENTS_SKIP_PROBE=1 python3 "$RESOLVER" --host cursor --json --project-root "$GATE_ROOT")"
assert_jq_true "GPT high subscription_first" \
  '[.rungs[] | select(.model=="gpt-5.6-sol" and .reasoning=="high") | .subscription_first] | .[0] == true' \
  "$gate_json"
assert_jq_true "GPT high invoke agent-codex" \
  '[.rungs[] | select(.model=="gpt-5.6-sol" and .reasoning=="high") | .subscription_invoke] | .[0] == "scripts/agent-codex/invoke.sh"' \
  "$gate_json"
assert_jq_true "Opus xhigh subscription_first Claude" \
  '[.rungs[] | select(.model=="opus-5" and .reasoning=="xhigh") | .subscription_host] | .[0] == "claude"' \
  "$gate_json"
assert_jq_true "Opus invoke agent-claude" \
  '[.rungs[] | select(.model=="opus-5") | .subscription_invoke] | unique | . == ["scripts/agent-claude/invoke.sh"]' \
  "$gate_json"
assert_jq_false "Composer skips subscription gate" \
  '[.rungs[] | select(.model=="composer-2.5") | .subscription_first] | any(. == true)' \
  "$gate_json"
assert_jq_false "Grok skips subscription gate" \
  '[.rungs[] | select(.model=="grok-4.6") | .subscription_first] | any(. == true)' \
  "$gate_json"
assert_jq_false "GLM skips subscription gate" \
  '[.rungs[] | select(.model=="glm-5.2") | .subscription_first] | any(. == true)' \
  "$gate_json"
assert_jq_false "Kimi skips subscription gate" \
  '[.rungs[] | select(.model=="kimi-k3") | .subscription_first] | any(. == true)' \
  "$gate_json"
assert_jq_false "Gemini skips subscription gate" \
  '[.rungs[] | select(.model=="gemini-3.7-flash") | .subscription_first] | any(. == true)' \
  "$gate_json"

gpt_plan="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning high)"
assert_jq_true "GPT decide-launch tries Codex first" \
  '.action == "invoke_subscription" and .subscription_host == "codex" and .subscription_skill == "silver-agent-codex"' \
  "$gpt_plan"

claude_plan="$(python3 "$RESOLVER" --decide-launch --model opus-5 --reasoning xhigh)"
assert_jq_true "Claude decide-launch tries Claude CLI first" \
  '.action == "invoke_subscription" and .subscription_host == "claude" and .subscription_invoke == "scripts/agent-claude/invoke.sh"' \
  "$claude_plan"

max_plan="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning max)"
assert_jq_true "GPT Max still subscription-first" \
  '.action == "invoke_subscription" and .reasoning == "max"' \
  "$max_plan"

reverify_plan="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning xhigh)"
assert_jq_true "GPT Extra High re-verify still subscription-first" \
  '.action == "invoke_subscription" and .reasoning == "xhigh"' \
  "$reverify_plan"

quota_plan="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning high --subscription-exit 1 --subscription-output 'HTTP 429 rate limit; quota retries exhausted')"
assert_jq_true "quota exhaustion allows Cursor fallback" \
  '.action == "cursor_fallback" and .reason == "quota-exhaustion" and .cursor_fallback == true and .quota_exhaustion == true' \
  "$quota_plan"

claude_quota="$(python3 "$RESOLVER" --decide-launch --model opus-5 --reasoning high --subscription-exit 1 --subscription-output 'Token Plan usage limit')"
assert_jq_true "Claude token-plan is quota fallback" \
  '.action == "cursor_fallback" and .reason == "quota-exhaustion" and .subscription_host == "claude"' \
  "$claude_quota"

missing_cli="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning high --subscription-exit 1 --subscription-output 'ERROR: native Codex CLI not found')"
assert_jq_true "missing CLI does not Cursor-fallback" \
  '.action == "fail" and .reason == "missing-cli" and .cursor_fallback == false' \
  "$missing_cli"

hash_mm="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning high --subscription-exit 1 --subscription-output 'ERROR: HASH MISMATCH on brief')"
assert_jq_true "HASH MISMATCH does not Cursor-fallback" \
  '.action == "fail" and .reason == "hash-mismatch" and .cursor_fallback == false' \
  "$hash_mm"

not_clean="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning high --subscription-exit 0 --subscription-output 'NOT CLEAN: leftover findings')"
assert_jq_true "NOT CLEAN success does not Cursor-fallback" \
  '.action == "accept_subscription" and .reason == "success" and .cursor_fallback == false' \
  "$not_clean"

network_fail="$(python3 "$RESOLVER" --decide-launch --model opus-5 --reasoning high --subscription-exit 1 --subscription-output 'ERROR: timed out waiting for Claude response')"
assert_jq_true "network timeout does not Cursor-fallback" \
  '.action == "fail" and .reason == "non-quota-failure" and .cursor_fallback == false' \
  "$network_fail"

other_plan="$(python3 "$RESOLVER" --decide-launch --model composer-2.5 --reasoning high)"
assert_jq_true "Composer decide-launch skips gate" \
  '.action == "cursor_task" and .subscription_first == false and (.subscription_invoke == null)' \
  "$other_plan"

grok_plan="$(python3 "$RESOLVER" --decide-launch --model grok-4.6 --reasoning xhigh)"
assert_jq_true "Grok decide-launch skips gate" \
  '.action == "cursor_task" and .subscription_first == false' \
  "$grok_plan"

assert_jq_true "Grok decide-launch default host is Cursor" \
  '.default_agent_route == "/sb:agent-cursor" and .preserves_host_mode == true' \
  "$grok_plan"
assert_jq_true "GPT decide-launch default host is Codex" \
  '.default_agent_host == "codex"' \
  "$gpt_plan"


if grep -qF 'Subscription-first (GPT / Claude)' "$SKILL" \
  && grep -qF 'scripts/agent-codex/invoke.sh' "$SKILL" \
  && grep -qF 'scripts/agent-claude/invoke.sh' "$SKILL" \
  && grep -qF 'Cursor `Task` **only** on quota exhaustion' "$SKILL"; then
  pass "SKILL documents subscription-first GPT/Claude routing"
else
  fail "SKILL documents subscription-first GPT/Claude routing"
fi
if grep -qF 'Subscription-First GPT and Claude Launch' "$SCENARIO" \
  && grep -qF '/sb:agent-codex' "$SCENARIO" \
  && grep -qF '**no** Cursor fallback' "$SCENARIO"; then
  pass "Skill scenario encodes subscription-first GPT/Claude launch"
else
  fail "Skill scenario encodes subscription-first GPT/Claude launch"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
