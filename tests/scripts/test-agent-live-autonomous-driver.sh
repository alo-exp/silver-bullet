#!/usr/bin/env bash
# scripts/agent-claude-autonomous-test.sh against a staged repo copy with a controlled
# MATRIX.json, a stub invoke.sh, stub outcome scorer / install fingerprint and a recording tmux.
# No Claude, tmux server or network is used; run output goes to SB_E2E_RUNS_DIR in the sandbox.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

export TL_TMP
export TMPDIR="$TL_TMP/tmp"
mkdir -p "$TMPDIR"
FAKE="$TL_TMP/repo"
mkdir -p "$FAKE"
cp -R "$TL_REPO_ROOT/scripts" "$FAKE/scripts"
tl_git_repo "$FAKE"
DRIVER="$FAKE/scripts/agent-claude-autonomous-test.sh"
PLAN="$FAKE/.planning/agent-claude-autonomous"
mkdir -p "$PLAN/briefs" "$TL_TMP/fixture-app"
RUNS="$TL_TMP/runs"
export SB_E2E_RUNS_DIR="$RUNS"

# --- staged collaborators --------------------------------------------------------------
cat >"$FAKE/scripts/lib/enterprise-e2e-row-pass-registry.sh" <<'EOF'
enterprise_e2e_install_fingerprint() { printf 'claude@fp-test+0123456789ab\n'; }
EOF
cat >"$FAKE/scripts/lib/enterprise-e2e-outcome-assessment.sh" <<'EOF'
enterprise_e2e_outcome_score_criterion() {
  printf '%s|%s|%s|%s|%s|%s\n' "$1" "$2" "${3##*/}" "${4##*/}" "$5" "$7" >>"$SCORE_RECORD"
  case " ${SCORE_CRASH:-} " in *" $1 "*) return 1 ;; esac
  case " ${SCORE_FAIL:-} " in *" $1 "*) echo fail; return 0 ;; esac
  echo pass
}
EOF
cat >"$FAKE/scripts/agent-claude/invoke.sh" <<'EOF'
#!/usr/bin/env bash
printf 'invoke-args:%s\n' "$*" >>"$INVOKE_RECORD"
printf 'invoke-env CLAUDE_WORK_DIR=%s SB_AGENT_CLAUDE_DELEGATE=%s\n' "${CLAUDE_WORK_DIR-<unset>}" "${SB_AGENT_CLAUDE_DELEGATE-<unset>}" >>"$INVOKE_RECORD"
exit "${INVOKE_RC:-0}"
EOF
chmod +x "$FAKE/scripts/agent-claude/invoke.sh"
mkdir -p "$FAKE/tests/scripts"
printf '#!/usr/bin/env bash\nexit "${STRUCT_RC:-0}"\n' >"$FAKE/tests/scripts/test-agent-claude-autonomous-test.sh"
chmod +x "$FAKE/tests/scripts/test-agent-claude-autonomous-test.sh"
printf 'brief one\n' >"$PLAN/briefs/AUTO-C01.md"
printf 'brief two\n' >"$PLAN/briefs/AUTO-C02.md"
cat >"$PLAN/MATRIX.json" <<EOF
{
  "fixture": {"work_dir_default": "$TL_TMP/fixture-app"},
  "rows": [
    {"id": "AUTO-C01", "blocking_outcomes": ["OUT-A", "OUT-B"], "scorer": {"enterprise_row_num": 3, "evidence": "api/"}, "brief_template": "briefs/AUTO-C01.md"},
    {"id": "AUTO-C02", "e2e_analog": "Row 6", "blocking_outcomes": ["OUT-C"], "scorer": {"evidence": "README.md"}, "brief_template": "briefs/AUTO-C02.md"},
    {"id": "AUTO-C03", "blocking_outcomes": ["OUT-WORLD-01"], "brief_template": null},
    {"id": "AUTO-T03", "e2e_analog": "row 1 subset", "blocking_outcomes": ["OUT-D"], "brief_template": "briefs/AUTO-C01.md"},
    {"id": "AUTO-T04", "e2e_analog": "meta", "blocking_outcomes": [], "brief_template": "briefs/MISSING.md"},
    {"id": "AUTO-T05", "blocking_outcomes": ["OUT-E"], "brief_template": null}
  ]
}
EOF

