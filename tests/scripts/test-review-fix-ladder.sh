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
  if jq -e "$filter" <<<"$json" >/dev/null; then
    pass "$desc"
  else
    fail "$desc"
    printf '%s\n' "$json"
  fi
}

assert_jq_false() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" <<<"$json" >/dev/null; then
    fail "$desc"
    printf '%s\n' "$json"
  else
    pass "$desc"
  fi
}

assert_file_exists "$RESOLVER" "review-fix-ladder.py exists"

# --- native Claude ladder resolution ---
default_json="$(python3 "$RESOLVER" --json --host claude --project-root "$WORKDIR")"
assert_jq_true "default Claude ladder: latest tiers by alias, Haiku and Luna-style start at xhigh" \
  '[.rungs[] | "\(.model):\(.effort)"] == ["haiku:xhigh","sonnet:high","sonnet:xhigh","opus:low","opus:medium","opus:high"] and .enabled == true and .spawn_tool == "Agent"' \
  "$default_json"
assert_jq_false "Fable is never part of the ladder" '[.rungs[].model] | index("fable")' "$default_json"
assert_jq_false "no Sonnet low/medium/max and no Opus xhigh/max by default" \
  '[.rungs[] | select((.model == "sonnet" and (.effort == "low" or .effort == "medium" or .effort == "max")) or (.model == "opus" and (.effort == "xhigh" or .effort == "max")))] | length > 0' "$default_json"

override_json="$(python3 "$RESOLVER" --json --host claude --project-root "$WORKDIR" --rungs 'rungs: +opus:xhigh -haiku:xhigh')"
assert_jq_true "prompt override adds and removes rungs" \
  '[.rungs[] | "\(.model):\(.effort)"] == ["sonnet:high","sonnet:xhigh","opus:low","opus:medium","opus:high","opus:xhigh"] and .source == "config"' \
  "$override_json"

mkdir -p "$WORKDIR/proj"
printf '{"review_fix_ladder": {"rungs": ["sonnet:high", "opus:high"]}}\n' >"$WORKDIR/proj/.silver-bullet.json"
cfg_json="$(python3 "$RESOLVER" --json --host claude --project-root "$WORKDIR/proj")"
assert_jq_true ".silver-bullet.json review_fix_ladder.rungs replaces the defaults" \
  '[.rungs[] | .model] == ["sonnet","opus"] and .source == "config"' "$cfg_json"

codex_json="$(python3 "$RESOLVER" --json --host codex)"
assert_jq_true "Codex: the ladder is disabled with a clear message and documented defaults only" \
  '.enabled == false and .rungs == [] and (.message | contains("not yet verified on Codex")) and .documented_defaults.luna == ["xhigh"] and .documented_defaults.terra == ["high","xhigh"] and (.documented_defaults.excluded | index("astra") != null)' \
  "$codex_json"
rc=0; SILVER_BULLET_RUNTIME=codex python3 "$RESOLVER" --start --charter-file "$WORKDIR/none.json" --project-root "$WORKDIR" >/dev/null 2>"$WORKDIR/err" || rc=$?
if [[ "$rc" -eq 3 ]] && grep -q "not yet verified on Codex" "$WORKDIR/err"; then pass "Codex --start stops with the clear message"; else fail "Codex --start stops with the clear message (rc $rc)"; fi

for role in reviewer verifier; do
  agent="$REPO_ROOT/agents/sb-rfl-$role.md"
  if [[ -f "$agent" ]] && grep -qx "name: sb-rfl-$role" "$agent" && grep -qx 'tools: Read, Grep, Glob' "$agent" \
    && ! grep -qE '^tools:.*(Bash|Edit|Write|Agent|MultiEdit)' "$agent"; then
    pass "agents/sb-rfl-$role.md is read-only (Read, Grep, Glob; no shell, edit or spawn tools)"
  else
    fail "agents/sb-rfl-$role.md is read-only"
  fi
done
if jq -e 'has("agents") | not' "$REPO_ROOT/.claude-plugin/plugin.json" >/dev/null; then
  pass "plugin.json declares no agents field (default agent discovery; the Claude schema rejects it)"
else
  fail "plugin.json declares no agents field"
fi

