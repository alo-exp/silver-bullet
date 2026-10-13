#!/usr/bin/env bash
# Portability guards for sb_site_session_run_regression_tests() mktemp behavior.
#
# Complements tests/scripts/test-site-regression-log-path.sh (which covers unique
# paths, stale literal XXXXXX.log, rc 90/91, and genuine suite failure).
#
# This file additionally:
#   - asserts no literal "XXXXXX" basename after a successful alloc
#   - proves RED against the pre-2044c86c / Claude-WT buggy body (suffix template)
#   - asserts GREEN against the live hooks/lib/site-session.sh implementation
#   - checks mkdir -p + unwedgeable fallback when the state dir is missing
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Stub repo: three trivial passing suites so the real site tests never run.
STUB_REPO="$TMP_ROOT/stub-repo"
mkdir -p "$STUB_REPO/tests/scripts"
for stub in test-site-chrome-regression test-site-doc-freshness test-site-content-freshness; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$STUB_REPO/tests/scripts/$stub.sh"
  chmod +x "$STUB_REPO/tests/scripts/$stub.sh"
done

# --- OLD buggy implementation (Claude WT / pre-2044c86c) for RED proof ----------
# Intentionally broken: BSD mktemp takes site-regression.XXXXXX.log literally.
sb_site_session_run_regression_tests_OLD() {
  local repo_root="$1"
  local log_file rc
  [[ -n "$repo_root" && -d "$repo_root/tests" ]] || return 1
  log_file="$(mktemp "${SB_RUNTIME_STATE_DIR:-/tmp}/site-regression.XXXXXX.log" 2>/dev/null)" || return 1
  (
    cd "$repo_root" || exit 1
    bash tests/scripts/test-site-chrome-regression.sh \
      && bash tests/scripts/test-site-doc-freshness.sh \
      && bash tests/scripts/test-site-content-freshness.sh
  ) >"$log_file" 2>&1
  rc=$?
  printf '%s' "$log_file"
  return $rc
}

echo "--- RED: old suffix-template mktemp wedges on second call ---"
RED_STATE="$TMP_ROOT/red-state"
mkdir -p "$RED_STATE"
export SB_RUNTIME_STATE_DIR="$RED_STATE"

# GNU mktemp (Linux CI) may still randomize X's before a suffix, so the classic
# wedge is macOS/BSD-only. Inject a BSD-faithful mktemp for the RED section so
# CI proves the same failure mode the gate hit on Darwin.
mktemp() {
  local template="${1:-}"
  case "$template" in
    *XXXXXX.*)
      if [[ -e "$template" ]]; then
        return 1
      fi
      : >"$template" || return 1
      printf '%s\n' "$template"
      return 0
      ;;
  esac
  command mktemp "$@"
}

rc_old1=0
log_old1="$(sb_site_session_run_regression_tests_OLD "$STUB_REPO")" || rc_old1=$?
rc_old2=0
log_old2="$(sb_site_session_run_regression_tests_OLD "$STUB_REPO")" || rc_old2=$?

unset -f mktemp

if [[ $rc_old1 -eq 0 && -f "$log_old1" && "${log_old1##*/}" == *XXXXXX* ]]; then
  pass "RED setup: first OLD call creates literal XXXXXX.log (BSD-faithful mktemp)"
else
  fail "RED setup: first OLD call unexpected (rc=$rc_old1 log=[$log_old1])"
fi

if [[ $rc_old2 -ne 0 ]]; then
  pass "RED proven: second OLD call fails (rc=$rc_old2) — classic BSD EEXIST wedge"
else
  fail "RED not proven: second OLD call succeeded (rc=$rc_old2 log=[$log_old2])"
fi

echo "--- GREEN: live sb_site_session_run_regression_tests ---"
# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/lib/site-session.sh"

GREEN_STATE="$TMP_ROOT/green-state"
# Intentionally do NOT mkdir — function must mkdir -p itself.
export SB_RUNTIME_STATE_DIR="$GREEN_STATE"
rm -rf "$GREEN_STATE"

rc1=0
log1="$(sb_site_session_run_regression_tests "$STUB_REPO")" || rc1=$?
rc2=0
log2="$(sb_site_session_run_regression_tests "$STUB_REPO")" || rc2=$?

if [[ $rc1 -eq 0 && $rc2 -eq 0 ]]; then
  pass "GREEN: two consecutive calls succeed (rc=0,0)"
else
  fail "GREEN: calls returned rc=$rc1,$rc2 (expected 0,0)"
fi

if [[ -n "$log1" && -n "$log2" && "$log1" != "$log2" && -f "$log1" && -f "$log2" ]]; then
  pass "GREEN: two distinct existing log paths"
else
  fail "GREEN: paths not distinct/existing: [$log1] [$log2]"
fi

for candidate in "$log1" "$log2"; do
  base="${candidate##*/}"
  if [[ "$base" == *XXXXXX* ]]; then
    fail "GREEN: log basename still contains literal XXXXXX: $base"
  else
    pass "GREEN: no literal XXXXXX in basename ($base)"
  fi
  if [[ "$candidate" == *.log ]]; then
    pass "GREEN: path ends in .log ($base)"
  else
    fail "GREEN: path does not end in .log: [$candidate]"
  fi
done

echo "--- GREEN: fallback when mktemp cannot create under state dir ---"
# Make state dir exist but unwritable so mktemp fails; fallback site-regression-$$.log
# should still let the suites run.
FALLBACK_STATE="$TMP_ROOT/fallback-state"
mkdir -p "$FALLBACK_STATE"
chmod 555 "$FALLBACK_STATE"
export SB_RUNTIME_STATE_DIR="$FALLBACK_STATE"

rc_fb=0
log_fb="$(sb_site_session_run_regression_tests "$STUB_REPO")" || rc_fb=$?
chmod 755 "$FALLBACK_STATE" 2>/dev/null || true

if [[ $rc_fb -eq 0 && -n "$log_fb" && -f "$log_fb" ]]; then
  pass "GREEN: unwritable state dir still yields a usable log via fallback (rc=0)"
elif [[ $rc_fb -eq 91 ]]; then
  # Acceptable last resort when even TMPDIR fallback fails in locked-down envs
  pass "GREEN: returns setup code 91 (not a test failure) when all log allocs fail"
else
  fail "GREEN: fallback path unexpected rc=$rc_fb log=[$log_fb]"
fi

if [[ -n "$log_fb" && "${log_fb##*/}" == *XXXXXX* ]]; then
  fail "GREEN: fallback basename contains literal XXXXXX"
else
  pass "GREEN: fallback basename has no literal XXXXXX"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
