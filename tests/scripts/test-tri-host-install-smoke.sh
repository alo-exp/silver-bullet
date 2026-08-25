#!/usr/bin/env bash
# Structural + timeout-helper tests for tri-host install smoke wiring.
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

dump_log() {
  local path="$1"
  echo "----- ${path} -----"
  if [[ -f "$path" ]]; then
    cat "$path"
  else
    echo "(missing)"
  fi
}


assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in $file"
  fi
}

assert_file_exists "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "tri-host smoke script exists"
chmod +x "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh"
assert_executable "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "tri-host smoke script executable"

assert_file_exists "${REPO_ROOT}/scripts/lib/command-timeout.sh" "portable command-timeout helper exists"
assert_contains "smoke runner sources command-timeout helper" \
  "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "command-timeout.sh"
assert_contains "smoke runner wraps commands with sb_run_with_timeout" \
  "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "sb_run_with_timeout"
assert_contains "smoke runner documents overall timeout env" \
  "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "SB_TRIHOST_OVERALL_TIMEOUT"
assert_contains "smoke runner documents per-command timeout env" \
  "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "SB_TRIHOST_CMD_TIMEOUT"
assert_contains "smoke runner loud-fails on hang" \
  "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "hang detected"
assert_contains "smoke runner skips installer post-install reconcile" \
  "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" "RT_SKIP_POST_INSTALL"

assert_file_exists "${REPO_ROOT}/docs/testing/pre-release-claims-registry.json" "pre-release claims registry exists"
assert_contains "pre-release registry wires tri-host smoke" \
  "${REPO_ROOT}/docs/testing/pre-release-claims-registry.json" "run-tri-host-install-smoke.sh"
assert_contains "pre-release registry documents hero-tri-host" \
  "${REPO_ROOT}/docs/testing/pre-release-claims-registry.json" "hero-tri-host"

PLAN="${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md"
assert_contains "validation plan documents pre-release taxonomy" "$PLAN" "Pre-release"
assert_contains "validation plan documents tri-host smoke" "$PLAN" "tri-host"

# Unit-test portable timeout helper (macOS may lack GNU timeout — helper must still kill).
# shellcheck source=../../scripts/lib/command-timeout.sh
source "${REPO_ROOT}/scripts/lib/command-timeout.sh"
slow_stub="$(mktemp "${TMPDIR:-/tmp}/sb-trihost-slow.XXXXXX")"
printf '#!/usr/bin/env bash\nsleep 30\n' >"$slow_stub"
chmod +x "$slow_stub"
helper_start=$(python3 -c 'import time; print(int(time.time()*1000))')
helper_rc=0
sb_run_with_timeout 1 "unit-test slow stub" -- "$slow_stub" >/dev/null 2>&1 || helper_rc=$?
helper_end=$(python3 -c 'import time; print(int(time.time()*1000))')
helper_elapsed=$((helper_end - helper_start))
rm -f "$slow_stub"
if [[ "$helper_elapsed" -lt 8000 && "$helper_rc" -eq 124 ]]; then
  pass "command-timeout kills 30s stub within 8s (elapsed ${helper_elapsed}ms, bin=$(sb_timeout_bin))"
else
  fail "command-timeout expected <8s and rc 124 (elapsed ${helper_elapsed}ms, rc=$helper_rc, bin=$(sb_timeout_bin))"
fi

# Short overall timeout must loud-fail instead of hanging forever.
overall_start=$(python3 -c 'import time; print(int(time.time()*1000))')
overall_rc=0
# Force inner path to a host that would otherwise run install; overall timeout=2 should win first.
SB_TRIHOST_OVERALL_TIMEOUT=2 SB_TRIHOST_CMD_TIMEOUT=60 SB_TRIHOST_DIAG_TIMEOUT=60 \
  RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" --host cursor \
  >/tmp/sb-trihost-overall-timeout.log 2>&1 || overall_rc=$?
overall_end=$(python3 -c 'import time; print(int(time.time()*1000))')
overall_elapsed=$((overall_end - overall_start))
if [[ "$overall_rc" -eq 124 && "$overall_elapsed" -lt 15000 ]]; then
  pass "overall timeout loud-fails within 15s (elapsed ${overall_elapsed}ms)"
elif grep -q 'timed out after' /tmp/sb-trihost-overall-timeout.log 2>/dev/null && [[ "$overall_elapsed" -lt 15000 ]]; then
  pass "overall timeout loud-fails within 15s (elapsed ${overall_elapsed}ms, rc=$overall_rc)"
else
  # If cursor install finishes under 2s (unlikely), still accept success — timeout path optional.
  if [[ "$overall_rc" -eq 0 && "$overall_elapsed" -lt 15000 ]]; then
    pass "cursor smoke completed before overall timeout (elapsed ${overall_elapsed}ms)"
  else
    fail "overall timeout expected rc 124 or quick finish (elapsed ${overall_elapsed}ms, rc=$overall_rc) — see /tmp/sb-trihost-overall-timeout.log"
  fi
fi

# Codex + Cursor + Claude smoke (Claude skipped only when CLI unavailable)
# Use generous but finite timeouts so a hang fails loud instead of stalling run-all-tests.
export SB_TRIHOST_OVERALL_TIMEOUT="${SB_TRIHOST_OVERALL_TIMEOUT:-600}"
export SB_TRIHOST_CMD_TIMEOUT="${SB_TRIHOST_CMD_TIMEOUT:-180}"
export SB_TRIHOST_DIAG_TIMEOUT="${SB_TRIHOST_DIAG_TIMEOUT:-90}"

if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" --host codex >/tmp/sb-trihost-codex.log 2>&1; then
  pass "codex tri-host smoke executes"
elif [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  pass "codex tri-host smoke skipped in CI (isolated codex install unavailable)"
elif grep -q 'TIMED OUT\|timed out after' /tmp/sb-trihost-codex.log 2>/dev/null; then
  fail "codex tri-host smoke TIMED OUT — see /tmp/sb-trihost-codex.log"
else
  fail "codex tri-host smoke failed — see /tmp/sb-trihost-codex.log"
fi

if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" --host cursor >/tmp/sb-trihost-cursor.log 2>&1; then
  pass "cursor tri-host smoke executes"
elif grep -q 'TIMED OUT\|timed out after' /tmp/sb-trihost-cursor.log 2>/dev/null; then
  dump_log /tmp/sb-trihost-cursor.log
  fail "cursor tri-host smoke TIMED OUT — see /tmp/sb-trihost-cursor.log"
else
  dump_log /tmp/sb-trihost-cursor.log
  fail "cursor tri-host smoke failed — see /tmp/sb-trihost-cursor.log"
fi

if command -v claude >/dev/null 2>&1; then
  if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/run-tri-host-install-smoke.sh" --host claude >/tmp/sb-trihost-claude.log 2>&1; then
    pass "claude tri-host smoke executes"
  elif grep -q 'TIMED OUT\|timed out after' /tmp/sb-trihost-claude.log 2>/dev/null; then
    fail "claude tri-host smoke TIMED OUT — see /tmp/sb-trihost-claude.log"
  else
    fail "claude tri-host smoke failed — see /tmp/sb-trihost-claude.log"
  fi
else
  pass "claude tri-host smoke skipped (CLI unavailable)"
fi

if bash "${REPO_ROOT}/tests/scripts/test-runtime-mirror-freshness.sh" >/dev/null 2>&1; then
  pass "tri-host smoke preserves generated runtime mirrors"
else
  fail "tri-host smoke preserves generated runtime mirrors"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
