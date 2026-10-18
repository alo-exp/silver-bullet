#!/usr/bin/env bash
# scripts/sb-tri-criteria-e2e.sh: preflight / start / score / live / cold / status from a staged
# tree. Scorer libs, per-track live/cold scripts and the structural test are stubs; the fixture work
# dir is a throwaway git repo. No host CLI, no tmux, no network.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/k-agents-live-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/k-agents-live-2-helpers.sh"

T="$TL_TMP/tree"
k2_stage_e2e_tree "$T" sb-tri-criteria-e2e.sh
S="$T/scripts/sb-tri-criteria-e2e.sh"
PL="$T/.planning/sb-tri-criteria-e2e"
WORK="$TL_TMP/work"
tl_git_repo "$WORK"
export STUB_LOG="$TL_TMP/stub.log"; : >"$STUB_LOG"
mkdir -p "$PL/scripts" "$T/docs/testing" "$T/hooks/lib"
: >"$T/hooks/lib/orchestrator-event-log.sh"
echo '{"criteria":[{"id":"OUT-MULTIWF-01"}]}' >"$T/docs/testing/outcome-criteria-registry.json"
echo '{"fixture":{"work_dir_default":"'"$WORK"'"}}' >"$PL/MATRIX.json"
echo design >"$PL/DESIGN.md"; echo criteria >"$PL/CURSOR-MULTIWF-CRITERIA.md"
mk_track() { # <TC-0N> <dir-name>
  local id="$1" dir="$PL/$2"
  mkdir -p "$dir/fixtures"
  echo rb >"$dir/RUNBOOK.md"; echo cr >"$dir/CRITERIA.md"
  cat >"$dir/MATRIX.json" <<JSON
{"fixture":{"vision_template":"fixtures/vision.md","prefs_template":"fixtures/prefs.json"},
 "rows":[{"id":"$id","blocking_outcomes":["OUT-A","OUT-B","OUT-WORLD-01"],"advisory_outcomes":["OUT-ADV"]}]}
JSON
  echo "# vision $id" >"$dir/fixtures/vision.md"; echo "{\"p\":\"$id\"}" >"$dir/fixtures/prefs.json"
}
mk_track TC-01 TC-01-multiwf-chain
mk_track TC-02 TC-02-dynamic-compose
mk_track TC-03 TC-03-net-new-workflow
cat >"$T/tests/scripts/test-sb-tri-criteria-e2e.sh" <<'EOS'
#!/usr/bin/env bash
echo "struct-test-ran"
[[ -z "${STRUCT_FAIL:-}" ]]
EOS
chmod +x "$T/tests/scripts/test-sb-tri-criteria-e2e.sh"
for sc in live-verify-track cold-verify-track live-verify-track-host; do
  cat >"$PL/scripts/$sc.sh" <<EOS
#!/usr/bin/env bash
echo "$sc \$* work=\${SB_TRI_CRITERIA_WORK_DIR:-} host=\${SB_TRI_CRITERIA_HOST:-} greenfield=\${SB_TRI_CRITERIA_GREENFIELD:-} preserve=\${SB_RUNTIME_PRESERVE_STATE_DIR:-} state=\${SB_RUNTIME_STATE_DIR:-unset}" >>"\${STUB_LOG:?}"
echo "stub session transcript" >"\${@: -1}/parent-session.log"
[[ -z "\${LIVE_SCRIPT_FAIL:-}" ]]
EOS
  chmod +x "$PL/scripts/$sc.sh"
done
RUNS="$TL_TMP/runs"
# Unique, increasing run ids without sleeping: the harness asks `date` for %Y%m%dT%H%M%SZ stamps.
REAL_DATE="$(command -v date)"
tl_stub date "if [[ \"\$*\" == *%Y%m%dT%H%M%SZ* ]]; then n=\$(cat '$TL_TMP/date.n' 2>/dev/null || echo 0); n=\$((n+1)); echo \$n >'$TL_TMP/date.n'; printf '20260301T%06dZ\n' \$n; else exec '$REAL_DATE' \"\$@\"; fi"
hash -r
run() { # [env...] -- args
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$STUB_LOG"
  tl_run env -u SB_RUNTIME_STATE_DIR -u SB_TRI_CRITERIA_HOST -u SB_TRI_CRITERIA_WORK_DIR -u SB_MINIMAL_INTENT_WORK_DIR \
    "${envs[@]}" SB_E2E_RUNS_DIR="$RUNS" bash "$S" "$@"
}

