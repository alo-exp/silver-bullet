#!/usr/bin/env bash
# scripts/minimal-intent-autonomous-e2e.sh: preflight / start / score / status flows from a staged
# tree. The scorer library, the structural test and the matrix are fixtures; no live host session.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/k-agents-live-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/k-agents-live-2-helpers.sh"

T="$TL_TMP/tree"
k2_stage_e2e_tree "$T" minimal-intent-autonomous-e2e.sh
S="$T/scripts/minimal-intent-autonomous-e2e.sh"
PL="$T/.planning/minimal-intent-e2e"
WORK="$TL_TMP/work"
mkdir -p "$PL/fixtures" "$WORK"
export STUB_LOG="$TL_TMP/stub.log"; : >"$STUB_LOG"
cat >"$PL/MATRIX.json" <<JSON
{"fixture":{"work_dir_default":"$WORK","vision_template":"fixtures/vision.md","prefs_template":"fixtures/prefs.json"},
 "rows":[
  {"id":"MI-01","blocking_outcomes":["OUT-A","OUT-B","OUT-WORLD-01"],"advisory_outcomes":["OUT-ADV","OUT-ADV2"]},
  {"id":"MI-02","vision_template":"fixtures/v2.md","prefs_template":"fixtures/p2.json","blocking_outcomes":[]},
  {"id":"MI-03","blocking_outcomes":["OUT-A"]}
 ]}
JSON
echo "# vision one" >"$PL/fixtures/vision.md"; echo '{"p":1}' >"$PL/fixtures/prefs.json"
echo "# vision two" >"$PL/fixtures/v2.md"
cat >"$T/tests/scripts/test-minimal-intent-autonomous-e2e.sh" <<'EOS'
#!/usr/bin/env bash
echo "struct-test-ran"
[[ -z "${STRUCT_FAIL:-}" ]]
EOS
chmod +x "$T/tests/scripts/test-minimal-intent-autonomous-e2e.sh"
RUNS="$TL_TMP/runs"
run() { # [env...] -- args
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$STUB_LOG"
  tl_run env "${envs[@]}" SB_E2E_RUNS_DIR="$RUNS" bash "$S" "$@"
}

# ---------------- help / unknown ----------------
run X=1 --
assert_eq "no command prints usage" 0 "$TL_STATUS"
assert_contains "usage text" "$TL_OUT" "Usage: minimal-intent-autonomous-e2e.sh <command> [options]"
run X=1 -- help
assert_contains "help alias" "$TL_OUT" "Commands:"
run X=1 -- --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
run X=1 -- bogus
assert_eq "unknown command exits 2" 2 "$TL_STATUS"
assert_contains "unknown command message" "$TL_ERR" "Unknown command: bogus"

# ---------------- preflight ----------------
run X=1 -- preflight
assert_eq "preflight passes" 0 "$TL_STATUS"
assert_contains "preflight fingerprint" "$TL_OUT" "install_fp=fp-stub-123"
assert_contains "preflight sb sha unknown outside a git repo" "$TL_OUT" "sb_git_sha=unknown"
assert_contains "preflight runs the structural test" "$TL_OUT" "struct-test-ran"
assert_contains "preflight structural ok" "$TL_OUT" "OK: structural harness tests"
assert_contains "preflight workdir ok" "$TL_OUT" "OK: fixture work_dir exists: $WORK"
assert_contains "preflight hook libs" "$TL_OUT" "OK: hooks/lib/orchestrator-scheduler.sh"
assert_contains "preflight final line" "$TL_OUT" "PREFLIGHT PASS (structural — live session not run)"
run STRUCT_FAIL=1 -- preflight
assert_eq "structural failure fails preflight" 1 "$TL_STATUS"
assert_contains "structural failure message" "$TL_ERR" "ERROR: structural harness tests failed"
run SB_MINIMAL_INTENT_SKIP_STRUCT=1 STRUCT_FAIL=1 -- preflight
assert_eq "skip env bypasses structural test" 0 "$TL_STATUS"
assert_contains "skip message" "$TL_OUT" "structural harness tests (skipped — inner preflight)"
assert_not_contains "skipped test never ran" "$TL_OUT" "struct-test-ran"
chmod -x "$T/tests/scripts/test-minimal-intent-autonomous-e2e.sh"
run X=1 -- preflight
assert_eq "non-executable structural test fails preflight" 1 "$TL_STATUS"
assert_contains "missing structural test message" "$TL_ERR" "ERROR: missing $T/tests/scripts/test-minimal-intent-autonomous-e2e.sh"
chmod +x "$T/tests/scripts/test-minimal-intent-autonomous-e2e.sh"
mv "$PL/MATRIX.json" "$PL/MATRIX.bak"
run X=1 -- preflight
assert_eq "missing matrix fails preflight" 1 "$TL_STATUS"
assert_contains "missing matrix message" "$TL_ERR" "ERROR: missing $PL/MATRIX.json"
mv "$PL/MATRIX.bak" "$PL/MATRIX.json"
mv "$T/hooks/lib/orchestrator-state.sh" "$TL_TMP/state.bak"
rmdir "$WORK"
run X=1 -- preflight
assert_eq "warnings do not fail preflight" 0 "$TL_STATUS"
assert_contains "missing workdir warning" "$TL_ERR" "WARN: fixture work_dir missing: $WORK"
assert_contains "missing hook warning" "$TL_ERR" "WARN: missing hooks/lib/orchestrator-state.sh"
mv "$TL_TMP/state.bak" "$T/hooks/lib/orchestrator-state.sh"; mkdir "$WORK"
chmod -x "$S"
run X=1 -- preflight
assert_eq "non-executable harness is tolerated" 0 "$TL_STATUS"
chmod +x "$S"

