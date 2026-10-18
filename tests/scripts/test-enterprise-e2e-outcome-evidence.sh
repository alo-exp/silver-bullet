#!/usr/bin/env bash
# Behaviour tests for the matrix/tri-criteria evidence resolution in
# scripts/lib/enterprise-e2e-outcome-assessment.sh (slug and evidence tables, composition-log
# candidates, evidence_resolved, matrix work dir, ledger row parsing).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f3-helpers.sh"

NOJQ="$(tl_path_without jq)"

# --- slug / evidence tables -------------------------------------------------
slugs=(silver-router silver-deep-research silver-feature silver-bugfix silver-ui silver-fast silver-test
  silver-refactor silver-benchmark silver-content silver-devops silver-deploy silver-canary silver-release
  review-triad ship-readiness silver-incident silver-retro silver-forensics process-maintenance
  post-exec-gates validate-substep)
for i in "${!slugs[@]}"; do
  oa -- enterprise_e2e_outcome_matrix_workflow_slug "$((i + 1))"
  assert_eq "slug: row $((i + 1))" "${slugs[$i]}" "$TL_OUT"
done
for r in 0 23 abc ""; do
  oa -- enterprise_e2e_outcome_matrix_workflow_slug "$r"
  assert_eq "slug: row '$r' has no slug" "" "$TL_OUT"
done
oa -- enterprise_e2e_outcome_matrix_workflow_slug
assert_eq "slug: no argument" "" "$TL_OUT"

paths=(.planning/workflows/router-session.md docs/ADR-001-runtime.md .planning/workflows/feature-currency.md
  .planning/workflows/bugfix-health.md ui/src/App.jsx .planning/workflows/fast-readme.md
  .planning/workflows/test-orders-integration.md .planning/workflows/refactor-order-validation.md
  docs/benchmarks/health.md docs/API.md .planning/workflows/devops-terraform-validation.md docs/DEPLOY.md
  docs/CANARY.md CHANGELOG.md .planning/reviews/triad-currency.md .planning/ship-readiness/checklist.md
  docs/incidents/INC-001.md docs/retro/RETRO-001.md docs/forensics/CI-001.md docs/WORKFLOW_E2E_MATRIX.md)
for i in "${!paths[@]}"; do
  oa -- enterprise_e2e_outcome_matrix_evidence_path "$((i + 1))"
  assert_eq "evidence path: row $((i + 1))" "${paths[$i]}" "$TL_OUT"
done
for r in 21 22 0 99 ""; do
  oa -- enterprise_e2e_outcome_matrix_evidence_path "$r"
  assert_eq "evidence path: row '$r' has none" "" "$TL_OUT"
done

# --- tri-criteria rows ------------------------------------------------------
for r in TC-01 TC-02 TC-03; do
  oa -- enterprise_e2e_outcome_is_tri_criteria_row "$r"
  assert_eq "tri row: $r" 0 "$TL_STATUS"
done
for r in TC-04 3 "" tc-01; do
  oa -- enterprise_e2e_outcome_is_tri_criteria_row "$r"
  assert_eq "tri row: '$r' is not one" 1 "$TL_STATUS"
done
oa -- enterprise_e2e_outcome_is_tri_criteria_row
assert_eq "tri row: no argument" 1 "$TL_STATUS"

RUN="$TL_TMP/run-dir"
mkdir -p "$RUN"
oa -- enterprise_e2e_outcome_tri_criteria_run_dir
assert_eq "run dir: unset" 1 "$TL_STATUS"
oa "SB_TRI_CRITERIA_RUN_DIR=$RUN" -- enterprise_e2e_outcome_tri_criteria_run_dir
assert_eq "run dir: set" "$RUN" "$TL_OUT"
oa "SB_TRI_CRITERIA_RUN_DIR=$TL_TMP/nope" -- enterprise_e2e_outcome_tri_criteria_run_dir
assert_eq "run dir: set to a missing directory" 1 "$TL_STATUS"

