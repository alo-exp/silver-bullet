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

# every GIT_* variable git documents that redirects the repository, index, objects, config, hooks, ssh,
# askpass, editor, exec path or templates: all are unset, the commit identity and the prompt switch stay
git_vars=(GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_INDEX_VERSION GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  GIT_COMMON_DIR GIT_NAMESPACE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM GIT_CONFIG GIT_CONFIG_GLOBAL
  GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_PARAMETERS
  GIT_EXEC_PATH GIT_TEMPLATE_DIR GIT_SSH GIT_SSH_COMMAND GIT_ASKPASS GIT_EDITOR GIT_SEQUENCE_EDITOR GIT_PAGER
  GIT_EXTERNAL_DIFF GIT_PROXY_COMMAND GIT_SSL_NO_VERIFY GIT_SSL_CAINFO GIT_TRACE GIT_TRACE2 GIT_REPLACE_REF_BASE
  GIT_NO_REPLACE_OBJECTS GIT_GRAFT_FILE GIT_SHALLOW_FILE GIT_PREFIX GIT_IMPLICIT_WORK_TREE GIT_ATTR_SOURCE
  GIT_ATTR_NOSYSTEM GIT_PROTOCOL_FROM_USER GIT_ALLOW_PROTOCOL GIT_CURL_VERBOSE GIT_REDIRECT_STDERR GIT_OPTIONAL_LOCKS
  GIT_DEFAULT_HASH GIT_MERGE_AUTOEDIT GIT_LITERAL_PATHSPECS GIT_QUARANTINE_PATH GIT_CONFIG_NOGLOBAL)
leak_cfg="$TL_TMP/leak.gitconfig"
printf '[probe]\n\tleak = yes\n[commit]\n\tgpgsign = true\n' >"$leak_cfg"
envprobe="$(mkfake test-gitvars.sh 'echo "LEFT=[$(env | grep -E "^GIT_" | grep -vE "^GIT_(AUTHOR|COMMITTER)_|^GIT_TERMINAL_PROMPT=" | cut -d= -f1 | tr "\n" " ")]"
echo "LEAK=[$(git config --get probe.leak || true)]"; echo "KEEP=[${GIT_AUTHOR_NAME:-}|${GIT_TERMINAL_PROMPT:-}]"; echo "Results: 1 passed, 0 failed"')"
envargs=()
for v in "${git_vars[@]}"; do envargs+=("$v=$leak_cfg"); done
tl_run env "${envargs[@]}" GIT_CONFIG_GLOBAL="$leak_cfg" GIT_AUTHOR_NAME=kept GIT_TERMINAL_PROMPT=0 bash "$RUNNER" "$envprobe"
assert_contains "no GIT_* redirect survives the runner (table of ${#git_vars[@]} variables)" "$TL_OUT" "LEFT=[]"
assert_contains "a leaked GIT_CONFIG_GLOBAL file is not read by git in the test" "$TL_OUT" "LEAK=[]"
assert_contains "the commit identity and the prompt switch are kept" "$TL_OUT" "KEEP=[kept|0]"
for v in "${git_vars[@]}"; do
  tl_run env "$v=$leak_cfg" bash -c 'source "$1/tests/lib/sandbox-env.sh"; sb_test_scrub_host_env; [[ -z "${!2+x}" ]]' _ "$TL_REPO_ROOT" "$v"
  assert_eq "sb_test_scrub_host_env unsets $v" "0" "$TL_STATUS"
done

# the runner aborts (70) before the test body when the sandbox check fails: drop KAY_HOME from the scrub list
# in a copy of the tree and let KAY_HOME point outside the sandbox
escdir="$TL_TMP/escape-repo"
mkdir -p "$escdir/tests/lib" "$escdir/hooks/lib"
cp "$RUNNER" "$escdir/tests/"
sed 's/unset KAY_HOME /unset /' "$TL_REPO_ROOT/tests/lib/sandbox-env.sh" >"$escdir/tests/lib/sandbox-env.sh"
cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$TL_REPO_ROOT/hooks/lib/path-canonical.sh" "$escdir/hooks/lib/"
body="$(mkfake test-escape.sh "touch '$TL_TMP/body-ran'; echo 'Results: 1 passed, 0 failed'")"
tl_run env SILVER_BULLET_RUNTIME=codex KAY_HOME="$TL_TMP/escaped-kay" bash "$escdir/tests/run-all-tests.sh" "$body"
assert_eq "an escaped runtime root fails the run" "1" "$TL_STATUS"
assert_contains "the file is reported with exit 70" "$TL_OUT" "SUITE FAILED (exit 70)"
assert_file_absent "the test body never ran" "$TL_TMP/body-ran"
assert_contains "the error names the escaped root" "$TL_OUT" "escaped-kay/.codex' is outside the sandbox HOME"

# the same scrub applies to tl_init for a test file run directly
tl_run env KAY_HOME="$real/kay" PI_CODING_AGENT_DIR="$real/pi" SILVER_BULLET_RUNTIME=codex \
  bash -c 'source "$1/tests/lib/testlib.sh"; tl_init; echo "ROOT=$SB_RUNTIME_HOME_ROOT HOME=$HOME"' _ "$TL_REPO_ROOT"
assert_match "tl_init scrubs KAY_HOME so the runtime root is inside the sandbox" 'ROOT=(/[^ ]*)/\.codex HOME=\1$' "$TL_OUT"

# ... but it never clobbers what a test set deliberately before calling it: the consent store that
# consent-helpers.sh puts in XDG_CONFIG_HOME, and the git identity
tl_run env GIT_AUTHOR_NAME=kept bash -c 'source "$1/tests/lib/consent-helpers.sh"; source "$1/tests/lib/testlib.sh"
  sb_test_consent_grant_all; before="$XDG_CONFIG_HOME"; tl_init
  echo "XDG=$([[ "$XDG_CONFIG_HOME" == "$before" && -d "$before" ]] && echo kept || echo lost) AUTHOR=${GIT_AUTHOR_NAME:-}"' _ "$TL_REPO_ROOT"
assert_contains "tl_init keeps a consent store set through XDG_CONFIG_HOME" "$TL_OUT" "XDG=kept AUTHOR=kept"
for helper in tests/hooks/helpers/common.sh tests/integration/helpers/common.sh; do
  tl_run env XDG_CONFIG_HOME="$TL_TMP/consent" GIT_AUTHOR_NAME=kept bash -c 'source "$1/$2"; echo "XDG=$XDG_CONFIG_HOME AUTHOR=${GIT_AUTHOR_NAME:-}"' _ "$TL_REPO_ROOT" "$helper"
  assert_contains "$helper keeps XDG_CONFIG_HOME and the git identity" "$TL_OUT" "XDG=$TL_TMP/consent AUTHOR=kept"
done

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
h1="$(mkfake test-h1.sh 'echo "Results: PASS=8 FAIL=0"')"
h2="$(mkfake test-h2.sh 'echo "Results: 5 passed, 0 failed, 2 skipped"')"
h3="$(mkfake test-h3.sh 'echo "Results: PASS=3 FAIL=2"; exit 1')"
run_runner "$h1" "$h2" "$h3"
assert_contains "the PASS=N FAIL=M form and a trailing suffix are read as Results lines" "$TL_OUT" "TOTAL: 16 passed, 2 failed"
assert_not_contains "and neither is reported as missing its Results line" "$TL_OUT" "no \"Results"
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
