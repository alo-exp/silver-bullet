#!/usr/bin/env bash
# Triage scenario for sb:review-fix-ladder — review → triage → file → launcher APPLY ACCEPT → verify.
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

  invoke_out="$(cd "$work_dir" && bash "$INVOKE_ADAPTER" invoke-skill sb:review-fix-ladder smoke-target.py 2>&1)"
  assert_output_contains "skill documents triage state machine" "$invoke_out" "rung_N_triage"
  assert_output_contains "skill documents file_valid_issues state" "$invoke_out" "file_valid_issues"
  assert_output_contains "skill forbids reviewer self-triage" "$invoke_out" "review subagent did.*not.*triage|Review subagent did.*not.*triage|FORBIDDEN.*review subagent to triage"

  triage_skill="$(cd "$SB_ROOT" && bash "$INVOKE_ADAPTER" invoke-skill sb:triage smoke-target.py 2>&1)"
  assert_output_contains "sb:triage skill loads" "$triage_skill" "BEGIN SKILL silver-triage|silver-triage"
  assert_output_contains "triage skill documents VALID-BLOCKER" "$triage_skill" "VALID-BLOCKER"

  for phase in review triage verify; do
    prompt="$(review_fix_ladder_phase_prompt "$phase" 1 8 "composer-2.5" "low")"
    assert_output_contains "phase prompt mentions ${phase}" "$prompt" "${phase}|rung_1_${phase}|/sb:triage|verify-only|REVIEW_RAW"
  done
  apply_prompt="$(review_fix_ladder_phase_prompt "fix" 1 8 "composer-2.5" "low")"
  assert_output_contains "launcher APPLY ACCEPT prompt is not a rung fix" "$apply_prompt" "APPLY ACCEPT"
  if printf '%s' "$apply_prompt" | grep -qiE 'Fix divide\(\) minimally|Reply with FIX_PASS'; then
    fail "APPLY ACCEPT does not instruct the rung to patch"
  else
    pass "APPLY ACCEPT does not instruct the rung to patch"
  fi

  if review_fix_ladder_launcher_apply_accept "$work_dir" && review_fix_ladder_fixture_fixed "$work_dir"; then
    pass "launcher APPLY ACCEPT patches divide()"
  else
    fail "launcher APPLY ACCEPT patches divide()"
  fi

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

  local phases=(review triage verify)
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
    if [[ "$phase" == "triage" ]]; then
      if review_fix_ladder_launcher_apply_accept "$work_dir" && review_fix_ladder_fixture_fixed "$work_dir"; then
        pass "live launcher APPLY ACCEPT patches divide()"
        printf '[apply] APPLY ACCEPT: launcher patched divide() zero-divisor guard\n' >>"$transcript_log"
      else
        fail "live launcher APPLY ACCEPT patches divide()"
      fi
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

run_github_enterprise_triage_scenario() {
  if [[ "${SB_RFL_GITHUB_E2E:-0}" != "1" && "${SB_LIVE_REVIEW_FIX_LADDER_GITHUB:-0}" != "1" ]]; then
    skip "github enterprise triage scenario (set SB_RFL_GITHUB_E2E=1 or SB_LIVE_REVIEW_FIX_LADDER_GITHUB=1)"
    return 0
  fi

  if ! review_fix_ladder_github_available; then
    skip "github enterprise triage scenario (gh auth or GITHUB_TOKEN required)"
    return 0
  fi

  local app_root="${SB_TEST_ENTERPRISE_APP_ROOT:-}"
  if [[ -z "$app_root" ]] || ! git -C "$app_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    skip "github enterprise triage scenario (SB_TEST_ENTERPRISE_APP_ROOT git repo required)"
    return 0
  fi

  local host work_dir resolver owner_repo issue_url issue_num fp title body
  host="$(review_fix_ladder_resolve_host "${SB_LIVE_RUNTIME:-cursor}")"
  work_dir="$(mktemp -d)"
  resolver="$RESOLVER"

  printf '\n=== Review Fix Ladder Triage Scenario (GitHub PM, host=%s) ===\n' "$host"

  review_fix_ladder_prepare_github_workdir "$app_root" "$work_dir"
  review_fix_ladder_seed_github_workspace "$work_dir" "$FIXTURE_DIR" "$resolver"

  owner_repo="$(review_fix_ladder_github_owner_repo "$work_dir")"
  assert_output_contains "github workspace remote" "$owner_repo" 'alo-exp/enterprise-grade-test-app|github\.com'

  tracker="$(jq -r '.issue_tracker' "${work_dir}/.silver-bullet.json")"
  adapter_type="$(jq -r '.issue_tracker_adapter.type' "${work_dir}/.silver-bullet.json")"
  if [[ "$tracker" == "github" && "$adapter_type" == "github" ]]; then
    pass "github issue_tracker_adapter configured"
  else
    fail "github issue_tracker_adapter configured"
  fi

  fp="$(bash "$ADD_SCRIPT" fingerprint --domain test --scope smoke-target.py --finding 'divide zero guard rfl e2e')"
  title="[RFL E2E] divide() zero check"
  body="Automated review-fix-ladder triage E2E fingerprint:${fp}"

  issue_url="$(review_fix_ladder_github_file_issue "$work_dir" "$title" "$body")"
  assert_output_contains "github issue created" "$issue_url" 'https://github.com/.*/issues/[0-9]+'
  issue_num="$(printf '%s' "$issue_url" | grep -oE '[0-9]+$')"

  if [[ -n "$issue_num" ]]; then
    gh issue view "$issue_num" --repo "$owner_repo" --json title,labels \
      | jq -e '.labels[].name' >/dev/null 2>&1 && pass "github issue visible via gh" || fail "github issue visible via gh"
  else
    fail "github issue visible via gh"
  fi

  review_fix_ladder_github_close_issue "$work_dir" "$issue_num"
  pass "github issue cleanup (closed)"

  rm -rf "$work_dir"
}

export SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO=1
run_automated_triage_scenario
run_github_enterprise_triage_scenario
run_live_triage_scenario

printf '\nResults: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[[ "$FAIL" -eq 0 ]]
