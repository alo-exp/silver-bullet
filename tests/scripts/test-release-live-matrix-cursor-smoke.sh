#!/usr/bin/env bash
# release-live-matrix-cursor-smoke.sh against stubbed installer, diagnostics and
# unit-test scripts in a minimal tree: isolated HOME handling, hooks.json
# verification, the matrix marker and failure propagation.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

T="$TL_TMP/tree"
STATE="$TL_TMP/marker-state"
LOG="$TL_TMP/calls.log"
FAKE_TMP="$TL_TMP/tmp"
mkdir -p "$FAKE_TMP"

build_tree() {
  rm -rf "$T"
  mkdir -p "$T/scripts" "$T/hooks/lib" "$T/tests/hooks"
  cp "$TL_REPO_ROOT/scripts/release-live-matrix-cursor-smoke.sh" "$T/scripts/"
  # Fixed runtime paths: the real helper derives them from HOME at source time.
  cat >"$T/hooks/lib/runtime-paths.sh" <<RP
SB_RUNTIME_STATE_DIR="$STATE"
RP
  cat >"$T/scripts/install-cursor.sh" <<'INST'
#!/usr/bin/env bash
echo "install HOME=$HOME CONFIG=${CURSOR_CONFIG_DIR-} RUNTIME=${SILVER_BULLET_RUNTIME-}" >>"$SMOKE_LOG"
if [[ -z "${STUB_NO_HOOKS:-}" ]]; then
  mkdir -p "$HOME/.cursor"
  echo "${STUB_HOOKS_BODY:-{\"hooks\":{\"x\":\"silver-bullet/hook.sh\"}}}" >"$HOME/.cursor/hooks.json"
fi
exit "${STUB_INSTALL_RC:-0}"
INST
  cat >"$T/scripts/sb-diagnostics.sh" <<'DIAG'
#!/usr/bin/env bash
echo "diag SMOKE=${SB_DIAG_SMOKE-} RUNTIME=${SILVER_BULLET_RUNTIME-} HOME=$HOME" >>"$SMOKE_LOG"
exit "${STUB_DIAG_RC:-0}"
DIAG
  local t
  for t in test-cursor-hook-bridge test-cursor-runtime-bootstrap test-runtime-paths; do
    cat >"$T/tests/hooks/$t.sh" <<UT
#!/usr/bin/env bash
echo "unit $t HOME=\$HOME" >>"\$SMOKE_LOG"
[[ "\${STUB_FAIL_UNIT:-}" == "$t" ]] && exit 6
exit 0
UT
  done
  chmod +x "$T"/scripts/*.sh "$T"/tests/hooks/*.sh
  rm -rf "$STATE"
  : >"$LOG"
}

run_smoke() {
  tl_run env SMOKE_LOG="$LOG" TMPDIR="$FAKE_TMP" "$@" timeout 60 bash "$T/scripts/release-live-matrix-cursor-smoke.sh"
}

# --- default: isolated fake HOME ----------------------------------------
build_tree
run_smoke
assert_eq "smoke passes" 0 "$TL_STATUS"
assert_contains "installer step announced" "$TL_OUT" "[cursor-smoke] Running install-cursor.sh in isolated HOME"
assert_contains "diagnostics step announced" "$TL_OUT" "[cursor-smoke] Running sb-diagnostics (cursor path)"
assert_contains "unit test step announced" "$TL_OUT" "[cursor-smoke] Running cursor hook unit tests"
assert_contains "PASS line" "$TL_OUT" "[cursor-smoke] PASS"
calls="$(<"$LOG")"
assert_match "installer ran in a temp fake HOME" "install HOME=$FAKE_TMP/sb-cursor-smoke\\.[A-Za-z0-9]+/fake-home CONFIG=$FAKE_TMP/sb-cursor-smoke\\.[A-Za-z0-9]+/fake-home/\\.cursor RUNTIME=cursor" "$calls"
assert_contains "diagnostics ran in smoke mode as cursor" "$calls" "diag SMOKE=1 RUNTIME=cursor HOME=$FAKE_TMP/sb-cursor-smoke."
for t in test-cursor-hook-bridge test-cursor-runtime-bootstrap test-runtime-paths; do
  assert_contains "$t ran with the fake HOME" "$calls" "unit $t HOME=$FAKE_TMP/sb-cursor-smoke."
done
assert_eq "temp root removed on exit" "" "$(ls -A "$FAKE_TMP")"
assert_eq "matrix marker written" "matrix=cursor-smoke" "$(<"$STATE/release-live-matrix")"
assert_contains "marker path reported" "$TL_OUT" "[cursor-smoke] Wrote $STATE/release-live-matrix"
assert_file_absent "real HOME untouched by the smoke" "$HOME/.cursor"

# Marker can be disabled.
build_tree
run_smoke SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER=0
assert_eq "marker-off run passes" 0 "$TL_STATUS"
assert_file_absent "no marker when disabled" "$STATE/release-live-matrix"
assert_not_contains "no Wrote line when disabled" "$TL_OUT" "Wrote"

# Without the runtime-paths helper the smoke still runs (marker off).
build_tree
rm -f "$T/hooks/lib/runtime-paths.sh"
run_smoke SB_RELEASE_LIVE_MATRIX_WRITE_CURSOR_MARKER=0
assert_eq "runs without runtime-paths helper" 0 "$TL_STATUS"

# --- caller-isolated environment ----------------------------------------
build_tree
CALLER_HOME="$TL_TMP/caller-home"
mkdir -p "$CALLER_HOME/.cursor"
run_smoke HOME="$CALLER_HOME" SB_CURSOR_SMOKE_USE_CURRENT_ENV=1 SB_SMOKE_CURSOR_FAKE_HOME="$CALLER_HOME" \
  CURSOR_CONFIG_DIR="$CALLER_HOME/.cursor"
assert_eq "caller-isolated run passes" 0 "$TL_STATUS"
assert_contains "caller isolation announced" "$TL_OUT" "[cursor-smoke] Using caller-isolated HOME=$CALLER_HOME CURSOR_CONFIG_DIR=$CALLER_HOME/.cursor"
assert_contains "installer used the caller HOME" "$(<"$LOG")" "install HOME=$CALLER_HOME "
assert_eq "no temp root created for caller isolation" "" "$(ls -A "$FAKE_TMP")"
assert_file_exists "caller hooks.json written" "$CALLER_HOME/.cursor/hooks.json"

# USE_CURRENT_ENV without a fake HOME marker falls back to a fresh temp HOME.
build_tree
run_smoke SB_CURSOR_SMOKE_USE_CURRENT_ENV=1
assert_eq "USE_CURRENT_ENV alone passes" 0 "$TL_STATUS"
assert_not_contains "temp HOME used without the fake-home marker" "$TL_OUT" "caller-isolated"

# --- failures -----------------------------------------------------------
# Caller-isolated HOME with no hooks.json and an installer that writes none.
build_tree
EMPTY_HOME="$TL_TMP/empty-home"
mkdir -p "$EMPTY_HOME"
run_smoke HOME="$EMPTY_HOME" SB_CURSOR_SMOKE_USE_CURRENT_ENV=1 SB_SMOKE_CURSOR_FAKE_HOME="$EMPTY_HOME" STUB_NO_HOOKS=1
assert_eq "installer without hooks.json fails" 1 "$TL_STATUS"
assert_contains "missing hooks.json reported" "$TL_ERR" "install-cursor.sh did not write $EMPTY_HOME/.cursor/hooks.json"
assert_not_contains "no diagnostics after a failed install check" "$(<"$LOG")" "diag"

# Default mode seeds an empty hooks.json, so a no-op installer is caught by the content check.
build_tree
run_smoke STUB_NO_HOOKS=1
assert_eq "no-op installer fails the content check" 1 "$TL_STATUS"
assert_contains "seeded hooks.json lacks silver-bullet" "$TL_ERR" "merged hooks.json missing silver-bullet entries"
assert_eq "temp root removed after failure" "" "$(ls -A "$FAKE_TMP")"

build_tree
run_smoke STUB_HOOKS_BODY='{"hooks":{}}'
assert_eq "hooks.json without silver-bullet fails" 1 "$TL_STATUS"
assert_contains "missing entries reported" "$TL_ERR" "merged hooks.json missing silver-bullet entries"

build_tree
run_smoke STUB_INSTALL_RC=4
assert_eq "installer failure propagates" 4 "$TL_STATUS"
assert_not_contains "no PASS after installer failure" "$TL_OUT" "PASS"

build_tree
run_smoke STUB_DIAG_RC=5
assert_eq "diagnostics failure propagates" 5 "$TL_STATUS"
assert_not_contains "unit tests skipped after diagnostics failure" "$(<"$LOG")" "unit "

build_tree
run_smoke STUB_FAIL_UNIT=test-cursor-runtime-bootstrap
assert_eq "unit test failure propagates" 6 "$TL_STATUS"
assert_contains "earlier unit test ran" "$(<"$LOG")" "unit test-cursor-hook-bridge"
assert_not_contains "later unit test skipped" "$(<"$LOG")" "unit test-runtime-paths"
assert_file_absent "no marker after a failed unit test" "$STATE/release-live-matrix"

tl_results
