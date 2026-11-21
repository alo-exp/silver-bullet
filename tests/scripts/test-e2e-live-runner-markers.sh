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
mkdir -p "$TREE/tests/live/lib"
cp "$TL_REPO_ROOT/tests/live/lib/evidence-guard.sh" "$TREE/tests/live/lib/"
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
assert_eq "e2e-live marker written for the claude-only run" "matrix=claude-only" "$(sed -n 1p "$E2EM")"
assert_match "e2e-live marker carries the commit it was earned at (R14-16)" '^commit=.+$' "$(sed -n 2p "$E2EM")"
assert_match "e2e-live marker carries a timestamp (R14-16)" '^written_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(sed -n 3p "$E2EM")"
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
assert_eq "inline marker written after the journey ran" "matrix=inline-full-surface" "$(sed -n 1p "$INLINE")"
assert_match "inline marker carries the commit (R14-16)" '^commit=.+$' "$(sed -n 2p "$INLINE")"

# A failing journey writes no evidence at all.
run_suite SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1 STUB_TEST_E2E_LIVE_FULL_SURFACE_JOURNEY_RC=1
assert_eq "failing journey fails the run" 1 "$TL_STATUS"
assert_file_absent "no inline marker after a failing journey" "$INLINE"
assert_file_absent "no e2e-live marker after a failing journey" "$E2EM"


# --- R14-12: a missing scenario is a failure, never a silent skip -------------------------------
mv "$E2E/scenarios/test-e2e-live-hook-failures.sh" "$TL_TMP/hook-failures.bak"
run_suite
assert_eq "a missing scenario fails the run" 1 "$TL_STATUS"
assert_contains "the missing scenario is named" "$TL_OUT" "SCENARIO MISSING: [claude] test-e2e-live-hook-failures.sh"
assert_not_contains "no ALL SCENARIOS PASSED banner" "$TL_OUT" "ALL SCENARIOS PASSED"
assert_file_absent "no e2e-live marker when a scenario is missing" "$E2EM"
mv "$TL_TMP/hook-failures.bak" "$E2E/scenarios/test-e2e-live-hook-failures.sh"

# An empty scenario set (nothing to run) is NOT-RUN, not a pass.
cp "$E2E/run-e2e-live-tests.sh" "$TL_TMP/runner.bak"
sed -i 's|^SCENARIOS=($|SCENARIOS=(|; /^  "\${SCENARIO_DIR}\/test-e2e-live-hook-failures.sh"$/d' "$E2E/run-e2e-live-tests.sh"
run_suite
assert_eq "an empty scenario set fails the run" 1 "$TL_STATUS"
assert_contains "an empty scenario set is reported as NOT-RUN" "$TL_OUT" "NOT-RUN"
assert_file_absent "no e2e-live marker for a NOT-RUN suite" "$E2EM"
cp "$TL_TMP/runner.bak" "$E2E/run-e2e-live-tests.sh"

# --- R14-06: a scenario that writes markers itself and then fails leaves none behind -------------
cat >"$E2E/scenarios/test-e2e-live-full-surface-journey.sh" <<EOS
#!/usr/bin/env bash
mkdir -p "$STATE"
printf 'matrix=inline-full-surface\n' >"$INLINE"
printf 'matrix=claude-only\n' >"$E2EM"
exit 1
EOS
run_suite SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1
assert_eq "failing journey fails the run" 1 "$TL_STATUS"
assert_file_absent "self-written inline marker removed after failure" "$INLINE"
assert_file_absent "self-written e2e-live marker removed after failure" "$E2EM"

