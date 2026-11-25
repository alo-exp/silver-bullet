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
  if jq -e "$filter" <<<"$json" >/dev/null; then
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

host_skip="$(python3 "$RESOLVER" --launch-policy --attempts 2 --outcome cannot_launch --policy-phase rung)"
assert_jq_true "attempt 2 skips and substitutes no model" \
  '.action == "skip" and .skipped == true and (has("substitute_model") | not)' \
  "$host_skip"

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

sub_art="$(python3 "$RESOLVER" --skip-artifact --rung-id 4 --next-rung 5 --attempts 2 --outcome cannot_launch --policy-phase rung)"
assert_jq_true "skip-artifact after retry is a plain skip" \
  '.action == "skip" and .skipped == true and (.skipped_md | startswith("# SKIPPED"))' \
  "$sub_art"

# --- mandatory launcher tables ---
steps="$(python3 "$RESOLVER" --launcher-steps)"
assert_jq_true "launcher mandatory steps include issue/triage/resolved/matrix" \
  '.steps == ["policy_c_artifact","issue_table","launcher_triage","triage_table","launcher_fix","resolved_table","issue_ledger_brief","ladder_complete_matrix"]' \
  "$steps"

issues_json='[{"id":"H1","severity":"HIGH","title":"broken lock"},{"id":"M1","severity":"MED","title":"missing table"},{"id":"L1","severity":"LOW","title":"typo"},{"id":"N1","severity":"NIT","title":"nitpick"}]'
issue_md="$(python3 "$RESOLVER" --issue-table --table-json "$issues_json")"
if grep -qF '### HIGH' <<<"$issue_md" \
  && grep -qF '### MED' <<<"$issue_md" \
  && grep -qF '### LOW' <<<"$issue_md" \
  && grep -qF '### NIT' <<<"$issue_md" \
  && grep -qF '| H1 | broken lock |' <<<"$issue_md"; then
  pass "issue table grouped by HIGH/MED/LOW/NIT"
else
  fail "issue table grouped by HIGH/MED/LOW/NIT"
  printf '%s\n' "$issue_md"
fi

triage_json='[{"id":"H1","severity":"HIGH","decision":"ACCEPT","reason":"valid"},{"id":"N1","severity":"NIT","decision":"REJECT","reason":"factually false"}]'
triage_md="$(python3 "$RESOLVER" --triage-table --table-json "$triage_json")"
if grep -qF '| Decision | Reason |' <<<"$triage_md" \
  && grep -qF '| H1 | HIGH | ACCEPT | valid |' <<<"$triage_md" \
  && grep -qF '| N1 | NIT | REJECT | factually false |' <<<"$triage_md"; then
  pass "triage table accepted vs rejected + reason"
else
  fail "triage table accepted vs rejected + reason"
  printf '%s\n' "$triage_md"
fi

resolved_json='[{"id":"H1","severity":"HIGH","title":"broken lock","decision":"ACCEPT","resolved":"yes"},{"id":"N1","severity":"NIT","title":"nitpick","decision":"REJECT","resolved":"n/a"}]'
resolved_md="$(python3 "$RESOLVER" --resolved-table --table-json "$resolved_json")"
if grep -qF '| Resolved |' <<<"$resolved_md" \
  && grep -qF '| H1 | HIGH | broken lock | ACCEPT | yes |' <<<"$resolved_md"; then
  pass "resolved table includes Resolved column"
else
  fail "resolved table includes Resolved column"
  printf '%s\n' "$resolved_md"
fi

matrix_json='[{"rung":"1","reviewer":"Composer 2.5 High","high":1,"med":1,"low":0,"nit":1,"reported":3,"accepted":2,"clean":false},{"rung":"2","reviewer":"Grok 4.6 High","high":0,"med":0,"low":0,"nit":0,"reported":0,"accepted":0,"clean":true},{"rung":"4","reviewer":"GLM 5.2 High","high":0,"med":0,"low":0,"nit":0,"reported":0,"accepted":0,"skipped_then_retried":true,"id_collision":true}]'
matrix_md="$(python3 "$RESOLVER" --ladder-matrix --table-json "$matrix_json")"
if grep -qF '| Rung | Reviewer | HIGH | MED | LOW | NIT | Reported | Accepted |' <<<"$matrix_md" \
  && grep -qF '| 1 | Composer 2.5 High | 1 | 1 | 0 | 1 | 3 | 2 |' <<<"$matrix_md" \
  && grep -qF 'skipped-then-retried' <<<"$matrix_md" \
  && grep -qF 'ID collision' <<<"$matrix_md" \
  && grep -qF 'CLEAN' <<<"$matrix_md"; then
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
  && grep -qF 'do not issue a reviewer ticket or spawn a reviewer subagent' "$SKILL" \
  && grep -qF 'RUNG-PROMPT-APPROVAL.md' "$SKILL" \
  && grep -qF 'approved: pending|yes' "$SKILL"; then
  pass "SKILL encodes Policy E rung-prompt user-approval gate"
else
  fail "SKILL encodes Policy E rung-prompt user-approval gate"
fi

# --- the old host routing / subscription flags are gone ---
for flag in --default-host-route --decide-launch --record-rung-review-outcome; do
  rc=0; python3 "$RESOLVER" "$flag" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$flag is rejected"; else fail "$flag is rejected (rc $rc)"; fi
done

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
