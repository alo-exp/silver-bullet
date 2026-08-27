#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
SKILL="${REPO_ROOT}/skills/silver-review-fix-ladder/SKILL.md"
SCENARIO="${REPO_ROOT}/tests/skill-scenarios/silver-review-fix-ladder.md"
COMMON="${REPO_ROOT}/scripts/lib/agent-delegate-common.sh"
HOOK="${REPO_ROOT}/hooks/rfl-quota-retry-due.sh"
HOOKS_JSON="${REPO_ROOT}/hooks/hooks.json"
export SB_RFL_TIMER_MODE=mock
export SB_RFL_NOTIFY=0
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

assert_file_exists "$RESOLVER" "review-fix-ladder.py exists"
assert_file_exists "${REPO_ROOT}/scripts/lib/rfl_quota_retry.py" "rfl_quota_retry.py exists"

NOW="2026-08-27T00:00:00Z"
classify() {
  python3 "$RESOLVER" --classify-quota-window --subscription-output "$1"
}

five="$(classify '[429]: 5-hour usage limit reached. Resets in 3hr 6min')"
assert_jq_true "5-hour OpenCode live shape classifies five_hour" \
  '.quota_class == "five_hour" and .should_schedule == true and .reset_seconds == 11160 and .reset_within_5h == true and .should_short_retry == false' \
  "$five"

reset_after="$(classify 'rate limit: reset after 59m 36s')"
assert_jq_true "reset after 59m 36s parses 3576s and is unknown quota" \
  '.quota_class == "unknown" and .reset_seconds == 3576 and .should_schedule == true and .reset_within_5h == true' \
  "$reset_after"

five_no_reset="$(classify '5-hour usage limit reached')"
assert_jq_true "5-hour without parsed reset still schedules default 5h" \
  '.quota_class == "five_hour" and .should_schedule == true and .schedule_delay_seconds == 18000 and .reset_seconds == null' \
  "$five_no_reset"

weekly_in="$(classify 'weekly limit reached. Resets in 3hr')"
assert_jq_true "weekly with reset ≤5h schedules" \
  '.quota_class == "weekly" and .should_schedule == true and .reset_seconds == 10800' \
  "$weekly_in"

weekly_out="$(classify 'weekly usage limit reached. Resets in 6hr')"
assert_jq_true "weekly with reset >5h does not schedule" \
  '.quota_class == "weekly" and .should_schedule == false and .reset_within_5h == false' \
  "$weekly_out"

monthly_in="$(classify 'monthly quota exhausted. Resets in 59m 36s')"
assert_jq_true "monthly with reset ≤5h schedules" \
  '.quota_class == "monthly" and .should_schedule == true' \
  "$monthly_in"

monthly_out="$(classify 'monthly limit reached. Resets in 2 days')"
assert_jq_true "monthly without parseable ≤5h reset does not schedule" \
  '.quota_class == "monthly" and .should_schedule == false' \
  "$monthly_out"

unknown_no="$(classify 'HTTP 429 rate limit; quota retries exhausted')"
assert_jq_true "unknown 429 without reset does not auto-schedule" \
  '.quota_class == "unknown" and .should_schedule == false and .should_short_retry == true' \
  "$unknown_no"

billing="$(classify 'Error: 401 insufficient balance')"
assert_jq_true "401 insufficient balance is billing not 5-hour" \
  '.quota_class == "billing" and .should_schedule == false and .should_short_retry == false' \
  "$billing"

billing_quota="$(classify '401 insufficient_quota: add credits')"
assert_jq_true "insufficient_quota billing does not schedule" \
  '.quota_class == "billing" and .should_schedule == false' \
  "$billing_quota"

mixed="$(classify '401 insufficient balance. 5-hour usage limit reached. Resets in 3hr 6min')"
assert_jq_true "401 plus clear 5-hour cap still classifies five_hour" \
  '.quota_class == "five_hour" and .should_schedule == true and .reset_seconds == 11160' \
  "$mixed"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/rfl-quota-retry.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