export SCORE_RECORD="$TL_TMP/score-record"
export INVOKE_RECORD="$TL_TMP/invoke-record"
: >"$SCORE_RECORD"
: >"$INVOKE_RECORD"

# a recording tmux (the real one must never be reached) and fail-loud stand-ins for host CLIs
TMUX_REC="$TL_TMP/tmux-record"
tl_stub tmux "printf '%s\n' \"\$*\" >>'$TMUX_REC'; exit 0"
for cli in claude expect codex opencode pi; do
  tl_stub "$cli" "printf '%s %s\n' $cli \"\$*\" >>'$TL_TMP/unexpected-cli.log'; exit 99"
done

drv() { tl_run timeout 60 bash "$DRIVER" "$@"; }

# wait_for_status RUN-ID WANT: poll the ledger (bounded, ~10s) until status == WANT.
wait_for_status() {
  local run="$1" want="$2" i status=""
  for i in $(seq 1 100); do
    status="$(jq -r .status "$RUNS/$run/ledger.json" 2>/dev/null || true)"
    [[ "$status" == "$want" ]] && break
    [[ "$i" -lt 100 ]] && sleep 0.1
  done
  printf '%s' "$status"
}

# ---------------------------------------------------------------- usage / dispatch
drv --help
assert_eq "--help exits 0" "0" "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "Usage: agent-claude-autonomous-test.sh <command> [options]"
drv
assert_eq "no command prints usage and exits 0" "0" "$TL_STATUS"
assert_contains "no command usage" "$TL_OUT" "Commands:"
drv bogus
assert_eq "an unknown command exits 2" "2" "$TL_STATUS"
assert_contains "an unknown command is named" "$TL_ERR" "Unknown command: bogus"

# ---------------------------------------------------------------- status
drv status
assert_eq "status without runs exits 0" "0" "$TL_STATUS"
assert_contains "status without runs says none" "$TL_OUT" "(none)"
mkdir -p "$RUNS"
drv status
assert_eq "status with an empty runs dir exits 0" "0" "$TL_STATUS"
tl_stub ls 'exit 2'
drv status
assert_eq "status survives a failing listing" "0" "$TL_STATUS"
assert_contains "status reports none when the listing fails" "$TL_OUT" "(none)"
rm -f "$TL_BIN/ls"
drv status --run nope
assert_eq "status of an unknown run exits 0" "0" "$TL_STATUS"
assert_contains "status of an unknown run says missing" "$TL_ERR" "missing: $RUNS/nope/ledger.json"
drv status --bogus
assert_eq "status with an unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "status unknown arg named" "$TL_ERR" "Unknown status arg: --bogus"
drv status --run
assert_eq "status --run without a value exits 2" "2" "$TL_STATUS"
assert_contains "status --run without a value message" "$TL_ERR" "--run requires a value"

# ---------------------------------------------------------------- start: argument errors
drv start
assert_eq "start without --row exits 2" "2" "$TL_STATUS"
assert_contains "start without --row message" "$TL_ERR" "--row required"
drv start --row
assert_eq "start --row without a value exits 2" "2" "$TL_STATUS"
assert_contains "start --row without a value message" "$TL_ERR" "--row requires a value"
drv start --work-dir
assert_eq "start --work-dir without a value exits 2" "2" "$TL_STATUS"
assert_contains "start --work-dir without a value message" "$TL_ERR" "--work-dir requires a value"
drv start --bogus
assert_eq "start unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "start unknown arg named" "$TL_ERR" "Unknown start arg: --bogus"
drv start --row AUTO-C03
assert_eq "start AUTO-C03 is refused (score-only)" "2" "$TL_STATUS"
assert_contains "start AUTO-C03 message" "$TL_ERR" "AUTO-C03 is score-only"
drv start --row AUTO-NOPE
assert_eq "start with an unknown row exits 1" "1" "$TL_STATUS"
assert_contains "start with an unknown row message" "$TL_ERR" "unknown row AUTO-NOPE"
drv start --row AUTO-T05
assert_eq "start with a row without a brief template exits 1" "1" "$TL_STATUS"
assert_contains "start with a row without a brief template message" "$TL_ERR" "unknown row AUTO-T05"
drv start --row AUTO-T04
assert_eq "start with a missing brief file exits 1" "1" "$TL_STATUS"
assert_contains "start with a missing brief file message" "$TL_ERR" "missing brief: $PLAN/briefs/MISSING.md"
drv start --row AUTO-C01 --work-dir "$TL_TMP/no-such-dir"
assert_eq "start with a missing work dir exits 1" "1" "$TL_STATUS"
assert_contains "start with a missing work dir message" "$TL_ERR" "work_dir not found: $TL_TMP/no-such-dir"

