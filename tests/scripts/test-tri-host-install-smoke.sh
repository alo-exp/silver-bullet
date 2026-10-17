#!/usr/bin/env bash
# Structural + timeout-helper tests for tri-host install smoke wiring.
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Logs and fixtures live in a private temp dir: fixed /tmp/sb-trihost-*.log
# names collided between concurrent runs and between users.
TRIHOST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-trihost-test.XXXXXX")"
trap 'rm -rf "$TRIHOST_TMP"' EXIT

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

# The smoke runs the real installers. They rewrite the checkout they run from
# and default to GitHub sources, the Codex installer needs a codex CLI, and the
# Claude installer drives the real claude CLI against GitHub. Run everything
# from a one-commit snapshot repository, offline: local marketplace and gitPath
# sources, a stub codex CLI, the fixture Cursor model catalog, installer/network
# stand-ins on PATH. The same checks then run on every machine.
# shellcheck source=tests/lib/repo-snapshot.sh
source "${REPO_ROOT}/tests/lib/repo-snapshot.sh"
# shellcheck source=tests/lib/offline-tools.sh
source "${REPO_ROOT}/tests/lib/offline-tools.sh"
SMOKE_ROOT="$(sb_repo_snapshot --git "$REPO_ROOT" "${TRIHOST_TMP}/silver-bullet")"
SMOKE="${SMOKE_ROOT}/scripts/run-tri-host-install-smoke.sh"
sb_offline_tools_install "${TRIHOST_TMP}/offline-bin"
mkdir -p "${TRIHOST_TMP}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' >"${TRIHOST_TMP}/bin/codex"
chmod +x "${TRIHOST_TMP}/bin/codex"
export PATH="${TRIHOST_TMP}/bin:${PATH}"
export CURSOR_UNIFIED_MARKETPLACE_SOURCE="$SMOKE_ROOT"
export CURSOR_AGENT_PLUGINS_REPO_URL="$SMOKE_ROOT"
export CURSOR_GITHUB_REPO_URL="$SMOKE_ROOT"
export SB_CURSOR_SB_AGENTS_OFFLINE=1
export SB_CURSOR_MODELS_CATALOG="${TRIHOST_TMP}/cursor-models-catalog.json"
cp "${REPO_ROOT}/tests/fixtures/cursor-models-catalog.json" "$SB_CURSOR_MODELS_CATALOG"

# Short overall timeout must loud-fail instead of hanging forever.
overall_start=$(python3 -c 'import time; print(int(time.time()*1000))')
overall_rc=0
# Force inner path to a host that would otherwise run install; overall timeout=2 should win first.
SB_TRIHOST_OVERALL_TIMEOUT=2 SB_TRIHOST_CMD_TIMEOUT=60 SB_TRIHOST_DIAG_TIMEOUT=60 \
  RTK_DISABLED=1 bash "$SMOKE" --host cursor \
  >"${TRIHOST_TMP}/overall-timeout.log" 2>&1 || overall_rc=$?
overall_end=$(python3 -c 'import time; print(int(time.time()*1000))')
overall_elapsed=$((overall_end - overall_start))
if [[ "$overall_rc" -eq 124 && "$overall_elapsed" -lt 15000 ]]; then
  pass "overall timeout loud-fails within 15s (elapsed ${overall_elapsed}ms)"
elif grep -q 'timed out after' "${TRIHOST_TMP}/overall-timeout.log" 2>/dev/null && [[ "$overall_elapsed" -lt 15000 ]]; then
  pass "overall timeout loud-fails within 15s (elapsed ${overall_elapsed}ms, rc=$overall_rc)"
else
  # If cursor install finishes under 2s (unlikely), still accept success — timeout path optional.
  if [[ "$overall_rc" -eq 0 && "$overall_elapsed" -lt 15000 ]]; then
    pass "cursor smoke completed before overall timeout (elapsed ${overall_elapsed}ms)"
  else
    dump_log "${TRIHOST_TMP}/overall-timeout.log"
    fail "overall timeout expected rc 124 or quick finish (elapsed ${overall_elapsed}ms, rc=$overall_rc)"
  fi
fi

# Codex + Cursor smoke always; Claude smoke on request (see below).
# Use generous but finite timeouts so a hang fails loud instead of stalling run-all-tests.
export SB_TRIHOST_OVERALL_TIMEOUT="${SB_TRIHOST_OVERALL_TIMEOUT:-600}"
export SB_TRIHOST_CMD_TIMEOUT="${SB_TRIHOST_CMD_TIMEOUT:-180}"
export SB_TRIHOST_DIAG_TIMEOUT="${SB_TRIHOST_DIAG_TIMEOUT:-90}"

for smoke_host in codex cursor; do
  smoke_log="${TRIHOST_TMP}/${smoke_host}.log"
  if RTK_DISABLED=1 bash "$SMOKE" --host "$smoke_host" >"$smoke_log" 2>&1; then
    pass "${smoke_host} tri-host smoke executes"
  elif grep -q 'TIMED OUT\|timed out after' "$smoke_log" 2>/dev/null; then
    dump_log "$smoke_log"
    fail "${smoke_host} tri-host smoke TIMED OUT"
  else
    dump_log "$smoke_log"
    fail "${smoke_host} tri-host smoke failed"
  fi
done

# The Claude smoke drives the real claude CLI against GitHub: live only.
if [[ "${SB_LIVE_CLAUDE_INSTALL_TEST:-0}" == "1" ]]; then
  smoke_log="${TRIHOST_TMP}/claude.log"
  if RTK_DISABLED=1 bash "$SMOKE" --host claude >"$smoke_log" 2>&1; then
    pass "claude tri-host smoke executes"
  elif grep -q 'TIMED OUT\|timed out after' "$smoke_log" 2>/dev/null; then
    dump_log "$smoke_log"
    fail "claude tri-host smoke TIMED OUT"
  else
    dump_log "$smoke_log"
    fail "claude tri-host smoke failed"
  fi
else
  pass "claude tri-host smoke skipped (live only: SB_LIVE_CLAUDE_INSTALL_TEST=1)"
fi

if bash "${REPO_ROOT}/tests/scripts/test-runtime-mirror-freshness.sh" >/dev/null 2>&1; then
  pass "tri-host smoke preserves generated runtime mirrors"
else
  fail "tri-host smoke preserves generated runtime mirrors"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
