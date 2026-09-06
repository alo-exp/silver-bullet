#!/usr/bin/env bash
# Live five-tool stack validation via /sb:agent-cursor (Cursor mandatory).
#
# Modes (SB_FIVE_TOOL_MODE):
#   skeleton  — structural checks only (default when SB_FIVE_TOOL_LIVE_EXECUTE unset)
#   prerelease — S01,S02,S04,S06,S09 with per-scenario timeout (pre-release gate)
#   full      — all S01–S10 scenarios
#
# Environment:
#   SB_FIVE_TOOL_LIVE=1              Include in run-all-tests.sh optional block
#   SB_FIVE_TOOL_LIVE_EXECUTE=1      Run delegate scenarios (auto-set by prerelease gate)
#   SB_FIVE_TOOL_PRERELEASE=1        Prerelease mode from test-five-tool-prerelease-cursor.sh
#   SB_FIVE_TOOL_SCENARIO_TIMEOUT=N  Per-scenario seconds (default 180 prerelease, 600 full)
#   CURSOR_AGENT_TIMEOUT=N           Passed to agent-cursor-delegate (default 1800)
#   SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=1  Treat skips as failures
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=tests/scripts/lib/five-tool-prerelease.sh
source "${SB_ROOT}/tests/scripts/lib/five-tool-prerelease.sh"

PASS=0
FAIL=0
SKIP=0
SKIP_REASON=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); SKIP_REASON="${SKIP_REASON:+$SKIP_REASON; }$1"; }
hard_skip_as_fail() {
  if [[ "${SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE:-}" == "1" ]]; then
    fail "$1"
  else
    skip "$1"
  fi
}

export SB_LIVE_AGENT=cursor
export SILVER_BULLET_RUNTIME=cursor

MODE="${SB_FIVE_TOOL_MODE:-skeleton}"
if [[ "${SB_FIVE_TOOL_PRERELEASE:-}" == "1" ]]; then
  MODE="${SB_FIVE_TOOL_MODE:-prerelease}"
  export SB_FIVE_TOOL_LIVE_EXECUTE=1
fi
if [[ "${SB_FIVE_TOOL_LIVE_EXECUTE:-}" == "1" && "$MODE" == "skeleton" ]]; then
  MODE="full"
fi

case "$MODE" in
  prerelease) SCENARIO_TIMEOUT="${SB_FIVE_TOOL_SCENARIO_TIMEOUT:-180}" ;;
  full) SCENARIO_TIMEOUT="${SB_FIVE_TOOL_SCENARIO_TIMEOUT:-600}" ;;
  *) SCENARIO_TIMEOUT="${SB_FIVE_TOOL_SCENARIO_TIMEOUT:-120}" ;;
esac

echo "=== Live Five-Tool Stack (Cursor) ==="
echo "mode=${MODE} scenario_timeout=${SCENARIO_TIMEOUT}s"
echo "Scenario doc: tests/skill-scenarios/silver-five-tool-stack.md"
echo ""

DELEGATE="${SB_ROOT}/scripts/agent-cursor-delegate.sh"
[[ -f "$DELEGATE" ]] && pass "agent-cursor-delegate.sh present" || fail "agent-cursor-delegate.sh present"

SCENARIO_DOC="${SB_ROOT}/tests/skill-scenarios/silver-five-tool-stack.md"
[[ -f "$SCENARIO_DOC" ]] && pass "scenario doc present" || fail "scenario doc present"
grep -q 'S10' "$SCENARIO_DOC" && pass "scenario doc lists 10 scenarios" || fail "scenario doc lists 10 scenarios"

grep -q 'Pre-release acceptance' "$SCENARIO_DOC" \
  && pass "scenario doc lists pre-release acceptance" || fail "scenario doc lists pre-release acceptance"

cursor_cli="$(five_tool_cursor_cli_path || true)"
if [[ -z "$cursor_cli" ]]; then
  hard_skip_as_fail "cursor-agent CLI not on PATH"