# --- composer -> catalog workflow id ---------------------------------------
cid() { oa -- enterprise_e2e_outcome_composer_catalog_workflow_id "$1"; }
for pair in silver-feature:WF-SILVER-FEATURE sb:silver-feature:WF-SILVER-FEATURE sb:silver:fast:WF-SILVER-FAST \
  silver-devops:WF-SILVER-DEVOPS silver-release:WF-SILVER-RELEASE silver-new-workflow:WF-SILVER-NEW-WORKFLOW \
  silver-ui:WF-SILVER-UI silver-bugfix:WF-SILVER-BUGFIX silver-router:WF-SILVER-ROUTER \
  silver-research:WF-SILVER-DEEP-RESEARCH silver-ship:WF-SILVER-SHIP silver-content:WF-SILVER-CONTENT \
  silver-foo-bar:WF-SILVER-FOO-BAR; do
  cid "${pair%:WF-*}"
  assert_eq "composer id: ${pair%:WF-*}" "WF-${pair##*:WF-}" "$TL_OUT"
done
cid "gsd-execute"
assert_eq "composer id: non-silver composer is rejected" 1 "$TL_STATUS"
assert_eq "composer id: non-silver composer prints nothing" "" "$TL_OUT"

# --- tri-criteria product evidence -----------------------------------------
APP="$TL_TMP/tc-app"
e2e_git_app "$APP"
prod() { oa -- enterprise_e2e_outcome_tri_criteria_product_present "$@"; }
prod TC-01 ""
assert_eq "product: empty work dir" 1 "$TL_STATUS"
mkdir -p "$TL_TMP/nogit"
prod TC-01 "$TL_TMP/nogit"
assert_eq "product: work dir without .git" 1 "$TL_STATUS"
prod TC-01 "$APP"
assert_eq "product TC-01: nothing yet" 1 "$TL_STATUS"
prod TC-02 "$APP"
assert_eq "product TC-02: nothing yet" 1 "$TL_STATUS"
prod TC-03 "$APP"
assert_eq "product TC-03: nothing yet" 1 "$TL_STATUS"
prod TC-09 "$APP"
assert_eq "product: unknown row id" 1 "$TL_STATUS"
mkdir -p "$APP/api/src" "$APP/scripts"
: >"$APP/api/src/waitlist.ts"
prod TC-01 "$APP"
assert_eq "product TC-01: waitlist source" 0 "$TL_STATUS"
rm "$APP/api/src/waitlist.ts"
git -C "$APP" branch feature/tc01-waitlist-saas
prod TC-01 "$APP"
assert_eq "product TC-01: feature branch" 0 "$TL_STATUS"
printf 'Add a runbook\n' >"$APP/README.md"
prod TC-02 "$APP"
assert_eq "product TC-02: README keywords" 0 "$TL_STATUS"
printf 'hello\n' >"$APP/README.md"
prod TC-02 "$APP"
assert_eq "product TC-02: README without keywords" 1 "$TL_STATUS"
: >"$APP/api/src/request-logger.ts"
prod TC-02 "$APP"
assert_eq "product TC-02: log source" 0 "$TL_STATUS"
rm "$APP/api/src/request-logger.ts"
git -C "$APP" branch feature/tc02-observability-runbook
prod TC-02 "$APP"
assert_eq "product TC-02: observability branch" 0 "$TL_STATUS"
git -C "$APP" branch -D feature/tc02-observability-runbook >/dev/null
git -C "$APP" branch feature/tc02-readme-badge
prod TC-02 "$APP"
assert_eq "product TC-02: readme-badge branch" 0 "$TL_STATUS"
: >"$APP/scripts/compliance-snapshot.sh"
prod TC-03 "$APP"
assert_eq "product TC-03: compliance script" 0 "$TL_STATUS"
rm "$APP/scripts/compliance-snapshot.sh"
git -C "$APP" branch feature/tc03-compliance-snapshot
prod TC-03 "$APP"
assert_eq "product TC-03: compliance branch" 0 "$TL_STATUS"

