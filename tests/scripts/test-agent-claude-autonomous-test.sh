#!/usr/bin/env bash
# Structural contract for agent-claude autonomous vision test harness.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="${REPO_ROOT}/scripts/agent-claude-autonomous-test.sh"
PLANNING="${REPO_ROOT}/.planning/agent-claude-autonomous"

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

echo "=== agent-claude autonomous harness structural tests ==="

[[ -x "$DRIVER" ]] && check "driver executable" pass || check "driver executable" fail
bash -n "$DRIVER" && check "driver shell syntax" pass || check "driver shell syntax" fail

for f in README.md RUNBOOK.md CRITERIA.md EVIDENCE-TEMPLATE.md MATRIX.json; do
  [[ -f "${PLANNING}/${f}" ]] && check "planning/${f}" pass || check "planning/${f}" fail
done

[[ -f "${PLANNING}/briefs/AUTO-C01.md" ]] && check "brief AUTO-C01" pass || check "brief AUTO-C01" fail
[[ -f "${PLANNING}/briefs/AUTO-C02.md" ]] && check "brief AUTO-C02" pass || check "brief AUTO-C02" fail

grep -q 'agent-claude-autonomous' "$DRIVER" && check "driver references track name" pass || check "driver references track name" fail
grep -q 'enterprise_e2e_outcome_score_criterion' "$DRIVER" && check "driver reuses outcome scorer" pass || check "driver reuses outcome scorer" fail
grep -q 'agent_claude_apply_delegate_env' "$DRIVER" && check "driver clears matrix env" pass || check "driver clears matrix env" fail
grep -q 'AUTO-C01' "${PLANNING}/MATRIX.json" && check "matrix defines AUTO-C01" pass || check "matrix defines AUTO-C01" fail

if command -v jq >/dev/null 2>&1; then
  jq -e '.rows | length == 3' "${PLANNING}/MATRIX.json" >/dev/null 2>&1 \
    && check "matrix has 3 rows" pass || check "matrix has 3 rows" fail
fi

bash "$DRIVER" --help >/dev/null 2>&1 && check "driver --help" pass || check "driver --help" fail
grep -q -- '--tmux' "$DRIVER" && check "driver documents --tmux" pass || check "driver documents --tmux" fail

dry_work_dir="$(mktemp -d "${TMPDIR:-/tmp}/agent-claude-auto-dry-XXXXXX")"
trap 'rm -rf "$dry_work_dir"' EXIT
dry_out="$(SB_E2E_RUNS_DIR="${dry_work_dir}/runs" bash "$DRIVER" start --row AUTO-C01 --dry-run --work-dir "$dry_work_dir" 2>&1)" || true
grep -q 'run_id=' <<<"$dry_out" && check "start dry-run creates run_id" pass || check "start dry-run creates run_id" fail

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
