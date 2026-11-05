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
if grep -q 'silver-verify,silver-review' <<<"$feature_q"; then
  echo "FAIL: silver-feature has verify before review"
  FAIL=$((FAIL + 1))
else
  echo "PASS: silver-feature review before verify"
  PASS=$((PASS + 1))
fi

bugfix_q="$(sb_orchestrator_default_queue_for_composer silver-bugfix)"
if grep -q '^silver-debug,silver-quality-gates,silver-context,silver-plan,silver-execute\|^silver-debug,FLOW-QUALITY-GATE,silver-context,silver-plan,silver-execute' <<<"$bugfix_q"; then
  echo "PASS: silver-bugfix diagnosis first, then the planning floor (R10-02)"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-bugfix must run debug, then quality-gates/context/plan before execute (got: $bugfix_q)"
  FAIL=$((FAIL + 1))
fi

devops_q="$(sb_orchestrator_default_queue_for_composer silver-devops)"
assert_order "silver-devops" "$devops_q" "silver-execute"

ui_q="$(sb_orchestrator_default_queue_for_composer silver-ui)"
if grep -q 'silver-execute,silver-ui-review,silver-review-request' <<<"$ui_q"; then
  echo "PASS: silver-ui post-exec opens with execute → ui-review → review triad"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui missing execute → ui-review → review triad prefix (got: $ui_q)"
  FAIL=$((FAIL + 1))
fi
if grep -q 'silver-ui-review,silver-review-request' <<<"$ui_q"; then
  echo "PASS: silver-ui ui-review before review triad"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui ui-review must precede review-request (got: $ui_q)"
  FAIL=$((FAIL + 1))
fi

if grep -q 'silver-plan,silver-ui-contract,silver-validate,silver-execute' <<<"$ui_q"; then
  echo "PASS: silver-ui pre-exec includes plan → ui-contract → validate → execute"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-ui missing plan → ui-contract → validate → execute prefix (got: $ui_q)"
  FAIL=$((FAIL + 1))
fi
if grep -q 'silver-plan,silver-validate,silver-execute' <<<"$devops_q"; then
  echo "PASS: silver-devops pre-exec includes validate before execute"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-devops missing validate before execute (got: $devops_q)"
  FAIL=$((FAIL + 1))
fi

release_q="$(sb_orchestrator_default_queue_for_composer silver-release)"
if grep -q 'silver-branch-finish,silver-completion-audit,silver-ship,silver-create-release' <<<"$release_q"; then
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

if grep -q 'devops-skill-router,devops-quality-gates,security,silver-context' <<<"$devops_q"; then
  echo "PASS: silver-devops pre-exec includes router, devops-qg, and pre-plan security"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver-devops missing router/devops-qg/security prefix (got: $devops_q)"
  FAIL=$((FAIL + 1))
fi

fast_q="$(sb_orchestrator_default_queue_for_composer silver-fast)"
if grep -q 'FLOW-QUALITY-GATE,silver-context,silver-plan,silver-validate,silver-execute,silver-verify' <<<"$fast_q"; then
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
if grep -q 'FLOW-QUALITY-GATE,silver-clarify,silver-spec,silver-context' <<<"$feature_no_spec"; then
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
if grep -q 'FLOW-QUALITY-GATE,silver-clarify,silver-spec,silver-context' <<<"$ui_no_spec"; then
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
if grep -q 'silver-execute' <<<"$research_q"; then
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

if grep -q 'silver-execute' <<<"$release_q"; then
  echo "FAIL: silver-release queue must not include silver-execute"
  FAIL=$((FAIL + 1))
else
  echo "PASS: silver-release excludes silver-execute"
  PASS=$((PASS + 1))
fi
if grep -q 'silver-create-release' <<<"$release_q"; then
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
SB_RUNTIME_STATE_DIR="$(dirname "$orch_test")"
export SB_RUNTIME_STATE_DIR
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

# R10-02: every composer queue that reaches silver-execute carries the whole planning floor first,
# so a worker that follows the queue is never stopped by dev-cycle-check / completion-audit.
FLOOR_SKILLS="silver-quality-gates silver-context silver-plan"
for composer in silver-feature silver-ui silver-bugfix silver-fast silver-refactor silver-test silver-benchmark silver-content silver-forensics silver-retro silver-release; do
  q="$(sb_orchestrator_default_queue_for_composer "$composer")"
  case ",$q," in *,silver-execute,*) ;; *) continue ;; esac
  before="${q%%,silver-execute*}"
  skills_before=""
  IFS=',' read -ra toks <<<"$before"
  for t in "${toks[@]}"; do skills_before="$skills_before $(sb_orchestrator_flow_to_skill "$t")"; done
  missing=""
  for f in $FLOOR_SKILLS; do
    case " $skills_before " in *" $f "*) ;; *) missing="$missing $f" ;; esac
  done
  if [[ -z "$missing" ]]; then
    echo "PASS: $composer queue carries the planning floor before silver-execute"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $composer queue lacks${missing} before silver-execute (got: $q)"
    FAIL=$((FAIL + 1))
  fi
done
for dc in silver-devops silver-canary silver-deploy silver-incident; do
  dq="$(sb_orchestrator_default_queue_for_composer "$dc")"
  devops_before="${dq%%,silver-execute*}"
  for f in silver-blast-radius devops-quality-gates silver-context silver-plan; do
    case ",$devops_before," in *,"$f",*) echo "PASS: $dc queue carries $f before execute"; PASS=$((PASS + 1)) ;; *) echo "FAIL: $dc lacks $f (got: $dq)"; FAIL=$((FAIL + 1)) ;; esac
  done