# ---------------- help / unknown ----------------
run X=1 --
assert_eq "no command prints usage" 0 "$TL_STATUS"
assert_contains "usage" "$TL_OUT" "Usage: sb-tri-criteria-e2e.sh <command> [options]"
run X=1 -- help
assert_contains "help alias" "$TL_OUT" "--greenfield"
run X=1 -- --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
run X=1 -- bogus
assert_eq "unknown command" 2 "$TL_STATUS"; assert_contains "unknown command message" "$TL_ERR" "Unknown command: bogus"

# ---------------- preflight ----------------
run X=1 -- preflight
assert_eq "preflight passes" 0 "$TL_STATUS"
assert_contains "preflight lists track files" "$TL_OUT" "OK: TC-03/MATRIX.json"
assert_contains "preflight structural" "$TL_OUT" "struct-test-ran"
assert_contains "preflight hooks" "$TL_OUT" "OK: hooks/lib/orchestrator-event-log.sh"
assert_contains "preflight registry" "$TL_OUT" "OK: OUT-MULTIWF-01 in outcome registry"
assert_contains "preflight final" "$TL_OUT" "PREFLIGHT PASS (structural — live sessions not run)"
run X=1 -- preflight --track TC-02
assert_contains "track filter keeps the chosen track" "$TL_OUT" "OK: TC-02/RUNBOOK.md"
assert_not_contains "track filter skips the others" "$TL_OUT" "TC-01/"
run X=1 -- preflight --bogus
assert_eq "preflight unknown arg" 2 "$TL_STATUS"; assert_contains "preflight unknown arg message" "$TL_ERR" "Unknown preflight arg: --bogus"
run STRUCT_FAIL=1 -- preflight
assert_eq "structural failure" 1 "$TL_STATUS"; assert_contains "structural failure message" "$TL_ERR" "structural harness tests failed"
run SB_TRI_CRITERIA_SKIP_STRUCT=1 STRUCT_FAIL=1 -- preflight
assert_eq "skip struct" 0 "$TL_STATUS"; assert_contains "skip struct message" "$TL_OUT" "skipped — inner preflight"
chmod -x "$T/tests/scripts/test-sb-tri-criteria-e2e.sh"
run X=1 -- preflight
assert_eq "non-executable struct test" 1 "$TL_STATUS"; assert_contains "missing struct test message" "$TL_ERR" "ERROR: missing $T/tests/scripts/test-sb-tri-criteria-e2e.sh"
chmod +x "$T/tests/scripts/test-sb-tri-criteria-e2e.sh"
mv "$PL/MATRIX.json" "$PL/MATRIX.bak"; mv "$PL/DESIGN.md" "$PL/DESIGN.bak"; mv "$PL/CURSOR-MULTIWF-CRITERIA.md" "$PL/CRIT.bak"
mv "$PL/TC-01-multiwf-chain/CRITERIA.md" "$PL/crit1.bak"; mv "$T/hooks/lib/orchestrator-state.sh" "$TL_TMP/st.bak"
run X=1 -- preflight
assert_eq "missing files fail preflight" 1 "$TL_STATUS"
assert_contains "missing umbrella matrix" "$TL_ERR" "ERROR: missing $PL/MATRIX.json"
assert_contains "missing design" "$TL_ERR" "ERROR: missing DESIGN.md"
assert_contains "missing criteria warning" "$TL_ERR" "WARN: missing CURSOR-MULTIWF-CRITERIA.md"
assert_contains "missing track file" "$TL_ERR" "ERROR: missing $PL/TC-01-multiwf-chain/CRITERIA.md"
assert_contains "missing hook warning" "$TL_ERR" "WARN: missing hooks/lib/orchestrator-state.sh"
mv "$PL/MATRIX.bak" "$PL/MATRIX.json"; mv "$PL/DESIGN.bak" "$PL/DESIGN.md"; mv "$PL/CRIT.bak" "$PL/CURSOR-MULTIWF-CRITERIA.md"
mv "$PL/crit1.bak" "$PL/TC-01-multiwf-chain/CRITERIA.md"; mv "$TL_TMP/st.bak" "$T/hooks/lib/orchestrator-state.sh"
echo '{"criteria":[]}' >"$T/docs/testing/outcome-criteria-registry.json"
run X=1 -- preflight
assert_eq "registry without the outcome fails" 1 "$TL_STATUS"; assert_contains "registry message" "$TL_ERR" "OUT-MULTIWF-01 missing from registry"
echo '{"criteria":[{"id":"OUT-MULTIWF-01"}]}' >"$T/docs/testing/outcome-criteria-registry.json"
NOJQ="$(tl_path_without jq)"
run PATH="$NOJQ" -- preflight
assert_eq "no jq skips the registry check" 0 "$TL_STATUS"; assert_not_contains "no registry line without jq" "$TL_OUT" "outcome registry"

