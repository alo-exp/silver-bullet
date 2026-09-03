#!/usr/bin/env bash
# Regression: orchestrator default queues must match composer canonical post-exec order.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
PASS=0
FAIL=0

# shellcheck source=/dev/null
source "$LIB"

assert_order() {
  local name="$1" queue="$2" after="$3"
  local pre="${queue%%,${after}*}"
  [[ "$pre" != "$queue" ]] || {
    echo "FAIL: $name — missing suffix starting at $after"
    FAIL=$((FAIL + 1))
    return
  }
  local segment="${queue#*${after}}"
  if [[ "$segment" == "$queue" ]]; then
    echo "FAIL: $name — anchor $after not found"
    FAIL=$((FAIL + 1))
    return
  fi
  echo "PASS: $name post-exec order"
  PASS=$((PASS + 1))
}

feature_q="$(sb_orchestrator_default_queue_for_composer silver-feature)"
assert_order "silver-feature" "$feature_q" "silver-execute"
if printf '%s' "$feature_q" | grep -q 'silver-verify,silver-review'; then
  echo "FAIL: silver-feature has verify before review"
  FAIL=$((FAIL + 1))
else
  echo "PASS: silver-feature review before verify"
  PASS=$((PASS + 1))
fi

bugfix_q="$(sb_orchestrator_default_queue_for_composer silver-bugfix)"
if printf '%s' "$bugfix_q" | grep -q 'silver-quality-gates,silver-context'; then
  echo "FAIL: silver-bugfix queue still includes pre-plan quality-gates/context"
  FAIL=$((FAIL + 1))
else
  echo "PASS: silver-bugfix diagnosis-first pre-chain"
  PASS=$((PASS + 1))
fi
if printf '%s' "$bugfix_q" | grep -q 'silver-debug,silver-plan,silver-execute'; then
  echo "PASS: silver-bugfix opens with debug → plan → execute"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-bugfix missing debug → plan → execute prefix"
  FAIL=$((FAIL + 1))
fi

devops_q="$(sb_orchestrator_default_queue_for_composer silver-devops)"
assert_order "silver-devops" "$devops_q" "silver-execute"

ui_q="$(sb_orchestrator_default_queue_for_composer silver-ui)"
if printf '%s' "$ui_q" | grep -q 'silver-execute,silver-ui-review,silver-review-request'; then
  echo "PASS: silver-ui post-exec opens with execute → ui-review → review triad"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui missing execute → ui-review → review triad prefix (got: $ui_q)"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$ui_q" | grep -q 'silver-ui-review,silver-review-request'; then
  echo "PASS: silver-ui ui-review before review triad"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui ui-review must precede review-request (got: $ui_q)"
  FAIL=$((FAIL + 1))
fi

if printf '%s' "$ui_q" | grep -q 'silver-plan,silver-ui-contract,silver-validate,silver-execute'; then
  echo "PASS: silver-ui pre-exec includes plan → ui-contract → validate → execute"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui missing plan → ui-contract → validate → execute prefix (got: $ui_q)"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$devops_q" | grep -q 'silver-plan,silver-validate,silver-execute'; then
  echo "PASS: silver-devops pre-exec includes validate before execute"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-devops missing validate before execute (got: $devops_q)"
  FAIL=$((FAIL + 1))
fi

release_q="$(sb_orchestrator_default_queue_for_composer silver-release)"
if printf '%s' "$release_q" | grep -q 'silver-branch-finish,silver-completion-audit,silver-ship,silver-create-release'; then
  echo "PASS: silver-release ship prep before ship and create-release"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-release missing branch-finish/completion-audit before ship (got: $release_q)"
  FAIL=$((FAIL + 1))
fi

if sb_orchestrator_is_flow_atom silver-create-release; then
  echo "PASS: silver-create-release is a flow atom"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-create-release not registered as flow atom"
  FAIL=$((FAIL + 1))
fi

if sb_orchestrator_is_flow_atom security && sb_orchestrator_is_flow_atom silver-review-request; then
  echo "PASS: security and review-request are flow atoms"
  PASS=$((PASS + 1))
else
  echo "FAIL: orchestrator flow_atom missing security or review-request"
  FAIL=$((FAIL + 1))
fi

if printf '%s' "$devops_q" | grep -q 'devops-skill-router,devops-quality-gates,security,silver-context'; then
  echo "PASS: silver-devops pre-exec includes router, devops-qg, and pre-plan security"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-devops missing router/devops-qg/security prefix (got: $devops_q)"
  FAIL=$((FAIL + 1))
fi

fast_q="$(sb_orchestrator_default_queue_for_composer silver-fast)"
if printf '%s' "$fast_q" | grep -q 'FLOW-QUALITY-GATE,silver-plan,silver-validate,silver-execute,silver-verify'; then
  echo "PASS: silver-fast Tier 2 orchestrator queue"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-fast queue incorrect (got: $fast_q)"
  FAIL=$((FAIL + 1))
