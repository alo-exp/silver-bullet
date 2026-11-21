#!/usr/bin/env bash
# The live harness must never report a pass it did not earn, and must never leave the
# operator's real state behind (review R14). Everything here runs with stubs: no real agent CLI,
# no network, and a sandboxed HOME, so the "operator's real state dir" is a temp directory.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

STATE="$SB_RUNTIME_STATE_DIR"
FIXTURE="$TL_TMP/fixture"
mkdir -p "$FIXTURE/api/src" "$FIXTURE/src/routes"
echo 'module.exports = 1;' >"$FIXTURE/api/src/health.js"
echo '// todos' >"$FIXTURE/src/routes/todos.js"

# --- R14-08: capture_mtime is one integer on GNU and BSD stat ---------------------------------
cat >"$TL_TMP/mtime.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/helpers.sh"
f="$TL_TMP/mt.txt"; echo x >"\$f"
capture_mtime "\$f"
capture_mtime "$TL_TMP/does-not-exist"
EOS
tl_run bash "$TL_TMP/mtime.sh"
assert_eq "capture_mtime exits 0" 0 "$TL_STATUS"
assert_match "capture_mtime of a file is one integer" '^[0-9]+$' "$(sed -n 1p <<<"$TL_OUT")"
assert_eq "capture_mtime of a missing file is 0" 0 "$(sed -n 2p <<<"$TL_OUT")"
assert_eq "capture_mtime prints exactly two lines" 2 "$(wc -l <<<"$TL_OUT" | tr -d ' ')"
# BSD fallback: GNU stat -c unavailable
tl_stub stat 'if [[ "$1" == "-c" ]]; then exit 1; fi; if [[ "$1" == "-f" ]]; then echo 1234; exit 0; fi; exit 1'
tl_run bash "$TL_TMP/mtime.sh"
assert_eq "capture_mtime falls back to BSD stat -f %m" 1234 "$(sed -n 1p <<<"$TL_OUT")"
rm -f "$TL_BIN/stat"

# capture_digest works with sha256sum only (no shasum) and prints nothing when neither exists.
cat >"$TL_TMP/digest.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/helpers.sh"
f="$TL_TMP/dg.txt"; echo x >"\$f"
capture_digest "\$f"
EOS
tl_run bash "$TL_TMP/digest.sh"
assert_match "capture_digest returns a sha256" '^[0-9a-f]{64}$' "$TL_OUT"
real_path="$PATH"
PATH="$(tl_path_without shasum)"
tl_run bash "$TL_TMP/digest.sh"
PATH="$real_path"
assert_match "capture_digest falls back to sha256sum" '^[0-9a-f]{64}$' "$TL_OUT"
PATH="$(tl_path_without shasum sha256sum)"
tl_run bash "$TL_TMP/digest.sh"
PATH="$real_path"
assert_eq "capture_digest is empty when no hasher exists" "" "$TL_OUT"

# --- R14-07: an aborted live scenario restores the operator's real state ----------------------
mkdir -p "$STATE"
printf 'silver-plan\n' >"$STATE/state"
printf '{"keep":1}\n' >"$SB_RUNTIME_HOME_ROOT/mcp-needs-auth-cache.json"
: >"$STATE/trivial"
cat >"$TL_TMP/abort.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/helpers.sh"
agent_preflight() { :; }
live_setup
[[ ! -s "$STATE/state" ]] || { echo "state was not truncated"; exit 9; }
false   # any failing command between setup and teardown aborts the script
echo "not reached"
EOS
tl_run bash "$TL_TMP/abort.sh"
assert_eq "aborted scenario exits non-zero" 1 "$TL_STATUS"
assert_eq "real state restored after abort" "silver-plan" "$(cat "$STATE/state")"
assert_eq "mcp auth cache restored after abort" '{"keep":1}' "$(cat "$SB_RUNTIME_HOME_ROOT/mcp-needs-auth-cache.json")"
assert_file_exists "trivial marker restored after abort" "$STATE/trivial"
assert_file_absent "no state backup left behind" "$STATE/state.live-test-backup-$$"
# a normal teardown followed by exit is idempotent and keeps the exit status
cat >"$TL_TMP/normal.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/helpers.sh"
agent_preflight() { :; }
live_setup
live_teardown
live_teardown
exit 0
EOS
tl_run bash "$TL_TMP/normal.sh"
assert_eq "normal run exits 0" 0 "$TL_STATUS"
assert_eq "real state intact after normal run" "silver-plan" "$(cat "$STATE/state")"
rm -f "$STATE/trivial"