# --- tri-criteria session evidence ------------------------------------------
sess() { oa -- enterprise_e2e_outcome_tri_criteria_session_evidence_present "$@"; }
oa_log "$TL_TMP/s-tc1.log" "chained WF-SILVER-DEVOPS next"
oa_log "$TL_TMP/s-tc1b.log" "built the waitlist"
oa_log "$TL_TMP/s-tc2.log" "added structured logging"
oa_log "$TL_TMP/s-tc3.log" "ran a posture audit"
oa_log "$TL_TMP/s-none.log" "nothing relevant"
sess TC-01 "$TL_TMP/s-tc1.log"; assert_eq "session TC-01: workflow id" 0 "$TL_STATUS"
sess TC-01 "$TL_TMP/s-tc1b.log"; assert_eq "session TC-01: waitlist" 0 "$TL_STATUS"
sess TC-02 "$TL_TMP/s-tc2.log"; assert_eq "session TC-02: structured logging" 0 "$TL_STATUS"
sess TC-03 "$TL_TMP/s-tc3.log"; assert_eq "session TC-03: posture audit" 0 "$TL_STATUS"
sess TC-01 "$TL_TMP/s-none.log"; assert_eq "session TC-01: no keywords" 1 "$TL_STATUS"
sess TC-02 "$TL_TMP/s-none.log"; assert_eq "session TC-02: no keywords" 1 "$TL_STATUS"
sess TC-03 "$TL_TMP/s-none.log"; assert_eq "session TC-03: no keywords" 1 "$TL_STATUS"
sess TC-09 "$TL_TMP/s-tc1.log"; assert_eq "session: unknown id" 1 "$TL_STATUS"
sess TC-01 "$TL_TMP/absent.log"; assert_eq "session: missing log" 1 "$TL_STATUS"
sess TC-01 ""; assert_eq "session: empty log arg" 1 "$TL_STATUS"
sess TC-01; assert_eq "session: no log arg" 1 "$TL_STATUS"

# --- composition log candidates --------------------------------------------
W="$TL_TMP/w-comp"
mkdir -p "$W/.planning"
cand() { oa "$@" -- enterprise_e2e_outcome_composition_log_candidates "$W"; }
oa -- enterprise_e2e_outcome_composition_log_candidates ""
assert_eq "candidates: empty work dir prints nothing" "" "$TL_OUT"
assert_eq "candidates: empty work dir succeeds" 0 "$TL_STATUS"
cand
assert_eq "candidates: nothing anywhere, no run dir" "" "$TL_OUT"
assert_eq "candidates: nothing anywhere, no run dir succeeds" 0 "$TL_STATUS"
cand "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "candidates: run dir set but nothing found -> 1" 1 "$TL_STATUS"
echo '{}' >"$W/.planning/orchestrator-composition-log.jsonl"
cand
assert_eq "candidates: work-dir log" "$W/.planning/orchestrator-composition-log.jsonl" "$TL_OUT"
cand "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "candidates: run dir set, only the work-dir log exists" "$W/.planning/orchestrator-composition-log.jsonl" "$TL_OUT"
assert_eq "candidates: succeeds" 0 "$TL_STATUS"
echo '{}' >"$RUN/orchestrator-composition-log.jsonl"
echo '{}' >"$RUN/composition_log.jsonl"
cand "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "candidates: run-dir logs first, then work-dir log" "$RUN/orchestrator-composition-log.jsonl
$RUN/composition_log.jsonl
$W/.planning/orchestrator-composition-log.jsonl" "$TL_OUT"
rm "$W/.planning/orchestrator-composition-log.jsonl"
cand "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "candidates: only run-dir logs" "$RUN/orchestrator-composition-log.jsonl
$RUN/composition_log.jsonl" "$TL_OUT"
assert_eq "candidates: run-dir logs found -> success" 0 "$TL_STATUS"
rm -f "$RUN/orchestrator-composition-log.jsonl" "$RUN/composition_log.jsonl"

# --- evidence resolved ------------------------------------------------------
EW="$TL_TMP/w-ev"
mkdir -p "$EW/.planning/workflows"
EV_ENV=()
evr() { oa ${EV_ENV[@]+"${EV_ENV[@]}"} -- enterprise_e2e_outcome_evidence_resolved "$@"; }
evr "$EW" "docs/x.md" 3
assert_eq "resolved: missing explicit evidence" 1 "$TL_STATUS"
evr "$EW" "" 99
assert_eq "resolved: no evidence path and unknown row" 1 "$TL_STATUS"
evr "$EW" "" ""
assert_eq "resolved: nothing given" 1 "$TL_STATUS"
mkdir -p "$EW/docs"
: >"$EW/docs/x.md"
evr "$EW" "docs/x.md" 3
assert_eq "resolved: explicit file" 0 "$TL_STATUS"
assert_eq "resolved: prints the evidence path" "docs/x.md" "$TL_OUT"
mkdir -p "$EW/docs/dir"
evr "$EW" "docs/dir" 3
assert_eq "resolved: explicit directory" 0 "$TL_STATUS"
: >"$EW/docs/ADR-001-runtime.md"
evr "$EW" "" 2
assert_eq "resolved: evidence path defaults from the row table" "docs/ADR-001-runtime.md" "$TL_OUT"
mkdir -p "$EW/.planning/workflows/.archive/old"
: >"$EW/.planning/workflows/.archive/old/gone.md"
evr "$EW" ".planning/workflows/gone.md" 3
assert_eq "resolved: archived by basename" 0 "$TL_STATUS"
evr "$EW" ".planning/workflows/feature-currency.md" 3
assert_eq "resolved: nothing for row 3 yet" 1 "$TL_STATUS"
: >"$EW/.planning/workflows/2026-01-01-silver-feature-run.md"
evr "$EW" ".planning/workflows/feature-currency.md" 3
assert_eq "resolved: live workflow file containing the slug" 0 "$TL_STATUS"
evr "$EW" ".planning/workflows/feature-currency.md" 4
assert_eq "resolved: slug of another row does not match" 1 "$TL_STATUS"
evr "$EW" ".planning/workflows/feature-currency.md" 99
assert_eq "resolved: row without slug cannot use slug lookups" 1 "$TL_STATUS"
rm "$EW/.planning/workflows/2026-01-01-silver-feature-run.md"
: >"$EW/.planning/workflows/.archive/old/2026-silver-feature-old.md"
evr "$EW" ".planning/workflows/feature-currency.md" 3
assert_eq "resolved: archived workflow file containing the slug" 0 "$TL_STATUS"