# ---------------- start ----------------
run X=1 -- start
assert_eq "start needs --track" 2 "$TL_STATUS"; assert_contains "start --track message" "$TL_ERR" "--track required"
run X=1 -- start --bogus
assert_eq "start unknown arg" 2 "$TL_STATUS"; assert_contains "start unknown arg message" "$TL_ERR" "Unknown start arg: --bogus"
run X=1 -- start --track TC-99
assert_eq "start unknown track" 1 "$TL_STATUS"; assert_contains "unknown track message" "$TL_ERR" "unknown track TC-99"
echo '{"rows":[]}' >"$PL/TC-02-dynamic-compose/MATRIX.json"
run X=1 -- start --track TC-02
assert_eq "start unknown row" 1 "$TL_STATUS"; assert_contains "unknown row message" "$TL_ERR" "unknown row TC-02"
mk_track TC-02 TC-02-dynamic-compose
mv "$PL/TC-03-net-new-workflow/fixtures/vision.md" "$TL_TMP/vision.bak"
run X=1 -- start --track TC-03
assert_eq "start missing vision" 1 "$TL_STATUS"; assert_contains "missing vision message" "$TL_ERR" "ERROR: missing vision: $PL/TC-03-net-new-workflow/fixtures/vision.md"
mv "$TL_TMP/vision.bak" "$PL/TC-03-net-new-workflow/fixtures/vision.md"
mv "$PL/TC-03-net-new-workflow/fixtures/prefs.json" "$TL_TMP/prefs.bak"
run X=1 -- start --track TC-03
assert_eq "start missing prefs" 1 "$TL_STATUS"; assert_contains "missing prefs message" "$TL_ERR" "ERROR: missing prefs: $PL/TC-03-net-new-workflow/fixtures/prefs.json"
mv "$TL_TMP/prefs.bak" "$PL/TC-03-net-new-workflow/fixtures/prefs.json"
run X=1 -- start --track TC-01 --work-dir "$TL_TMP/nowhere"
assert_eq "start missing work dir" 1 "$TL_STATUS"; assert_contains "missing work dir message" "$TL_ERR" "work_dir not found: $TL_TMP/nowhere"
run X=1 -- start --track TC-01 --dry-run
assert_eq "dry run exits 0" 0 "$TL_STATUS"
assert_contains "dry run message" "$TL_OUT" "DRY-RUN: run dir prepared; live session not started"
RUN1="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
assert_match "run id" '^[0-9]{8}T[0-9]{6}Z-TC-01$' "$RUN1"
assert_eq "vision and prefs copied" "# vision TC-01|{\"p\":\"TC-01\"}" "$(cat "$RUNS/$RUN1/INTENT-SEED.txt")|$(cat "$RUNS/$RUN1/prefs.json")"
assert_eq "ledger defaults to cursor parent" "TC-01|TC-01|prepared|cursor|parent|false" \
  "$(jq -r '[.track_id,.row_id,.status,.host,.orchestrator_mode,(.live_session_run|tostring)]|join("|")' "$RUNS/$RUN1/ledger.json")"
assert_contains "design path printed" "$TL_OUT" "design=$PL/DESIGN.md"
for h in claude codex; do
  run SB_TRI_CRITERIA_HOST=$h -- start --track TC-01 --dry-run
  id="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
  assert_eq "ledger for host $h" "$h|delegation" "$(jq -r '[.host,.orchestrator_mode]|join("|")' "$RUNS/$id/ledger.json")"
  assert_contains "mechanism for host $h" "$(jq -r .mechanism "$RUNS/$id/ledger.json")" "/sb:agent-$h"