done
# The floor is configurable: a project's required_planning is honoured, and an already
# present token (FLOW-QUALITY-GATE for silver-quality-gates) is not duplicated.
proj="$(mktemp -d)"
printf '{"skills":{"required_planning":["silver-quality-gates","silver-context","silver-plan","silver-clarify"]}}' >"$proj/.silver-bullet.json"
q="$(sb_orchestrator_queue_for_composer silver-bugfix "$proj")"
if [[ "$q" == "silver-debug,FLOW-QUALITY-GATE,silver-context,silver-clarify,silver-plan,silver-execute"* || "$q" == "silver-debug,silver-quality-gates,silver-context,silver-clarify,silver-plan,silver-execute"* ]]; then
  echo "PASS: project required_planning extends the bugfix floor"; PASS=$((PASS + 1))
else
  echo "FAIL: project floor not applied (got: $q)"; FAIL=$((FAIL + 1))
fi
q="$(sb_orchestrator_queue_for_composer silver-feature "$proj")"
if [[ "$q" == FLOW-QUALITY-GATE,* && "${q%%,silver-execute*}" != *"silver-quality-gates"* ]]; then
  echo "PASS: a token already standing for a floor skill is not duplicated"; PASS=$((PASS + 1))
else
  echo "FAIL: duplicate floor skill (got: $q)"; FAIL=$((FAIL + 1))
fi
printf '{"skills":{"required_planning":[]}}' >"$proj/.silver-bullet.json"
q="$(sb_orchestrator_queue_for_composer silver-bugfix "$proj")"
if [[ "$q" == silver-debug,*silver-quality-gates*silver-plan,silver-execute* || "$q" == silver-debug,FLOW-QUALITY-GATE*silver-plan,silver-execute* ]]; then
  echo "PASS: an empty configured floor falls back to the shipped default"; PASS=$((PASS + 1))
else
  echo "FAIL: empty configured floor (got: $q)"; FAIL=$((FAIL + 1))
fi
rm -rf "$proj"
# A project whose active_workflow is devops-cycle gets the devops floor, as the hooks do.
proj="$(mktemp -d)"
printf '{"project":{"active_workflow":"devops-cycle"},"skills":{"required_planning_devops":["silver-blast-radius","devops-quality-gates","silver-context","silver-plan"]}}' >"$proj/.silver-bullet.json"
q="$(sb_orchestrator_queue_for_composer silver-incident "$proj")"
if [[ "${q%%,silver-execute*}" == *devops-quality-gates* && "${q%%,silver-execute*}" != *silver-quality-gates* ]]; then
  echo "PASS: devops-cycle project: incident queue carries the devops floor"; PASS=$((PASS + 1))
else
  echo "FAIL: devops-cycle floor not applied (got: $q)"; FAIL=$((FAIL + 1))
fi
rm -rf "$proj"
# Without the shipped template the built-in floors apply.
staged_lib="$(mktemp -d)/hooks/lib"
mkdir -p "$staged_lib"
cp "$REPO_ROOT/hooks/lib/orchestrator-state.sh" "$REPO_ROOT/hooks/lib/orchestrator-io.sh" "$REPO_ROOT/hooks/lib/orchestrator-directive.sh" "$staged_lib/"
got="$(bash -c 'source "$1"; sb_orchestrator_planning_floor_csv silver-bugfix' _ "$staged_lib/orchestrator-state.sh")"
if [[ "$got" == "silver-quality-gates,silver-context,silver-plan" ]]; then
  echo "PASS: no template: built-in three-skill floor"; PASS=$((PASS + 1))
else
  echo "FAIL: built-in floor (got: $got)"; FAIL=$((FAIL + 1))
fi
got="$(bash -c 'source "$1"; sb_orchestrator_planning_floor_csv silver-devops' _ "$staged_lib/orchestrator-state.sh")"
if [[ "$got" == "silver-blast-radius,devops-quality-gates,silver-context,silver-plan" ]]; then
  echo "PASS: no template: built-in devops floor"; PASS=$((PASS + 1))
else
  echo "FAIL: built-in devops floor (got: $got)"; FAIL=$((FAIL + 1))
fi
rm -rf "$(dirname "$(dirname "$staged_lib")")"
# Queues without an execute step are untouched.
q="$(sb_orchestrator_default_queue_for_composer silver-deep-research)"
if [[ "$q" == "silver-clarify,silver-deep-research,silver-ensure-docs,silver-validate" ]]; then
  echo "PASS: queue without silver-execute gets no floor"; PASS=$((PASS + 1))
else
  echo "FAIL: deep-research queue changed (got: $q)"; FAIL=$((FAIL + 1))
fi
# A queue with no plan step gets the floor before execute.
q="$(sb_orchestrator_apply_planning_floor "silver-debug,silver-execute" "silver-quality-gates,silver-plan")"
if [[ "$q" == "silver-debug,silver-quality-gates,silver-plan,silver-execute" ]]; then
  echo "PASS: floor goes before execute when there is no plan step"; PASS=$((PASS + 1))
else
  echo "FAIL: no-plan queue (got: $q)"; FAIL=$((FAIL + 1))
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