# tri-criteria rows
TW="$TL_TMP/w-tri"
e2e_git_app "$TW"
SESSLOG="$TL_TMP/tri-session.log"
echo x >"$SESSLOG"
EV_ENV=("SB_TRI_CRITERIA_SESSION_LOG=$SESSLOG")
evr "$TW" "" TC-01
assert_eq "tri resolved: session log wins" "$SESSLOG" "$TL_OUT"
EV_ENV=("SB_TRI_CRITERIA_SESSION_LOG=$TL_TMP/absent.log")
evr "$TW" "" TC-01
assert_eq "tri resolved: missing session log, nothing else" 1 "$TL_STATUS"
echo '{}' >"$RUN/orchestrator-composition-log.jsonl"
EV_ENV=("SB_TRI_CRITERIA_RUN_DIR=$RUN")
evr "$TW" "" TC-02
assert_eq "tri resolved: composition log from the run dir" "$RUN/orchestrator-composition-log.jsonl" "$TL_OUT"
rm "$RUN/orchestrator-composition-log.jsonl"
EV_ENV=("SB_TRI_CRITERIA_RUN_DIR=$RUN")
evr "$TW" "" TC-01
assert_eq "tri resolved: run dir without logs, no product" 1 "$TL_STATUS"
git -C "$TW" branch feature/tc01-waitlist-saas
evr "$TW" "" TC-01
assert_eq "tri resolved: falls through to product evidence" ".planning/sb-tri-criteria-e2e/runs/TC-01/product-evidence" "$TL_OUT"
EV_ENV=()
evr "$TW" "" TC-01
assert_eq "tri resolved: product evidence without a run dir" ".planning/sb-tri-criteria-e2e/runs/TC-01/product-evidence" "$TL_OUT"
evr "$TW" "" TC-03
assert_eq "tri resolved: no product for TC-03" 1 "$TL_STATUS"
# a candidate path that is not a file is skipped (stub the candidate generator)
STUB="enterprise_e2e_outcome_composition_log_candidates() { printf '\n%s\n%s\n' '$TL_TMP/ghost.jsonl' '$RUN/real.jsonl'; }"
oa_sh "$STUB
enterprise_e2e_outcome_evidence_resolved '$TW' '' TC-03" "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "tri resolved: only ghost candidates -> not resolved" 1 "$TL_STATUS"
echo '{}' >"$RUN/real.jsonl"
oa_sh "$STUB
enterprise_e2e_outcome_evidence_resolved '$TW' '' TC-03" "SB_TRI_CRITERIA_RUN_DIR=$RUN"
assert_eq "tri resolved: blank and ghost candidates skipped, real one used" "$RUN/real.jsonl" "$TL_OUT"

# --- evidence_present wrapper ----------------------------------------------
oa -- enterprise_e2e_outcome_matrix_evidence_present "$EW" docs/x.md 3
assert_eq "evidence_present: found" 0 "$TL_STATUS"
assert_eq "evidence_present: silent" "" "$TL_OUT"
oa -- enterprise_e2e_outcome_matrix_evidence_present "$EW" docs/zzz.md 4
assert_eq "evidence_present: missing" 1 "$TL_STATUS"