for gone in --decide-launch --default-host-route --mark-quota-fallback --codex-home; do
  rc=0; python3 "$RESOLVER" "$gone" x >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$gone (Cursor / subscription-first / Codex cache) is gone"; else fail "$gone is gone (rc $rc)"; fi
done
if grep -rqiE 'cursor|subscription-first|grok|composer' "$REPO_ROOT/scripts/_review_fix_ladder_impl.py" "$REPO_ROOT/scripts/lib/rfl_native.py" "$REPO_ROOT/scripts/lib/rfl_hook.py" "$REPO_ROOT/scripts/lib/rfl_policy_c.py" "$REPO_ROOT/scripts/lib/rfl_launcher_policy.py" "$REPO_ROOT/scripts/lib/quota_window.py" "$REPO_ROOT/hooks/review-fix-ladder-guard.sh" "$REPO_ROOT/skills/silver-review-fix-ladder/SKILL.md" "$REPO_ROOT/agents/sb-rfl-reviewer.md" "$REPO_ROOT/agents/sb-rfl-verifier.md"; then
  fail "no Cursor / subscription-first / Grok wording in the RFL skill, impl or state libs"
else
  pass "no Cursor / subscription-first / Grok wording in the RFL skill, impl or state libs"
fi

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
if grep -qF "After each rung’s review, the agent that launched the RFL applies ACCEPT fixes" "$SKILL" \
  || grep -qF "After each rung's review, the agent that launched the RFL applies ACCEPT fixes" "$SKILL"; then
  pass "SKILL Policy B: launcher applies ACCEPT fixes"
else
  fail "SKILL Policy B: launcher applies ACCEPT fixes"
fi
if grep -qF 'The rung subagent does not implement' "$SKILL"; then
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
if grep -qF 'Not in the default ladder: Sonnet low/medium/max, Opus xhigh/max' "$SKILL"; then
  pass "SKILL documents the excluded efforts"
else
  fail "SKILL documents the excluded efforts"
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
  && grep -qF 'two consecutive captured review passes' "$SKILL" \
  && grep -qF 'consecutive_clean_reviews == 2' "$SKILL" \
  && grep -qF -- '--assert-consecutive-clean' "$SKILL" \
  && grep -qF 'there is no command to record it by hand' "$SKILL" \
  && grep -qF 'Do **not** start the next ladder model until' "$SKILL"; then
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
  && grep -qF 'issue ledger' "$SKILL" \
  && grep -qF 'as a pack' "$SKILL" \
  && grep -qF 'only legal review brief' "$SKILL"; then
  pass "SKILL Policy G: pack-ledger hop review, all severities"
else
  fail "SKILL Policy G: pack-ledger hop review, all severities"
fi
if grep -qF 'Policy map (A–G)' "$SKILL" \
  && grep -qF 'Canonical verify overlay (HARD)' "$SKILL" \
  && grep -qF '`verify_1` runs **every cycle**' "$SKILL" \
  && grep -qF '`verify_2` runs once the streak is 2' "$SKILL"; then
  pass "SKILL A–G map + canonical verify overlay"
else
  fail "SKILL A–G map + canonical verify overlay"
fi
if grep -qF '### Policy E — rung-prompt user-approval (HARD)' "$SKILL" \
  && grep -qF 'concise bullet list of only the key tasks and instructions' "$SKILL" \
  && grep -qF 'Do **not** dump the entire prompt' "$SKILL" \
  && grep -qF 'Until approved:' "$SKILL" \
  && grep -qF 'do not issue a reviewer ticket or spawn a reviewer subagent' "$SKILL" \
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
if grep -qF 'The rung subagent does not implement' "$WORKER" \
  && grep -qF 'Forbidden reject reasons' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes RFL triage and fix-owner policy"
else
  fail "REVIEW-TRIAGE worker encodes RFL triage and fix-owner policy"
fi
if grep -qF 'APPLY ACCEPT completeness (HARD)' "$WORKER" \
  && grep -qF 'Low, deferred, nitpicks, and minor' "$WORKER" \
  && grep -qF 'the launcher applying fixes is an explicit exception' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes APPLY ACCEPT lands all non-wrong nits"
else
  fail "REVIEW-TRIAGE worker encodes APPLY ACCEPT lands all non-wrong nits"
