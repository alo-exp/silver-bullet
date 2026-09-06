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
#   SB_FIVE_TOOL_SCENARIO_TIMEOUT=N  Delegate budget (default 180 prerelease, 600 full)
#   CURSOR_AGENT_TIMEOUT=N           Delegate budget override
#   SB_FIVE_TOOL_OUTER_GRACE_SECONDS=N  Outer watchdog grace after delegate budget (default 30)
#   SB_FIVE_TOOL_OUTER_TIMEOUT=N     Explicit outer watchdog override
#   SB_FIVE_TOOL_SCENARIOS=CSV       Optional scenario-name filter for focused reruns
#   SB_FIVE_TOOL_KEEP_ARTIFACTS=1    Preserve fixture and delegate logs for diagnosis
#   SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=1  Treat skips as failures
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=scripts/lib/command-timeout.sh
source "${SB_ROOT}/scripts/lib/command-timeout.sh"
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
# Live fixtures must boot the complete MCP stack; lightweight mode is for ordinary
# production delegations and can suppress the very wiring these scenarios verify.
export SB_AGENT_CURSOR_LIGHTWEIGHT=0
export SB_LIVE_CURSOR_FORCE_HEADLESS=1
export SB_LIVE_CURSOR_IN_SESSION=0
export SB_AGENT_CURSOR_STREAM_JSON=1

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
OUTER_GRACE="${SB_FIVE_TOOL_OUTER_GRACE_SECONDS:-30}"
SCENARIO_FILTER="${SB_FIVE_TOOL_SCENARIOS:-}"

echo "=== Live Five-Tool Stack (Cursor) ==="
echo "mode=${MODE} scenario_timeout=${SCENARIO_TIMEOUT}s"
echo "outer_watchdog_grace=${OUTER_GRACE}s"
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
LOG_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-five-tool-logs.XXXXXX")"

cleanup_live_artifacts() {
  if [[ "${SB_FIVE_TOOL_KEEP_ARTIFACTS:-}" == "1" ]]; then
    echo "Preserved live fixtures: ${WORK_ROOT}" >&2
    echo "Preserved delegate logs: ${LOG_ROOT}" >&2
    return
  fi
  # Cursor/MCP helpers can outlive the CLI process after a quota or transport
  # error. Give their per-scenario cleanup a chance to finish, then retry the
  # exact fixture roots briefly so a late npm write cannot turn cleanup into a
  # second, misleading gate failure.
  for _ in 1 2 3 4 5; do
    rm -rf "$WORK_ROOT" "$LOG_ROOT" 2>/dev/null && return
    sleep 1
  done
  echo "WARN: unable to remove live fixture roots: ${WORK_ROOT} ${LOG_ROOT}" >&2
}
trap cleanup_live_artifacts EXIT

