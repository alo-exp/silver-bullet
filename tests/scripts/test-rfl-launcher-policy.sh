#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
POLICY="${REPO_ROOT}/scripts/lib/rfl_launcher_policy.py"
SKILL="${REPO_ROOT}/skills/silver-review-fix-ladder/SKILL.md"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

assert_jq_true() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    pass "$desc"
  else
    fail "$desc"
    printf '%s\n' "$json"
  fi
}

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_file_exists "$RESOLVER" "review-fix-ladder.py shim exists"
assert_file_exists "$POLICY" "rfl_launcher_policy.py exists"
assert_file_exists "$SKILL" "review-fix-ladder SKILL.md exists"

# --- launch/timeout: retry once → skip → post-ladder retry ---
timeout1="$(python3 "$RESOLVER" --launch-policy --attempts 1 --outcome timeout --policy-phase rung)"
assert_jq_true "timeout attempt 1 retries immediately" \
  '.action == "retry_immediate" and .retry == true and .skipped == false and .retry_kind == "immediate"' \
  "$timeout1"

timeout2="$(python3 "$RESOLVER" --launch-policy --attempts 2 --outcome timeout --policy-phase rung)"
assert_jq_true "timeout attempt 2 skips and queues post-ladder retry" \
  '.action == "skip" and .skipped == true and .post_ladder_retry_pending == true' \
  "$timeout2"

launch1="$(python3 "$RESOLVER" --launch-policy --attempts 1 --outcome cannot_launch --policy-phase rung)"
assert_jq_true "cannot_launch attempt 1 retries immediately" \
  '.action == "retry_immediate" and .outcome == "cannot_launch"' \
  "$launch1"

launch2="$(python3 "$RESOLVER" --launch-policy --attempts 2 --outcome cannot_launch --policy-phase rung)"
assert_jq_true "cannot_launch attempt 2 skips" \
  '.action == "skip" and .skipped == true' \
  "$launch2"

oc401="$(python3 "$RESOLVER" --launch-policy --attempts 2 --outcome cannot_launch --policy-phase rung --host opencode)"
assert_jq_true "OpenCode cannot_launch attempt 2 substitutes Grok 4.6 High" \
  '.action == "substitute_grok" and .skipped == false and .substitute_model == "cursor-grok-4.6-high" and .substitute_host == "cursor" and .failed_host == "opencode"' \
  "$oc401"

pi401="$(python3 "$RESOLVER" --launch-policy --attempts 2 --outcome cannot_launch --policy-phase rung --host pi)"
assert_jq_true "Pi cannot_launch attempt 2 substitutes Grok 4.6 High" \
  '.action == "substitute_grok" and .skipped == false and .substitute_model == "cursor-grok-4.6-high" and .failed_host == "pi"' \
  "$pi401"

cursor_skip="$(python3 "$RESOLVER" --launch-policy --attempts 2 --outcome timeout --policy-phase rung --host cursor)"
assert_jq_true "Cursor timeout attempt 2 still skips" \
  '.action == "skip" and .skipped == true' \
  "$cursor_skip"

post_ok="$(python3 "$RESOLVER" --launch-policy --attempts 1 --outcome success --policy-phase post_ladder)"
assert_jq_true "post-ladder success recovers skipped rung" \
  '.action == "recovered" and .skipped == false and .post_ladder_retry_done == true' \
  "$post_ok"

post_fail="$(python3 "$RESOLVER" --launch-policy --attempts 1 --outcome timeout --policy-phase post_ladder)"
assert_jq_true "post-ladder timeout remains skipped" \
  '.action == "remain_skipped" and .skipped == true and .post_ladder_retry_done == true and .post_ladder_retry_pending == false' \
  "$post_fail"

skip_art="$(python3 "$RESOLVER" --skip-artifact --rung-id 4 --next-rung 5 --attempts 2 --outcome timeout --policy-phase rung)"
assert_jq_true "skip artifact records retry/skip for launcher" \
  '.skipped == true and .post_ladder_retry_pending == true and (.skipped_md | contains("SKIPPED"))' \
  "$skip_art"

