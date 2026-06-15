#!/usr/bin/env bash
# Regression: orchestrator default queues must match composer canonical post-exec order.
set -euo pipefail

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

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