# ---------------------------------------------------------------- start --dry-run
drv start --row AUTO-C01 --dry-run
assert_eq "start --dry-run exits 0" "0" "$TL_STATUS"
assert_contains "dry-run prints the install fingerprint" "$TL_OUT" "install_fp=claude@fp-test+0123456789ab"
assert_contains "dry-run says it skipped the invoke" "$TL_OUT" "DRY-RUN: run dir prepared; skipping invoke"
assert_contains "dry-run uses the fixture work dir" "$TL_OUT" "work_dir=$TL_TMP/fixture-app"
run_id="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
assert_match "dry-run run id has a timestamp and the row id" '^[0-9]{8}T[0-9]{6}Z-AUTO-C01$' "$run_id"
assert_eq "dry-run copied the brief" "brief one" "$(cat "$RUNS/$run_id/brief.md")"
assert_file_exists "dry-run created the log" "$RUNS/$run_id/claude-run.log"
assert_eq "dry-run ledger status" "started" "$(jq -r .status "$RUNS/$run_id/ledger.json")"
assert_eq "dry-run ledger row" "AUTO-C01" "$(jq -r .row_id "$RUNS/$run_id/ledger.json")"
assert_match "dry-run ledger records the git sha" '^[0-9a-f]{12}$' "$(jq -r .sb_git_sha "$RUNS/$run_id/ledger.json")"
assert_eq "dry-run ledger records the harness" "scripts/agent-claude-autonomous-test.sh" "$(jq -r .harness "$RUNS/$run_id/ledger.json")"
assert_eq "dry-run never invoked the delegate" "" "$(cat "$INVOKE_RECORD")"
drv status
assert_contains "status lists the run" "$TL_OUT" "$run_id"
drv status --run "$run_id"
assert_contains "status --run prints the ledger" "$TL_OUT" '"row_id": "AUTO-C01"'

# unknown git sha when SB_ROOT is not a repository
mkdir -p "$TL_TMP/nogit"
tl_run timeout 60 env SB_ROOT="$TL_TMP/nogit" bash "$DRIVER" start --row AUTO-C02 --dry-run --work-dir "$TL_TMP/fixture-app"
assert_eq "dry-run outside a git repo exits 0" "0" "$TL_STATUS"
run_id2="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
assert_eq "dry-run outside a git repo records sha unknown" "unknown" "$(jq -r .sb_git_sha "$RUNS/$run_id2/ledger.json")"
assert_eq "dry-run honours --work-dir" "brief two" "$(cat "$RUNS/$run_id2/brief.md")"

# ---------------------------------------------------------------- start: background launch
: >"$INVOKE_RECORD"
INVOKE_RC=0 drv start --row AUTO-C01 --use-print
assert_eq "background start exits 0" "0" "$TL_STATUS"
assert_contains "background start reports the delegate pid" "$TL_OUT" "STARTED: delegate PID"
assert_contains "background start prints the monitor command" "$TL_OUT" "MONITOR: bash scripts/agent-claude/monitor.sh --log"
bg_run="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
bg_status="$(wait_for_status "$bg_run" completed)"
assert_eq "the background delegate completes and the ledger records it" "completed" "$bg_status"
assert_eq "the ledger records the delegate exit" "0" "$(jq -r .delegate_exit "$RUNS/$bg_run/ledger.json")"
assert_match "the ledger records a completion time" '^[0-9]{4}-' "$(jq -r .completed_at "$RUNS/$bg_run/ledger.json")"
assert_match "the pid file matches the ledger" '^[0-9]+$' "$(cat "$RUNS/$bg_run/delegate.pid")"
assert_eq "the ledger pid is the pid file" "$(cat "$RUNS/$bg_run/delegate.pid")" "$(jq -r .delegate_pid "$RUNS/$bg_run/ledger.json")"
assert_contains "invoke got the work dir, brief, log and --use-print" "$(cat "$INVOKE_RECORD")" "invoke-args:--work-dir $TL_TMP/fixture-app --brief-file $RUNS/$bg_run/brief.md --log $RUNS/$bg_run/claude-run.log --use-print"
assert_contains "invoke ran with the delegation env" "$(cat "$INVOKE_RECORD")" "invoke-env CLAUDE_WORK_DIR=$TL_TMP/fixture-app SB_AGENT_CLAUDE_DELEGATE=1"