sub_art="$(python3 "$RESOLVER" --skip-artifact --rung-id 4 --next-rung 5 --attempts 2 --outcome cannot_launch --policy-phase rung --host opencode)"
assert_jq_true "OpenCode skip-artifact after retry records Grok substitute" \
  '.action == "substitute_grok" and .skipped == false and (.skipped_md | contains("SUBSTITUTE GROK")) and (.skipped_md | contains("cursor-grok-4.6-high"))' \
  "$sub_art"

# --- mandatory launcher tables ---
steps="$(python3 "$RESOLVER" --launcher-steps)"
assert_jq_true "launcher mandatory steps include issue/triage/resolved/matrix" \
  '.steps == ["policy_c_artifact","issue_table","launcher_triage","triage_table","launcher_fix","resolved_table","issue_ledger_brief","ladder_complete_matrix"]' \
  "$steps"

issues_json='[{"id":"H1","severity":"HIGH","title":"broken lock"},{"id":"M1","severity":"MED","title":"missing table"},{"id":"L1","severity":"LOW","title":"typo"},{"id":"N1","severity":"NIT","title":"nitpick"}]'
issue_md="$(python3 "$RESOLVER" --issue-table --table-json "$issues_json")"
if printf '%s' "$issue_md" | grep -qF '### HIGH' \
  && printf '%s' "$issue_md" | grep -qF '### MED' \
  && printf '%s' "$issue_md" | grep -qF '### LOW' \
  && printf '%s' "$issue_md" | grep -qF '### NIT' \
  && printf '%s' "$issue_md" | grep -qF '| H1 | broken lock |'; then
  pass "issue table grouped by HIGH/MED/LOW/NIT"
else
  fail "issue table grouped by HIGH/MED/LOW/NIT"
  printf '%s\n' "$issue_md"
fi

triage_json='[{"id":"H1","severity":"HIGH","decision":"ACCEPT","reason":"valid"},{"id":"N1","severity":"NIT","decision":"REJECT","reason":"factually false"}]'
triage_md="$(python3 "$RESOLVER" --triage-table --table-json "$triage_json")"
if printf '%s' "$triage_md" | grep -qF '| Decision | Reason |' \
  && printf '%s' "$triage_md" | grep -qF '| H1 | HIGH | ACCEPT | valid |' \
  && printf '%s' "$triage_md" | grep -qF '| N1 | NIT | REJECT | factually false |'; then
  pass "triage table accepted vs rejected + reason"
else
  fail "triage table accepted vs rejected + reason"
  printf '%s\n' "$triage_md"
fi

resolved_json='[{"id":"H1","severity":"HIGH","title":"broken lock","decision":"ACCEPT","resolved":"yes"},{"id":"N1","severity":"NIT","title":"nitpick","decision":"REJECT","resolved":"n/a"}]'
resolved_md="$(python3 "$RESOLVER" --resolved-table --table-json "$resolved_json")"
if printf '%s' "$resolved_md" | grep -qF '| Resolved |' \
  && printf '%s' "$resolved_md" | grep -qF '| H1 | HIGH | broken lock | ACCEPT | yes |'; then
  pass "resolved table includes Resolved column"
else
  fail "resolved table includes Resolved column"
  printf '%s\n' "$resolved_md"
fi