# ---------------- start ----------------
run X=1 -- start
assert_eq "start needs --row" 2 "$TL_STATUS"; assert_contains "start --row message" "$TL_ERR" "--row required"
run X=1 -- start --bogus
assert_eq "start unknown arg" 2 "$TL_STATUS"; assert_contains "start unknown arg message" "$TL_ERR" "Unknown start arg: --bogus"
run X=1 -- start --row NOPE
assert_eq "start unknown row" 1 "$TL_STATUS"; assert_contains "start unknown row message" "$TL_ERR" "unknown row NOPE"
echo '{"p":2}' >"$PL/fixtures/p2.json"; rm -f "$PL/fixtures/v2.md"
run X=1 -- start --row MI-02
assert_eq "start missing vision" 1 "$TL_STATUS"; assert_contains "start missing vision message" "$TL_ERR" "ERROR: missing vision: $PL/fixtures/v2.md"
echo "# vision two" >"$PL/fixtures/v2.md"; rm -f "$PL/fixtures/p2.json"
run X=1 -- start --row MI-02
assert_eq "start missing prefs" 1 "$TL_STATUS"; assert_contains "start missing prefs message" "$TL_ERR" "ERROR: missing prefs: $PL/fixtures/p2.json"
run X=1 -- start --row MI-01 --work-dir "$TL_TMP/nowhere"
assert_eq "start missing work dir" 1 "$TL_STATUS"; assert_contains "start missing work dir message" "$TL_ERR" "work_dir not found: $TL_TMP/nowhere"
run X=1 -- start --row MI-01 --dry-run
assert_eq "dry-run start exits 0" 0 "$TL_STATUS"
assert_contains "dry-run message" "$TL_OUT" "DRY-RUN: run dir prepared; live parent session not started"
assert_not_contains "dry-run has no checklist" "$TL_OUT" "LIVE SESSION CHECKLIST"
RUN1="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
assert_match "run id format" '^[0-9]{8}T[0-9]{6}Z-MI-01$' "$RUN1"
assert_eq "vision copied" "# vision one" "$(cat "$RUNS/$RUN1/vision.md")"
assert_eq "intent seed mirrors vision" "# vision one" "$(cat "$RUNS/$RUN1/INTENT-SEED.txt")"
assert_eq "prefs copied" '{"p":1}' "$(cat "$RUNS/$RUN1/prefs.json")"
assert_file_exists "empty session log created" "$RUNS/$RUN1/parent-session.log"
assert_eq "ledger stub" "MI-01|prepared|fp-stub-123|false|cursor|parent" \
  "$(jq -r '[.row_id,.status,.install_fp,(.live_session_run|tostring),.host,.orchestrator_mode]|join("|")' "$RUNS/$RUN1/ledger.json")"
