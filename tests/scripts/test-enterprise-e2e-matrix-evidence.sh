#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="$(mktemp -d "${TMPDIR}/sb-matrix-evidence.XXXXXX")"
# shellcheck source=tests/scripts/lib/enterprise-e2e-fixture.sh
source "${REPO_ROOT}/tests/scripts/lib/enterprise-e2e-fixture.sh"
enterprise_e2e_test_fixture_init "$REPO_ROOT"
trap 'rm -rf "$STATE_DIR" ${enterprise_e2e_test_fixture_temp:+"$enterprise_e2e_test_fixture_temp"}' EXIT

export HOME="$STATE_DIR/home"
mkdir -p "$HOME/.codex/.silver-bullet"
export SB_RUNTIME_STATE_DIR="$HOME/.codex/.silver-bullet"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_E2E_ENTERPRISE_MATRIX=1
export WORK_DIR="$FIXTURE"
export SB_ROOT="$REPO_ROOT"

# shellcheck source=scripts/lib/enterprise-e2e-matrix-quiesce.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-matrix-quiesce.sh"
# shellcheck source=hooks/lib/e2e-matrix-routing.sh
source "${REPO_ROOT}/hooks/lib/e2e-matrix-routing.sh"

mkdir -p "$FIXTURE/.planning/workflows"
printf 'active\n' >"$FIXTURE/.planning/workflows/stale.md"
printf 'active\n' >"$FIXTURE/.planning/workflows/20260629T120000Z-abc123-silver-feature.md"
matrix_quiesce_active_workflows
if [[ ! -f "$FIXTURE/.planning/workflows/stale.md" ]]; then
  echo "PASS: quiesce archives active workflow files"
  ((PASS++)) || true
else
  echo "FAIL: quiesce archives active workflow files"
  ((FAIL++)) || true
fi
assert_ok "quiesce moves files into archive" test -f "$FIXTURE/.planning/workflows/.archive/stale.md"

jq -n --arg repo "$FIXTURE" '{current_flow:"FLOW-EXECUTE",repo_root:$repo}' \
  >"$SB_RUNTIME_STATE_DIR/orchestrator.json"
enterprise_e2e_matrix_quiesce_orchestrator_queue "$REPO_ROOT"
if [[ ! -f "$SB_RUNTIME_STATE_DIR/orchestrator.json" ]]; then
  echo "PASS: orchestrator queue quiesce clears stale state"
  ((PASS++)) || true
else
  echo "FAIL: orchestrator queue quiesce clears stale state"
  ((FAIL++)) || true
fi

jq -n --arg repo "$FIXTURE" '{current_flow:"FLOW-EXECUTE",repo_root:$repo}' \
  >"$SB_RUNTIME_STATE_DIR/orchestrator.json"
sb_e2e_matrix_set_routing_row_marker
if sb_e2e_matrix_routing_row_active; then
  echo "PASS: routing row marker active under enterprise matrix"
  ((PASS++)) || true
else
  echo "FAIL: routing row marker active under enterprise matrix"
  ((FAIL++)) || true
fi
sb_e2e_matrix_clear_routing_row_marker
if ! sb_e2e_matrix_routing_row_active; then
  echo "PASS: routing row marker clears after row"
  ((PASS++)) || true
else
  echo "FAIL: routing row marker clears after row"
  ((FAIL++)) || true
fi

printf 'silver-context\nsilver-feature\n' >"$HOME/.codex/.silver-bullet/state"
matrix_write_router_session_evidence ".planning/workflows/router-session-test.md"
assert_ok "router evidence stub written on routing-only pass" \
  test -f "$FIXTURE/.planning/workflows/router-session-test.md"
rm -f "$FIXTURE/.planning/workflows/router-session-test.md"

# --- Outcome assessment harness (workflow row 1 checklist) ---
# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"
OUT_CHECKLIST="${STATE_DIR}/row-1-outcomes.md"
printf 'silver-context\n' >"$SB_RUNTIME_STATE_DIR/state"
cat >"$FIXTURE/.planning/workflows/router-session.md" <<'EOF'
# Router session evidence
EOF
enterprise_e2e_outcome_write_workflow_checklist 1 "$OUT_CHECKLIST" "$FIXTURE" "$SB_RUNTIME_STATE_DIR" "" "" ".planning/workflows/router-session.md"
assert_ok "outcome checklist written for workflow row 1" test -f "$OUT_CHECKLIST"
if grep -q 'OUT-TAILOR-01' "$OUT_CHECKLIST" && grep -q 'OUT-ORCH-01' "$OUT_CHECKLIST"; then
  echo "PASS: row 1 checklist includes primary outcome criteria"
  ((PASS++)) || true
else
  echo "FAIL: row 1 checklist missing primary criteria"
  ((FAIL++)) || true
fi
score="$(enterprise_e2e_outcome_score_criterion OUT-TAILOR-01 "$FIXTURE" "$SB_RUNTIME_STATE_DIR" "" 1 "" ".planning/workflows/router-session.md")"
if [[ "$score" == "pass" ]]; then
  echo "PASS: OUT-TAILOR-01 pass on router fixture"
  ((PASS++)) || true
else
  echo "FAIL: OUT-TAILOR-01 expected pass got $score"
  ((FAIL++)) || true
fi
rm -f "$FIXTURE/.planning/workflows/router-session.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