done
run SB_TRI_CRITERIA_HOST=weird -- start --track TC-01 --dry-run
id="$(sed -n 's/^run_id=//p' <<<"$TL_OUT")"
assert_eq "unknown host normalized to cursor" "cursor|parent" "$(jq -r '[.host,.orchestrator_mode]|join("|")' "$RUNS/$id/ledger.json")"
run SB_TRI_CRITERIA_WORK_DIR="$TL_TMP" -- start --track TC-02
assert_eq "live start" 0 "$TL_STATUS"
assert_contains "work dir env honored" "$TL_OUT" "work_dir=$TL_TMP"
assert_contains "checklist host hint" "$TL_OUT" "1. Host: Cursor parent orchestrator in: $TL_TMP"
assert_contains "checklist score hint" "$TL_OUT" "--track TC-02"
run SB_MINIMAL_INTENT_WORK_DIR="$TL_TMP" -- start --track TC-03
assert_contains "minimal-intent work dir fallback" "$TL_OUT" "work_dir=$TL_TMP"
assert_contains "TC-03 on cursor keeps the cursor hint" "$TL_OUT" "Cursor parent orchestrator"
run SB_TRI_CRITERIA_HOST=agent-claude -- start --track TC-03
assert_contains "TC-03 agent-claude hint" "$TL_OUT" "agent-claude delegation (see TC-03 RUNBOOK)"