RUN_DIR="$WORKDIR/rfl-demo"
mkdir -p "$RUN_DIR"
BLOB='[429]: 5-hour usage limit reached. Resets in 3hr 6min'

sched="$(python3 "$RESOLVER" --schedule-quota-retry --run-dir "$RUN_DIR" --run-id rfl-demo \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "$NOW" --subscription-output "$BLOB")"
assert_jq_true "schedules 5-hour job with fire_at 3h6m later" \
  '.scheduled == true and .deduped == false and .job.status == "scheduled" and .job.fire_at == "2026-08-27T03:06:00Z" and .job.model == "opencode-go/glm-5.3"' \
  "$sched"
assert_jq_true "schedule arms a mock timer at fire_at" \
  '.armed == true and .timer.backend == "mock" and .timer.armed == true and (.timer.command | contains("--quota-retry-wake"))' \
  "$sched"

dup="$(python3 "$RESOLVER" --schedule-quota-retry --run-dir "$RUN_DIR" --run-id rfl-demo \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "$NOW" --subscription-output "$BLOB")"
assert_jq_true "duplicate run+rung+model does not stack" \
  '.deduped == true and .scheduled == true and .job.fire_at == "2026-08-27T03:06:00Z"' \
  "$dup"

job_count="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["jobs"]))' <"$RUN_DIR/quota-retry-schedule.json")"
[[ "$job_count" == "1" ]] && pass "schedule file has one job" || fail "schedule file has one job (got $job_count)"

python3 "$RESOLVER" --mark-ladder-status active --run-dir "$RUN_DIR" --quota-now "$NOW" >/dev/null
active="$(python3 "$RESOLVER" --activate-quota-retry --run-dir "$RUN_DIR" --run-id rfl-demo \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "2026-08-27T03:06:00Z")"
assert_jq_true "active ladder executes same-model retry" \
  '.action == "retry_rung" and .execute == true and .model == "opencode-go/glm-5.3" and .same_named_model == true and (.substitute_model == null)' \
  "$active"

# Fresh job for the over/ask path
RUN2="$WORKDIR/rfl-over"
mkdir -p "$RUN2"
python3 "$RESOLVER" --schedule-quota-retry --run-dir "$RUN2" --run-id rfl-over \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "$NOW" --subscription-output "$BLOB" >/dev/null
python3 "$RESOLVER" --mark-ladder-status completed --run-dir "$RUN2" --quota-now "$NOW" >/dev/null
ask="$(python3 "$RESOLVER" --activate-quota-retry --run-dir "$RUN2" --run-id rfl-over \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "2026-08-27T03:06:00Z" 2>"$WORKDIR/ask.err")"
assert_jq_true "completed ladder asks user and does not execute" \
  '.action == "ask_user" and .execute == false and (.ask | contains("already finished")) and (.ask | contains("rung-04"))' \
  "$ask"
if grep -q '\[rfl\] ASK:' "$WORKDIR/ask.err"; then
  pass "activation prints ASK on stderr for the host"
else
  fail "activation prints ASK on stderr for the host"
  cat "$WORKDIR/ask.err"
fi

aborted_dir="$WORKDIR/rfl-abort"
mkdir -p "$aborted_dir"
python3 "$RESOLVER" --schedule-quota-retry --run-dir "$aborted_dir" --run-id rfl-abort \
  --rung-id rung-01 --model gpt-5.6-sol --quota-now "$NOW" --subscription-output "$BLOB" >/dev/null
python3 "$RESOLVER" --mark-ladder-status aborted --run-dir "$aborted_dir" --quota-now "$NOW" >/dev/null
abort_ask="$(python3 "$RESOLVER" --activate-quota-retry --run-dir "$aborted_dir" --run-id rfl-abort \
  --rung-id rung-01 --model gpt-5.6-sol --quota-now "2026-08-27T03:06:00Z" 2>/dev/null)"