fi

tmp_no_spec=$(mktemp -d)
mkdir -p "$tmp_no_spec/.planning"
feature_no_spec="$(sb_orchestrator_queue_for_composer silver-feature "$tmp_no_spec")"
rm -rf "$tmp_no_spec"
if printf '%s' "$feature_no_spec" | grep -q 'FLOW-QUALITY-GATE,silver-clarify,silver-spec,silver-context'; then
  echo "PASS: silver-feature queue inserts silver-clarify then silver-spec when SPEC.md absent"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-feature missing clarify-then-spec when SPEC.md absent (got: $feature_no_spec)"
  FAIL=$((FAIL + 1))
fi

tmp_no_spec_ui=$(mktemp -d)
mkdir -p "$tmp_no_spec_ui/.planning"
ui_no_spec="$(sb_orchestrator_queue_for_composer silver-ui "$tmp_no_spec_ui")"
rm -rf "$tmp_no_spec_ui"
if printf '%s' "$ui_no_spec" | grep -q 'FLOW-QUALITY-GATE,silver-clarify,silver-spec,silver-context'; then
  echo "PASS: silver-ui queue inserts silver-clarify then silver-spec when SPEC.md absent"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui missing clarify-then-spec when SPEC.md absent (got: $ui_no_spec)"
  FAIL=$((FAIL + 1))
fi

if sb_orchestrator_is_flow_atom devops-skill-router; then
  echo "PASS: devops-skill-router is a flow atom"
  PASS=$((PASS + 1))
else
  echo "FAIL: devops-skill-router not registered as flow atom"
  FAIL=$((FAIL + 1))
fi

research_q="$(sb_orchestrator_default_queue_for_composer silver-deep-research)"
if [[ "$research_q" == "silver-clarify,silver-deep-research,silver-ensure-docs,silver-validate" ]]; then
  echo "PASS: silver-deep-research clarify → research → document → validate queue"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-deep-research queue incorrect (got: $research_q)"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$research_q" | grep -q 'silver-execute'; then
  echo "FAIL: silver-deep-research queue must not include silver-execute"
  FAIL=$((FAIL + 1))
else
  echo "PASS: silver-deep-research excludes execute atom"
  PASS=$((PASS + 1))
fi
if sb_orchestrator_is_flow_atom silver-deep-research && sb_orchestrator_is_flow_atom silver-ensure-docs; then
  echo "PASS: silver-deep-research and silver-ensure-docs are flow atoms"
  PASS=$((PASS + 1))
else
  echo "FAIL: orchestrator flow_atom missing research or ensure-docs"
  FAIL=$((FAIL + 1))
fi

if sb_orchestrator_is_flow_atom silver-handoff; then
  echo "PASS: silver-handoff is a flow atom"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-handoff not registered as flow atom"
  FAIL=$((FAIL + 1))
fi

if printf '%s' "$release_q" | grep -q 'silver-execute'; then
  echo "FAIL: silver-release queue must not include silver-execute"
  FAIL=$((FAIL + 1))
else
  echo "PASS: silver-release excludes silver-execute"
  PASS=$((PASS + 1))
fi
if printf '%s' "$release_q" | grep -q 'silver-create-release'; then
  echo "PASS: silver-release ends with silver-create-release"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-release missing silver-create-release tail (got: $release_q)"
  FAIL=$((FAIL + 1))
fi

# FLOW-* queue tokens must resolve when the invocable skill completes (not only exact token match).
orch_test="${SB_RUNTIME_STATE_DIR:-/tmp}/orchestrator-queue-index-$$.json"
mkdir -p "$(dirname "$orch_test")"
printf '{"flow_queue":["FLOW-QUALITY-GATE-PRESHIP","silver-plan","silver-execute"],"last_completed_index":-1}' >"$orch_test"
export SB_RUNTIME_STATE_DIR="$(dirname "$orch_test")"
mv "$orch_test" "${SB_RUNTIME_STATE_DIR}/orchestrator.json"
idx="$(sb_orchestrator_queue_index_for_atom silver-quality-gates "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 0 2>/dev/null || true)"
if [[ "$idx" == "0" ]]; then
  echo "PASS: silver-quality-gates matches FLOW-QUALITY-GATE-PRESHIP queue token"
  PASS=$((PASS + 1))
else
  echo "FAIL: FLOW-QUALITY-GATE-PRESHIP not resolved for silver-quality-gates (idx=$idx)"
  FAIL=$((FAIL + 1))
fi
rm -f "${SB_RUNTIME_STATE_DIR}/orchestrator.json" 2>/dev/null || true

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
