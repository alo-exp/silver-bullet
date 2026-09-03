#!/usr/bin/env bash
# Tests directive → worker template resolution and directive schema fields.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_OD="$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
LIB_PARENT="$REPO_ROOT/hooks/lib/orchestrator-parent.sh"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"

cleanup() {
  rm -f "${SB_TEST_DIR}/orchestrator-directive.json" 2>/dev/null || true
}
trap cleanup EXIT

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (got='$got' want='$want')"
    FAIL=$((FAIL + 1))
  fi
}

source "$LIB_OD"
source "$LIB_PARENT"

sb_orchestrator_directive_write "silver-execute" "build feature" "handoff test" true
assert_eq "template for execute" "$(jq -r '.next_worker_template' "${SB_TEST_DIR}/orchestrator-directive.json")" "EXECUTE"
assert_eq "next_skill preserved" "$(jq -r '.next_skill' "${SB_TEST_DIR}/orchestrator-directive.json")" "silver-execute"

assert_eq "flow quality gate template" "$(sb_orchestrator_worker_template_for_skill 'FLOW-QUALITY-GATE')" "QUALITY-GATE"
assert_eq "plan template" "$(sb_orchestrator_worker_template_for_skill 'silver-plan')" "PLAN"
assert_eq "devops quality gates skill mapping" "$(sb_orchestrator_flow_to_skill 'devops-quality-gates')" "devops-quality-gates"
assert_eq "deep research decide template" "$(sb_orchestrator_worker_template_for_skill 'silver-deep-research')" "DECIDE"
assert_eq "design handoff template" "$(sb_orchestrator_worker_template_for_skill 'silver-handoff')" "DESIGN-HANDOFF"
assert_eq "flow design handoff token" "$(sb_orchestrator_worker_template_for_skill 'FLOW-DESIGN-HANDOFF')" "DESIGN-HANDOFF"
assert_eq "design handoff flow to skill" "$(sb_orchestrator_flow_to_skill 'FLOW-DESIGN-HANDOFF')" "silver-handoff"
assert_eq "ensure docs template" "$(sb_orchestrator_worker_template_for_skill 'silver-ensure-docs')" "DOCUMENT"
assert_eq "flow document token" "$(sb_orchestrator_worker_template_for_skill 'FLOW-DOCUMENT')" "DOCUMENT"
assert_eq "flow document to skill" "$(sb_orchestrator_flow_to_skill 'FLOW-DOCUMENT')" "silver-ensure-docs"
assert_eq "flow verify token" "$(sb_orchestrator_flow_to_skill 'FLOW-VERIFY')" "silver-verify"
assert_eq "flow secure token" "$(sb_orchestrator_flow_to_skill 'FLOW-SECURE')" "security"
assert_eq "security template" "$(sb_orchestrator_worker_template_for_skill 'security')" "SECURITY"
assert_eq "silver-secure template" "$(sb_orchestrator_worker_template_for_skill 'silver-secure')" "SECURE"
assert_eq "create-release template" "$(sb_orchestrator_worker_template_for_skill 'silver-create-release')" "RELEASE"
assert_eq "orchestrator router template" "$(sb_orchestrator_worker_template_for_skill 'silver-orchestrator')" "ROUTER"
assert_eq "flow quality gate preship" "$(sb_orchestrator_flow_to_skill 'FLOW-QUALITY-GATE-PRESHIP')" "silver-quality-gates"
assert_eq "flow review request token" "$(sb_orchestrator_flow_to_skill 'FLOW-REVIEW-REQUEST')" "silver-review-request"
assert_eq "no silver-FLOW prefix fallback" "$(sb_orchestrator_flow_to_skill 'FLOW-VERIFY' | grep -c 'silver-FLOW-' || true)" "0"

ctx="$(sb_orchestrator_directive_context_block)"
if printf '%s' "$ctx" | grep -qF 'next_worker_template: EXECUTE.md'; then
  echo "PASS: context includes worker template"
  PASS=$((PASS + 1))
else
  echo "FAIL: context includes worker template"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