assert_jq_true "aborted ladder also asks instead of executing" \
  '.action == "ask_user" and .execute == false and .ladder_status == "aborted"' \
  "$abort_ask"

nosched="$(python3 "$RESOLVER" --schedule-quota-retry --run-dir "$RUN_DIR" --run-id rfl-demo \
  --rung-id rung-09 --model kimi-k3-max --quota-now "$NOW" \
  --subscription-output 'weekly limit reached. Resets in 12hr')"
assert_jq_true "weekly >5h does not write a job" \
  '.scheduled == false and .job == null' \
  "$nosched"

# Skill / scenario contract
if grep -qF -- '--schedule-quota-retry' "$SKILL" \
  && grep -qF -- '--quota-retry-wake' "$SKILL" \
  && grep -qF 'rfl-quota-retry-due.sh' "$SKILL" \
  && grep -qF 'QUOTA-RETRY-ASK.md' "$SKILL" \
  && grep -qF '5-hour usage cap' "$SKILL" \
  && grep -qF 'already over' "$SKILL"; then
  pass "SKILL documents timer wake and ladder-over ask"
else
  fail "SKILL documents timer wake and ladder-over ask"
fi
if grep -qF -- '--schedule-quota-retry' "$SCENARIO" \
  && grep -qF -- '--quota-retry-wake' "$SCENARIO" \
  && grep -qF 'ASK the user' "$SCENARIO"; then
  pass "Skill scenario encodes quota-window schedule + ask"
else
  fail "Skill scenario encodes quota-window schedule + ask"
fi
if grep -qF 'rfl-quota-retry-due.sh' "$HOOKS_JSON"; then
  pass "hooks.json registers rfl-quota-retry-due.sh"
else
  fail "hooks.json registers rfl-quota-retry-due.sh"
fi
assert_file_exists "$HOOK" "rfl-quota-retry-due.sh exists"

# Shared helper: 5-hour blobs block 60s retries
# shellcheck source=scripts/lib/agent-delegate-common.sh
source "$COMMON"
if agent_delegate_quota_blocks_short_retry '[429]: 5-hour usage limit reached. Resets in 3hr 6min'; then
  pass "5-hour blob blocks short quota retry"
else
  fail "5-hour blob blocks short quota retry"
fi
if agent_delegate_quota_blocks_short_retry 'HTTP 429 rate limit; quota retries exhausted'; then
  fail "transient unknown 429 still allows short retry"
else
  pass "transient unknown 429 still allows short retry"
fi

# --- Timer wake: due / not-due / ladder-over ---
PROJ="$WORKDIR/proj"
ACTIVE_DIR="$PROJ/.planning/rfl-wake-active"
OVER_DIR="$PROJ/.planning/rfl-wake-over"
FUTURE_DIR="$PROJ/.planning/rfl-wake-future"
mkdir -p "$ACTIVE_DIR" "$OVER_DIR" "$FUTURE_DIR"
printf '{}\n' >"$PROJ/.silver-bullet.json"
printf '# silver-bullet\n' >"$PROJ/silver-bullet.md"

python3 "$RESOLVER" --schedule-quota-retry --run-dir "$ACTIVE_DIR" --run-id rfl-wake-active \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "$NOW" --subscription-output "$BLOB" >/dev/null
python3 "$RESOLVER" --mark-ladder-status active --run-dir "$ACTIVE_DIR" --quota-now "$NOW" >/dev/null
python3 "$RESOLVER" --schedule-quota-retry --run-dir "$OVER_DIR" --run-id rfl-wake-over \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "$NOW" --subscription-output "$BLOB" >/dev/null
python3 "$RESOLVER" --mark-ladder-status completed --run-dir "$OVER_DIR" --quota-now "$NOW" >/dev/null
python3 "$RESOLVER" --schedule-quota-retry --run-dir "$FUTURE_DIR" --run-id rfl-wake-future \
  --rung-id rung-04 --model opencode-go/glm-5.3 --quota-now "$NOW" --subscription-output "$BLOB" >/dev/null
