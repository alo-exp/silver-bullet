#!/usr/bin/env bash
# Structural contract for sb-tri-criteria E2E harness.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="${REPO_ROOT}/scripts/sb-tri-criteria-e2e.sh"
PLANNING="${REPO_ROOT}/.planning/sb-tri-criteria-e2e"
ASSESS="${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == pass ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== sb-tri-criteria E2E harness structural tests ==="

chmod +x "$DRIVER" 2>/dev/null || true
[[ -x "$DRIVER" ]] && check "driver executable" pass || check "driver executable" fail
bash -n "$DRIVER" && check "driver shell syntax" pass || check "driver shell syntax" fail
bash -n "$ASSESS" && check "outcome assessment shell syntax" pass || check "outcome assessment shell syntax" fail

for f in README.md DESIGN.md MATRIX.json CURSOR-MULTIWF-CRITERIA.md; do
  [[ -f "${PLANNING}/${f}" ]] && check "planning/${f}" pass || check "planning/${f}" fail
done

for track in TC-01-multiwf-chain TC-02-dynamic-compose TC-03-net-new-workflow; do
  for f in RUNBOOK.md CRITERIA.md MATRIX.json; do
    [[ -f "${PLANNING}/${track}/${f}" ]] && check "${track}/${f}" pass || check "${track}/${f}" fail
  done
done

grep -q 'OUT-MULTIWF-01' "$ASSESS" && check "scorer OUT-MULTIWF-01" pass || check "scorer OUT-MULTIWF-01" fail
grep -q 'OUT-DYNAMIC-01' "$ASSESS" && check "scorer OUT-DYNAMIC-01" pass || check "scorer OUT-DYNAMIC-01" fail
grep -q 'OUT-NEWWF-01' "$ASSESS" && check "scorer OUT-NEWWF-01" pass || check "scorer OUT-NEWWF-01" fail
grep -q 'enterprise_e2e_outcome_score_multiwf' "$ASSESS" && check "multiwf scorer fn" pass || check "multiwf scorer fn" fail
grep -q 'enterprise_e2e_outcome_score_dynamic' "$ASSESS" && check "dynamic scorer fn" pass || check "dynamic scorer fn" fail
grep -q 'enterprise_e2e_outcome_score_newwf' "$ASSESS" && check "newwf scorer fn" pass || check "newwf scorer fn" fail

EVIDENCE="${PLANNING}/scripts/emit-tri-criteria-evidence.sh"
FIXTURE="${PLANNING}/scripts/fixture-checkout.sh"
[[ -f "$EVIDENCE" ]] && bash -n "$EVIDENCE" && check "emit-tri-criteria-evidence.sh syntax" pass || check "emit-tri-criteria-evidence.sh syntax" fail
[[ -f "$FIXTURE" ]] && bash -n "$FIXTURE" && check "fixture-checkout.sh syntax" pass || check "fixture-checkout.sh syntax" fail
grep -q 'tri_criteria_greenfield_checkout_fixture' "$FIXTURE" && check "greenfield checkout fn" pass || check "greenfield checkout fn" fail
grep -q '\-\-greenfield' "$DRIVER" && check "driver --greenfield flag" pass || check "driver --greenfield flag" fail

if command -v jq >/dev/null 2>&1; then
  jq -e '.tracks | length == 3' "${PLANNING}/MATRIX.json" >/dev/null 2>&1 \
    && check "umbrella matrix has 3 tracks" pass || check "umbrella matrix has 3 tracks" fail
  jq -e '.criteria[] | select(.id=="OUT-DYNAMIC-01")' \
    "${REPO_ROOT}/docs/testing/outcome-criteria-registry.json" >/dev/null 2>&1 \
    && check "registry OUT-DYNAMIC-01" pass || check "registry OUT-DYNAMIC-01" fail
fi

bash "$DRIVER" --help >/dev/null 2>&1 && check "driver --help" pass || check "driver --help" fail

dry_work_dir="$(mktemp -d "${TMPDIR:-/tmp}/tri-criteria-dry-XXXXXX")"
trap 'rm -rf "$dry_work_dir"' EXIT
dry_out="$(SB_E2E_RUNS_DIR="${dry_work_dir}/runs" bash "$DRIVER" start --track TC-01 --dry-run --work-dir "$dry_work_dir" 2>&1)" || true
grep -q 'run_id=' <<<"$dry_out" && check "TC-01 dry-run creates run_id" pass || check "TC-01 dry-run creates run_id" fail
grep -q 'vision.md' <<<"$dry_out" && check "dry-run copies vision" pass || check "dry-run copies vision" fail

preflight_out="$(SB_TRI_CRITERIA_SKIP_STRUCT=1 bash "$DRIVER" preflight 2>&1)" || true
grep -q 'PREFLIGHT PASS' <<<"$preflight_out" && check "preflight structural pass" pass || check "preflight structural pass" fail
grep -q 'live sessions not run' <<<"$preflight_out" && check "preflight honest about live gap" pass || check "preflight honest about live gap" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