# --- R14-03/R14-06: release evidence the operator earned survives a run ------------------------
printf 'matrix=claude-only\n' >"$STATE/release-live-matrix"
printf 'adversarial-review-clean\n' >"$STATE/quality-gate-state"
printf 'verify-tests\n' >"$STATE/verify-tests-state"
cat >"$E2E/scenarios/test-e2e-live-hook-failures.sh" <<EOS
#!/usr/bin/env bash
# a real session's SessionStart removes branch-scoped evidence
rm -f "$STATE/release-live-matrix" "$STATE/quality-gate-state"
rm -f "$STATE/verify-tests-state"
exit "\${STUB_HOOK_RC:-0}"
EOS
run_suite STUB_HOOK_RC=0
assert_eq "run passes" 0 "$TL_STATUS"
assert_eq "release-live-matrix survives the live session reset" "matrix=claude-only" "$(cat "$STATE/release-live-matrix")"
assert_eq "quality-gate-state survives the live session reset" "adversarial-review-clean" "$(cat "$STATE/quality-gate-state")"
assert_eq "verify-tests-state restored" "verify-tests" "$(cat "$STATE/verify-tests-state")"
assert_eq "e2e marker still written on a full pass" "matrix=claude-only" "$(sed -n 1p "$E2EM")"
run_suite STUB_HOOK_RC=1
assert_eq "failing run exits 1" 1 "$TL_STATUS"
assert_eq "release-live-matrix survives a failing run" "matrix=claude-only" "$(cat "$STATE/release-live-matrix")"
assert_eq "quality-gate-state survives a failing run" "adversarial-review-clean" "$(cat "$STATE/quality-gate-state")"

# --- evidence a concurrent session earns during the run is never rolled back or deleted ---------
cat >"$E2E/scenarios/test-e2e-live-hook-failures.sh" <<EOS
#!/usr/bin/env bash
rm -f "$STATE/release-live-matrix"
printf 'matrix=full-claude-codex\\ncommit=newer\\n' >"$STATE/release-live-matrix"
printf 'earned-by-another-session\\n' >"$STATE/quality-gate-state"
exit 0
EOS
printf 'matrix=claude-only\n' >"$STATE/release-live-matrix"
run_suite
assert_contains "newer foreign release evidence is kept" "$(cat "$STATE/release-live-matrix")" "commit=newer"
assert_eq "newer foreign quality-gate-state is kept" "earned-by-another-session" "$(cat "$STATE/quality-gate-state")"
assert_eq "no snapshot directory is left behind" 0 "$(find "$STATE" -maxdepth 1 -name '.sb-evidence-snapshot.*' | wc -l | tr -d ' ')"

# a snapshot left by a SIGKILLed runner is recovered by the next start (missing files only)
mkdir -p "$STATE/.sb-evidence-snapshot.dead"
printf 'matrix=claude-only\ncommit=old\n' >"$STATE/.sb-evidence-snapshot.dead/release-live-matrix"
printf 'stale\n' >"$STATE/.sb-evidence-snapshot.dead/quality-gate-state"
echo 2147483646 >"$STATE/.sb-evidence-snapshot.dead/owner.pid"
mkdir -p "$STATE/.sb-evidence-snapshot.live"
printf 'live-owner\n' >"$STATE/.sb-evidence-snapshot.live/verify-tests-state"
echo $$ >"$STATE/.sb-evidence-snapshot.live/owner.pid"
rm -f "$STATE/release-live-matrix"
cat >"$E2E/scenarios/test-e2e-live-hook-failures.sh" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
run_suite
assert_contains "the crashed runner's missing evidence is put back" "$(cat "$STATE/release-live-matrix")" "commit=old"
assert_eq "recovery never overwrites existing evidence" "earned-by-another-session" "$(cat "$STATE/quality-gate-state")"
assert_file_absent "the dead runner's snapshot is removed" "$STATE/.sb-evidence-snapshot.dead"
assert_file_exists "a snapshot of a live runner is left alone" "$STATE/.sb-evidence-snapshot.live/owner.pid"
rm -rf "$STATE/.sb-evidence-snapshot.live"

# --- R14-15: every post-setup exit tears the isolated home down ---------------------------------
cat >"$TREE/tests/live/lib/codex-cli-isolation.sh" <<EOS
setup_codex_cli_isolation() { SB_ISO="$TL_TMP/iso-home"; mkdir -p "\$SB_ISO"; CODEX_BIN=""; }
teardown_codex_cli_isolation() { rm -rf "$TL_TMP/iso-home"; echo TORN-DOWN >>"$TL_TMP/teardown.log"; }
EOS
: >"$TL_TMP/teardown.log"
run_suite SB_E2E_LIVE_RUNTIMES=codex
assert_eq "preflight failure after setup exits 1" 1 "$TL_STATUS"
assert_contains "the isolated home is torn down on the failing exit" "$(cat "$TL_TMP/teardown.log")" "TORN-DOWN"
assert_file_absent "no isolated home directory remains" "$TL_TMP/iso-home"

tl_results
