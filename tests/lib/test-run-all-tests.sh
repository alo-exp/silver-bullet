#!/usr/bin/env bash
# Self-tests for tests/run-all-tests.sh: sandbox isolation, --suite validation, result parsing,
# skipped-file accounting, the per-file timeout and interrupt handling.
set -euo pipefail
# shellcheck source=testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/testlib.sh"
tl_init

RUNNER="$TL_REPO_ROOT/tests/run-all-tests.sh"
# the nested runs keep this sandbox's PATH instead of rebuilding it from scratch each time
export SB_TEST_HOST_TOOLS=1
FAKE="$TL_TMP/fake"
mkdir -p "$FAKE"

# mkfake <name> <body>: a fake test file; prints its path.
mkfake() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$FAKE/$1"
  printf '%s' "$FAKE/$1"
}
# proc_alive <pid>: running (a zombie that init has not yet reaped is gone for our purposes).
proc_alive() {
  local st
  st="$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')"
  [[ -n "$st" && "$st" != Z* ]]
}
# run_runner <args...>: run the real runner on a clean slate of settings; output in TL_OUT.
run_runner() {
  tl_run env -u SB_TEST_NO_SKIP -u SB_TEST_FILE_TIMEOUT bash "$RUNNER" "$@"
}

# --- R15-01: every variable that names real host state is scrubbed ---------------------------
real="$TL_TMP/real"
mkdir -p "$real/kay/.codex/.silver-bullet" "$real/pi/.silver-bullet" "$real/codex-home" "$real/extra/.silver-bullet"
: >"$real/kay/.codex/.silver-bullet/seal.key"
: >"$real/pi/.silver-bullet/seal.key"
before="$(cd "$real" && find . | sort | tr '\n' ' ')"
probe="$(mkfake test-probe.sh 'echo "STATE=$SB_RUNTIME_STATE_DIR"; echo "HOMEROOT=$SB_RUNTIME_HOME_ROOT"; echo "HOME=$HOME"
echo "VARS=[${KAY_HOME:-}|${PI_CODING_AGENT_DIR:-}|${CODEX_HOME:-}|${CLAUDE_CONFIG_DIR:-}|${SB_RUNTIME_EXTRA_STATE_ROOTS:-}|${XDG_CONFIG_HOME:-}|${XDG_DATA_HOME:-}|${CLAUDE_PLUGIN_ROOT:-}]"
rm -f "$SB_RUNTIME_STATE_DIR/seal.key"; mkdir -p "$SB_RUNTIME_STATE_DIR"; : >"$SB_RUNTIME_STATE_DIR/fixture-file"
echo "Results: 1 passed, 0 failed"')"

tl_run env SILVER_BULLET_RUNTIME=codex KAY_HOME="$real/kay" CODEX_HOME="$real/codex-home" \
  CLAUDE_CONFIG_DIR="$real/claude" SB_RUNTIME_EXTRA_STATE_ROOTS="$real/extra/.silver-bullet" \
  XDG_CONFIG_HOME="$real/xdg" XDG_DATA_HOME="$real/xdg" CLAUDE_PLUGIN_ROOT="$real/plugin" \
  bash "$RUNNER" "$probe"
assert_eq "codex runtime with KAY_HOME exported: runner exits 0" "0" "$TL_STATUS"
home_line="$(grep '^HOME=' <<<"$TL_OUT" | head -1)"
state_line="$(grep '^STATE=' <<<"$TL_OUT" | head -1)"
assert_contains "state dir sits under the sandbox HOME" "$state_line" "STATE=${home_line#HOME=}/.codex/.silver-bullet"
assert_contains "every host-state variable is scrubbed" "$TL_OUT" "VARS=[|||||||]"
assert_eq "the seeded real KAY_HOME state is untouched" "$before" "$(cd "$real" && find . | sort | tr '\n' ' ')"

tl_run env SILVER_BULLET_RUNTIME=pi PI_CODING_AGENT_DIR="$real/pi" bash "$RUNNER" "$probe"
home_line="$(grep '^HOME=' <<<"$TL_OUT" | head -1)"
assert_contains "pi runtime with PI_CODING_AGENT_DIR exported: state under the sandbox" \
  "$(grep '^STATE=' <<<"$TL_OUT" | head -1)" "STATE=${home_line#HOME=}/.pi/agent/.silver-bullet"
assert_eq "the seeded real PI_CODING_AGENT_DIR state is untouched" "$before" "$(cd "$real" && find . | sort | tr '\n' ' ')"

# --- R15-02: git repository redirects are dropped ---------------------------------------------
gitprobe="$(mkfake test-git.sh 'd=$(mktemp -d); git -C "$d" init -q; : >"$d/f"; git -C "$d" add f
echo "INDEX=[${GIT_INDEX_FILE:-}|${GIT_OBJECT_DIRECTORY:-}|${GIT_CEILING_DIRECTORIES:-}]"; echo "Results: 1 passed, 0 failed"')"
tl_run env GIT_INDEX_FILE="$TL_TMP/outer-index" GIT_OBJECT_DIRECTORY="$TL_TMP/objs" GIT_CEILING_DIRECTORIES="$TL_TMP" \
  bash "$RUNNER" "$gitprobe"