elif ! five_tool_cursor_agent_authenticated; then
  hard_skip_as_fail "cursor-agent not authenticated (set CURSOR_API_KEY or cursor-agent login)"
else
  pass "cursor-agent available and authenticated"
fi

if [[ "$MODE" == "skeleton" ]]; then
  skip "skeleton mode (set SB_FIVE_TOOL_LIVE_EXECUTE=1 or SB_FIVE_TOOL_PRERELEASE=1 for delegate)"
fi

if [[ "$SKIP" -gt 0 && "$MODE" == "skeleton" ]]; then
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "Skip reason: ${SKIP_REASON}"
  echo "Re-run prerelease: SB_FIVE_TOOL_PRERELEASE=1 bash tests/scripts/test-five-tool-prerelease-cursor.sh"
  echo "Re-run full live: SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=full bash tests/live/test-live-five-tool-stack-cursor.sh"
  exit 0
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "Blocker: ${SKIP_REASON}"
  exit 1
fi

if [[ "$SKIP" -gt 0 ]]; then
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "Skip reason: ${SKIP_REASON}"
  exit 1
fi

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-five-tool-live.XXXXXX")"
trap 'rm -rf "$WORK_ROOT"' EXIT

run_scenario() {
  local id="$1" prompt="$2"
  local work_dir="${WORK_ROOT}/${id}"
  local log="${work_dir}/delegate.log"
  local delegate_pid deadline_epoch grace_deadline now
  mkdir -p "$work_dir"
  echo "--- Scenario ${id} (timeout ${SCENARIO_TIMEOUT}s) ---"

  kill_descendants() {
    local parent="$1" child
    for child in $(pgrep -P "$parent" 2>/dev/null || true); do
      kill_descendants "$child"
      kill -TERM "$child" 2>/dev/null || true
    done
  }

  cleanup_scenario_processes() {
    # agent.sh starts cursor-agent in a separate session and kills that process
    # group on timeout.  Restrict fallback cleanup to the known delegate PID;
    # a pgrep -f work-directory scan can match the harness or its supervisors
    # while they are still carrying the scenario path in their command line.
    [[ -n "${delegate_pid:-}" ]] && kill_descendants "$delegate_pid"
  }

  local delegate_exit=0
  local inner_timeout="$SCENARIO_TIMEOUT"
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=20 "${SCENARIO_TIMEOUT}" \
      env CURSOR_AGENT_TIMEOUT="${inner_timeout}" \
      CURSOR_AGENT_MODEL="${CURSOR_AGENT_MODEL:-composer-2.5}" \
      CURSOR_MODEL="${CURSOR_MODEL:-composer-2.5}" \
      bash "$DELEGATE" --work-dir "$work_dir" --prompt "$prompt" --log "$log" --sb-root "$SB_ROOT" \
      >/dev/null 2>&1 || delegate_exit=$?
  else
    env CURSOR_AGENT_TIMEOUT="${inner_timeout}" \
      CURSOR_AGENT_MODEL="${CURSOR_AGENT_MODEL:-composer-2.5}" \
      CURSOR_MODEL="${CURSOR_MODEL:-composer-2.5}" \
      bash "$DELEGATE" --work-dir "$work_dir" --prompt "$prompt" --log "$log" --sb-root "$SB_ROOT" \
      >/dev/null 2>&1 &
    delegate_pid=$!
    deadline_epoch=$(( $(date +%s) + SCENARIO_TIMEOUT ))
    while kill -0 "$delegate_pid" 2>/dev/null; do
      now="$(date +%s)"
      if (( now >= deadline_epoch )); then
        # macOS does not ship the GNU timeout utility. Keep the documented
        # per-scenario deadline portable and clean up the process group.
        kill -TERM "$delegate_pid" 2>/dev/null || true
        grace_deadline=$(( now + 20 ))
        while kill -0 "$delegate_pid" 2>/dev/null; do
          (( $(date +%s) >= grace_deadline )) && break
          sleep 1
        done
        kill -KILL "$delegate_pid" 2>/dev/null || true
        wait "$delegate_pid" 2>/dev/null || true
        delegate_exit=124
        break
      fi
      sleep 1
    done
    if [[ "$delegate_exit" -eq 0 ]]; then
      wait "$delegate_pid" || delegate_exit=$?
    fi
  fi

  # Best-effort cleanup of orphaned cursor-agent children for this work_dir.
  # Use the unique scenario path with explicit ancestor exclusions; a broad
  # pkill can accidentally terminate the prerelease supervisor itself.
  if [[ "$delegate_exit" -ne 0 ]]; then
    cleanup_scenario_processes
  fi

  case "$delegate_exit" in
    0)
      if [[ -f "$log" ]] && grep -qiE 'PASS|pass/fail:\s*pass|scenario.*pass' "$log" 2>/dev/null; then
        pass "${id}: delegation completed with pass signal"
      elif [[ -f "$log" ]] && grep -qiE 'FAIL|pass/fail:\s*fail|scenario.*fail' "$log" 2>/dev/null; then
        fail "${id}: agent reported failure (see ${log})"
      else
        pass "${id}: delegation completed"
      fi
      ;;
    124)
      fail "${id}: timed out after ${SCENARIO_TIMEOUT}s (see ${log})"
      ;;
    *)
      fail "${id}: delegation failed exit ${delegate_exit} (see ${log})"
      ;;
  esac
}