# --- R14-11: assertions need a real decision ----------------------------------------------------
cat >"$TL_TMP/assert.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/helpers.sh"
assert_hook_json_decision "empty output is not an allow" "" "allow"
assert_hook_json_decision "garbage is not a deny" "not json" "deny"
assert_hook_json_decision "deny json passes" '{"hookSpecificOutput":{"permissionDecision":"deny"}}' "deny"
assert_hook_json_decision "block json passes" '{"decision":"block"}' "block"
live_hook_audit_enable
assert_hook_audit_entry "missing entry fails" dev-cycle-check deny "" 0
printf '%s\n' '{"hook_name":"dev-cycle-check","decision":"deny","detail":"HARD STOP"}' >>"\$LIVE_HOOK_AUDIT_FILE"
assert_hook_audit_entry "matching entry passes" dev-cycle-check deny "HARD STOP" 0
assert_hook_audit_entry "wrong decision fails" dev-cycle-check allow "" 0
live_hook_audit_clear
assert_hook_audit_entry "cleared log has no entry" dev-cycle-check deny "" 0
live_hook_audit_disable
print_results
EOS
tl_run bash "$TL_TMP/assert.sh"
assert_contains "empty hook output fails the allow assertion" "$TL_OUT" "FAIL: empty output is not an allow"
assert_contains "malformed output fails the deny assertion" "$TL_OUT" "FAIL: garbage is not a deny"
assert_contains "deny JSON passes" "$TL_OUT" "PASS: deny json passes"
assert_contains "block JSON passes" "$TL_OUT" "PASS: block json passes"
assert_contains "missing audit entry fails" "$TL_OUT" "FAIL: missing entry fails"
assert_contains "matching audit entry passes" "$TL_OUT" "PASS: matching entry passes"
assert_contains "wrong audit decision fails" "$TL_OUT" "FAIL: wrong decision fails"
assert_contains "cleared audit log fails" "$TL_OUT" "FAIL: cleared log has no entry"

# --- R14-01: the hook-delivery preflight needs the agent's own run -------------------------------
cat >"$TL_TMP/delivery.sh" <<EOS
export SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE"
export SB_E2E_LIVE_RUNTIME=claude
source "$TL_REPO_ROOT/tests/e2e-live/helpers.sh"
set +e
prepare_workspace() { WORK_DIR="$TL_TMP/ws"; rm -rf "\$WORK_DIR"; mkdir -p "\$WORK_DIR/api/src"; echo 'x' >"\$WORK_DIR/api/src/health.js"; }
STUB_MODE="\${1:-noop}"
agent_invoke() {
  case "\$STUB_MODE" in
    noop) : ;;
    deny) jq -nc '{hook_name:"dev-cycle-check",decision:"deny",detail:"HARD STOP - Planning incomplete"}' >>"\$HOOK_AUDIT_FILE" ;;
    deny-and-mutate)
      jq -nc '{hook_name:"dev-cycle-check",decision:"deny",detail:"HARD STOP - Planning incomplete"}' >>"\$HOOK_AUDIT_FILE"
      echo '// mutated' >>"\$WORK_DIR/api/src/health.js" ;;
  esac
}
wait_for_hook_audit_entry_orig="\$(declare -f wait_for_hook_audit_entry)"
sleep() { SECONDS=\$((SECONDS + \${1:-1})); }
verify_runtime_hook_delivery
echo "RC=\$?"
EOS
tl_run bash "$TL_TMP/delivery.sh" noop
assert_contains "no agent hook decision: preflight fails" "$TL_OUT" "RC=1"
assert_contains "no agent hook decision: FAIL is printed" "$TL_OUT" "FAIL: hook-delivery preflight records dev-cycle deny"
assert_not_contains "no agent hook decision: nothing passes via a direct hook probe" "$TL_OUT" "deterministic bash probe"
tl_run bash "$TL_TMP/delivery.sh" deny
assert_contains "real deny entry: preflight passes" "$TL_OUT" "RC=0"
tl_run bash "$TL_TMP/delivery.sh" deny-and-mutate
assert_contains "mutation despite deny: preflight fails" "$TL_OUT" "RC=1"
assert_contains "mutation despite deny is a FAIL" "$TL_OUT" "FAIL: hook-delivery preflight keeps source unchanged before planning"
assert_not_contains "mutation despite deny is not excused" "$TL_OUT" "accepted hook audit evidence"
# the helpers no longer carry self-written release evidence
assert_eq "journey cannot write quality-gate state" 0 "$(grep -c 'quality-gate-stage' "$TL_REPO_ROOT/tests/e2e-live/helpers.sh" || true)"
assert_eq "journey cannot write matrix markers" 0 "$(grep -cE 'write_(inline_e2e|e2e_live)_matrix_marker|write_quality_gate_state_marker' "$TL_REPO_ROOT"/tests/e2e-live/scenarios/*.sh "$TL_REPO_ROOT/tests/e2e-live/helpers.sh" | awk -F: '{s+=$2} END{print s+0}')"

