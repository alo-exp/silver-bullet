#!/usr/bin/env bash
# Unified test runner: hook unit tests, script unit tests, integration scenarios,
# harness self-tests, E2E-live harness checks, TUI contracts and the coverage matrix.
#
# Usage:
#   bash tests/run-all-tests.sh                  # every default suite
#   bash tests/run-all-tests.sh --jobs 4         # run test files in parallel
#   bash tests/run-all-tests.sh --suite hooks    # suites whose directory matches
#   bash tests/run-all-tests.sh tests/hooks/test-ci-status-check.sh   # given files only
#   bash tests/run-all-tests.sh --list           # print the test files and exit
#
# Isolation: every test file runs with its own temporary HOME (so runtime state under
# ~/.claude, ~/.codex, ~/.cursor never touches the real home directory) and with
# optional host tools hidden from PATH (graphify, agentmemory, claude, gh, ...), so
# local results match CI. Set SB_TEST_HOST_TOOLS=1 to keep them visible, or
# SB_TEST_HIDE_TOOLS="a b c" to choose the hidden set.
#
# Opt-in live suites:
#   SB_ENTERPRISE_E2E_LIVE=1  adds tests/enterprise-e2e-live (structural validation of
#                             the operator-only interactive Claude TUI matrix; full live
#                             matrix: bash scripts/run-enterprise-e2e-live-test.sh, see
#                             docs/ENTERPRISE-E2E-LIVE-TEST.md)
#   SB_FIVE_TOOL_LIVE=1       adds tests/live/test-live-five-tool-stack-cursor.sh
#                             (the pre-release gate runs test-five-tool-prerelease-cursor.sh)
#
# Coverage: tests/coverage/run-coverage.sh runs this script with SB_COV_DIR set; each
# test file then traces into its own directory and is folded in when it finishes.
set -euo pipefail

# Default to Claude runtime for live/E2E verification; Kay remains available via
# scripts/run-sb-live-tests-kay.sh when isolated Codex-compatible runs are needed.
: "${SILVER_BULLET_RUNTIME:=claude}"
export SILVER_BULLET_RUNTIME

export SB_LIVE_AGENT="${SB_LIVE_AGENT:-claude}"
export SB_E2E_LIVE_AGENT="${SB_E2E_LIVE_AGENT:-claude}"
export SB_LIVE_RUNTIMES="${SB_LIVE_RUNTIMES:-claude}"
export SB_E2E_LIVE_RUNTIMES="${SB_E2E_LIVE_RUNTIMES:-claude}"
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT="${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-1}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# A UTF-8 locale like CI's; some tests read non-ASCII skill files.
if [[ -z "${LANG:-}" && -z "${LC_ALL:-}" ]]; then
  export LANG=C.UTF-8
fi

JOBS="${SB_TEST_JOBS:-1}"
LIST_ONLY=0
SUITE_FILTER=()
EXPLICIT_FILES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -j|--jobs) JOBS="$2"; shift 2 ;;
    --suite) SUITE_FILTER+=("$2"); shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "run-all-tests: unknown option $1" >&2; exit 64 ;;
    *) EXPLICIT_FILES+=("$1"); shift ;;
  esac
done
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "run-all-tests: --jobs needs a positive integer" >&2; exit 64; }

# label|directory, in execution order.
SUITES=(
  "Hook Unit Tests|hooks"
  "Script Unit Tests|scripts"
  "Integration Scenario Tests|integration"
  "Test Harness Tests|lib coverage"
  "Documentation Tests|docs"
  "E2E Live Harness Tests|e2e-live"
  "TUI Contract Tests|tui-contract"
)
if [[ "${SB_ENTERPRISE_E2E_LIVE:-}" == "1" ]]; then
  SUITES+=("Enterprise E2E Live Tests|enterprise-e2e-live")
fi