python3 "$RESOLVER" --mark-ladder-status active --run-dir "$FUTURE_DIR" --quota-now "$NOW" >/dev/null

not_due="$(python3 "$RESOLVER" --quota-retry-wake --run-dir "$FUTURE_DIR" --quota-now "$NOW")"
assert_jq_true "not-due wake does not activate" \
  '.results[0].action == "not_due" and .results[0].execute == false and (.user_visible | length) == 0 and (.hook_context // "") == ""' \
  "$not_due"
if [[ ! -f "$FUTURE_DIR/QUOTA-RETRY-EXECUTE.md" && ! -f "$FUTURE_DIR/QUOTA-RETRY-ASK.md" ]]; then
  pass "not-due wake writes no ASK/EXECUTE artifact"
else
  fail "not-due wake writes no ASK/EXECUTE artifact"
fi

due_active="$(python3 "$RESOLVER" --quota-retry-wake --run-dir "$ACTIVE_DIR" --quota-now "2026-08-27T03:06:00Z")"
assert_jq_true "due wake with active ladder executes same model" \
  '.results[0].action == "retry_rung" and .results[0].execute == true and .results[0].model == "opencode-go/glm-5.3" and (.executes | length) == 1' \
  "$due_active"
assert_file_exists "$ACTIVE_DIR/QUOTA-RETRY-EXECUTE.md" "due active wake writes EXECUTE artifact"
if [[ -f "$ACTIVE_DIR/QUOTA-RETRY-ASK.md" ]]; then
  fail "due active wake must not write ASK artifact"
else
  pass "due active wake must not write ASK artifact"
fi

due_over="$(python3 "$RESOLVER" --quota-retry-wake --run-dir "$OVER_DIR" --quota-now "2026-08-27T03:06:00Z" 2>"$WORKDIR/wake-ask.err")"
assert_jq_true "due wake with ladder over asks and does not execute" \
  '.results[0].action == "ask_user" and .results[0].execute == false and (.asks[0] | contains("already finished")) and (.hook_context | contains("user-visible ask"))' \
  "$due_over"
assert_file_exists "$OVER_DIR/QUOTA-RETRY-ASK.md" "ladder-over wake writes ASK.md"
if grep -q 'already finished' "$OVER_DIR/QUOTA-RETRY-ASK.md" \
  && grep -qF 'Do **not** execute' "$OVER_DIR/QUOTA-RETRY-ASK.md"; then
  pass "ASK.md is user-visible and forbids execute"
else
  fail "ASK.md is user-visible and forbids execute"
fi
if [[ -f "$OVER_DIR/QUOTA-RETRY-EXECUTE.md" ]]; then
  fail "ladder-over wake must not write EXECUTE artifact"
else
  pass "ladder-over wake must not write EXECUTE artifact"
fi
if grep -q '\[rfl\] ASK:' "$WORKDIR/wake-ask.err"; then
  pass "wake prints ASK on stderr"
else
  fail "wake prints ASK on stderr"
fi

# Hook: due over job injects additionalContext; not-due does not
export SB_RFL_RESOLVER="$RESOLVER"
# Isolated future-only project: SessionStart must stay quiet before fire_at
FUTURE_PROJ="$WORKDIR/future-only"
mkdir -p "$FUTURE_PROJ/.planning/rfl-future"
printf '{}\n' >"$FUTURE_PROJ/.silver-bullet.json"
printf '# silver-bullet\n' >"$FUTURE_PROJ/silver-bullet.md"
python3 "$RESOLVER" --schedule-quota-retry --run-dir "$FUTURE_PROJ/.planning/rfl-future" --run-id rfl-future \
  --rung-id rung-01 --model gpt-5.6-sol --quota-now "$NOW" --subscription-output "$BLOB" >/dev/null
not_due_hook="$(SB_RFL_PROJECT_ROOT="$FUTURE_PROJ" SB_RFL_QUOTA_NOW="$NOW" SB_RFL_HOOK_EVENT="SessionStart" \
  "$HOOK" <<<'{"hook_event_name":"SessionStart"}')"