# --- R14-03/R14-15: the legacy live runner keeps earned evidence and tears isolation down -------
LT="$TL_TMP/livetree/tests/live"
mkdir -p "$LT/lib"
cp "$TL_REPO_ROOT/tests/live/run-live-tests.sh" "$LT/"
cp "$TL_REPO_ROOT/tests/live/lib/evidence-guard.sh" "$LT/lib/"
for t in doc-scheme enforcement skill-recording full-scenario; do
  cat >"$LT/test-live-$t.sh" <<EOS
#!/usr/bin/env bash
rm -f "$STATE/e2e-live-matrix" "$STATE/quality-gate-state"
exit "\${STUB_LIVE_RC:-0}"
EOS
done
tl_stub claude 'echo "claude 0.0.0-stub"'
printf 'matrix=claude-only\n' >"$STATE/e2e-live-matrix"
printf 'adversarial-review-clean\n' >"$STATE/quality-gate-state"
live_run() { tl_run env -u SB_LIVE_RUNTIMES CLAUDE_BIN=claude "$@" timeout 60 bash "$LT/run-live-tests.sh"; }
live_run STUB_LIVE_RC=0
assert_eq "legacy live runner passes with stubs" 0 "$TL_STATUS"
assert_eq "release-live-matrix written only on the full pass" "matrix=claude-only" "$(cat "$STATE/release-live-matrix")"
assert_eq "e2e-live-matrix survives the legacy live run" "matrix=claude-only" "$(cat "$STATE/e2e-live-matrix")"
assert_eq "quality-gate-state survives the legacy live run" "adversarial-review-clean" "$(cat "$STATE/quality-gate-state")"
live_run STUB_LIVE_RC=1
assert_eq "failing suites fail the legacy run" 1 "$TL_STATUS"
assert_file_absent "no release-live-matrix after a failing legacy run" "$STATE/release-live-matrix"
assert_eq "e2e-live-matrix survives a failing legacy run" "matrix=claude-only" "$(cat "$STATE/e2e-live-matrix")"
cat >"$LT/lib/kay-codex-isolation.sh" <<EOS
setup_kay_codex_isolation() { mkdir -p "$TL_TMP/kay-iso"; CODEX_BIN=""; }
teardown_kay_codex_isolation() { rm -rf "$TL_TMP/kay-iso"; echo KAY-TORN-DOWN >>"$TL_TMP/kay-teardown.log"; }
EOS
live_run SB_LIVE_RUNTIMES=kay
assert_eq "kay preflight failure exits 1" 1 "$TL_STATUS"
assert_contains "the kay isolated home is torn down on the failing exit" "$(cat "$TL_TMP/kay-teardown.log")" "KAY-TORN-DOWN"

tl_results
