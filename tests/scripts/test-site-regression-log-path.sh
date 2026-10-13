#!/usr/bin/env bash
# Regression guards for sb_site_session_run_regression_tests() log-path creation.
#
# BSD/macOS mktemp only randomizes a TRAILING run of X's. The old template
# "site-regression.XXXXXX.log" was therefore taken literally: the first call
# created that exact filename and every later call failed EEXIST, so the
# function returned before running anything and the gate emitted
# "Log: unknown" — permanently blocking git push and Stop.
#
# Complementary coverage (RED/GREEN portability + fallback):
#   tests/hooks/test-site-session-mktemp-portability.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/site-session.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Isolated state dir — the function writes its log here.
export SB_RUNTIME_STATE_DIR="$TMP_ROOT/state"
mkdir -p "$SB_RUNTIME_STATE_DIR"

# Stub repo: three trivial passing suites so the real site tests never run.
STUB_REPO="$TMP_ROOT/stub-repo"
mkdir -p "$STUB_REPO/tests/scripts"
for stub in test-site-chrome-regression test-site-doc-freshness test-site-content-freshness; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB_REPO/tests/scripts/$stub.sh"
  chmod +x "$STUB_REPO/tests/scripts/$stub.sh"
done

# --- 1. Two consecutive calls must produce different log paths -----------------
rc1=0
log1="$(sb_site_session_run_regression_tests "$STUB_REPO")" || rc1=$?
rc2=0
log2="$(sb_site_session_run_regression_tests "$STUB_REPO")" || rc2=$?

if [[ $rc1 -eq 0 ]]; then
  pass "first call succeeds against stub suites (rc=0)"
else
  fail "first call returned rc=$rc1 (expected 0)"
fi

if [[ $rc2 -eq 0 ]]; then
  pass "second call succeeds against stub suites (rc=0)"
else
  fail "second call returned rc=$rc2 (expected 0) — mktemp EEXIST wedge regression"
fi

if [[ -n "$log1" && -n "$log2" && "$log1" != "$log2" ]]; then
  pass "two consecutive calls produce different log paths"
else
  fail "log paths not unique: first=[$log1] second=[$log2]"
fi

# --- 2. A pre-existing literal XXXXXX.log must not wedge the function ----------
LITERAL="$SB_RUNTIME_STATE_DIR/site-regression.XXXXXX.log"
: >"$LITERAL"

rc3=0
log3="$(sb_site_session_run_regression_tests "$STUB_REPO")" || rc3=$?

if [[ $rc3 -eq 0 ]]; then
  pass "stale literal site-regression.XXXXXX.log does not wedge the function"
else
  fail "stale literal file wedged the function (rc=$rc3)"
fi

if [[ -n "$log3" && "$log3" != "$LITERAL" ]]; then
  pass "returned log path is not the stale literal file"
else
  fail "returned stale literal path: [$log3]"
fi

if [[ -f "$log3" ]]; then
  pass "returned log path exists on disk"
else
  fail "returned log path does not exist: [$log3]"
fi

# --- 3. Returned path ends in .log --------------------------------------------
for candidate in "$log1" "$log2" "$log3"; do
  if [[ "$candidate" == *.log ]]; then
    pass "log path ends in .log (${candidate##*/})"
  else
    fail "log path does not end in .log: [$candidate]"
  fi
done

# --- 4. Missing tests dir returns 90, not 1 -----------------------------------
NO_TESTS_REPO="$TMP_ROOT/no-tests-repo"
mkdir -p "$NO_TESTS_REPO"

rc4=0
sb_site_session_run_regression_tests "$NO_TESTS_REPO" >/dev/null 2>&1 || rc4=$?

if [[ $rc4 -eq 90 ]]; then
  pass "missing tests dir returns 90 (setup error, distinguishable from test failure)"
else
  fail "missing tests dir returned $rc4 (expected 90)"
fi

rc5=0
sb_site_session_run_regression_tests "" >/dev/null 2>&1 || rc5=$?

if [[ $rc5 -eq 90 ]]; then
  pass "empty repo_root returns 90"
else
  fail "empty repo_root returned $rc5 (expected 90)"
fi

# --- 5. A genuinely failing suite still returns non-zero and not a setup code --
FAIL_REPO="$TMP_ROOT/fail-repo"
mkdir -p "$FAIL_REPO/tests/scripts"
printf '#!/usr/bin/env bash\nexit 3\n' >"$FAIL_REPO/tests/scripts/test-site-chrome-regression.sh"
for stub in test-site-doc-freshness test-site-content-freshness; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FAIL_REPO/tests/scripts/$stub.sh"
done
chmod +x "$FAIL_REPO"/tests/scripts/*.sh

rc6=0
log6="$(sb_site_session_run_regression_tests "$FAIL_REPO")" || rc6=$?

if [[ $rc6 -ne 0 && $rc6 -ne 90 && $rc6 -ne 91 ]]; then
  pass "genuine suite failure returns a test-failure code (rc=$rc6), not a setup code"
else
  fail "genuine suite failure returned rc=$rc6 (expected non-zero and not 90/91)"
fi

if [[ -n "$log6" && -f "$log6" ]]; then
  pass "failing run still returns a readable log path"
else
  fail "failing run returned no usable log path: [$log6]"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
