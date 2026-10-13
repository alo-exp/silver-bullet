#!/usr/bin/env bash
# Claude/Anthropic 5-hour quota: classify, schedule, invoke wrapper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
INVOKE="${REPO_ROOT}/scripts/agent-pi/invoke.sh"
HOST_EXEC="${REPO_ROOT}/scripts/lib/agent-host-exec.sh"
QUOTA_SH="${REPO_ROOT}/scripts/lib/agent-pi-quota-retry.sh"
FIXTURES="${REPO_ROOT}/tests/fixtures/quota"
export SB_RFL_TIMER_MODE=mock
export SB_RFL_NOTIFY=0
unset SB_RFL_QUOTA_HOST SB_RFL_QUOTA_WAKE_AT SB_RFL_MODEL 2>/dev/null || true
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

classify_file() {
  python3 "$RESOLVER" --classify-quota-window "$@"
}

# --- classify: Console remaining time is 5h and schedules ---
console="$(classify_file --quota-host claude --model claude/claude-opus-5-high \
  --subscription-output-file "${FIXTURES}/claude-5h-console.txt")"
assert_jq_true "Claude Console 2h32m classifies five_hour and schedules" \
  '.quota_class == "five_hour" and .should_schedule == true and .reset_seconds == 9120 and .should_short_retry == false' \
  "$console"

# --- classify: Omni 429 + retry_after + Claude host → 5h ---
omni="$(classify_file --quota-host claude --model claude/claude-opus-5-high \
  --subscription-output-file "${FIXTURES}/omni-rate-limit-error.json")"
assert_jq_true "Omni rate_limit_error with retry_after is five_hour" \
  '.quota_class == "five_hour" and .should_schedule == true and .reset_seconds == 9120' \
  "$omni"

# --- classify: generic 429 on Claude is 5h (not unknown) ---
generic="$(classify_file --quota-host claude --model claude/claude-opus-5-high \
  --subscription-output-file "${FIXTURES}/claude-generic-429.txt")"
assert_jq_true "Claude generic 429 classifies five_hour and schedules" \
  '.quota_class == "five_hour" and .should_schedule == true and .should_short_retry == false' \
  "$generic"

# --- classify: same generic 429 without Claude host stays unknown ---
unknown="$(classify_file --subscription-output-file "${FIXTURES}/claude-generic-429.txt")"
assert_jq_true "generic 429 without Claude host stays unknown (no auto 5h)" \
  '.quota_class == "unknown" and .should_schedule == false' \
  "$unknown"

# --- classify: weekly does not become 5h even with Claude host ---
weekly="$(classify_file --quota-host claude --model claude/claude-opus-5-high \
  --subscription-output-file "${FIXTURES}/weekly-limit.txt")"
assert_jq_true "weekly on Claude host stays weekly and does not use 5h default" \
  '.quota_class == "weekly" and .should_schedule == false' \
  "$weekly"

# --- schedule: persist wake_at / reset_at; idempotent ---
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-pi-quota.XXXXXX")"
RUN_DIR="${WORKDIR}/rfl-demo"
mkdir -p "$RUN_DIR"
NOW="2026-08-28T13:09:00Z"
WAKE="2026-08-28T15:41:00Z"
BLOB='Claude 5-hour quota has been exhausted. Resets in 2hr 32min'
sched="$(python3 "$RESOLVER" --schedule-quota-retry --run-dir "$RUN_DIR" \
  --run-id rfl-demo --rung-id rung-10 --model claude/claude-opus-5-high \
  --quota-host claude --quota-now "$NOW" --subscription-output "$BLOB")"
assert_jq_true "schedules 5h job with wake_at 15:41Z from 2h32m remaining" \
  '.scheduled == true and .quota_class == "five_hour" and .job.fire_at == "2026-08-28T15:41:00Z" and .job.wake_at == "2026-08-28T15:41:00Z" and .job.reset_at == "2026-08-28T15:41:00Z"' \
  "$sched"

dup="$(python3 "$RESOLVER" --schedule-quota-retry --run-dir "$RUN_DIR" \
  --run-id rfl-demo --rung-id rung-10 --model claude/claude-opus-5-high \
  --quota-host claude --quota-now "$NOW" --subscription-output "$BLOB")"
assert_jq_true "second schedule is idempotent" \
  '.deduped == true and .scheduled == true and .job.wake_at == "2026-08-28T15:41:00Z"' \
  "$dup"

weekly_sched="$(python3 "$RESOLVER" --schedule-quota-retry --run-dir "$RUN_DIR" \
  --run-id rfl-demo --rung-id rung-09 --model claude/claude-opus-5-high \
  --quota-host claude --quota-now "$NOW" \
  --subscription-output-file "${FIXTURES}/weekly-limit.txt")"
assert_jq_true "weekly does not write a 5h job" \
  '.scheduled == false and .quota_class == "weekly" and .job == null' \
  "$weekly_sched"