# --- matrix work dir --------------------------------------------------------
mwd() { oa "$@" -- enterprise_e2e_outcome_matrix_work_dir; }
mwd
assert_eq "work dir: nothing configured" 1 "$TL_STATUS"
mwd "SB_TEST_ENTERPRISE_APP_ROOT=$TL_TMP/app-root"
assert_eq "work dir: env wins" "$TL_TMP/app-root" "$TL_OUT"
printf '{"test_enterprise_app_root":"%s"}\n' "$TL_TMP/cfg-app" >"$OA_ROOT/.silver-bullet.json"
mwd
assert_eq "work dir: from .silver-bullet.json" "$TL_TMP/cfg-app" "$TL_OUT"
mwd "SB_TEST_ENTERPRISE_APP_ROOT=$TL_TMP/app-root"
assert_eq "work dir: env still wins over config" "$TL_TMP/app-root" "$TL_OUT"
mwd "PATH=$NOJQ"
assert_eq "work dir: no jq cannot read config" 1 "$TL_STATUS"
echo '{"other":1}' >"$OA_ROOT/.silver-bullet.json"
mwd
assert_eq "work dir: config without the key" 1 "$TL_STATUS"
echo 'not json' >"$OA_ROOT/.silver-bullet.json"
mwd
assert_eq "work dir: unparsable config" 1 "$TL_STATUS"
rm -f "$OA_ROOT/.silver-bullet.json"

# --- ledger rows ------------------------------------------------------------
LEDGER="$TL_TMP/ledger.md"
cat >"$LEDGER" <<'LG'
| 1 | summary table | x |
| 3 | `silver-feature` | wf | note | Pass | a | b | c | q-ref | am-ref |
| 3 | `silver-feature` | dup | note | Fail | a | b | c | q2 | am2 |
| 12 | `silver-deploy` | wf | note | **Fail** | a | b | c | **gq** |  |
LG
ll() { oa -- enterprise_e2e_outcome_ledger_workflow_line "$@"; }
ll "$LEDGER" 3
assert_eq "ledger line: first backtick-slug row" '| 3 | `silver-feature` | wf | note | Pass | a | b | c | q-ref | am-ref |' "$TL_OUT"
ll "$LEDGER" 1
assert_eq "ledger line: summary rows without a slug are skipped" "" "$TL_OUT"
ll "$LEDGER" 12
assert_contains "ledger line: row 12 exact (row 1 pattern does not match 12)" "$TL_OUT" '`silver-deploy`'
ll "$LEDGER" abc
assert_eq "ledger line: non-numeric row" "" "$TL_OUT"
assert_eq "ledger line: non-numeric row succeeds" 0 "$TL_STATUS"
ll "$TL_TMP/absent.md" 3
assert_eq "ledger line: missing ledger" "" "$TL_OUT"
ll "" 3
assert_eq "ledger line: empty ledger arg" 0 "$TL_STATUS"
ll
assert_eq "ledger line: no args" 0 "$TL_STATUS"

# an unreadable ledger yields no line instead of aborting (needs a non-root user: root ignores mode bits)
if [[ "$(id -u)" -eq 0 ]]; then
  echo "SKIP: unreadable-ledger case needs a non-root user"
else
  cp "$LEDGER" "$TL_TMP/locked-ledger.md"
  chmod 000 "$TL_TMP/locked-ledger.md"
  ll "$TL_TMP/locked-ledger.md" 3
  assert_eq "ledger line: unreadable ledger -> no line, success" "0:" "$TL_STATUS:$TL_OUT"
  chmod 600 "$TL_TMP/locked-ledger.md"
fi

parse() { oa -- enterprise_e2e_outcome_ledger_parse_workflow_row "$1"; }
parse '| 3 | `silver-feature` | wf | note | Pass | a | b | c | q-ref | am-ref |'
assert_eq "parse row: graphify ref, agentmemory ref, lower-cased status" "q-ref
am-ref
pass" "$TL_OUT"
parse '| 12 | `silver-deploy` | wf | note | **Fail** | a | b | c | **gq** |  |'
assert_eq "parse row: asterisks and blanks stripped" "gq

fail" "$TL_OUT"
parse ""
assert_eq "parse row: empty line fails" 1 "$TL_STATUS"
assert_eq "parse row: empty line prints nothing" "" "$TL_OUT"
parse "short | row"
assert_eq "parse row: short row yields three blank fields" 3 "$(wc -l <"$TL_TMP/.out" | tr -d ' ')"
assert_eq "parse row: short row has no content" "" "$TL_OUT"

tl_results