: >"$INVOKE_RECORD"
INVOKE_RC=3 drv start --row AUTO-C02 --work-dir "$TL_TMP/fixture-app"
bg_run2="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
assert_eq "a failing delegate is recorded as failed" "failed" "$(wait_for_status "$bg_run2" failed)"
assert_eq "the ledger records the failing delegate exit" "3" "$(jq -r .delegate_exit "$RUNS/$bg_run2/ledger.json")"
assert_not_contains "no --use-print without the flag" "$(cat "$INVOKE_RECORD")" "--use-print"

# ---------------------------------------------------------------- start --tmux (recording tmux)
: >"$TMUX_REC"
drv start --row AUTO-C01 --tmux
assert_eq "tmux start exits 0" "0" "$TL_STATUS"
assert_contains "tmux start reports the session" "$TL_OUT" "STARTED: tmux session agent-claude-auto-auto-c01"
tmux_run="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
assert_eq "tmux session name is recorded" "agent-claude-auto-auto-c01" "$(cat "$RUNS/$tmux_run/tmux.session")"
assert_eq "the ledger records the tmux session and running status" "agent-claude-auto-auto-c01 running" \
  "$(jq -r '.tmux_session + " " + .status' "$RUNS/$tmux_run/ledger.json")"
tmux_log="$(cat "$TMUX_REC")"
assert_contains "a stale session is killed first" "$tmux_log" "kill-session -t agent-claude-auto-auto-c01"
assert_contains "a detached session is created" "$tmux_log" "new-session -d -s agent-claude-auto-auto-c01"
assert_contains "the session runs invoke.sh with the brief and log" "$tmux_log" "agent-claude/invoke.sh"
assert_contains "the session records the exit in the ledger" "$tmux_log" "doc['status'] = 'completed' if exit_code == 0 else 'failed'"
assert_contains "the session passes the work dir" "$tmux_log" "CLAUDE_WORK_DIR="
# a failing `kill-session` for a stale session is ignored
tl_stub tmux "printf '%s\n' \"\$*\" >>'$TMUX_REC'; case \"\$1\" in kill-session) exit 1 ;; esac; exit 0"
: >"$TMUX_REC"
drv start --row AUTO-C01 --tmux
assert_eq "tmux start tolerates a failing kill-session" "0" "$TL_STATUS"
assert_contains "tmux start still creates the session" "$(cat "$TMUX_REC")" "new-session -d -s agent-claude-auto-auto-c01"
tl_stub tmux "printf '%s\n' \"\$*\" >>'$TMUX_REC'; exit 0"
NOTMUX_PATH="$(tl_path_without tmux)"
tl_run timeout 60 env PATH="$NOTMUX_PATH" bash "$DRIVER" start --row AUTO-C01 --tmux
assert_eq "tmux start without tmux exits 1" "1" "$TL_STATUS"
assert_contains "tmux start without tmux message" "$TL_ERR" "tmux required for --tmux"

# ---------------------------------------------------------------- preflight
drv preflight
assert_eq "preflight in a healthy staged repo exits 0" "0" "$TL_STATUS"
assert_contains "preflight reports the fingerprint" "$TL_OUT" "install_fp=claude@fp-test+0123456789ab"
assert_contains "preflight runs the dry-run harness preflight" "$TL_OUT" "OK: agent-claude preflight (dry-run)"
assert_contains "preflight runs the structural tests" "$TL_OUT" "OK: structural harness tests"
assert_contains "preflight finds the fixture work dir" "$TL_OUT" "OK: fixture work_dir exists: $TL_TMP/fixture-app"
assert_contains "preflight passes" "$TL_OUT" "PREFLIGHT PASS"
assert_contains "preflight warns when graphify is missing" "$TL_ERR" "WARN: graphify not on PATH"
tl_stub graphify 'exit 0'
drv preflight
assert_contains "preflight sees graphify" "$TL_OUT" "OK: graphify on PATH"
rm -f "$TL_BIN/graphify"