if printf '%s' "$not_due_hook" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext // "") == ""' >/dev/null \
  && [[ ! -f "$FUTURE_PROJ/.planning/rfl-future/QUOTA-RETRY-EXECUTE.md" ]]; then
  pass "SessionStart hook stays quiet when jobs are not due"
else
  fail "SessionStart hook stays quiet when jobs are not due"
  printf '%s\n' "$not_due_hook"
fi

# ACK the already-executed active job so the project hook only resurfaces the ASK
printf 'acked\n' >"$ACTIVE_DIR/QUOTA-RETRY-ACK.md"
export SB_RFL_PROJECT_ROOT="$PROJ"
export SB_RFL_HOOK_EVENT="SessionStart"
due_hook="$(SB_RFL_QUOTA_NOW="2026-08-27T03:06:00Z" "$HOOK" <<<'{"hook_event_name":"SessionStart"}')"
if printf '%s' "$due_hook" | jq -e '.hookSpecificOutput.additionalContext | contains("user-visible ask") or contains("already finished")' >/dev/null; then
  pass "SessionStart hook injects ladder-over ask into additionalContext"
else
  fail "SessionStart hook injects ladder-over ask into additionalContext"
  printf '%s\n' "$due_hook"
fi
if printf '%s' "$due_hook" | jq -e '.hookSpecificOutput.additionalContext | contains("already finished")' >/dev/null \
  && ! printf '%s' "$due_hook" | jq -e '.hookSpecificOutput.additionalContext | contains("Execute rung")' >/dev/null; then
  pass "hook ask path does not also instruct execute"
else
  # Active dir already executed; hook may resurface EXECUTE.md unless ACK'd.
  # ACK the execute artifact so only ASK remains visible.
  if [[ -f "$ACTIVE_DIR/QUOTA-RETRY-EXECUTE.md" ]]; then
    printf 'acked\n' >"$ACTIVE_DIR/QUOTA-RETRY-ACK.md"
  fi
  due_hook2="$(SB_RFL_QUOTA_NOW="2026-08-27T03:06:00Z" "$HOOK" <<<'{"hook_event_name":"UserPromptSubmit"}')"
  if printf '%s' "$due_hook2" | jq -e '.hookSpecificOutput.additionalContext | contains("already finished")' >/dev/null \
    && ! printf '%s' "$due_hook2" | jq -e '.hookSpecificOutput.additionalContext | contains("Execute rung")' >/dev/null; then
    pass "hook ask path does not also instruct execute"
  else
    fail "hook ask path does not also instruct execute"
    printf '%s\n' "$due_hook2"
  fi
fi

# Isolated project: only a future job — hook must not activate
SOLO="$WORKDIR/solo"
mkdir -p "$SOLO/.planning/rfl-solo"
printf '{}\n' >"$SOLO/.silver-bullet.json"
printf '# silver-bullet\n' >"$SOLO/silver-bullet.md"
python3 "$RESOLVER" --schedule-quota-retry --run-dir "$SOLO/.planning/rfl-solo" --run-id rfl-solo \
  --rung-id rung-01 --model gpt-5.6-sol --quota-now "$NOW" --subscription-output "$BLOB" >/dev/null
solo_hook="$(SB_RFL_PROJECT_ROOT="$SOLO" SB_RFL_QUOTA_NOW="$NOW" SB_RFL_HOOK_EVENT="UserPromptSubmit" \
  "$HOOK" <<<'{"hook_event_name":"UserPromptSubmit"}')"
if printf '%s' "$solo_hook" | jq -e '(.hookSpecificOutput.additionalContext // "") == ""' >/dev/null \
  && [[ ! -f "$SOLO/.planning/rfl-solo/QUOTA-RETRY-EXECUTE.md" ]]; then
  pass "UserPromptSubmit hook does not activate a not-due job"
else
  fail "UserPromptSubmit hook does not activate a not-due job"
  printf '%s\n' "$solo_hook"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