assert_eq "work dir comes from the matrix default" "work_dir=$WORK" "$(grep '^work_dir=' <<<"$TL_OUT")"
run SB_MINIMAL_INTENT_WORK_DIR="$TL_TMP" -- start --row MI-01
assert_eq "live start exits 0" 0 "$TL_STATUS"
assert_contains "env work dir used" "$TL_OUT" "work_dir=$TL_TMP"
assert_contains "operator checklist printed" "$TL_OUT" "LIVE SESSION CHECKLIST (operator):"
assert_contains "checklist names the score command" "$TL_OUT" "score --run "

# ---------------- score ----------------
RUN2="20260101T000000Z-MI-01"
mkdir -p "$RUNS/$RUN2"
jq -n '{row_id:"MI-01",status:"prepared"}' >"$RUNS/$RUN2/ledger.json"
run X=1 -- score
assert_eq "score needs --run" 2 "$TL_STATUS"; assert_contains "score --run message" "$TL_ERR" "--run required"
run X=1 -- score --bogus
assert_eq "score unknown arg" 2 "$TL_STATUS"; assert_contains "score unknown arg message" "$TL_ERR" "Unknown score arg: --bogus"
run X=1 -- score --run missing-run
assert_eq "score unknown run" 1 "$TL_STATUS"; assert_contains "score unknown run message" "$TL_ERR" "run dir not found: $RUNS/missing-run"
run X=1 -- score --run "$RUN2"
assert_eq "score needs a session log" 1 "$TL_STATUS"
assert_contains "score empty log message" "$TL_ERR" "session log empty or missing: $RUNS/$RUN2/parent-session.log"
assert_contains "score empty log hint" "$TL_ERR" "HINT: live parent session not captured"
echo "transcript" >"$RUNS/$RUN2/parent-session.log"
mkdir -p "$WORK/.planning/phases/p1"; echo s >"$WORK/.planning/phases/p1/SUMMARY.md"
run SB_RUNTIME_STATE_DIR="$TL_TMP/state" SCORE_OUT_ADV= -- score --run "$RUN2"
assert_eq "all outcomes pass" 0 "$TL_STATUS"
assert_contains "run header" "$TL_OUT" "run_id=$RUN2 row_id=MI-01"
assert_contains "blocking outcome scored" "$TL_OUT" "  OUT-A: pass|stub ok"
assert_contains "world outcome composite pass" "$TL_OUT" "  OUT-WORLD-01: pass"
assert_contains "advisory outcome empty detail shows n/a" "$TL_OUT" "  OUT-ADV: n/a (advisory)"
assert_contains "advisory outcome listed" "$TL_OUT" "  OUT-ADV2: pass|stub ok (advisory)"
assert_contains "verdict pass" "$TL_OUT" "VERDICT: PASS"
assert_contains "scorer args: outcome, work dir, state dir, log, ledger, evidence" "$(cat "$STUB_LOG")" \
  "SCORE OUT-A $WORK $TL_TMP/state $RUNS/$RUN2/parent-session.log  $RUNS/$RUN2/ledger.json .planning/phases/p1/SUMMARY.md"