tl_run timeout 60 env STRUCT_RC=1 bash "$DRIVER" preflight
assert_eq "preflight fails when the structural tests fail" "1" "$TL_STATUS"
assert_contains "preflight reports failing structural tests" "$TL_ERR" "structural harness tests failed"
assert_not_contains "a failed preflight does not claim PASS" "$TL_OUT" "PREFLIGHT PASS"

mv "$FAKE/tests/scripts/test-agent-claude-autonomous-test.sh" "$TL_TMP/struct.moved"
drv preflight
assert_eq "preflight without the structural test file still passes" "0" "$TL_STATUS"
mv "$TL_TMP/struct.moved" "$FAKE/tests/scripts/test-agent-claude-autonomous-test.sh"

mv "$FAKE/scripts/claude-interactive-invoke.expect" "$TL_TMP/expect.moved" 2>/dev/null || true
drv preflight
assert_eq "preflight fails when the harness dry-run preflight fails" "1" "$TL_STATUS"
assert_contains "preflight reports harness dry-run issues" "$TL_ERR" "WARN: agent-claude preflight dry-run issues"
mv "$TL_TMP/expect.moved" "$FAKE/scripts/claude-interactive-invoke.expect" 2>/dev/null || true

mv "$PLAN/MATRIX.json" "$TL_TMP/matrix.moved"
mv "$FAKE/scripts/agent-claude/invoke.sh" "$TL_TMP/invoke.moved"
tl_run timeout 60 bash -c "bash '$DRIVER' preflight"
assert_eq "preflight without matrix and invoke.sh fails" "1" "$TL_STATUS"
assert_contains "preflight reports the missing matrix" "$TL_ERR" "ERROR: missing $PLAN/MATRIX.json"
assert_contains "preflight reports the missing invoke.sh" "$TL_ERR" "ERROR: missing invoke.sh"
mv "$TL_TMP/invoke.moved" "$FAKE/scripts/agent-claude/invoke.sh"
mv "$TL_TMP/matrix.moved" "$PLAN/MATRIX.json"

# a fixture work dir that does not exist is only a warning
sed -i "s#$TL_TMP/fixture-app#$TL_TMP/fixture-gone#" "$PLAN/MATRIX.json"
drv preflight
assert_eq "preflight with a missing fixture dir still passes" "0" "$TL_STATUS"
assert_contains "preflight warns about the missing fixture dir" "$TL_ERR" "WARN: fixture work_dir missing: $TL_TMP/fixture-gone"
sed -i "s#$TL_TMP/fixture-gone#$TL_TMP/fixture-app#" "$PLAN/MATRIX.json"

# a non-git SB_ROOT reports sha unknown in the preflight header (the harness dry-run then fails: no expect harness)
tl_run timeout 60 env SB_ROOT="$TL_TMP/nogit" bash "$DRIVER" preflight
assert_contains "preflight outside a git repo reports an unknown sha" "$TL_OUT" "sb_git_sha=unknown"
assert_eq "preflight with an unusable SB_ROOT fails" "1" "$TL_STATUS"

# ---------------------------------------------------------------- score: errors
drv score
assert_eq "score without --run exits 2" "2" "$TL_STATUS"
assert_contains "score without --run message" "$TL_ERR" "--run required"
drv score --run
assert_eq "score --run without a value exits 2" "2" "$TL_STATUS"
assert_contains "score --run without a value message" "$TL_ERR" "--run requires a value"
drv score --bogus
assert_eq "score unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "score unknown arg named" "$TL_ERR" "Unknown score arg: --bogus"
drv score --run nope
assert_eq "score of an unknown run exits 1" "1" "$TL_STATUS"
assert_contains "score of an unknown run message" "$TL_ERR" "missing ledger: $RUNS/nope/ledger.json"
mkdir -p "$RUNS/no-log"
printf '{"row_id":"AUTO-C01"}\n' >"$RUNS/no-log/ledger.json"
drv score --run no-log
assert_eq "score without a log exits 1" "1" "$TL_STATUS"
assert_contains "score without a log message" "$TL_ERR" "missing log: $RUNS/no-log/claude-run.log"

