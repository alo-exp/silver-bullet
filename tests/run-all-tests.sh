#!/usr/bin/env bash
# Unified test runner: hook unit tests, script unit tests, integration scenarios,
# harness self-tests, E2E-live harness checks, TUI contracts and the coverage matrix.
#
# Usage:
#   bash tests/run-all-tests.sh                  # every default suite
#   bash tests/run-all-tests.sh --jobs 4         # run test files in parallel
#   bash tests/run-all-tests.sh --suite hooks    # suites with exactly this directory name (unknown: exit 64)
#   bash tests/run-all-tests.sh tests/hooks/test-ci-status-check.sh   # given files only
#   bash tests/run-all-tests.sh --list           # print the test files and exit
#   bash tests/run-all-tests.sh --timeout 600    # per-file time limit in seconds (0 = none)
#
# Isolation: every test file runs with its own temporary HOME (so runtime state under
# ~/.claude, ~/.codex never touches the real home directory), with every variable that
# names real host state scrubbed (KAY_HOME, PI_CODING_AGENT_DIR, CODEX_HOME, XDG_*, GIT_*
# repository redirects, ...; see tests/lib/sandbox-env.sh), and with optional host tools
# hidden from PATH (graphify, agentmemory, claude, gh, ...), so local results match CI.
# Set SB_TEST_HOST_TOOLS=1 to keep them visible, or SB_TEST_HIDE_TOOLS="a b c" to choose
# the hidden set.
#
# Results: a file's counts come from its last "Results: N passed, M failed" line (a legacy
# "<label>: N passed, M failed" summary line is accepted when there is none). A file that
# exits 0 without any such line fails, unless it printed SKIP lines. A file that ran nothing
# (a summary of 0 passed, 0 failed, or only SKIP lines) is reported as skipped, never as a
# pass, and SB_TEST_NO_SKIP=1 fails the run for it. SB_TEST_FILE_TIMEOUT (default 1800 s) limits one file; on expiry its process group
# (recorded at launch) gets SIGTERM, then SIGKILL after SB_TEST_KILL_GRACE (10) seconds, and the file fails.
#
# Opt-in live suites:
#   SB_ENTERPRISE_E2E_LIVE=1  adds tests/enterprise-e2e-live (structural validation of
#                             the operator-only interactive Claude TUI matrix; full live
#                             matrix: bash scripts/run-enterprise-e2e-live-test.sh, see
#                             docs/ENTERPRISE-E2E-LIVE-TEST.md)
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
FILE_TIMEOUT="${SB_TEST_FILE_TIMEOUT:-1800}"
KILL_GRACE="${SB_TEST_KILL_GRACE:-10}"
LIST_ONLY=0
SUITE_FILTER=()
EXPLICIT_FILES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -j|--jobs) JOBS="$2"; shift 2 ;;
    --suite) SUITE_FILTER+=("$2"); shift 2 ;;
    --timeout) FILE_TIMEOUT="$2"; shift 2 ;;
    --list) LIST_ONLY=1; shift ;;
    -h|--help) sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "run-all-tests: unknown option $1" >&2; exit 64 ;;
    *) EXPLICIT_FILES+=("$1"); shift ;;
  esac
done
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "run-all-tests: --jobs needs a positive integer" >&2; exit 64; }
[[ "$FILE_TIMEOUT" =~ ^[0-9]+$ ]] || { echo "run-all-tests: the timeout needs a number of seconds (0 disables it)" >&2; exit 64; }

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

