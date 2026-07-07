#!/usr/bin/env bash
# Triage scenario for silver:review-fix-ladder — review → triage → file → fix → verify.
#
# Automated (default): resolver, skill contract, mock PM adapter, phase prompt shapes.
# Live (opt-in): one rung phase sequence with cursor in-session driver.
#
# Enterprise E2E: set SB_TEST_ENTERPRISE_APP_ROOT to cursor fixture worktree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/review-fix-ladder-smoke"
RESOLVER="${SB_ROOT}/scripts/review-fix-ladder.py"
INVOKE_ADAPTER="${SB_ROOT}/scripts/silver-bullet"
ADD_SCRIPT="${SB_ROOT}/scripts/silver-add.sh"
PASS=0
FAIL=0
SKIP=0

# shellcheck source=tests/live/lib/review-fix-ladder-common.sh
source "${SCRIPT_DIR}/lib/review-fix-ladder-common.sh"
# shellcheck source=tests/live/lib/review-fix-ladder-triage-scenario.sh
source "${SCRIPT_DIR}/lib/review-fix-ladder-triage-scenario.sh"

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP: %s\n' "$1"; SKIP=$((SKIP + 1)); }

assert_output_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qiE "$needle"; then
    pass "$label"
  else
    fail "$label"
    printf '  snippet: %s\n' "$(printf '%s' "$haystack" | head -c 300)"
  fi
}

run_automated_triage_scenario() {
  local host work_dir mock_adapter adapter_log ladder_json invoke_out phase prompt

  host="$(review_fix_ladder_resolve_host "${SB_LIVE_RUNTIME:-cursor}")"
  work_dir="$(mktemp -d)"
  mock_adapter="${work_dir}/mock-pm-adapter.sh"
  adapter_log="${work_dir}/adapter-log.jsonl"

  printf '=== Review Fix Ladder Triage Scenario (automated, host=%s) ===\n' "$host"

  review_fix_ladder_write_mock_adapter "$mock_adapter" "$adapter_log"
  review_fix_ladder_seed_triage_workspace "$work_dir" "$FIXTURE_DIR" "$RESOLVER" "$mock_adapter"

  ladder_json="$(review_fix_ladder_ladder_json "$host" "$work_dir")"
  assert_output_contains "resolver returns host ${host}" "$ladder_json" "\"host\": \"${host}\""

  invoke_out="$(cd "$work_dir" && bash "$INVOKE_ADAPTER" invoke-skill silver-review-fix-ladder smoke-target.py 2>&1)"
  assert_output_contains "skill documents triage state machine" "$invoke_out" "rung_N_triage"
  assert_output_contains "skill documents file_valid_issues state" "$invoke_out" "file_valid_issues"
  assert_output_contains "skill forbids reviewer self-triage" "$invoke_out" "review subagent did.*not.*triage|Review subagent did.*not.*triage|FORBIDDEN.*review subagent to triage"

  triage_skill="$(cd "$SB_ROOT" && bash "$INVOKE_ADAPTER" invoke-skill silver-triage smoke-target.py 2>&1)"
  assert_output_contains "silver:triage skill loads" "$triage_skill" "BEGIN SKILL silver-triage|silver-triage"
  assert_output_contains "triage skill documents VALID-BLOCKER" "$triage_skill" "VALID-BLOCKER"

  for phase in review triage fix verify; do
    prompt="$(review_fix_ladder_phase_prompt "$phase" 1 8 "composer-2.5" "low")"
    assert_output_contains "phase prompt mentions ${phase}" "$prompt" "${phase}|rung_1_${phase}|/silver:triage|verify-only|FIX_PASS|REVIEW_RAW"
  done

  local payload result
  payload="$(jq -n \
    --arg schema "silver-triage-issue-v1" \
    --arg title "divide() zero check" \
    --arg body "divide() lacks zero guard" \
    --arg fp "$(bash "$ADD_SCRIPT" fingerprint --domain test --scope smoke-target.py --finding 'zero check')" \
    '{schema: $schema, title: $title, body: $body, fingerprint: $fp, classification: "VALID-NONBLOCKER"}')"
  result="$(bash "$ADD_SCRIPT" adapter-create --payload "$payload" --root "$work_dir")"
  assert_output_contains "mock PM adapter create status" "$result" '"status": "created"'
  assert_output_contains "mock PM adapter create id" "$result" 'PM-TRIAGE-1'
  [[ -f "$adapter_log" ]] && pass "mock PM adapter received payload" || fail "mock PM adapter received payload"

  local review_resp triage_resp
  review_resp="$(review_fix_ladder_cursor_phase_response review)"
  triage_resp="$(review_fix_ladder_cursor_phase_response triage)"
  if review_fix_ladder_assert_phase_response review "$review_resp"; then
    pass "review phase response shape"
  else
    fail "review phase response shape"
  fi
  if review_fix_ladder_assert_phase_response triage "$triage_resp"; then
    pass "triage phase response shape"
  else
    fail "triage phase response shape"
  fi
  if review_fix_ladder_assert_review_triage_separation "$review_resp" "$triage_resp"; then
    pass "review/triage separation (no self-triage)"
  else
    fail "review/triage separation (no self-triage)"
  fi

  rm -rf "$work_dir"
}