# Shared brief prefix — composer-2.5 only, report PASS/FAIL one line at end.
BRIEF_PREFIX='You are running a Silver Bullet five-tool stack live scenario via /sb:agent-cursor. Use composer-2.5 only. End your final message with exactly one line: SCENARIO_RESULT: PASS or SCENARIO_RESULT: FAIL.'

run_prerelease_scenarios() {
  run_scenario "S01-opt-in" \
    "${BRIEF_PREFIX} Opt in all five recommended tools in this temp project, run install-leanctx-sb.sh --dry-run, confirm lctx_ MCP prefix in mcp.json."

  run_scenario "S02-read-ast" \
    "${BRIEF_PREFIX} Read hooks/lib/stack-compression-coordinator.sh using lctx_read_ast (not native Read for analysis). Confirm Grep routing is not incorrectly denied."

  run_scenario "S04-shell-rtk" \
    "${BRIEF_PREFIX} Run git status via Bash once; confirm RTK rewrite applies and LeanCTX does not second-wrap shell."

  run_scenario "S06-graph-memory" \
    "${BRIEF_PREFIX} Run graphify query on five-tool routing and memory_save one decision; confirm lctx_remember is blocked by coordinator."

  run_scenario "S09-conflict-regression" \
    "${BRIEF_PREFIX} Verify coordinator denies sb_stack_double_compression when RTK-rewritten Bash is re-offered to LeanCTX shell MCP."
}

run_full_scenarios() {
  run_prerelease_scenarios

  run_scenario "S03-grep-cm" \
    "${BRIEF_PREFIX} Use ctx_search or ctx_execute for analysis grep — not LeanCTX double-read."

  run_scenario "S05-webfetch" \
    "${BRIEF_PREFIX} Attempt WebFetch; expect Context Mode deny and no LeanCTX fetch MCP."

  run_scenario "S07-wire-ledger" \
    "${BRIEF_PREFIX} Smoke wire proxy / savings ledger entry if lean-ctx proxy available."

  run_scenario "S08-pathjail-injection" \
    "${BRIEF_PREFIX} Confirm PathJail allow + injection scan entries in leanctx session log within 60s."

  run_scenario "S10-lifecycle" \
    "${BRIEF_PREFIX} PreCompact lifecycle ordering: CM → AM → LeanCTX → stop-check."
}

case "$MODE" in
  prerelease) run_prerelease_scenarios ;;
  full) run_full_scenarios ;;
  *) ;;
esac

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ "$FAIL" -eq 0 ]] || exit 1