# ---------------------------------------------------------------- score: scored rows
mk_run() { # mk_run ID ROW LOG-BYTES
  mkdir -p "$RUNS/$1"
  printf '{"row_id":"%s","status":"completed"}\n' "$2" >"$RUNS/$1/ledger.json"
  head -c "$3" /dev/zero | tr '\0' 'l' >"$RUNS/$1/claude-run.log"
}
mk_run run-c01 AUTO-C01 800
: >"$SCORE_RECORD"
drv score --run run-c01
assert_eq "scoring a passing row exits 0" "0" "$TL_STATUS"
assert_contains "scoring header" "$TL_OUT" "=== scoring run run-c01 (row AUTO-C01, scorer_row_num=3) ==="
assert_contains "scoring prints each criterion" "$TL_OUT" "  OUT-A => pass"
assert_contains "scoring prints the second criterion" "$TL_OUT" "  OUT-B => pass"
assert_contains "scoring verdict" "$TL_OUT" "VERDICT: PASS (conservative"
assert_eq "ledger verdict" "PASS" "$(jq -r .verdict "$RUNS/run-c01/ledger.json")"
assert_eq "ledger blocking outcomes" '{"OUT-A":"pass","OUT-B":"pass"}' "$(jq -c .blocking_outcomes "$RUNS/run-c01/ledger.json")"
assert_eq "ledger log bytes" "800" "$(jq -r .log_bytes "$RUNS/run-c01/ledger.json")"
assert_match "ledger scored_at" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$(jq -r .scored_at "$RUNS/run-c01/ledger.json")"
assert_contains "the scorer got the row number and evidence" "$(cat "$SCORE_RECORD")" "OUT-A|$TL_TMP/fixture-app|"
assert_contains "the scorer got row 3 and the evidence path" "$(cat "$SCORE_RECORD")" "|3|api/"

tl_run timeout 60 env SCORE_FAIL="OUT-B" bash "$DRIVER" score --run run-c01
assert_eq "a failing criterion still scores (exit 0)" "0" "$TL_STATUS"
assert_contains "a failing criterion is shown" "$TL_OUT" "  OUT-B => fail"
assert_eq "a failing criterion makes the verdict FAIL" "FAIL" "$(jq -r .verdict "$RUNS/run-c01/ledger.json")"
tl_run timeout 60 env SCORE_CRASH="OUT-A" bash "$DRIVER" score --run run-c01
assert_contains "a crashing scorer counts as fail" "$TL_OUT" "  OUT-A => fail"
assert_eq "a crashing scorer makes the verdict FAIL" "FAIL" "$(jq -r .verdict "$RUNS/run-c01/ledger.json")"

mk_run run-small AUTO-C01 100
drv score --run run-small
assert_contains "a log below the floor warns" "$TL_OUT" "WARN: log floor not met (100 < 512 B)"
assert_eq "a log below the floor fails the verdict" "FAIL" "$(jq -r .verdict "$RUNS/run-small/ledger.json")"
tl_run timeout 60 env SB_AGENT_CLAUDE_LOG_FLOOR=50 bash "$DRIVER" score --run run-small
assert_eq "SB_AGENT_CLAUDE_LOG_FLOOR lowers the floor" "PASS" "$(jq -r .verdict "$RUNS/run-small/ledger.json")"

# scorer profile mapping: analog 'row 6' -> 6, 'row 1' -> 3, others -> 0
mk_run run-c02 AUTO-C02 800
: >"$SCORE_RECORD"
drv score --run run-c02
assert_contains "analog row 6 maps to scorer row 6" "$TL_OUT" "scorer_row_num=6"
assert_contains "the evidence for the analog row is passed" "$(cat "$SCORE_RECORD")" "|6|README.md"
mk_run run-t03 AUTO-T03 800
drv score --run run-t03
assert_contains "analog row 1 maps to scorer row 3" "$TL_OUT" "scorer_row_num=3"
mk_run run-t04 AUTO-T04 800
drv score --run run-t04
assert_contains "an analog without a row maps to scorer row 0" "$TL_OUT" "scorer_row_num=0"
assert_eq "a row without blocking outcomes passes on the log floor alone" "PASS" "$(jq -r .verdict "$RUNS/run-t04/ledger.json")"
mk_run run-unknown AUTO-NOPE 800
drv score --run run-unknown
assert_eq "scoring a ledger of an unknown row fails" "1" "$TL_STATUS"