# ---------------- score ----------------
RUN2="20260101T000000Z-TC-01"
mkdir -p "$RUNS/$RUN2"; jq -n '{row_id:"TC-01",status:"prepared"}' >"$RUNS/$RUN2/ledger.json"
run X=1 -- score
assert_eq "score needs --run" 2 "$TL_STATUS"; assert_contains "score --run message" "$TL_ERR" "--run required"
run X=1 -- score --run "$RUN2"
assert_eq "score needs --track" 2 "$TL_STATUS"; assert_contains "score --track message" "$TL_ERR" "--track required"
run X=1 -- score --bogus
assert_eq "score unknown arg" 2 "$TL_STATUS"; assert_contains "score unknown arg message" "$TL_ERR" "Unknown score arg: --bogus"
run X=1 -- score --run nope --track TC-01
assert_eq "score unknown run" 1 "$TL_STATUS"; assert_contains "unknown run message" "$TL_ERR" "run dir not found: $RUNS/nope"
run X=1 -- score --run "$RUN2" --track TC-01
assert_eq "score without log" 1 "$TL_STATUS"
assert_contains "empty log message" "$TL_ERR" "session log empty or missing: $RUNS/$RUN2/parent-session.log"
assert_contains "empty log hint" "$TL_ERR" "HINT: live session not captured"
echo transcript >"$RUNS/$RUN2/parent-session.log"
run X=1 -- score --run "$RUN2" --track TC-99
assert_eq "score unknown track" 1 "$TL_STATUS"; assert_contains "unknown track message" "$TL_ERR" "unknown track TC-99"
run SB_RUNTIME_STATE_DIR="$TL_TMP/st" -- score --run "$RUN2" --track TC-01
assert_eq "score without composition log warns but passes" 0 "$TL_STATUS"
assert_contains "composition warning" "$TL_OUT" "WARN: composition log missing: $WORK/.planning/orchestrator-composition-log.jsonl"
assert_contains "world composite" "$TL_OUT" "  OUT-WORLD-01: pass"
assert_contains "advisory shown" "$TL_OUT" "  OUT-ADV: pass|stub ok (advisory)"
assert_contains "verdict" "$TL_OUT" "VERDICT: PASS"
assert_contains "scorer gets row id and ledger" "$(cat "$STUB_LOG")" "SCORE OUT-A $WORK $TL_TMP/st $RUNS/$RUN2/parent-session.log TC-01 $RUNS/$RUN2/ledger.json "
assert_eq "ledger scored with track" "scored|PASS|TC-01|true" "$(jq -r '[.status,.verdict,.track_id,(.live_session_run|tostring)]|join("|")' "$RUNS/$RUN2/ledger.json")"
mkdir -p "$WORK/.planning"; echo '{}' >"$WORK/.planning/orchestrator-composition-log.jsonl"
run STUB_WF_COUNT=5 -- score --run "$RUN2" --track TC-01
assert_contains "composition log counted" "$TL_OUT" "distinct_workflow_ids=5"
mv "$WORK/.planning/orchestrator-composition-log.jsonl" "$TL_TMP/comp.bak"
echo '{}' >"$RUNS/$RUN2/orchestrator-composition-log.jsonl"
run STUB_WF_COUNT= -- score --run "$RUN2" --track TC-01
assert_contains "run-dir composition log counted, empty count shows 0" "$TL_OUT" "distinct_workflow_ids=0"
mv "$RUNS/$RUN2/orchestrator-composition-log.jsonl" "$TL_TMP/comp2.bak"
run SCOREFAIL_OUT_A=1 -- score --run "$RUN2" --track TC-01
assert_contains "crashing scorer is a bare fail" "$TL_OUT" "  OUT-A: fail"
run SCOREFAIL_OUT_ADV=1 -- score --run "$RUN2" --track TC-01
assert_eq "crashing advisory scorer tolerated" 0 "$TL_STATUS"
assert_contains "crashing advisory shows n/a" "$TL_OUT" "  OUT-ADV: n/a (advisory)"
cp "$PL/TC-01-multiwf-chain/MATRIX.json" "$TL_TMP/m1.bak"
jq '.rows[0].advisory_outcomes = 5' "$TL_TMP/m1.bak" >"$PL/TC-01-multiwf-chain/MATRIX.json"
run X=1 -- score --run "$RUN2" --track TC-01
assert_eq "unreadable advisory list is tolerated" 0 "$TL_STATUS"
assert_not_contains "no advisory lines then" "$TL_OUT" "(advisory)"
cp "$TL_TMP/m1.bak" "$PL/TC-01-multiwf-chain/MATRIX.json"
run SCORE_OUT_A="fail|x" -- score --run "$RUN2" --track TC-01
assert_eq "failing outcome" 1 "$TL_STATUS"; assert_contains "world fails" "$TL_OUT" "  OUT-WORLD-01: fail"
run SCORE_OUT_A="" -- score --run "$RUN2" --track TC-01
assert_contains "empty detail is a bare fail" "$TL_OUT" "  OUT-A: fail"
run SCORE_OUT_A="n/a" SCORE_OUT_ADV= -- score --run "$RUN2" --track TC-01
assert_eq "n/a acceptable" 0 "$TL_STATUS"; assert_contains "empty advisory shows n/a" "$TL_OUT" "  OUT-ADV: n/a (advisory)"
echo other >"$TL_TMP/o.log"
: >"$STUB_LOG"
tl_run env -u SB_RUNTIME_STATE_DIR SB_E2E_RUNS_DIR="$RUNS" STUB_LOG="$STUB_LOG" bash "$S" score --run "$RUN2" --track TC-01 --log "$TL_TMP/o.log"
assert_contains "custom log" "$TL_OUT" "log=$TL_TMP/o.log"
assert_contains "state dir default under HOME/.cursor" "$(cat "$STUB_LOG")" " $HOME/.cursor/.silver-bullet "

# ---------------- live ----------------
run X=1 -- live
assert_eq "live needs --track" 2 "$TL_STATUS"; assert_contains "live --track message" "$TL_ERR" "--track required"
run X=1 -- live --bogus
assert_eq "live unknown arg" 2 "$TL_STATUS"; assert_contains "live unknown arg message" "$TL_ERR" "Unknown live arg: --bogus"
run X=1 -- live --track TC-01 --host mainframe
assert_eq "live bad host" 2 "$TL_STATUS"; assert_contains "bad host message" "$TL_ERR" "--host must be cursor, claude, or codex (got: mainframe)"
last_run() { local d r=""; for d in "$RUNS"/*-"$1"; do r="${d##*/}"; done; printf '%s' "$r"; }
run X=1 -- live --track TC-01 --work-dir "$WORK"
assert_eq "cursor live passes" 0 "$TL_STATUS"
assert_contains "live banner" "$TL_OUT" "host=cursor work_dir=$WORK greenfield=0"
assert_contains "live note" "$TL_OUT" "NOTE: bootstrap-orchestrator*.sh NOT used; product gate required"
LR="$(last_run TC-01)"
assert_contains "cursor script invoked as <track> <run-dir>" "$(cat "$STUB_LOG")" "live-verify-track TC-01 $RUNS/$LR work=$WORK host=cursor greenfield=0 preserve=1 state=unset"
assert_contains "scored with the cursor state dir" "$(cat "$STUB_LOG")" " $HOME/.cursor/.silver-bullet/tri-criteria-live-$LR "
assert_eq "live ledger records the fixture branch and sha" "feature/test|ok" \
  "$(jq -r '[.fixture_branch,(.fixture_sha|if length==12 then "ok" else . end)]|join("|")' "$RUNS/$LR/ledger.json")"