assert_contains "GIT_* repository redirects are unset" "$TL_OUT" "INDEX=[||]"
assert_file_absent "the caller's index is never created" "$TL_TMP/outer-index"

# the same scrub applies to tl_init for a test file run directly
tl_run env KAY_HOME="$real/kay" PI_CODING_AGENT_DIR="$real/pi" SILVER_BULLET_RUNTIME=codex GIT_INDEX_FILE="$TL_TMP/x" \
  bash -c 'source "$1/tests/lib/testlib.sh"; tl_init; echo "ROOT=$SB_RUNTIME_HOME_ROOT HOME=$HOME IDX=${GIT_INDEX_FILE:-}"' _ "$TL_REPO_ROOT"
assert_match "tl_init scrubs KAY_HOME so the runtime root is inside the sandbox" 'ROOT=(/[^ ]*)/\.codex HOME=\1 IDX=$' "$TL_OUT"

# an escape from the sandbox aborts before the test body runs
tl_run bash -c 'source "$1/tests/lib/sandbox-env.sh"; HOME=/a SB_RUNTIME_HOME_ROOT=/b sb_test_assert_sandboxed' _ "$TL_REPO_ROOT"
assert_eq "a runtime root outside HOME is refused" "70" "$TL_STATUS"
assert_contains "the refusal names both paths" "$TL_ERR" "'/b' is outside the sandbox HOME '/a'"

# --- R15-04: --suite is exact and an empty selection fails -----------------------------------
run_runner --suite hoks --list
assert_eq "an unknown suite exits 64" "64" "$TL_STATUS"
assert_contains "the error names the suite and the known ones" "$TL_ERR" "unknown suite 'hoks' (known: hooks scripts"
run_runner --suite s --list
assert_eq "a substring of a suite name is not a suite" "64" "$TL_STATUS"
run_runner --suite hooks --list
assert_eq "an exact suite lists" "0" "$TL_STATUS"
assert_eq "an exact suite lists only its own group" "Hook Unit Tests" "$(cut -f1 <<<"$TL_OUT" | sort -u)"
run_runner --suite lib --list
assert_contains "a directory name selects its whole group" "$(cut -f1 <<<"$TL_OUT" | sort -u | tr '\n' ,)" "Test Harness Tests"
run_runner --suite enterprise-e2e-live --list
assert_eq "an opt-in suite is unknown while it is not enabled" "64" "$TL_STATUS"
emptydir="$TL_TMP/empty-repo"
mkdir -p "$emptydir/tests/lib" "$emptydir/hooks/lib"
cp "$RUNNER" "$emptydir/tests/"
cp "$TL_REPO_ROOT/tests/lib/sandbox-env.sh" "$emptydir/tests/lib/"
cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$TL_REPO_ROOT/hooks/lib/path-canonical.sh" "$emptydir/hooks/lib/"
tl_run bash "$emptydir/tests/run-all-tests.sh"
assert_eq "a selection with no test files exits 64" "64" "$TL_STATUS"
assert_contains "and says so" "$TL_ERR" "holds no test files"
run_runner --jobs 0
assert_eq "--jobs 0 is refused" "64" "$TL_STATUS"
run_runner --timeout soon "$probe"
assert_eq "a non-numeric timeout is refused" "64" "$TL_STATUS"
run_runner --bogus
assert_eq "an unknown option is refused" "64" "$TL_STATUS"
run_runner "$FAKE/test-moved.sh"
assert_eq "a missing explicit file exits 66" "66" "$TL_STATUS"
run_runner --help
assert_contains "--help prints the usage" "$TL_OUT" "--timeout 600"

# --- R15-05: the Results line decides ---------------------------------------------------------
a="$(mkfake test-a.sh 'echo "Results: 4 passed, 2 failed"; echo "(nested tool said: 0 failed)"; echo "summary: 9 passed"; exit 0')"
run_runner "$a"
assert_eq "failures in the Results line fail the run even if later text says 0 failed" "1" "$TL_STATUS"
assert_contains "totals come from the Results line" "$TL_OUT" "TOTAL: 4 passed, 2 failed"
b="$(mkfake test-b.sh 'echo "Results: 4 passed, 0 failed"; echo "nested: 9 passed, 7 failed"; echo "TOTAL: 1 passed, 5 failed"')"
run_runner "$b"
assert_eq "text after the Results line is ignored" "0" "$TL_STATUS"
assert_contains "pass totals are not inflated" "$TL_OUT" "TOTAL: 4 passed, 0 failed"
c="$(mkfake test-c.sh 'echo "all good"; exit 0')"
run_runner "$c"
assert_eq "exit 0 without a Results line fails" "1" "$TL_STATUS"
assert_contains "and names the missing line" "$TL_OUT" 'no "Results: N passed, M failed" line'
d="$(mkfake test-d.sh 'echo "=== widget: 3 passed, 1 failed ==="; exit 1')"
run_runner "$d"
assert_contains "a legacy labelled summary line is accepted when there is no Results line" "$TL_OUT" "TOTAL: 3 passed, 1 failed"
e="$(mkfake test-e.sh 'echo "Results: 2 passed, 0 failed"; exit 3')"
run_runner "$e"
assert_eq "a non-zero exit fails despite a clean Results line" "1" "$TL_STATUS"
assert_contains "and counts once" "$TL_OUT" "TOTAL: 2 passed, 1 failed"

