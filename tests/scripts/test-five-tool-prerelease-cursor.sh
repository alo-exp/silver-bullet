#!/usr/bin/env bash
# Five-tool stack pre-release gate — offline bundle + optional live /silver:agent-cursor validation.
#
# Invoked automatically from scripts/pre-release-gate.sh (SB_FIVE_TOOL_PRERELEASE=1).
# Also runs in tests/run-all-tests.sh Script Unit Tests (offline wiring + bundle only).
#
# Live delegate (when leanctx opted in):
#   SB_FIVE_TOOL_PRERELEASE=1 SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=1 \
#     bash tests/scripts/test-five-tool-prerelease-cursor.sh
#
# Manual full matrix:
#   SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=full \
#     bash tests/live/test-live-five-tool-stack-cursor.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_ROOT="$REPO_ROOT"
# shellcheck source=tests/scripts/lib/five-tool-prerelease.sh
source "${REPO_ROOT}/tests/scripts/lib/five-tool-prerelease.sh"

PASS=0
FAIL=0
SKIP=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP: %s\n' "$1"; SKIP=$((SKIP + 1)); }

PRERELEASE="${SB_FIVE_TOOL_PRERELEASE:-0}"
REQUIRE_LIVE="${SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE:-0}"
LEANCTX_ON=0
five_tool_leanctx_opted_in "${REPO_ROOT}/.silver-bullet.json" && LEANCTX_ON=1

echo "=== Five-Tool Pre-Release Gate (Cursor) ==="
echo "repo=${REPO_ROOT}"
echo "prerelease=${PRERELEASE} require_live=${REQUIRE_LIVE} leanctx_opted_in=${LEANCTX_ON}"
echo ""

# --- Structural wiring (always) ---
assert_file() {
  local path="$1" label="$2"
  [[ -f "$path" ]] && pass "$label" || fail "$label — missing $path"
}

assert_file "${REPO_ROOT}/scripts/agent-cursor-delegate.sh" "agent-cursor-delegate.sh present"
assert_file "${REPO_ROOT}/skills/silver-agent-cursor/SKILL.md" "silver-agent-cursor skill present"
assert_file "${REPO_ROOT}/tests/live/test-live-five-tool-stack-cursor.sh" "live five-tool harness present"
assert_file "${REPO_ROOT}/tests/skill-scenarios/silver-five-tool-stack.md" "five-tool scenario doc present"
assert_file "${REPO_ROOT}/docs/testing/FIVE-TOOL-PRERELEASE.md" "FIVE-TOOL-PRERELEASE operator doc present"

if grep -q 'five-tool-stack-cursor' "${REPO_ROOT}/docs/testing/pre-release-claims-registry.json" 2>/dev/null; then
  pass "pre-release-claims-registry.json registers five-tool claim"
else
  fail "pre-release-claims-registry.json registers five-tool claim"
fi

if grep -q 'test-five-tool-prerelease-cursor' "${REPO_ROOT}/scripts/pre-release-gate.sh" 2>/dev/null; then
  pass "pre-release-gate.sh invokes five-tool prerelease script"
else
  fail "pre-release-gate.sh invokes five-tool prerelease script"
fi

grep -q '/silver:agent-cursor' "${REPO_ROOT}/skills/silver-agent-cursor/SKILL.md" \
  && pass "agent-cursor route documented" || fail "agent-cursor route documented"

grep -q 'composer-2.5' "${REPO_ROOT}/scripts/agent-cursor-delegate.sh" \
  && pass "delegate pins composer-2.5" || fail "delegate pins composer-2.5"

# --- Offline hook/script bundle (always in CI) ---
echo ""
echo "--- Offline five-tool bundle ---"
offline_failures=0
five_tool_prerelease_run_offline_bundle "$REPO_ROOT" || offline_failures=$?
if [[ "$offline_failures" -eq 0 ]]; then
  pass "offline five-tool bundle green"
else
  fail "offline five-tool bundle (${offline_failures} failing tests)"
fi

# --- Live delegate via /silver:agent-cursor ---
echo ""
echo "--- Live five-tool delegate (agent-cursor) ---"

run_live=0
if [[ "$PRERELEASE" == "1" && "$LEANCTX_ON" == "1" ]]; then
  run_live=1
elif [[ "${SB_FIVE_TOOL_LIVE:-}" == "1" ]]; then
  run_live=1
fi

if [[ "$run_live" -eq 0 ]]; then
  skip "live delegate not requested (leanctx not opted in or SB_FIVE_TOOL_PRERELEASE unset)"
elif ! five_tool_cursor_cli_path >/dev/null; then
  if [[ "$REQUIRE_LIVE" == "1" ]]; then
    fail "cursor-agent CLI required for leanctx pre-release live gate"
  else
    skip "cursor-agent CLI not on PATH"
  fi
elif ! five_tool_cursor_agent_authenticated; then
  if [[ "$REQUIRE_LIVE" == "1" ]]; then
    fail "cursor-agent auth required (CURSOR_API_KEY or cursor-agent login)"
  else
    skip "cursor-agent not authenticated"
  fi
else
  export SB_FIVE_TOOL_LIVE=1
  export SB_FIVE_TOOL_LIVE_EXECUTE=1
  export SB_FIVE_TOOL_MODE="${SB_FIVE_TOOL_MODE:-prerelease}"
  export SB_FIVE_TOOL_SCENARIO_TIMEOUT="${SB_FIVE_TOOL_SCENARIO_TIMEOUT:-180}"
  export CURSOR_AGENT_TIMEOUT="${SB_FIVE_TOOL_SCENARIO_TIMEOUT}"
  export CURSOR_AGENT_MODEL="${CURSOR_AGENT_MODEL:-composer-2.5}"
  export CURSOR_MODEL="${CURSOR_MODEL:-composer-2.5}"

  # BSD/macOS mktemp only randomizes trailing X's — create then add .log.
  live_log_base="$(mktemp "${TMPDIR:-/tmp}/sb-five-tool-prerelease-live.XXXXXX")"
  live_log="${live_log_base}.log"
  mv "$live_log_base" "$live_log"
  live_exit=0
  if bash "${REPO_ROOT}/tests/live/test-live-five-tool-stack-cursor.sh" >"$live_log" 2>&1; then
    pass "live five-tool prerelease scenarios green"
    five_tool_prerelease_write_marker "live-prerelease"
  else
    live_exit=$?
    fail "live five-tool prerelease scenarios failed (exit ${live_exit})"
    printf '  log tail: %s\n' "$(tail -20 "$live_log" 2>/dev/null || true)"
  fi
  rm -f "$live_log"
fi

if [[ "$PRERELEASE" == "1" && "$LEANCTX_ON" == "0" ]]; then
  five_tool_prerelease_write_marker "offline-only-leanctx-disabled"
elif [[ "$offline_failures" -eq 0 && "$FAIL" -eq 0 ]]; then
  five_tool_prerelease_write_marker "offline"
fi

echo ""
echo "Five-tool pre-release: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ "$FAIL" -eq 0 ]]