matrix_json='[{"rung":"1","reviewer":"Composer 2.5 High","high":1,"med":1,"low":0,"nit":1,"reported":3,"accepted":2,"clean":false},{"rung":"2","reviewer":"Grok 4.6 High","high":0,"med":0,"low":0,"nit":0,"reported":0,"accepted":0,"clean":true},{"rung":"4","reviewer":"GLM 5.2 High","high":0,"med":0,"low":0,"nit":0,"reported":0,"accepted":0,"skipped_then_retried":true,"id_collision":true}]'
matrix_md="$(python3 "$RESOLVER" --ladder-matrix --table-json "$matrix_json")"
if printf '%s' "$matrix_md" | grep -qF '| Rung | Reviewer | HIGH | MED | LOW | NIT | Reported | Accepted |' \
  && printf '%s' "$matrix_md" | grep -qF '| 1 | Composer 2.5 High | 1 | 1 | 0 | 1 | 3 | 2 |' \
  && printf '%s' "$matrix_md" | grep -qF 'skipped-then-retried' \
  && printf '%s' "$matrix_md" | grep -qF 'ID collision' \
  && printf '%s' "$matrix_md" | grep -qF 'CLEAN'; then
  pass "ladder-complete matrix with footnotes"
else
  fail "ladder-complete matrix with footnotes"
  printf '%s\n' "$matrix_md"
fi

two_rung_json='[{"rung":"1","reviewer":"Composer 2.5 High","high":1,"med":2,"low":3,"nit":4,"reported":10,"accepted":5},{"rung":"2","reviewer":"Grok 4.6 High","high":2,"med":0,"low":1,"nit":1,"reported":4,"accepted":3}]'
two_md="$(python3 "$RESOLVER" --ladder-matrix --table-json "$two_rung_json")"
last_row="$(printf '%s\n' "$two_md" | grep '^|' | tail -1)"
if [[ "$last_row" == "| TOTAL | — | 3 | 2 | 4 | 5 | 14 | 8 |" ]]; then
  pass "2-rung ladder-complete matrix ends with TOTAL sums"
else
  fail "2-rung ladder-complete matrix ends with TOTAL sums"
  printf 'last_row=%s\n%s\n' "$last_row" "$two_md"
fi

if grep -qF 'These launcher steps are **mandatory**' "$SKILL" \
  && grep -qF 'table grouped by severity' "$SKILL" \
  && grep -qF '**triage table**' "$SKILL" \
  && grep -qF '**Resolved** column' "$SKILL" \
  && grep -qF '### Policy D — ladder-complete matrix (HARD)' "$SKILL" \
  && grep -qF 'Last row MUST be **TOTAL**' "$SKILL"; then
  pass "SKILL encodes mandatory launcher tables + complete matrix"
else
  fail "SKILL encodes mandatory launcher tables + complete matrix"
fi
if grep -qF '### Policy F — two consecutive CLEAN reviews per rung (HARD)' "$SKILL" \
  && grep -qF 'consecutive_clean_reviews == 2' "$SKILL" \
  && grep -qF -- '--assert-consecutive-clean' "$SKILL"; then
  pass "SKILL encodes Policy F two consecutive CLEAN reviews"
else
  fail "SKILL encodes Policy F two consecutive CLEAN reviews"
fi
if grep -qF '### Policy G — hop review (pack-ledger) (HARD)' "$SKILL" \
  && grep -qF 'do not re-report ledger rows' "$SKILL" \
  && grep -qF 'all severities' "$SKILL" \
  && grep -qF -- '--issue-ledger' "$SKILL" \
  && grep -qF -- '--write-review-brief' "$SKILL" \
  && grep -qF 'as a pack' "$SKILL" \
  && grep -qF 'only legal review brief' "$SKILL"; then
  pass "SKILL encodes Policy G pack-ledger hop review"
else
  fail "SKILL encodes Policy G pack-ledger hop review"
fi
if grep -qF '### Policy E — rung-prompt user-approval (HARD)' "$SKILL" \
  && grep -qF 'concise bullet list of only the key tasks and instructions' "$SKILL" \
  && grep -qF 'Do **not** dump the entire prompt' "$SKILL" \
  && grep -qF 'Until approved:' "$SKILL" \
  && grep -qF 'do not spawn reviewer Tasks / Pi invoke' "$SKILL" \
  && grep -qF 'RUNG-PROMPT-APPROVAL.md' "$SKILL" \
  && grep -qF 'approved: pending|yes' "$SKILL"; then
  pass "SKILL encodes Policy E rung-prompt user-approval gate"
