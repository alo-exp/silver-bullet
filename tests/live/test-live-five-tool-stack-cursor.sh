#!/usr/bin/env bash
# Live five-tool stack validation via /silver:agent-cursor (Cursor mandatory).
# Requires SB_FIVE_TOOL_LIVE=1 (run-all-tests) and cursor-agent auth for execution.
# Default: structural skeleton only — scenarios skip unless SB_FIVE_TOOL_LIVE_EXECUTE=1.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0
SKIP_REASON=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); SKIP_REASON="${SKIP_REASON:+$SKIP_REASON; }$1"; }

export SB_LIVE_AGENT=cursor
export SILVER_BULLET_RUNTIME=cursor

echo "=== Live Five-Tool Stack (Cursor) ==="
echo "Scenario doc: tests/skill-scenarios/silver-five-tool-stack.md"
echo ""

DELEGATE="${SB_ROOT}/scripts/agent-cursor-delegate.sh"
[[ -f "$DELEGATE" ]] && pass "agent-cursor-delegate.sh present" || fail "agent-cursor-delegate.sh present"

SCENARIO_DOC="${SB_ROOT}/tests/skill-scenarios/silver-five-tool-stack.md"
[[ -f "$SCENARIO_DOC" ]] && pass "scenario doc present" || fail "scenario doc present"
grep -q 'S10' "$SCENARIO_DOC" && pass "scenario doc lists 10 scenarios" || fail "scenario doc lists 10 scenarios"

cursor_cli=""
cursor_cli="$(command -v cursor-agent 2>/dev/null || command -v agent 2>/dev/null || true)"
if [[ -z "$cursor_cli" ]]; then
  skip "cursor-agent CLI not on PATH"
elif [[ -z "${CURSOR_API_KEY:-}" ]]; then
  if ! "$cursor_cli" status 2>&1 | grep -qiE 'logged in as|email:|account:'; then
    skip "cursor-agent not authenticated (no CURSOR_API_KEY; status not logged in)"
  fi
fi

if [[ "${SB_FIVE_TOOL_LIVE_EXECUTE:-}" != "1" ]]; then
  skip "skeleton mode (set SB_FIVE_TOOL_LIVE_EXECUTE=1 to run delegate scenarios)"
fi

if [[ "$SKIP" -gt 0 && "${SB_FIVE_TOOL_LIVE_EXECUTE:-}" != "1" ]]; then
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "Skip reason: ${SKIP_REASON}"
  echo "Re-run with: SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 bash tests/live/test-live-five-tool-stack-cursor.sh"
  exit 0
fi

if [[ "$SKIP" -gt 0 ]]; then
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "Skip reason: ${SKIP_REASON}"
  exit 1
fi

# shellcheck source=tests/live/helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-five-tool-live.XXXXXX")"
trap 'rm -rf "$WORK_ROOT"' EXIT

run_scenario() {
  local id="$1" prompt="$2"
  local work_dir="${WORK_ROOT}/${id}"
  mkdir -p "$work_dir"
  local log="${work_dir}/delegate.log"
  echo "--- Scenario ${id} ---"
  if bash "$DELEGATE" --work-dir "$work_dir" --prompt "$prompt" --log "$log" --sb-root "$SB_ROOT" >/dev/null 2>&1; then
    pass "${id}: delegation completed"
  else
    fail "${id}: delegation failed (see ${log})"
  fi
}

run_scenario "S01-opt-in" \
  "Opt in all five recommended tools in this temp project, run install-leanctx-sb.sh --dry-run, confirm lctx_ MCP prefix in mcp.json. Report pass/fail only."

run_scenario "S02-read-ast" \
  "Read a large file using lctx_read_ast (not native Read). Confirm CM read-deny did not misfire on Grep."

run_scenario "S03-grep-cm" \
  "Use ctx_search or ctx_execute for analysis grep — not LeanCTX double-read."

run_scenario "S04-shell-rtk" \
  "Run git status via Bash once with RTK rewrite; confirm no LeanCTX shell second wrap."

run_scenario "S05-webfetch" \
  "Attempt WebFetch; expect CM deny and no LeanCTX fetch MCP."

run_scenario "S06-graph-memory" \
  "Run graphify query and memory_save; confirm coordinator blocks lctx_remember."

run_scenario "S07-wire-ledger" \
  "Smoke wire proxy / savings ledger entry if lean-ctx proxy available."

run_scenario "S08-pathjail-injection" \
  "Confirm PathJail allow + injection scan entries in leanctx session log within 60s."

run_scenario "S09-conflict-regression" \
  "Verify sb_stack_double_compression deny on RTK-rewritten Bash re-offered to LeanCTX shell."

run_scenario "S10-lifecycle" \
  "PreCompact lifecycle ordering: CM → AM → LeanCTX → stop-check."

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
[[ "$FAIL" -eq 0 ]] || exit 1