# --- wrapper: invoke.sh schedules on fixture stderr; 124 does not ---
# shellcheck source=scripts/lib/agent-host-exec.sh
source "$HOST_EXEC"
# shellcheck source=scripts/lib/agent-pi-quota-retry.sh
source "$QUOTA_SH"

WRAP_RUN="${WORKDIR}/rfl-wrap"
WRAP_RUNG="${WRAP_RUN}/rung-10-claude-opus-5-high"
mkdir -p "$WRAP_RUNG"
export SB_RFL_RUN_DIR="$WRAP_RUN"
export SB_RFL_RUN_ID="rfl-wrap"
export SB_RFL_RUNG_ID="rung-10"
export SB_RFL_QUOTA_HOST="claude"
export PI_MODEL="claude/claude-opus-5-high"
export WORK_DIR="$WRAP_RUNG"

wrap_out="$(mktemp "${TMPDIR:-/tmp}/quota-wrap-XXXXXX")"
agent_host_pi_maybe_schedule_quota_retry 1 "$(cat "${FIXTURES}/claude-5h-console.txt")" \
  >"$wrap_out" 2>&1 || true
if grep -qE '\[agent-pi\] quota 5h; retry at 20[0-9]{2}-' "$wrap_out"; then
  pass "wrapper prints greppable quota 5h retry line"
else
  fail "wrapper prints greppable quota 5h retry line"
  cat "$wrap_out"
fi
if [[ -f "${WRAP_RUN}/quota-retry-schedule.json" ]]; then
  pass "wrapper wrote quota-retry-schedule.json under run-dir"
else
  fail "wrapper wrote quota-retry-schedule.json under run-dir"
fi

hang_run="${WORKDIR}/rfl-hang"
mkdir -p "$hang_run"
export SB_RFL_RUN_DIR="$hang_run"
hang_out="$(mktemp "${TMPDIR:-/tmp}/quota-hang-XXXXXX")"
agent_host_pi_maybe_schedule_quota_retry 124 "$(cat "${FIXTURES}/idle-124.txt")" \
  >"$hang_out" 2>&1 || true
if grep -q 'quota 5h' "$hang_out"; then
  fail "EXIT 124 hang does not schedule 5h retry"
  cat "$hang_out"
else
  pass "EXIT 124 hang does not schedule 5h retry"
fi
if [[ -f "${hang_run}/quota-retry-schedule.json" ]]; then
  fail "EXIT 124 does not write a schedule file"
else
  pass "EXIT 124 does not write a schedule file"
fi

# invoke.sh end-to-end with a fake delegate
FAKE="$(mktemp "${TMPDIR:-/tmp}/fake-pi-XXXXXX")"
chmod +x "$FAKE"
cat >"$FAKE" <<'EOF'
#!/usr/bin/env bash
cat >&2 <<'QUOTA'
HTTP 429 rate_limit_error: 5-hour usage limit reached. Resets in 2hr 32min
QUOTA
exit 1
EOF
INV_RUN="${WORKDIR}/rfl-invoke"
INV_RUNG="${INV_RUN}/rung-10-claude-opus-5-high"
mkdir -p "$INV_RUNG"
export SB_AGENT_PI_DELEGATE="$FAKE"
export SB_RFL_RUN_DIR="$INV_RUN"
export SB_RFL_RUN_ID="rfl-invoke"
export SB_RFL_RUNG_ID="rung-10"
export SB_RFL_QUOTA_HOST="claude"
export PI_MODEL="claude/claude-opus-5-high"
inv_out="$(mktemp "${TMPDIR:-/tmp}/quota-inv-XXXXXX")"
set +e
bash "$INVOKE" --work-dir "$INV_RUNG" --prompt "noop" >"$inv_out" 2>&1
inv_rc=$?
set -e
[[ "$inv_rc" -eq 1 ]] && pass "invoke exits 1 on quota fixture" || fail "invoke exits 1 on quota fixture (rc=$inv_rc)"
if grep -qE '\[agent-pi\] quota 5h; retry at 20[0-9]{2}-' "$inv_out"; then
  pass "invoke.sh prints quota 5h retry at ISO"
else
  fail "invoke.sh prints quota 5h retry at ISO"
  cat "$inv_out"
fi
if [[ -f "${INV_RUN}/quota-retry-schedule.json" ]] \
  && jq -e '.jobs[0].quota_class == "five_hour" and .jobs[0].wake_at != null' \
    "${INV_RUN}/quota-retry-schedule.json" >/dev/null; then
  pass "invoke.sh persisted five_hour wake_at"
else
  fail "invoke.sh persisted five_hour wake_at"
  [[ -f "${INV_RUN}/quota-retry-schedule.json" ]] && cat "${INV_RUN}/quota-retry-schedule.json"
fi
if grep -q -- '--continue' "$inv_out"; then
  fail "quota EXIT must not --continue"
else
  pass "quota EXIT must not --continue"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