else
  fail "SKILL encodes Policy E rung-prompt user-approval gate"
fi

# --- default host routing matrix (user override wins) ---
grok_host="$(python3 "$RESOLVER" --default-host-route --model grok-4.6)"
assert_jq_true "Grok defaults to /sb:agent-cursor" \
  '.host == "cursor" and .route == "/sb:agent-cursor" and .family == "grok" and .preserves_host_mode == true' \
  "$grok_host"

composer_host="$(python3 "$RESOLVER" --default-host-route --model composer-2.5)"
assert_jq_true "Composer defaults to /sb:agent-cursor" \
  '.host == "cursor" and .skill == "silver-agent-cursor" and .family == "composer"' \
  "$composer_host"

gpt_host="$(python3 "$RESOLVER" --default-host-route --model gpt-5.6-sol)"
assert_jq_true "GPT defaults to Codex" \
  '.host == "codex" and .route == "/sb:agent-codex" and .family == "gpt"' \
  "$gpt_host"

claude_host="$(python3 "$RESOLVER" --default-host-route --model opus-5)"
assert_jq_true "Claude defaults to /sb:agent-claude" \
  '.host == "claude" and .route == "/sb:agent-claude" and .family == "claude"' \
  "$claude_host"

gemini_host="$(python3 "$RESOLVER" --default-host-route --model gemini-3.7-flash)"
assert_jq_true "Gemini defaults to Gemini CLI when unnamed" \
  '.host == "gemini-cli" and .source == "gemini_cascade" and .family == "gemini"' \
  "$gemini_host"

gemini_no_cli="$(python3 "$RESOLVER" --default-host-route --model gemini-3.7-flash --available-hosts pi,opencode,cursor,codex,claude)"
assert_jq_true "Gemini cascade falls to Pi when Gemini CLI absent" \
  '.host == "pi" and .route == "/sb:agent-pi"' \
  "$gemini_no_cli"

other_host="$(python3 "$RESOLVER" --default-host-route --model glm-5.2)"
assert_jq_true "Other models default to Pi" \
  '.host == "pi" and .family == "other" and .route == "/sb:agent-pi"' \
  "$other_host"

override="$(python3 "$RESOLVER" --default-host-route --model grok-4.6 --user-agent /sb:agent-pi)"
assert_jq_true "user override wins over Grok→Cursor default" \
  '.host == "pi" and .user_override == true and .source == "user_override"' \
  "$override"

gpt_override="$(python3 "$RESOLVER" --default-host-route --model gpt-5.6-sol --user-agent cursor)"
assert_jq_true "user override can move GPT off Codex" \
  '.host == "cursor" and .user_override == true' \
  "$gpt_override"

named="$(python3 "$RESOLVER" --default-host-route --model glm-5.2 --user-agent windsurf)"
assert_jq_true "named external agent wins for other models" \
  '.host == "windsurf" and .user_override == true' \
  "$named"

decide_grok="$(python3 "$RESOLVER" --decide-launch --model grok-4.6 --reasoning high)"
assert_jq_true "decide-launch attaches Cursor default host without remapping GPT/Claude" \
  '.action == "cursor_task" and .default_agent_route == "/sb:agent-cursor" and .preserves_host_mode == true' \
  "$decide_grok"

decide_gpt="$(python3 "$RESOLVER" --decide-launch --model gpt-5.6-sol --reasoning high)"
assert_jq_true "GPT decide-launch stays Codex, not Grok High" \
  '.action == "invoke_subscription" and .subscription_host == "codex" and .default_agent_host == "codex"' \
  "$decide_gpt"

if grep -qF '/sb:agent-cursor' "$SKILL" \
  && grep -qF 'Do **not** smash host `--mode`' "$SKILL" \
  && grep -qF 'Do **not** remap RFL GPT/Claude rungs onto Grok High' "$SKILL" \
  && grep -qF -- '--default-host-route' "$SKILL"; then
  pass "SKILL encodes default host routing matrix"
else
  fail "SKILL encodes default host routing matrix"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