# ---------------------------------------------------------------- score: composite AUTO-C03
mk_comp() { # mk_comp ID verdict-json...
  mkdir -p "$RUNS/$1"
  printf '{"row_id":"AUTO-C03","composite_runs":%s}\n' "$2" >"$RUNS/$1/ledger.json"
  head -c "${3:-800}" /dev/zero | tr '\0' 'l' >"$RUNS/$1/claude-run.log"
}
mkdir -p "$RUNS/dep-ok1" "$RUNS/dep-ok2" "$RUNS/dep-bad" "$RUNS/dep-partial"
printf '{"verdict":"PASS","blocking_outcomes":{"OUT-A":"pass"}}\n' >"$RUNS/dep-ok1/ledger.json"
printf '{"verdict":"PASS","blocking_outcomes":{}}\n' >"$RUNS/dep-ok2/ledger.json"
printf '{"verdict":"FAIL","blocking_outcomes":{"OUT-A":"pass"}}\n' >"$RUNS/dep-bad/ledger.json"
printf '{"verdict":"PASS","blocking_outcomes":{"OUT-A":"partial"}}\n' >"$RUNS/dep-partial/ledger.json"

mk_comp comp-ok '["dep-ok1","dep-ok2"]'
drv score --run comp-ok
assert_eq "a satisfied composite exits 0" "0" "$TL_STATUS"
assert_contains "composite world check passes" "$TL_OUT" "OUT-WORLD-01 => pass (composite dependency check)"
assert_contains "composite verdict" "$TL_OUT" "VERDICT: PASS (composite"
assert_eq "composite ledger verdict" "PASS" "$(jq -r .verdict "$RUNS/comp-ok/ledger.json")"
assert_eq "composite ledger outcome" '{"OUT-WORLD-01":"pass"}' "$(jq -c .blocking_outcomes "$RUNS/comp-ok/ledger.json")"
assert_eq "composite ledger log bytes" "800" "$(jq -r .log_bytes "$RUNS/comp-ok/ledger.json")"

mk_comp comp-one '["dep-ok1"]'
drv score --run comp-one
assert_contains "a composite with fewer than two runs fails" "$TL_OUT" "OUT-WORLD-01 => fail"
assert_eq "a composite with fewer than two runs gets FAIL" "FAIL" "$(jq -r .verdict "$RUNS/comp-one/ledger.json")"
mk_comp comp-missing '["dep-ok1","dep-gone"]'
drv score --run comp-missing
assert_contains "a composite with a missing sub-ledger fails" "$TL_OUT" "OUT-WORLD-01 => fail"
mk_comp comp-bad '["dep-ok1","dep-bad"]'
drv score --run comp-bad
assert_contains "a composite with a non-PASS sub-verdict fails" "$TL_OUT" "OUT-WORLD-01 => fail"
mk_comp comp-partial '["dep-ok1","dep-partial"]'
drv score --run comp-partial
assert_contains "a composite with a non-pass blocking outcome fails" "$TL_OUT" "OUT-WORLD-01 => fail"
mk_comp comp-nokey '[]'
printf '{"row_id":"AUTO-C03"}\n' >"$RUNS/comp-nokey/ledger.json"
drv score --run comp-nokey
assert_contains "a composite without composite_runs fails" "$TL_OUT" "OUT-WORLD-01 => fail"
mk_comp comp-small '["dep-ok1","dep-ok2"]' 100
drv score --run comp-small
assert_contains "a composite log below the floor warns" "$TL_OUT" "WARN: log floor not met (100 < 512 B)"
assert_eq "a composite log below the floor fails the verdict" "FAIL" "$(jq -r .verdict "$RUNS/comp-small/ledger.json")"

assert_file_absent "no real host CLI was reached" "$TL_TMP/unexpected-cli.log"
assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"
assert_eq "the checkout tree was not touched by the run dirs" "" "$(git -C "$TL_REPO_ROOT" status --porcelain --untracked-files=all -- .planning/agent-claude-autonomous/runs 2>/dev/null || true)"

tl_results