run_live_triage_scenario() {
  if [[ "${SB_LIVE_REVIEW_FIX_LADDER_LIVE:-0}" != "1" ]]; then
    skip "live triage scenario (set SB_LIVE_REVIEW_FIX_LADDER_LIVE=1)"
    return 0
  fi

  local runtime="${SB_LIVE_RUNTIME:-cursor}"
  if [[ "$runtime" != "cursor" ]]; then
    skip "live triage scenario cursor-only (got runtime=$runtime)"
    return 0
  fi

  export SB_LIVE_AGENT="$runtime"
  export SB_LIVE_RUNTIME="$runtime"
  export SILVER_BULLET_RUNTIME=cursor
  export SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO=1
  export SB_LIVE_REVIEW_FIX_LADDER_LITE_PROMPT=0

  # shellcheck source=tests/live/helpers.sh
  source "${SCRIPT_DIR}/helpers.sh"

  printf '\n=== Review Fix Ladder Triage Scenario (live cursor) ===\n'

  if ! agent_preflight; then
    skip "live triage scenario (cursor preflight failed)"
    return 0
  fi
  pass "cursor agent preflight"

  local work_dir mock_adapter adapter_log phase prompt response cleaned transcript_log
  work_dir="$(mktemp -d)"
  mock_adapter="${work_dir}/mock-pm-adapter.sh"
  adapter_log="${work_dir}/adapter-log.jsonl"
  transcript_log="${work_dir}/triage-phase-transcript.log"
  : >"$transcript_log"

  git -C "$work_dir" init -q
  git -C "$work_dir" config user.email "triage-ladder@silver-bullet.test"
  git -C "$work_dir" config user.name "Triage Ladder Live"
  review_fix_ladder_write_mock_adapter "$mock_adapter" "$adapter_log"
  review_fix_ladder_seed_triage_workspace "$work_dir" "$FIXTURE_DIR" "$RESOLVER" "$mock_adapter"

  export WORK_DIR="$work_dir"
  if cursor_in_session_active 2>/dev/null; then
    export SB_LIVE_CURSOR_SESSION_DIR="${work_dir}/.cursor-live-session"
    mkdir -p "$SB_LIVE_CURSOR_SESSION_DIR"
    printf 'NOTE: cursor in-session triage scenario — session %s\n' "$SB_LIVE_CURSOR_SESSION_DIR"
  fi

  local phases=(review triage fix verify)
  local phase
  for phase in "${phases[@]}"; do
    prompt="$(review_fix_ladder_phase_prompt "$phase" 1 8 "composer-2.5" "low")"
    if cursor_in_session_active 2>/dev/null; then
      response="$(review_fix_ladder_cursor_phase_response "$phase")"
      local req_id="${phase}-$$"
      bash "${SCRIPT_DIR}/lib/cursor-in-session-respond.sh" "$SB_LIVE_CURSOR_SESSION_DIR" "$req_id" "$response" >/dev/null
    else
      response="$(invoke_claude_permissive "$prompt")"
    fi
    cleaned="$(printf '%s' "$response")"
    printf '[%s] %s\n' "$phase" "$cleaned" >>"$transcript_log"
    if review_fix_ladder_assert_phase_response "$phase" "$cleaned"; then
      pass "live phase ${phase} evidence"
    else
      fail "live phase ${phase} evidence"
    fi
  done

  if [[ -f "$adapter_log" ]] || cursor_in_session_active 2>/dev/null; then
    pass "triage scenario exercised PM adapter path (mock or in-session)"
  else
    fail "triage scenario exercised PM adapter path"
  fi

  local review_line triage_line
  review_line="$(grep '^\[review\]' "$transcript_log" | head -1 || true)"
  triage_line="$(grep '^\[triage\]' "$transcript_log" | head -1 || true)"
  if review_fix_ladder_assert_review_triage_separation "${review_line#\[review\] }" "${triage_line#\[triage\] }"; then
    pass "live review/triage separation"
  else
    fail "live review/triage separation"
  fi

  printf '\n--- Triage phase transcript (%s) ---\n' "$transcript_log"
  cat "$transcript_log"

  rm -rf "$work_dir"
}

export SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO=1
run_automated_triage_scenario
run_live_triage_scenario

printf '\nResults: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[[ "$FAIL" -eq 0 ]]