assert_eq "live ledger ends scored" "scored" "$(jq -r .status "$RUNS/$LR/ledger.json")"
run X=1 -- live --track TC-02 --host claude --work-dir "$WORK" --greenfield
assert_eq "claude greenfield live passes" 0 "$TL_STATUS"
LR="$(last_run TC-02)"
assert_contains "host script invoked as <host> <track> <run-dir>" "$(cat "$STUB_LOG")" "live-verify-track-host claude TC-02 $RUNS/$LR work=$WORK host=claude greenfield=1"
assert_eq "greenfield flag in ledger" "true" "$(jq -r .greenfield "$RUNS/$LR/ledger.json")"
assert_contains "scored with the claude state dir" "$(cat "$STUB_LOG")" " $HOME/.claude/.silver-bullet/tri-criteria-live-$LR "
run X=1 -- live --track TC-03 --host codex --work-dir "$WORK"
assert_eq "codex live passes" 0 "$TL_STATUS"
LR="$(last_run TC-03)"
assert_contains "codex host script" "$(cat "$STUB_LOG")" "live-verify-track-host codex TC-03 $RUNS/$LR"
assert_contains "scored with a tri-criteria state dir" "$(cat "$STUB_LOG")" "/.silver-bullet/tri-criteria-live-$LR "
run SB_TRI_CRITERIA_HOST=claude SB_TRI_CRITERIA_WORK_DIR="$WORK" -- live --track TC-01
assert_contains "host and work dir from env" "$TL_OUT" "host=claude work_dir=$WORK"
run LIVE_SCRIPT_FAIL=1 -- live --track TC-01 --work-dir "$WORK"
assert_eq "failing live script aborts" 1 "$TL_STATUS"
assert_not_contains "no score after a failing live script" "$TL_OUT" "VERDICT"
run SCORE_OUT_A="fail|x" -- live --track TC-01 --work-dir "$WORK"
assert_eq "failing score fails live" 1 "$TL_STATUS"
: >"$STUB_LOG"
tl_run env -u SB_RUNTIME_STATE_DIR SB_E2E_RUNS_DIR="$RUNS" STUB_LOG="$STUB_LOG" PATH="$NOJQ" bash "$S" live --track TC-01 --host claude --greenfield --work-dir "$WORK"
assert_eq "live without jq passes" 0 "$TL_STATUS"
LR="$(last_run TC-01)"
assert_eq "no jq: greenfield not recorded, fixture branch not added" "false|null" "$(jq -r '[.greenfield,(.fixture_branch // "null")]|join("|")' "$RUNS/$LR/ledger.json")"
# no work dir anywhere: the umbrella matrix default is used; a non-git fixture records "unknown"
NOGIT="$TL_TMP/nogit"; mkdir -p "$NOGIT"
jq --arg w "$NOGIT" '.fixture.work_dir_default=$w' "$PL/MATRIX.json" >"$TL_TMP/mx.json"; cp "$PL/MATRIX.json" "$TL_TMP/mx.bak"; cp "$TL_TMP/mx.json" "$PL/MATRIX.json"
run X=1 -- live --track TC-01
assert_eq "live with the matrix default work dir" 0 "$TL_STATUS"
assert_contains "default work dir used" "$TL_OUT" "work_dir=$NOGIT"
LR="$(last_run TC-01)"
assert_eq "non-git fixture recorded as unknown" "unknown|unknown" "$(jq -r '[.fixture_branch,.fixture_sha]|join("|")' "$RUNS/$LR/ledger.json")"
cp "$TL_TMP/mx.bak" "$PL/MATRIX.json"
# a track whose matrix lacks the row cannot go live or cold
cp "$PL/TC-02-dynamic-compose/MATRIX.json" "$TL_TMP/m2.bak"; echo '{"rows":[]}' >"$PL/TC-02-dynamic-compose/MATRIX.json"
run X=1 -- live --track TC-02 --work-dir "$WORK"
assert_eq "live with unknown row" 1 "$TL_STATUS"
run X=1 -- cold --track TC-02 --work-dir "$WORK"
assert_eq "cold with unknown row" 1 "$TL_STATUS"
cp "$TL_TMP/m2.bak" "$PL/TC-02-dynamic-compose/MATRIX.json"
mv "$PL/scripts/live-verify-track.sh" "$PL/scripts/live.bak"
run X=1 -- live --track TC-01 --work-dir "$WORK"
assert_eq "missing live script" 1 "$TL_STATUS"; assert_contains "missing live script message" "$TL_ERR" "ERROR: missing $PL/scripts/live-verify-track.sh"
mv "$PL/scripts/live.bak" "$PL/scripts/live-verify-track.sh"
run X=1 -- live --track TC-99 --work-dir "$WORK"
assert_eq "live unknown track" 1 "$TL_STATUS"