fi
if grep -qF 'Policy C — launcher reports after every rung' "$WORKER" \
  && grep -qF 'the launcher must message the user with a severity-grouped update' "$WORKER" \
  && grep -qF 'after each rung' "$WORKER" \
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
  && grep -qF 'Until approved: do not issue a ticket or spawn a reviewer' "$WORKER" \
  && grep -qF -- '--approve' "$WORKER"; then
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
  && grep -qF 'Until approved: do not issue a ticket or spawn a reviewer' "$SCENARIO" \
  && grep -qF 'RUNG-PROMPT-APPROVAL.md' "$SCENARIO" \
  && grep -qF -- '--approve' "$SCENARIO" \
  && grep -qF 'materially change' "$SCENARIO"; then
  pass "Skill scenario encodes Policy E rung-prompt user-approval"
else
  fail "Skill scenario encodes Policy E rung-prompt user-approval"
fi

if grep -qF 'Anti-stall (Policy B leftover loop — HARD)' "$SKILL" \
  && grep -qF 'Corpus sweep, not one-line cycles' "$SKILL" \
  && grep -qF '**Quota and rate limits:**' "$SKILL" \
  && grep -qF 'Nothing is scheduled and no timer is armed' "$SKILL" \
  && grep -qF 'Cap residual loops' "$SKILL"; then
  pass "SKILL encodes anti-stall leftover loop"
else
  fail "SKILL encodes anti-stall leftover loop"
fi
if grep -qF 'Launch/timeout retry then skip (HARD)' "$SKILL" \
  && grep -qF 'After **2** failed attempts' "$SKILL" \
  && grep -qF 'SKIPPED.md' "$SKILL" \
  && grep -qF 'failed to produce a verdict' "$SKILL" \
  && grep -qF 'Do **not** skip because of a CLEAN/NOT CLEAN review' "$SKILL" \
  && grep -qF 'never a substitution' "$SKILL" \
  && grep -qF '**Never Fast.**' "$SKILL" \
  && grep -qF 'each skipped rung is retried once more' "$SKILL" \
  && grep -qF 'or after a recorded two-attempt skip' "$SKILL"; then
  pass "SKILL encodes launch retry-then-skip"
else
  fail "SKILL encodes launch retry-then-skip"
fi
if grep -qF 'Anti-Stall leftover loop (Policy B)' "$SCENARIO" \
  && grep -qF 'Corpus sweep, not one-line cycles' "$SCENARIO" \
  && grep -qF 'Cap residual loops' "$SCENARIO"; then
  pass "Skill scenario encodes anti-stall leftover loop"
else
  fail "Skill scenario encodes anti-stall leftover loop"
fi
if grep -qF 'Skip after two failed attempts' "$SCENARIO" \
  && grep -qF 'SKIPPED.md' "$SCENARIO" \
  && grep -qF 'RFL ABORT <run-id>' "$SCENARIO" \
  && grep -qF 'Never substitute another model or vendor' "$SCENARIO" \
  && grep -qF 'not caused by a CLEAN/NOT CLEAN review' "$SCENARIO" \
  && grep -qF 'each skipped rung is retried once more' "$SCENARIO"; then
  pass "Skill scenario encodes the skip policy"
else
  fail "Skill scenario encodes the skip policy"
fi
if grep -qF 'Corpus sweep' "$WORKER" || grep -qF 'Anti-stall' "$WORKER"; then
  pass "REVIEW-TRIAGE worker mentions the anti-stall loop"
else
  fail "REVIEW-TRIAGE worker mentions the anti-stall loop"
fi
if grep -qF 'two failed attempts on a phase are recorded as `SKIPPED.md`' "$WORKER" \
  && grep -qF 'skipped rungs are retried once after the ladder' "$WORKER" \
  && grep -qF 'a quota response pauses the run' "$WORKER" \
  && grep -qF 'RFL ABORT <run-id>' "$WORKER" \
  && grep -qF 'untrusted data' "$WORKER"; then
  pass "REVIEW-TRIAGE worker encodes the skip, pause, abort and untrusted-data rules"
else
  fail "REVIEW-TRIAGE worker encodes the skip, pause, abort and untrusted-data rules"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
