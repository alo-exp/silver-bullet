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
printf 'main\n' >"$STATE/branch"
printf '{"keep":1}\n' >"$SB_RUNTIME_HOME_ROOT/mcp-needs-auth-cache.json"
: >"$STATE/trivial"
cat >"$TL_TMP/abort.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/helpers.sh"
agent_preflight() { :; }
live_setup
[[ "\$(cat "$STATE/state")" == silver-plan ]] || { echo "operator state was touched"; exit 9; }
[[ "\$SILVER_BULLET_STATE_FILE" == "$STATE"/state-live-test-* && "\$SILVER_BULLET_BRANCH_FILE" == "$STATE"/branch-live-test-* ]] || { echo "nested session not isolated"; exit 8; }
false   # any failing command between setup and teardown aborts the script
echo "not reached"
EOS
tl_run bash "$TL_TMP/abort.sh"
assert_eq "aborted scenario exits non-zero" 1 "$TL_STATUS"
assert_eq "real state restored after abort" "silver-plan" "$(cat "$STATE/state")"
assert_eq "operator branch file untouched after abort (R14-03)" "main" "$(cat "$STATE/branch")"
leftover=("$STATE"/state-live-test-* "$STATE"/branch-live-test-*)
assert_eq "no per-run state file left after abort" "0" "$([[ -e "${leftover[0]}" ]] && echo "${#leftover[@]}" || echo 0)"
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
tl_git_repo "$TL_TMP/livetree"
tl_stub claude 'echo "claude 0.0.0-stub"'
printf 'matrix=claude-only\n' >"$STATE/e2e-live-matrix"
printf 'adversarial-review-clean\n' >"$STATE/quality-gate-state"
live_run() { tl_run env -u SB_LIVE_RUNTIMES CLAUDE_BIN=claude "$@" timeout 60 bash "$LT/run-live-tests.sh"; }
live_run STUB_LIVE_RC=0
assert_eq "legacy live runner passes with stubs" 0 "$TL_STATUS"
assert_eq "release-live-matrix written only on the full pass" "matrix=claude-only" "$(sed -n 1p "$STATE/release-live-matrix")"
assert_match "release-live-matrix carries the commit (R14-16)" '^commit=[0-9a-f]{40}$' "$(sed -n 2p "$STATE/release-live-matrix")"
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

# --- R14-09: Kay transcripts are private, redacted and never default into the checkout -----------
# the token-shaped fixture is assembled from pieces so no secret-shaped literal is committed
FAKE_PAT="ghp""_abcdefghijklmnopqrstuvwxyz0123456789""ABCD"
cat >"$TL_TMP/kay.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/agents/kay/agent.sh"
KAY_HOME="$TL_TMP/kayhome"; mkdir -p "\$KAY_HOME"
SB_ROOT="$TL_REPO_ROOT"
kay_resolve_session_archive() { return 1; }
src="$TL_TMP/rollout.jsonl"
printf '%s\n' '{"type":"thread.started","thread_id":"th-1"}' '{"type":"tool","out":"token ${FAKE_PAT}"}' >"\$src"
printf 'prompt text' >"$TL_TMP/prompt.txt"
dir="\$(codex_transcript_dir)"
echo "DIR=\$dir"
kay_capture_transcript "\$src" "$TL_TMP/prompt.txt" "2020-01-01T00:00:00Z" "$TL_TMP" >/dev/null
echo "MODE_DIR=\$(stat -c %a "\$dir")"
echo "MODE_LATEST=\$(stat -c %a "\$dir/latest.jsonl")"
echo "MODE_SESSION=\$(stat -c %a "\$dir/th-1.jsonl" 2>/dev/null || echo none)"
grep -c '${FAKE_PAT}' "\$dir/latest.jsonl" || true
EOS
tl_run bash "$TL_TMP/kay.sh"
assert_contains "kay default transcript dir is inside the isolated home" "$TL_OUT" "DIR=$TL_TMP/kayhome/.sb-transcripts"
assert_not_contains "kay default transcript dir is not in the checkout" "$TL_OUT" "DIR=$TL_REPO_ROOT"
assert_contains "kay transcript dir is 0700" "$TL_OUT" "MODE_DIR=700"
assert_contains "kay latest.jsonl is 0600" "$TL_OUT" "MODE_LATEST=600"
assert_eq "kay transcript holds no planted token" 0 "$(grep -c '^[1-9]' <<<"$(tail -1 <<<"$TL_OUT")")"
assert_contains "kay transcript keeps non-secret content" "$(cat "$TL_TMP/kayhome/.sb-transcripts/latest.jsonl")" "prompt text"
cat >"$TL_TMP/kay2.sh" <<EOS
source "$TL_REPO_ROOT/tests/live/agents/kay/agent.sh"
unset KAY_HOME KAY_SB_TEST_HOME SB_LIVE_CODEX_ISOLATION_DIR CODEX_TRANSCRIPT_DIR
codex_transcript_dir
CODEX_TRANSCRIPT_DIR=/explicit codex_transcript_dir
EOS
tl_run bash "$TL_TMP/kay2.sh"
assert_eq "kay fallback transcript dir is a private cache dir" "$HOME/.cache/silver-bullet/live-transcripts/kay
/explicit" "$TL_OUT"
assert_eq "transcript directories are gitignored" 0 "$(cd "$TL_REPO_ROOT" && git check-ignore -q tests/live/agents/kay/transcripts/latest.jsonl && git check-ignore -q tests/live/agents/codex/transcripts/x.jsonl; echo $?)"
assert_eq "codex isolation no longer defaults transcripts into the checkout" 0 "$(grep -c 'SB_ROOT}/tests/live/agents/codex/transcripts' "$TL_REPO_ROOT/tests/live/lib/codex-cli-isolation.sh" || true)"

# --- R14-13: the READMEs describe what the runners do -------------------------------------------
LIVE_README="$TL_REPO_ROOT/tests/live/README.md"
E2E_README="$TL_REPO_ROOT/tests/e2e-live/README.md"
default_rt="$(grep -E '^  RUNTIMES=\(claude\)$' "$TL_REPO_ROOT/tests/live/run-live-tests.sh" >/dev/null && echo claude)"
assert_eq "the legacy runner defaults to the claude runtime" claude "$default_rt"
assert_eq "the e2e runner defaults to the claude runtime" claude "$(grep -E '^  RUNTIMES=\(claude\)$' "$TL_REPO_ROOT/tests/e2e-live/run-e2e-live-tests.sh" >/dev/null && echo claude)"
assert_contains "live README names the claude default runtime" "$(cat "$LIVE_README")" "Claude by default"
assert_contains "live README names the claude-only marker" "$(cat "$LIVE_README")" "matrix=claude-only"
assert_not_contains "live README no longer calls codex-only the standard prerequisite" "$(cat "$LIVE_README")" "are now the standard release prerequisite"
assert_not_contains "live README no longer claims PID-named isolated state files" "$(cat "$LIVE_README")" "live-test-state-{PID}"
assert_not_contains "live README no longer says the Kay agent is the default" "$(cat "$LIVE_README")" "real Kay-backed agent**"
assert_contains "live README describes the backup and restore of trivial/cache" "$(cat "$LIVE_README")" "EXIT\` trap that restores them"
assert_contains "e2e README names the claude-only marker" "$(cat "$E2E_README")" "matrix=claude-only"
assert_not_contains "e2e README no longer promises the supervised matrix satisfies the gate" "$(cat "$E2E_README")" "complete either the Kay diagnostic path"
assert_contains "e2e README states the supervised matrix writes the inline marker" "$(cat "$E2E_README")" "writes the same marker"
assert_contains "the release block message names the supervised matrix and the commit rule" "$(cat "$TL_REPO_ROOT/hooks/lib/completion-audit/deploy-tier.sh")" "commit= naming the commit the matrix ran on"

# --- R14-14: the workflow can really target a self-hosted runner ---------------------------------
WF_FILE="$TL_REPO_ROOT/.github/workflows/e2e-live.yml"
assert_contains "e2e-live.yml takes a runner input" "$(cat "$WF_FILE")" "      runner:"
assert_contains "e2e-live.yml runs on the runner input" "$(cat "$WF_FILE")" 'runs-on: ${{ inputs.runner }}'
assert_not_contains "e2e-live.yml no longer pins ubuntu-latest" "$(cat "$WF_FILE")" "runs-on: ubuntu-latest"
assert_not_contains "e2e-live.yml no longer hard-seeds the codex runtime" "$(cat "$WF_FILE")" "export SILVER_BULLET_RUNTIME=codex
          source"
assert_contains "e2e-live.yml seeds the runtime of the first requested runtime" "$(cat "$WF_FILE")" 'case "${runtimes[0]}" in'

# review r1 minors
assert_not_contains "the journey prompt no longer says the harness writes release markers" "$(cat "$TL_REPO_ROOT/tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh")" "The harness writes the release-readiness markers"
assert_contains "workflow summary escapes the backticks around runner" "$(cat "$WF_FILE")" 'with the \`runner\` input set to a runner'
assert_not_contains "the shared workspace .tmp is never chmod'ed" "$(cat "$TL_REPO_ROOT/tests/live/lib/codex-cli-isolation.sh" "$TL_REPO_ROOT/tests/live/lib/kay-codex-isolation.sh")" 'chmod 700 "${workspace_root}/.tmp"'

tl_results