# --- R15-10: skipped files are reported apart from passes -------------------------------------
sk="$(mkfake test-skip.sh 'echo "  SKIP: prerequisite missing"; echo "Results: 0 passed, 0 failed"')"
bare="$(mkfake test-bare-skip.sh 'echo "SKIP: jq required"; exit 0')"
run_runner "$bare"
assert_eq "a file that only prints SKIP and exits 0 is skipped, not failed" "0" "$TL_STATUS"
assert_contains "and is reported as skipped" "$TL_OUT" "test-bare-skip.sh (nothing ran, 1 SKIP lines)"
ok="$(mkfake test-ok.sh 'echo "PASS: x"; echo "  SKIP: optional case"; echo "Results: 1 passed, 0 failed"')"
run_runner "$sk" "$ok"
assert_eq "a skipped file does not fail the default run" "0" "$TL_STATUS"
assert_contains "the skipped file is reported" "$TL_OUT" "test-skip.sh (nothing ran, 1 SKIP lines)"
assert_contains "a partial skip is reported too" "$TL_OUT" "test-ok.sh (1 SKIP lines, the rest ran)"
assert_contains "the total counts the skipped file apart" "$TL_OUT" "TOTAL: 1 passed, 0 failed (1/1 suites green), 1 files skipped"
assert_contains "the suite line counts it" "$TL_OUT" "2 files, 1 passed, 0 failed, 1 skipped"
tl_run env SB_TEST_NO_SKIP=1 bash "$RUNNER" "$sk"
assert_eq "SB_TEST_NO_SKIP=1 fails a run that skipped a file" "1" "$TL_STATUS"
tl_run env SB_TEST_NO_SKIP=1 bash "$RUNNER" "$ok"
assert_eq "SB_TEST_NO_SKIP=1 leaves a partial skip alone" "0" "$TL_STATUS"

# --- R15-11: a hung file is stopped by its recorded process group ----------------------------
pidfile="$TL_TMP/child.pid"
hung="$(mkfake test-hung.sh "sleep 300 & echo \$! >'$pidfile'; echo started; wait")"
run_runner_t() { tl_run env SB_TEST_FILE_TIMEOUT=2 SB_TEST_KILL_GRACE=1 bash "$RUNNER" "$@"; }
run_runner_t "$hung"
assert_eq "a file past the timeout fails the run" "1" "$TL_STATUS"
assert_contains "the failure names the file and the limit" "$TL_ERR" "test-hung.sh exceeded 2s"
assert_contains "the log says it timed out" "$TL_OUT" "timed out after 2s"
assert_contains "the failure report lists it with exit 124" "$TL_OUT" "test-hung.sh (exit 124)"
child="$(cat "$pidfile")"
if proc_alive "$child"; then
  kill -KILL "$child" 2>/dev/null || true
  tl_fail "the timeout stops the hung file's children (process group)"
else
  tl_pass "the timeout stops the hung file's children (process group)"
fi
stubborn="$(mkfake test-stubborn.sh "trap '' TERM; sleep 300 & echo \$! >'$pidfile'; while :; do sleep 1; done")"
run_runner_t "$stubborn"
assert_eq "a file that ignores SIGTERM is killed after the grace period" "1" "$TL_STATUS"
child="$(cat "$pidfile")"
if proc_alive "$child"; then
  kill -KILL "$child" 2>/dev/null || true
  tl_fail "SIGKILL reaches the ignoring file's group"
else
  tl_pass "SIGKILL reaches the ignoring file's group"
fi
tl_run env SB_TEST_FILE_TIMEOUT=0 bash "$RUNNER" "$ok"
assert_eq "a timeout of 0 disables the limit" "0" "$TL_STATUS"

# --- an interrupted runner stops the tests it started and cleans up ---------------------------
rm -f "$pidfile"
waiter="$(mkfake test-wait.sh "sleep 300 & echo \$! >'$pidfile'; wait")"
bash "$RUNNER" "$waiter" >"$TL_TMP/interrupted.out" 2>&1 &
runner_pid=$!
for _ in $(seq 1 100); do [[ -s "$pidfile" ]] && break; sleep 0.1; done
kill -TERM "$runner_pid"
rstatus=0
wait "$runner_pid" || rstatus=$?
assert_eq "an interrupted runner exits 130" "130" "$rstatus"
child="$(cat "$pidfile")"
if proc_alive "$child"; then
  kill -KILL "$child" 2>/dev/null || true
  tl_fail "an interrupted runner leaves no test process behind"
else
  tl_pass "an interrupted runner leaves no test process behind"
fi

tl_results