# ---------------- cold ----------------
run X=1 -- cold
assert_eq "cold needs --track" 2 "$TL_STATUS"; assert_contains "cold --track message" "$TL_ERR" "--track required"
run X=1 -- cold --bogus
assert_eq "cold unknown arg" 2 "$TL_STATUS"; assert_contains "cold unknown arg message" "$TL_ERR" "Unknown cold arg: --bogus"
run X=1 -- cold --track TC-01 --no-bootstrap --work-dir "$WORK"
assert_eq "cold passes" 0 "$TL_STATUS"
assert_contains "cold banner" "$TL_OUT" "=== sb-tri-criteria E2E cold verify ==="
CR="$(last_run TC-01)"
assert_contains "cold script invoked" "$(cat "$STUB_LOG")" "cold-verify-track TC-01 $RUNS/$CR work=$WORK"
assert_eq "cold ledger scored" "scored|PASS" "$(jq -r '[.status,.verdict]|join("|")' "$RUNS/$CR/ledger.json")"
chmod -x "$PL/scripts/cold-verify-track.sh"
run X=1 -- cold --track TC-02
assert_eq "cold chmods a non-executable script and runs it" 0 "$TL_STATUS"
mv "$PL/scripts/cold-verify-track.sh" "$PL/scripts/cold.bak"
run X=1 -- cold --track TC-02
assert_eq "missing cold script" 1 "$TL_STATUS"; assert_contains "missing cold script message" "$TL_ERR" "ERROR: missing $PL/scripts/cold-verify-track.sh"
run X=1 -- cold --track TC-99
assert_eq "cold unknown track" 1 "$TL_STATUS"

# ---------------- status ----------------
run X=1 -- status --bogus
assert_eq "status unknown arg" 2 "$TL_STATUS"
run X=1 -- status --run "$RUN2"
assert_contains "status of one run" "$TL_OUT" '"row_id": "TC-01"'
run X=1 -- status --run nope
assert_eq "status unknown run" "No ledger for nope" "$TL_OUT"
EMPTY_RUNS="$TL_TMP/empty-runs"; mkdir -p "$EMPTY_RUNS"
tl_run env SB_E2E_RUNS_DIR="$EMPTY_RUNS" bash "$S" status
assert_eq "empty runs dir lists nothing" "=== sb-tri-criteria runs ===" "$TL_OUT"
run X=1 -- status
assert_contains "listing header" "$TL_OUT" "=== sb-tri-criteria runs ==="
assert_contains "listing reads the redirected runs dir" "$TL_OUT" "TC-01  TC-01  scored  verdict=PASS  live=True"
mkdir -p "$PL/runs/old"; jq -n '{track_id:"TC-02",row_id:"TC-02",status:"prepared",verdict:null,live_session_run:false}' >"$PL/runs/old/ledger.json"
tl_run env -u SB_E2E_RUNS_DIR bash "$S" status
assert_contains "default runs dir listing" "$TL_OUT" "TC-02  TC-02  prepared  verdict=None  live=False"

tl_results