suite_selected() {
  local dirs="$1" f
  [[ ${#SUITE_FILTER[@]} -eq 0 ]] && return 0
  for f in "${SUITE_FILTER[@]}"; do
    [[ " $dirs " == *" $f "* || " $dirs " == *"$f"* ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Isolation helpers
# ---------------------------------------------------------------------------
RUN_TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-run-all.XXXXXX")"
cleanup_run() { rm -rf "$RUN_TMP"; }
trap cleanup_run EXIT

# Pin the Python user site before HOME changes so user-installed packages still import.
if [[ -z "${PYTHONUSERBASE:-}" ]] && command -v python3 >/dev/null 2>&1; then
  PYTHONUSERBASE="$(python3 -m site --user-base 2>/dev/null || true)"
  [[ -n "$PYTHONUSERBASE" ]] && export PYTHONUSERBASE
fi

HIDE_TOOLS="${SB_TEST_HIDE_TOOLS:-graphify agentmemory iii context-mode rtk lean-ctx claude codex cursor-agent agent opencode pi kay gh alumnium search uv uvx pipx brew}"
TEST_PATH="$PATH"
if [[ "${SB_TEST_HOST_TOOLS:-0}" != "1" && -n "$HIDE_TOOLS" ]]; then
  # Rebuild PATH as one directory of symlinks without the hidden tools. The first
  # occurrence of a name wins, matching normal PATH lookup.
  safe_bin="$RUN_TMP/path"
  mkdir -p "$safe_bin"
  IFS=: read -r -a _path_dirs <<<"$PATH"
  for _dir in "${_path_dirs[@]}"; do
    [[ -d "$_dir" ]] || continue
    for _entry in "$_dir"/*; do
      _name="${_entry##*/}"
      [[ -x "$_entry" && ! -e "$safe_bin/$_name" && ! -L "$safe_bin/$_name" ]] || continue
      [[ " $HIDE_TOOLS " == *" $_name "* ]] && continue
      ln -s "$_entry" "$safe_bin/$_name"
    done
  done
  TEST_PATH="$safe_bin"
fi

COV_MAIN="${SB_COV_DIR:-}"

# run_one <test-file> <log> : run one test file in its own sandbox; writes <log>.status.
run_one() {
  local test_file="$1" log="$2"
  local sandbox="$RUN_TMP/job.${log##*/}"
  mkdir -p "$sandbox/home" "$sandbox/tmp"
  local start=$SECONDS status=0
  (
    export HOME="$sandbox/home"
    export TMPDIR="$sandbox/tmp"
    export PATH="$TEST_PATH"
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME \
      SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME \
      SB_RUNTIME_PRESERVE_STATE_DIR SILVER_BULLET_STATE_FILE SILVER_BULLET_BRANCH_FILE
    # shellcheck source=../hooks/lib/runtime-paths.sh
    source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
    export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME
    if [[ -n "$COV_MAIN" ]]; then
      export SB_COV_MAIN_DIR="$COV_MAIN"
      export SB_COV_DIR="$sandbox/cov"
      mkdir -p "$SB_COV_DIR/raw"
    fi
    cd "$REPO_ROOT"
    bash "$test_file" </dev/null
  ) >"$log" 2>&1 || status=$?
  printf '%s %s\n' "$status" "$((SECONDS - start))" >"$log.status"
}

# finish_one <log>: fold coverage traces and remove the sandbox (serialised in the parent).
finish_one() {
  local log="$1" sandbox="$RUN_TMP/job.${1##*/}"
  if [[ -n "$COV_MAIN" && -d "$sandbox/cov" ]]; then
    python3 "$REPO_ROOT/tests/coverage/sbcov.py" collect --cov-dir "$sandbox/cov" >/dev/null 2>&1 || true
    python3 "$REPO_ROOT/tests/coverage/sbcov.py" merge --cov-dir "$COV_MAIN" "$sandbox/cov/bash-hits.json" >/dev/null 2>&1 || true
  fi
  rm -rf "$sandbox"
}

# ---------------------------------------------------------------------------
# Collect test files
# ---------------------------------------------------------------------------
declare -a ALL_FILES=() ALL_SUITE=()
if [[ ${#EXPLICIT_FILES[@]} -gt 0 ]]; then
  for f in "${EXPLICIT_FILES[@]}"; do
    [[ -f "$f" ]] || { echo "run-all-tests: no such test file: $f" >&2; exit 66; }
    ALL_FILES+=("$(cd "$(dirname "$f")" && pwd)/$(basename "$f")")
    ALL_SUITE+=("Selected Tests")
  done
else
  for entry in "${SUITES[@]}"; do
    label="${entry%%|*}"
    dirs="${entry#*|}"
    suite_selected "$dirs" || continue
    for d in $dirs; do
      for test_file in "$SCRIPT_DIR/$d"/test-*.sh; do
        [[ -f "$test_file" ]] || continue
        ALL_FILES+=("$test_file")
        ALL_SUITE+=("$label")
      done
    done
  done
fi

if [[ "$LIST_ONLY" -eq 1 ]]; then
  for i in "${!ALL_FILES[@]}"; do printf '%s\t%s\n' "${ALL_SUITE[$i]}" "${ALL_FILES[$i]#"$REPO_ROOT"/}"; done
  exit 0
fi

# ---------------------------------------------------------------------------
# Execute (up to $JOBS at a time) and report in a stable order
# ---------------------------------------------------------------------------
TOTAL_PASS=0
TOTAL_FAIL=0
SUITE_PASS=0
SUITE_FAIL=0
declare -a TIMINGS=()

n=${#ALL_FILES[@]}
declare -a PIDS=()
declare -A DONE=()
next_to_start=0
next_to_print=0
current_suite=""
suite_files=0
suite_pass=0
suite_fail=0
declare -a suite_failed_files=()

close_suite() {
  [[ -z "$current_suite" ]] && return 0
  printf '\n%s: %d files, %d passed, %d failed\n' "$current_suite" "$suite_files" "$suite_pass" "$suite_fail"
  if [[ ${#suite_failed_files[@]} -gt 0 ]]; then
    printf 'Failed test files: %s\n' "${suite_failed_files[*]}"
  fi
  TOTAL_PASS=$((TOTAL_PASS + suite_pass))
  TOTAL_FAIL=$((TOTAL_FAIL + suite_fail))
  if [[ $suite_fail -eq 0 ]]; then SUITE_PASS=$((SUITE_PASS + 1)); else SUITE_FAIL=$((SUITE_FAIL + 1)); fi
}

print_result() {
  local i="$1" log="$RUN_TMP/log.$1"
  local test_file="${ALL_FILES[$i]}" suite="${ALL_SUITE[$i]}"
  if [[ "$suite" != "$current_suite" ]]; then
    close_suite
    current_suite="$suite"
    suite_files=0 suite_pass=0 suite_fail=0
    suite_failed_files=()
    printf '\n========================================\n'
    printf '  %s\n' "$suite"
    printf '========================================\n\n'
  fi
  local base output exit_code secs p f
  base="$(basename "$test_file")"
  read -r exit_code secs <"$log.status"
  output="$(cat "$log")"
  echo "[ $base ]"
  printf '%s\n' "$output"
  suite_files=$((suite_files + 1))
  # Extract PASS/FAIL counts from the last "Results: N passed, M failed" line.
  p=$(printf '%s' "$output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1 || echo "0")
  f=$(printf '%s' "$output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | tail -1 || echo "0")
  p=${p:-0}
  f=${f:-0}
  suite_pass=$((suite_pass + p))
  suite_fail=$((suite_fail + f))
  if [[ $exit_code -ne 0 ]]; then
    # Some contract tests fail before printing a Results line. Count the
    # non-zero file once when its own reported failure count is zero.
    [[ $f -eq 0 ]] && suite_fail=$((suite_fail + 1))
    suite_failed_files+=("$base")
    printf '  *** SUITE FAILED (exit %d) ***\n\n' "$exit_code"
  fi
  TIMINGS+=("$secs ${test_file#"$REPO_ROOT"/}")
}

while [[ $next_to_print -lt $n ]]; do
  # Start jobs while there is capacity.
  while [[ $next_to_start -lt $n && ${#PIDS[@]} -lt $JOBS ]]; do
    run_one "${ALL_FILES[$next_to_start]}" "$RUN_TMP/log.$next_to_start" &
    PIDS+=("$!:$next_to_start")
    next_to_start=$((next_to_start + 1))
  done
  # Reap finished jobs.
  declare -a still=()
  reaped=0
  for entry in "${PIDS[@]}"; do
    pid="${entry%%:*}"
    idx="${entry#*:}"
    if kill -0 "$pid" 2>/dev/null; then
      still+=("$entry")
    else
      wait "$pid" 2>/dev/null || true
      finish_one "$RUN_TMP/log.$idx"
      DONE[$idx]=1
      reaped=1
    fi
  done
  PIDS=("${still[@]+"${still[@]}"}")
  unset still
  # Print every finished result that is next in order.
  while [[ $next_to_print -lt $n && -n "${DONE[$next_to_print]:-}" ]]; do
    print_result "$next_to_print"
    next_to_print=$((next_to_print + 1))
  done
  [[ $reaped -eq 0 && $next_to_print -lt $n ]] && sleep 0.1
done
close_suite

# Five-tool live Cursor validation (agent-cursor harness). Offline hook/script tests above always run.
# Pre-release gate (scripts/pre-release-gate.sh Stage 4c) invokes test-five-tool-prerelease-cursor.sh.
# Optional manual full live: SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=full
if [[ "${SB_FIVE_TOOL_LIVE:-}" == "1" && ${#EXPLICIT_FILES[@]} -eq 0 ]]; then
  printf '\n========================================\n'
  printf '  Five-Tool Live Tests (Cursor)\n'
  printf '========================================\n\n'
  live_file="$SCRIPT_DIR/live/test-live-five-tool-stack-cursor.sh"
  if [[ -f "$live_file" ]]; then
    echo "[ $(basename "$live_file") ]"
    live_exit=0
    live_output=$(bash "$live_file" </dev/null 2>&1) || live_exit=$?
    printf '%s\n' "$live_output"
    lp=$(printf '%s' "$live_output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1 || echo "0")
    lf=$(printf '%s' "$live_output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | tail -1 || echo "0")
    lp=${lp:-0}
    lf=${lf:-0}
    TOTAL_PASS=$((TOTAL_PASS + lp))
    TOTAL_FAIL=$((TOTAL_FAIL + lf))
    if [[ $live_exit -ne 0 || "$lf" -gt 0 ]]; then
      SUITE_FAIL=$((SUITE_FAIL + 1))
      printf '  *** SUITE FAILED (exit %d) ***\n\n' "$live_exit"
    else
      SUITE_PASS=$((SUITE_PASS + 1))
    fi
    printf '\nFive-Tool Live: %d passed, %d failed\n' "$lp" "$lf"
  fi
fi

# Coverage matrix: every hook registered in hooks.json is exercised by some test.
coverage_exit=0
if [[ ${#EXPLICIT_FILES[@]} -eq 0 && ${#SUITE_FILTER[@]} -eq 0 ]]; then
  printf '\n========================================\n'
  printf '  Coverage Matrix\n'
  printf '========================================\n\n'
  bash "$SCRIPT_DIR/integration/coverage-matrix.sh" || coverage_exit=$?
  if [[ $coverage_exit -ne 0 ]]; then
    SUITE_FAIL=$((SUITE_FAIL + 1))
  else
    SUITE_PASS=$((SUITE_PASS + 1))
  fi
fi

if [[ ${#TIMINGS[@]} -gt 0 ]]; then
  printf '\nSlowest test files:\n'
  printf '%s\n' "${TIMINGS[@]}" | sort -rn | head -5 | awk '{printf "  %4ss  %s\n", $1, $2}'
fi

printf '\n========================================\n'
printf '  TOTAL: %d passed, %d failed (%d/%d suites green)\n' \
  "$TOTAL_PASS" "$TOTAL_FAIL" "$SUITE_PASS" "$((SUITE_PASS + SUITE_FAIL))"
printf '========================================\n'

[[ $TOTAL_FAIL -eq 0 && $coverage_exit -eq 0 ]] && exit 0 || exit 1