assert_not_contains "world outcome is composite, never scored directly" "$(cat "$STUB_LOG")" "SCORE OUT-WORLD-01"
assert_eq "ledger scored" "scored|PASS|true" "$(jq -r '[.status,.verdict,(.live_session_run|tostring)]|join("|")' "$RUNS/$RUN2/ledger.json")"
assert_eq "ledger records the log" "$RUNS/$RUN2/parent-session.log" "$(jq -r .session_log "$RUNS/$RUN2/ledger.json")"
# failing outcome and empty scorer output
run SCORE_OUT_B="fail|bad" -- score --run "$RUN2"
assert_eq "failing outcome fails the run" 1 "$TL_STATUS"
assert_contains "failing outcome shown" "$TL_OUT" "  OUT-B: fail|bad"
assert_contains "world composite fails" "$TL_OUT" "  OUT-WORLD-01: fail"
assert_contains "verdict fail" "$TL_OUT" "VERDICT: FAIL"
assert_eq "ledger records the failure" "FAIL" "$(jq -r .verdict "$RUNS/$RUN2/ledger.json")"
run SCORE_OUT_B="" -- score --run "$RUN2"
assert_contains "empty scorer detail is a failure" "$TL_OUT" "  OUT-B: fail|scorer unavailable"
run SCORE_OUT_B="n/a" -- score --run "$RUN2"
assert_eq "n/a counts as acceptable" 0 "$TL_STATUS"
# custom log path, fallback evidence file, no phases dir
rm -rf "$WORK/.planning/phases"; mkdir -p "$WORK/.planning/workflows"; echo c >"$WORK/.planning/workflows/feature-currency.md"
echo "other transcript" >"$TL_TMP/other.log"
tl_run env -u SB_RUNTIME_STATE_DIR SB_E2E_RUNS_DIR="$RUNS" SCORE_OUT_ADV= STUB_LOG="$STUB_LOG" bash "$S" score --run "$RUN2" --log "$TL_TMP/other.log"
assert_eq "custom log accepted" 0 "$TL_STATUS"
assert_contains "currency fallback evidence" "$(cat "$STUB_LOG")" ".planning/workflows/feature-currency.md"
assert_eq "state dir defaults under HOME/.cursor" "ok" "$(grep -q " $HOME/.cursor/.silver-bullet " "$STUB_LOG" && echo ok)"
rm -rf "$WORK/.planning"
run X=1 -- score --run "$RUN2" --log "$TL_TMP/other.log"
assert_eq "no evidence available still scores" 0 "$TL_STATUS"
# scorer crashing (non-zero, no output) is a failed outcome, advisory crash is tolerated
run SCOREFAIL_OUT_B=1 -- score --run "$RUN2"
assert_eq "crashing blocking scorer fails the run" 1 "$TL_STATUS"
assert_contains "crashing scorer reported as unavailable" "$TL_OUT" "  OUT-B: fail|scorer unavailable"
run SCOREFAIL_OUT_ADV=1 -- score --run "$RUN2"
assert_eq "crashing advisory scorer is tolerated" 0 "$TL_STATUS"
assert_contains "crashing advisory scorer shows n/a" "$TL_OUT" "  OUT-ADV: n/a (advisory)"
# evidence lookup failing is tolerated
mkdir -p "$WORK/.planning/phases/p9"
tl_stub find 'exit 1'
hash -r
run X=1 -- score --run "$RUN2"
assert_eq "failing evidence search is tolerated" 0 "$TL_STATUS"
rm -f "$TL_BIN/find"; hash -r
# a row without advisory outcomes
mkdir -p "$RUNS/run3"; jq -n '{row_id:"MI-03",status:"prepared"}' >"$RUNS/run3/ledger.json"; echo t >"$RUNS/run3/parent-session.log"
run X=1 -- score --run run3
assert_eq "row without advisory outcomes" 0 "$TL_STATUS"
assert_not_contains "no advisory lines" "$TL_OUT" "(advisory)"

# ---------------- status ----------------
run X=1 -- status --bogus
assert_eq "status unknown arg" 2 "$TL_STATUS"; assert_contains "status unknown arg message" "$TL_ERR" "Unknown status arg: --bogus"
run X=1 -- status --run "$RUN2"
assert_contains "status of one run prints the ledger" "$TL_OUT" '"verdict": "PASS"'
run X=1 -- status --run nope
assert_eq "status of an unknown run" "No ledger for nope" "$TL_OUT"
run X=1 -- status
EMPTY_RUNS="$TL_TMP/empty-runs"; mkdir -p "$EMPTY_RUNS"
tl_run env SB_E2E_RUNS_DIR="$EMPTY_RUNS" bash "$S" status
assert_eq "empty runs dir lists nothing" "=== minimal-intent runs ===" "$TL_OUT"
# listing reads the redirected runs dir (SB_E2E_RUNS_DIR)
run X=1 -- status
assert_contains "listing header" "$TL_OUT" "=== minimal-intent runs ==="
assert_contains "listing shows runs from the redirected dir" "$TL_OUT" "MI-01  scored  verdict=PASS  live=True"
assert_contains "listing shows every run" "$TL_OUT" "MI-03  scored"
# the default location is used when no redirect is set
mkdir -p "$PL/runs/20250101T000000Z-MI-01"; jq -n '{row_id:"MI-01",status:"prepared",verdict:null,live_session_run:false}' >"$PL/runs/20250101T000000Z-MI-01/ledger.json"
: >"$STUB_LOG"
tl_run env -u SB_E2E_RUNS_DIR bash "$S" status
assert_contains "default runs dir listing" "$TL_OUT" "MI-01  prepared  verdict=None  live=False"

tl_results
