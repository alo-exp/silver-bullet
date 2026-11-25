#!/usr/bin/env bash
# Claude/Anthropic 5-hour quota: classify and report (the delegate schedules nothing), invoke wrapper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/review-fix-ladder.py"
INVOKE="${REPO_ROOT}/scripts/agent-pi/invoke.sh"
HOST_EXEC="${REPO_ROOT}/scripts/lib/agent-host-exec.sh"
QUOTA_SH="${REPO_ROOT}/scripts/lib/agent-pi-quota-retry.sh"
FIXTURES="${REPO_ROOT}/tests/fixtures/quota"
unset SB_RFL_QUOTA_HOST SB_RFL_QUOTA_WAKE_AT SB_RFL_MODEL 2>/dev/null || true
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

# --- the scheduler is gone: its flags are rejected, nothing is persisted ---
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-pi-quota.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
rc=0; python3 "$RESOLVER" --schedule-quota-retry --run-dir "$WORKDIR" >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 2 ]] && pass "--schedule-quota-retry is rejected" || fail "--schedule-quota-retry is rejected (rc=$rc)"

# --- wrapper: classify-and-report on fixture output; 124 reports nothing ---
# shellcheck source=scripts/lib/agent-host-exec.sh
source "$HOST_EXEC"
# shellcheck source=scripts/lib/agent-pi-quota-retry.sh
source "$QUOTA_SH"
export SB_RFL_QUOTA_HOST="claude"
export PI_MODEL="claude/claude-opus-5-high"
wrap_out="$(mktemp "${TMPDIR:-/tmp}/quota-wrap-XXXXXX")"
agent_host_pi_maybe_schedule_quota_retry 1 "$(cat "${FIXTURES}/claude-5h-console.txt")" >"$wrap_out" 2>&1 || true
if grep -qE '\[agent-pi\] quota 5h; window resets in 9120s; no retry is scheduled' "$wrap_out"; then
  pass "wrapper prints the greppable 5h window line"
else
  fail "wrapper prints the greppable 5h window line"; cat "$wrap_out"
fi
hang_out="$(mktemp "${TMPDIR:-/tmp}/quota-hang-XXXXXX")"
agent_host_pi_maybe_schedule_quota_retry 124 "$(cat "${FIXTURES}/idle-124.txt")" >"$hang_out" 2>&1 || true
if grep -q 'quota 5h' "$hang_out"; then fail "EXIT 124 hang is not quota"; cat "$hang_out"; else pass "EXIT 124 hang is not quota"; fi

# invoke.sh end-to-end with a fake delegate
FAKE="$(mktemp "${TMPDIR:-/tmp}/fake-pi-XXXXXX")"
cat >"$FAKE" <<'EOF'
#!/usr/bin/env bash
cat >&2 <<'QUOTA'
HTTP 429 rate_limit_error: 5-hour usage limit reached. Resets in 2hr 32min
QUOTA
exit 1
EOF
chmod +x "$FAKE"
INV_RUNG="${WORKDIR}/rung-10-claude-opus-5-high"
mkdir -p "$INV_RUNG"
export SB_AGENT_PI_DELEGATE_SCRIPT="$FAKE"
inv_out="$(mktemp "${TMPDIR:-/tmp}/quota-inv-XXXXXX")"
set +e
bash "$INVOKE" --work-dir "$INV_RUNG" --prompt "noop" >"$inv_out" 2>&1
inv_rc=$?
set -e
[[ "$inv_rc" -eq 1 ]] && pass "invoke exits 1 on quota fixture" || fail "invoke exits 1 on quota fixture (rc=$inv_rc)"
if grep -qE '\[agent-pi\] quota 5h; window resets in [0-9]+s' "$inv_out"; then
  pass "invoke.sh reports the 5h window"
else
  fail "invoke.sh reports the 5h window"; cat "$inv_out"
fi
if [[ -n "$(find "$WORKDIR" -name 'quota-retry-schedule.json')" ]]; then
  fail "invoke.sh must not persist a schedule"
else
  pass "invoke.sh persists nothing"
fi
if grep -q -- '--continue' "$inv_out"; then fail "quota EXIT must not --continue"; else pass "quota EXIT must not --continue"; fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