# A filter selects a suite only by the exact name of one of its directories.
suite_selected() {
  local dirs="$1" f
  [[ ${#SUITE_FILTER[@]} -eq 0 ]] && return 0
  for f in "${SUITE_FILTER[@]}"; do
    [[ " $dirs " == *" $f "* ]] && return 0
  done
  return 1
}

# An unknown --suite value would otherwise run nothing and report green.
for _f in "${SUITE_FILTER[@]+"${SUITE_FILTER[@]}"}"; do
  _known=0
  for _entry in "${SUITES[@]}"; do
    [[ " ${_entry#*|} " == *" $_f "* ]] && _known=1
  done
  if [[ "$_known" -eq 0 ]]; then
    _names=""
    for _entry in "${SUITES[@]}"; do _names="$_names ${_entry#*|}"; done
    echo "run-all-tests: unknown suite '$_f' (known:$_names)" >&2
    exit 64
  fi
done

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
      if [[ -f "${_dir%/}/../pyvenv.cfg" && "$_name" == python* ]]; then
        # A symlink to a venv's python resolves to the base interpreter, which then
        # ignores the venv's packages; exec through the venv path keeps it active.
        _quoted="'${_entry//\'/\'\\\'\'}'"  # single-quoted, so $ ` " \ in the path stay literal
        printf '#!/bin/sh\nexec %s "$@"\n' "$_quoted" >"$safe_bin/$_name"
        chmod +x "$safe_bin/$_name"
      else
        ln -s "$_entry" "$safe_bin/$_name"
      fi
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
    # every variable that names real host state (KAY_HOME, PI_CODING_AGENT_DIR, CODEX_HOME, XDG_*, git
    # repository redirects such as GIT_INDEX_FILE, ...) is dropped before the runtime paths are recomputed
    # shellcheck source=lib/sandbox-env.sh
    source "$SCRIPT_DIR/lib/sandbox-env.sh"
    sb_test_scrub_host_env
    # shellcheck source=../hooks/lib/runtime-paths.sh
    source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
    export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME
    sb_test_assert_sandboxed
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

if [[ ${#ALL_FILES[@]} -eq 0 ]]; then
  echo "run-all-tests: the selection holds no test files" >&2
  exit 64
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
# Failing files with their FAIL lines, repeated at the end so a truncated CI log
# still shows every failure next to the totals.
declare -a FAILURE_REPORT=()

n=${#ALL_FILES[@]}
declare -a PIDS=()
declare -A FINISHED=()
next_to_start=0
next_to_print=0
current_suite=""
suite_files=0
suite_pass=0
suite_fail=0
declare -a suite_failed_files=()
suite_skipped=0
TOTAL_SKIPPED=0
declare -a SKIP_REPORT=()

close_suite() {
  [[ -z "$current_suite" ]] && return 0
  printf '\n%s: %d files, %d passed, %d failed' "$current_suite" "$suite_files" "$suite_pass" "$suite_fail"
  [[ $suite_skipped -eq 0 ]] || printf ', %d skipped' "$suite_skipped"
  printf '\n'
  TOTAL_SKIPPED=$((TOTAL_SKIPPED + suite_skipped))
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
    suite_files=0 suite_pass=0 suite_fail=0 suite_skipped=0
    suite_failed_files=()
    printf '\n========================================\n'
    printf '  %s\n' "$suite"
    printf '========================================\n\n'
  fi
  local base output exit_code secs p=0 f=0 line have_results=0 skip_lines
  base="$(basename "$test_file")"
  read -r exit_code secs <"$log.status"
  output="$(cat "$log")"
  echo "[ $base ]"
  printf '%s\n' "$output"
  suite_files=$((suite_files + 1))
  # A file's counts come from its last "Results: N passed, M failed" line; only without one is a
  # legacy "<label>: N passed, M failed" summary line accepted. Any other line that merely mentions
  # a count (a nested tool's output, an echoed fixture) is ignored.
  line="$(printf '%s\n' "$output" | grep -E '^Results: [0-9]+ passed, [0-9]+ failed[[:space:]]*$' | tail -n 1 || true)"
  [[ -n "$line" ]] || line="$(printf '%s\n' "$output" | grep -E '^[=[:space:]]*([A-Za-z][A-Za-z0-9 _-]*:[[:space:]]*)?[0-9]+ passed, [0-9]+ failed[[:space:]=]*$' | tail -n 1 || true)"
  if [[ "$line" =~ ([0-9]+)\ passed,\ ([0-9]+)\ failed ]]; then
    p="${BASH_REMATCH[1]}" f="${BASH_REMATCH[2]}" have_results=1
  fi
  suite_pass=$((suite_pass + p))
  suite_fail=$((suite_fail + f))
  skip_lines="$(printf '%s\n' "$output" | grep -cE '^ *SKIP' || true)"
  if [[ $exit_code -ne 0 ]]; then
    # Some contract tests fail before printing a Results line. Count the
    # non-zero file once when its own reported failure count is zero.
    [[ $f -eq 0 ]] && suite_fail=$((suite_fail + 1))
    suite_failed_files+=("$base")
    if [[ $exit_code -eq 124 ]]; then
      printf '  *** SUITE FAILED (timed out after %ss) ***\n\n' "$FILE_TIMEOUT"
    else
      printf '  *** SUITE FAILED (exit %d) ***\n\n' "$exit_code"
    fi
  elif [[ $have_results -eq 0 && $skip_lines -eq 0 ]]; then
    # A file that exits 0 without reporting any result proves nothing.
    suite_fail=$((suite_fail + 1))
    suite_failed_files+=("$base")
    printf '  *** SUITE FAILED (exit 0 but no "Results: N passed, M failed" line) ***\n\n'
    exit_code=65
  elif [[ $p -eq 0 && $f -eq 0 ]]; then
    # It ran nothing (a missing prerequisite, for example, which prints SKIP and exits 0, with or
    # without a Results line): reported apart from the passes.
    suite_skipped=$((suite_skipped + 1))
    SKIP_REPORT+=("${test_file#"$REPO_ROOT"/} (nothing ran, $skip_lines SKIP lines)")
    printf '  *** SKIPPED (0 passed, 0 failed) ***\n\n'
    if [[ "${SB_TEST_NO_SKIP:-0}" == "1" ]]; then
      suite_fail=$((suite_fail + 1))
      suite_failed_files+=("$base")
      exit_code=66
    fi
  elif [[ $skip_lines -gt 0 ]]; then
    SKIP_REPORT+=("${test_file#"$REPO_ROOT"/} ($skip_lines SKIP lines, the rest ran)")
  fi
  if [[ $exit_code -ne 0 || $f -gt 0 ]]; then
    FAILURE_REPORT+=("${test_file#"$REPO_ROOT"/} (exit $exit_code)")
    while IFS= read -r line; do
      FAILURE_REPORT+=("    $line")
    done < <(printf '%s\n' "$output" | grep -E '^ *(FAIL|✗|❌)' | awk 'NR <= 10')
  fi
  TIMINGS+=("$secs ${test_file#"$REPO_ROOT"/}")
}

# Job control gives every background test its own process group (the group id is the job's
# pid), so a timeout or an interrupt can stop the whole tree by that recorded id, never by name.
set -m
declare -A STARTED=() TIMED_OUT=() TERM_AT=()

# stop_group <pgid> <signal>: signal the process group that launch created for a test (its id is
# the job's pid, recorded when the job started). The runner's own group is never signalled: if job
# control did not give the job a group of its own, only the job's pid is.
OWN_PGID="$(ps -o pgid= -p $$ | tr -d ' ')"
# group_alive <pgid>: a process of the group is still running (a zombie whose parent died with the
# group may stay in the table, so it does not count).
group_alive() {
  ps -eo pgid=,stat= 2>/dev/null | awk -v g="$1" '$1 == g && $2 !~ /^Z/ {found = 1} END {exit !found}'
}
stop_group() {
  local pgid="$1" sig="$2"
  if [[ "$pgid" != "$OWN_PGID" ]] && group_alive "$pgid"; then
    kill "-$sig" -- "-$pgid" 2>/dev/null || true
  else
    kill "-$sig" "$pgid" 2>/dev/null || true
  fi
}

# An interrupt of the runner stops every test it started, then the sandbox goes.
abort_run() {
  local entry
  trap '' INT TERM
  for entry in "${PIDS[@]+"${PIDS[@]}"}"; do stop_group "${entry%%:*}" TERM; done
  sleep 1
  for entry in "${PIDS[@]+"${PIDS[@]}"}"; do stop_group "${entry%%:*}" KILL; done
  exit 130
}
trap abort_run INT TERM

while [[ $next_to_print -lt $n ]]; do
  # Start jobs while there is capacity.
  while [[ $next_to_start -lt $n && ${#PIDS[@]} -lt $JOBS ]]; do
    run_one "${ALL_FILES[$next_to_start]}" "$RUN_TMP/log.$next_to_start" &
    PIDS+=("$!:$next_to_start")
    STARTED[$next_to_start]=$SECONDS
    next_to_start=$((next_to_start + 1))
  done
  # Reap finished jobs.
  declare -a still=()
  reaped=0
  for entry in "${PIDS[@]}"; do
    pid="${entry%%:*}"
    idx="${entry#*:}"
    # A stopped job counts as running while any process of its group is left: the leader can die on
    # SIGTERM while its test, which ignores it, goes on.
    if { [[ -z "${TIMED_OUT[$idx]:-}" ]] && kill -0 "$pid" 2>/dev/null; } ||
      { [[ -n "${TIMED_OUT[$idx]:-}" ]] && group_alive "$pid"; }; then
      still+=("$entry")
      if [[ "$FILE_TIMEOUT" -gt 0 ]]; then
        if [[ -z "${TIMED_OUT[$idx]:-}" && $((SECONDS - STARTED[$idx])) -ge $FILE_TIMEOUT ]]; then
          TIMED_OUT[$idx]=1 TERM_AT[$idx]=$SECONDS
          echo "run-all-tests: ${ALL_FILES[$idx]#"$REPO_ROOT"/} exceeded ${FILE_TIMEOUT}s; stopping process group $pid" >&2
          stop_group "$pid" TERM
        elif [[ -n "${TIMED_OUT[$idx]:-}" && $((SECONDS - TERM_AT[$idx])) -ge $KILL_GRACE ]]; then
          stop_group "$pid" KILL
        fi
      fi
    else
      wait "$pid" 2>/dev/null || true
      if [[ -n "${TIMED_OUT[$idx]:-}" ]]; then
        printf '\nrun-all-tests: timed out after %ss and was stopped\n' "$FILE_TIMEOUT" >>"$RUN_TMP/log.$idx"
        printf '124 %s\n' "$((SECONDS - STARTED[$idx]))" >"$RUN_TMP/log.$idx.status"
      fi
      finish_one "$RUN_TMP/log.$idx"
      FINISHED[$idx]=1
      reaped=1
    fi
  done
  PIDS=("${still[@]+"${still[@]}"}")
  unset still
  # Print every finished result that is next in order.
  while [[ $next_to_print -lt $n && -n "${FINISHED[$next_to_print]:-}" ]]; do
    print_result "$next_to_print"
    next_to_print=$((next_to_print + 1))
  done
  [[ $reaped -eq 0 && $next_to_print -lt $n ]] && sleep 0.1
done
close_suite

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
  # awk reads all of sort's output: `head` would close the pipe early, and the
  # resulting SIGPIPE fails the whole runner under pipefail.
  printf '%s\n' "${TIMINGS[@]}" | sort -rn | awk 'NR <= 5 {printf "  %4ss  %s\n", $1, $2}'
fi

if [[ ${#SKIP_REPORT[@]} -gt 0 ]]; then
  printf '\nSkipped (never counted as passes; SB_TEST_NO_SKIP=1 fails the run for files that ran nothing):\n'
  printf '  %s\n' "${SKIP_REPORT[@]}"
fi

if [[ ${#FAILURE_REPORT[@]} -gt 0 ]]; then
  printf '\nFailures:\n'
  printf '  %s\n' "${FAILURE_REPORT[@]}"
fi

printf '\n========================================\n'
printf '  TOTAL: %d passed, %d failed (%d/%d suites green)' \
  "$TOTAL_PASS" "$TOTAL_FAIL" "$SUITE_PASS" "$((SUITE_PASS + SUITE_FAIL))"
[[ $TOTAL_SKIPPED -eq 0 ]] || printf ', %d files skipped' "$TOTAL_SKIPPED"
printf '\n'
printf '========================================\n'

[[ $TOTAL_FAIL -eq 0 && $coverage_exit -eq 0 ]] && exit 0 || exit 1
