#!/usr/bin/env bash
# Structural contract for minimal-intent autonomous E2E harness.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="${REPO_ROOT}/scripts/minimal-intent-autonomous-e2e.sh"
PLANNING="${REPO_ROOT}/.planning/minimal-intent-e2e"

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

echo "=== minimal-intent E2E harness structural tests ==="

chmod +x "$DRIVER" 2>/dev/null || true
[[ -x "$DRIVER" ]] && check "driver executable" pass || check "driver executable" fail
bash -n "$DRIVER" && check "driver shell syntax" pass || check "driver shell syntax" fail

for f in README.md RUNBOOK.md CRITERIA.md MATRIX.json; do
  [[ -f "${PLANNING}/${f}" ]] && check "planning/${f}" pass || check "planning/${f}" fail
done

[[ -f "${PLANNING}/fixtures/MI-01-vision.md" ]] && check "fixture MI-01 vision" pass || check "fixture MI-01 vision" fail
[[ -f "${PLANNING}/fixtures/MI-01-prefs.json" ]] && check "fixture MI-01 prefs" pass || check "fixture MI-01 prefs" fail

grep -q 'minimal-intent-e2e' "$DRIVER" && check "driver references track name" pass || check "driver references track name" fail
grep -q 'orchestrator_mode' "${PLANNING}/MATRIX.json" && check "matrix declares parent mode" pass || check "matrix declares parent mode" fail
grep -q 'MI-01' "${PLANNING}/MATRIX.json" && check "matrix defines MI-01" pass || check "matrix defines MI-01" fail
grep -q 'OUT-ORCH-01' "${PLANNING}/MATRIX.json" && check "matrix includes OUT-ORCH-01" pass || check "matrix includes OUT-ORCH-01" fail

if command -v jq >/dev/null 2>&1; then
  jq -e '.rows | length >= 1' "${PLANNING}/MATRIX.json" >/dev/null 2>&1 \
    && check "matrix has at least 1 row" pass || check "matrix has at least 1 row" fail
  jq -e '.host == "cursor"' "${PLANNING}/MATRIX.json" >/dev/null 2>&1 \
    && check "matrix host is cursor" pass || check "matrix host is cursor" fail
fi

for hook in orchestrator-directive.sh orchestrator-scheduler.sh orchestrator-state.sh; do
  [[ -f "${REPO_ROOT}/hooks/lib/${hook}" ]] && check "hook lib ${hook}" pass || check "hook lib ${hook}" fail
done

bash "$DRIVER" --help >/dev/null 2>&1 && check "driver --help" pass || check "driver --help" fail

dry_work_dir="$(mktemp -d "${TMPDIR:-/tmp}/minimal-intent-dry-XXXXXX")"
trap 'rm -rf "$dry_work_dir"' EXIT
dry_out="$(SB_E2E_RUNS_DIR="${dry_work_dir}/runs" bash "$DRIVER" start --row MI-01 --dry-run --work-dir "$dry_work_dir" 2>&1)" || true
grep -q 'run_id=' <<<"$dry_out" && check "start dry-run creates run_id" pass || check "start dry-run creates run_id" fail
grep -q 'vision.md' <<<"$dry_out" && check "dry-run copies vision" pass || check "dry-run copies vision" fail

preflight_out="$(SB_MINIMAL_INTENT_SKIP_STRUCT=1 bash "$DRIVER" preflight 2>&1)" || true
grep -q 'PREFLIGHT PASS' <<<"$preflight_out" && check "preflight structural pass" pass || check "preflight structural pass" fail
grep -q 'live session not run' <<<"$preflight_out" && check "preflight honest about live gap" pass || check "preflight honest about live gap" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
