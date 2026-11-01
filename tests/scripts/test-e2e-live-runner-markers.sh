#!/usr/bin/env bash
# Release evidence written by tests/e2e-live/run-e2e-live-tests.sh, driven with stub
# scenarios, stub preflights and a stub claude CLI (no live agent runs). The
# matrix=inline-full-surface marker that the plugin-runtime release gate requires may only
# come from a run that actually executed the inline full-surface journey (R13-29).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

TREE="$TL_TMP/tree"
E2E="$TREE/tests/e2e-live"
mkdir -p "$E2E/scenarios"
cp "$TL_REPO_ROOT/tests/e2e-live/run-e2e-live-tests.sh" "$E2E/"
RAN="$TL_TMP/ran.log"
for s in test-e2e-live-hook-failures test-e2e-live-full-surface-journey; do
  printf '#!/usr/bin/env bash\necho "%s $SB_E2E_LIVE_RUNTIME" >>"%s"\nexit "${STUB_%s_RC:-0}"\n' \
    "$s" "$RAN" "$(printf '%s' "$s" | tr 'a-z-' 'A-Z_')" >"$E2E/scenarios/$s.sh"
done
for p in dependency-access-preflight hook-delivery-preflight recommended-tools-preflight; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$E2E/$p.sh"
done
tl_stub claude 'echo "claude 0.0.0-stub"'
STATE="$SB_RUNTIME_STATE_DIR"
INLINE="$STATE/inline-e2e-matrix"
E2EM="$STATE/e2e-live-matrix"

run_suite() {
  : >"$RAN"
  tl_run env -u SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY CLAUDE_BIN=claude SB_E2E_LIVE_RUNTIMES=claude "$@" \
    timeout 60 bash "$E2E/run-e2e-live-tests.sh"
}

# Default run: only the hook-failure matrix runs, so the inline-journey evidence is not written.
run_suite
assert_eq "default run passes" 0 "$TL_STATUS"
assert_eq "only the hook-failure scenario ran" "test-e2e-live-hook-failures claude" "$(<"$RAN")"
assert_eq "e2e-live marker written for the claude-only run" "matrix=claude-only" "$(cat "$E2EM")"
assert_file_absent "no inline-full-surface marker without the journey" "$INLINE"
assert_contains "the missing journey is explained" "$TL_OUT" "inline-e2e-matrix not written"

# A stale marker from an earlier run is not left behind as evidence.
printf 'matrix=inline-full-surface\n' >"$INLINE"
run_suite
assert_file_absent "stale inline marker removed by a run without the journey" "$INLINE"

# With the journey included and passing, the marker is written.
run_suite SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1
assert_eq "journey run passes" 0 "$TL_STATUS"
assert_contains "the journey ran" "$(<"$RAN")" "test-e2e-live-full-surface-journey claude"
assert_eq "inline marker written after the journey ran" "matrix=inline-full-surface" "$(cat "$INLINE")"

# A failing journey writes no evidence at all.
run_suite SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1 STUB_TEST_E2E_LIVE_FULL_SURFACE_JOURNEY_RC=1
assert_eq "failing journey fails the run" 1 "$TL_STATUS"
assert_file_absent "no inline marker after a failing journey" "$INLINE"
assert_file_absent "no e2e-live marker after a failing journey" "$E2EM"

tl_results