cleanup_cursor_fixture_processes() {
  local work_dir="$1" cursor_home="$2" cursor_config_dir="$3" cursor_data_dir="$4"

  # Cursor's MCP child tools may create a separate process group (notably the
  # TypeScript language server) and therefore survive the adapter's process
  # group watchdog. Match only this fixture's exact paths and protect the
  # current shell/ancestor groups from accidental self-termination.
  python3 - "$work_dir" "$cursor_home" "$cursor_config_dir" "$cursor_data_dir" <<'PY'
import os
import signal
import subprocess
import sys
import time

roots = {value for value in sys.argv[1:] if value}
roots |= {os.path.realpath(value) for value in roots}

def rows():
    raw = subprocess.check_output(
        ["ps", "-axo", "pid=,ppid=,pgid=,command="],
        text=True,
        errors="replace",
    )
    result = []
    for line in raw.splitlines():
        parts = line.strip().split(None, 3)
        if len(parts) != 4:
            continue
        try:
            result.append((int(parts[0]), int(parts[1]), int(parts[2]), parts[3]))
        except ValueError:
            continue
    return result

current_pid = os.getpid()
protected_pids = {current_pid}
protected_groups = set()
parent_by_pid = {pid: ppid for pid, ppid, _, _ in rows()}
pid = current_pid
while pid in parent_by_pid:
    parent = parent_by_pid[pid]
    if parent in protected_pids:
        break
    protected_pids.add(parent)
    pid = parent
for row_pid, row_ppid, row_pgid, _ in rows():
    if row_pid in protected_pids:
        protected_groups.add(row_pgid)

def matching_rows():
    matched = []
    for row in rows():
        pid, _, pgid, command = row
        if pid in protected_pids or pgid in protected_groups:
            continue
        if any(root in command or root in os.path.realpath(command) for root in roots):
            matched.append(row)
    return matched

groups = {pgid for _, _, pgid, _ in matching_rows()}
for pgid in groups:
    try:
        os.killpg(pgid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass
if groups:
    time.sleep(0.25)
for pgid in {pgid for _, _, pgid, _ in matching_rows()}:
    try:
        os.killpg(pgid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass
PY
}

run_scenario() {
  local id="$1" prompt="$2"
  if [[ -n "$SCENARIO_FILTER" ]] && ! \
    printf ',%s,' "$SCENARIO_FILTER" | grep -Fq ",${id},"; then
    skip "${id}: filtered by SB_FIVE_TOOL_SCENARIOS"
    return 0
  fi
  local work_dir="${WORK_ROOT}/${id}"
  # Keep the live stream log outside the entire model-visible fixture. Cursor
  # can otherwise discover and read its own still-growing transcript, creating
  # a self-referential tool loop that appears to the wrapper as a 180s timeout.
  local log="${LOG_ROOT}/${id}.delegate.log"
  local cursor_home="${work_dir}/cursor-home"
  local cursor_config_dir="${work_dir}/cursor-config"
  local cursor_data_dir="${work_dir}/cursor-data"
  local five_tool_enabled="true"
  [[ "$id" == "S01-opt-in" ]] && five_tool_enabled="false"
  mkdir -p "$work_dir"
  cat >"${work_dir}/.silver-bullet.json" <<JSON
{
  "recommended_tools": {
    "graphify": {"enabled_by_user": ${five_tool_enabled}},
    "agentmemory": {"enabled_by_user": ${five_tool_enabled}},
    "context_mode": {"enabled_by_user": ${five_tool_enabled}},
    "leanctx": {"enabled_by_user": ${five_tool_enabled}},
    "rtk": {"enabled_by_user": ${five_tool_enabled}}
  }
}
JSON
  echo "--- Scenario ${id} (timeout ${SCENARIO_TIMEOUT}s) ---"

  # Cursor CLI discovers installed plugin hooks from its normal user state. Keep
  # the live fixture deterministic by giving it an isolated config/data root,
  # seeded from the already-verified shared SB config. This prevents a stale
  # plugin-cache hook (for example `npx -y context-mode`) from being loaded in
  # addition to the manifest-backed five-tool wiring under test.
  # HOME is isolated too: Cursor's plugin cache is rooted below HOME and can
  # otherwise inject a host-installed plugin even when CURSOR_CONFIG_DIR is
  # temporary. Seed only the credential file needed by cursor-agent status.
  mkdir -p "$cursor_home/.cursor" "$cursor_config_dir" "$cursor_data_dir"
  if [[ -f "${HOME}/.cursor/auth.json" ]]; then
    cp "${HOME}/.cursor/auth.json" "$cursor_home/.cursor/auth.json"
    chmod 600 "$cursor_home/.cursor/auth.json"
  fi
  # Cursor can rehydrate enabled marketplace plugins from the account even when
  # its filesystem roots are isolated. Disable plugin-owned five-tool surfaces
  # in this test-only profile so each scenario exercises the single global
  # manifest and global hooks seeded below, rather than a duplicate plugin MCP
  # server or legacy plugin hook. This does not alter the user's Cursor state.
  cat >"${cursor_home}/.cursor/settings.json" <<'JSON'
{
  "enabledPlugins": {
    "silver-bullet@alo-labs": false,
    "context-mode@context-mode": false,
    "sidekick@alo-labs": false,
    "episodic-memory@episodic-memory-dev": false
  }
}
JSON
  # CURSOR_CONFIG_DIR is the CLI's effective user-config root; keep the same
  # test-only plugin disablement there as well as in HOME/.cursor. Without this
  # mirror, Cursor can rehydrate account-enabled plugin hooks into the fixture.
  cp "${cursor_home}/.cursor/settings.json" "${cursor_config_dir}/settings.json"
  for config_name in hooks.json mcp.json; do
    if [[ ! -f "${HOME}/.cursor/${config_name}" ]]; then
      fail "${id}: missing global Cursor ${config_name} seed"
      return 0
    fi
    cp "${HOME}/.cursor/${config_name}" "${cursor_config_dir}/${config_name}"
    # The Cursor CLI resolves MCP and hook files from ~/.cursor even when the
    # desktop-specific config override is present; keep both views identical.
    cp "${HOME}/.cursor/${config_name}" "${cursor_home}/.cursor/${config_name}"
  done
  # The global Cursor file can also contain bridge hooks contributed by an
  # installed Silver Bullet plugin. They are outside this fixture's manifest
  # contract and can re-enter the old routing path, so exclude them from the
  # per-scenario copy without touching the user's global file. The legacy
  # lean-ctx deny/redirect/rewrite hooks are removed here as well because an
  # older host process may have repopulated them after the global repair.
  local sanitized_hooks="${cursor_config_dir}/hooks.sanitized.json"
  jq '
    if (.hooks | type) == "object" then
      .hooks |= with_entries(
        if (.value | type) == "array" then
           .value |= map(
             select(
               ((.command // "") | contains("cursor-hook-bridge.sh") | not)
               and ((.command // "") | contains("/.cursor/plugins/") | not)
               and ((.command // "") | contains("/.claude/plugins/") | not)
               and ((.command // "") | contains("/.codex/plugins/") | not)
               and ((.command // "") | test("lean-ctx hook (deny|redirect|rewrite)") | not)
             )
           )
        else . end
      )
    else . end
  ' "${cursor_config_dir}/hooks.json" >"$sanitized_hooks"
  mv "$sanitized_hooks" "${cursor_config_dir}/hooks.json"
  cp "${cursor_config_dir}/hooks.json" "${cursor_home}/.cursor/hooks.json"
  if [[ -f "${HOME}/.cursor/cli-config.json" ]]; then
    cp "${HOME}/.cursor/cli-config.json" "${cursor_config_dir}/cli-config.json"
    cp "${HOME}/.cursor/cli-config.json" "${cursor_home}/.cursor/cli-config.json"
  fi

  # The source checkout is an explicit second Cursor root, but LeanCTX applies
  # its own MCP path jail.  Grant only this fixture's source root to the copied
  # LeanCTX server configuration so the AST-route scenario can inspect the
  # checkout without weakening the user's global configuration.
  local mcp_with_roots="${cursor_config_dir}/mcp.with-roots.json"
  jq --arg root "$SB_ROOT" \
    '.mcpServers.leanctx.env = ((.mcpServers.leanctx.env // {}) + {LEAN_CTX_EXTRA_ROOTS: $root})' \
    "${cursor_config_dir}/mcp.json" >"$mcp_with_roots"
  mv "$mcp_with_roots" "${cursor_config_dir}/mcp.json"
  cp "${cursor_config_dir}/mcp.json" "${cursor_home}/.cursor/mcp.json"

  local delegate_exit=0
  local inner_timeout="${CURSOR_AGENT_TIMEOUT:-$SCENARIO_TIMEOUT}"
  local outer_timeout="${SB_FIVE_TOOL_OUTER_TIMEOUT:-$((inner_timeout + OUTER_GRACE))}"
  local scenario_context="Perform only this scenario's requested checks. After the required checks succeed, stop immediately and emit the required result line; do not run broad test suites, inspect unrelated files, or search for alternate tool names."
  case "$id" in
    S01-opt-in)
      scenario_context+=" Set all five enabled_by_user values true in ${work_dir}/.silver-bullet.json, then run bash ${SB_ROOT}/scripts/install-leanctx-sb.sh --host cursor --project-root ${work_dir} --dry-run and inspect ${cursor_config_dir}/mcp.json for the lctx_ prefix."
      ;;
    S02-read-ast)
      scenario_context+=" Use the logical LeanCTX AST route lctx_read_ast exactly once. The current LeanCTX server exposes that route as leanctx-ctx_read (server leanctx, tool ctx_read); call it with path ${SB_ROOT}/hooks/lib/stack-compression-coordinator.sh and mode auto. Then use context-mode-ctx_search (server context-mode, tool ctx_search) once to confirm the Grep cooperative route succeeds. Do not use native Read or native Grep, and do not run the coordinator test suite."
      ;;
    S09-conflict-regression)
      scenario_context+=" Call context-mode-ctx_execute exactly once with language shell, cwd ${work_dir}, and code bash ${SB_ROOT}/tests/hooks/test-stack-compression-coordinator.sh. Confirm its output includes RTK+LeanCTX shell double-wrap denied and Results with 0 failed; that Bash test exercises sb_stack_should_deny_bash_double_wrap with an RTK-rewritten command and checks sb_stack_double_compression. Do not use native Shell, source the coordinator from the interactive shell, call leanctx-lctx_shell, or run any other test suite."
      ;;
  esac
  local scoped_prompt="${BRIEF_PREFIX} Scenario root: ${work_dir}. Source checkout: ${SB_ROOT}. Use only those two paths; do not search /Users, /tmp, or parent fixture directories, and do not read any delegate transcript. Use the configured five-tool MCP names directly. ${scenario_context} ${prompt}"
  local timed_command=(
    env
    "HOME=${cursor_home}"
    "CURSOR_AGENT_TIMEOUT=${inner_timeout}"
    "CURSOR_AGENT_MODEL=${CURSOR_AGENT_MODEL:-composer-2.5}"
    "CURSOR_MODEL=${CURSOR_MODEL:-composer-2.5}"
    "SB_AGENT_CURSOR_APPROVE_MCPS=1"
    "CURSOR_CONFIG_DIR=${cursor_config_dir}"
    "CURSOR_DATA_DIR=${cursor_data_dir}"
    bash "$DELEGATE"
    --no-escalate
    --work-dir "$work_dir"
    --prompt "$scoped_prompt"
    --log "$log"
    --sb-root "$SB_ROOT"
  )
  sb_run_with_timeout "$outer_timeout" "Cursor ${id}" -- "${timed_command[@]}" \
    >/dev/null 2>&1 || delegate_exit=$?

  cleanup_cursor_fixture_processes "$work_dir" "$cursor_home" "$cursor_config_dir" "$cursor_data_dir"

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
    "Read hooks/lib/stack-compression-coordinator.sh through the logical LeanCTX AST route lctx_read_ast and confirm Grep routing is not incorrectly denied."

  run_scenario "S04-shell-rtk" \
    "${BRIEF_PREFIX} Run git status via Bash once; confirm RTK rewrite applies and LeanCTX does not second-wrap shell."

  run_scenario "S06-graph-memory" \
    "${BRIEF_PREFIX} Run graphify query on five-tool routing and memory_save one decision; confirm lctx_remember is blocked by coordinator."

  run_scenario "S09-conflict-regression" \
    "Verify coordinator denies sb_stack_double_compression when RTK-rewritten Bash is re-offered to LeanCTX shell MCP."
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
