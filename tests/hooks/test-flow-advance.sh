#!/usr/bin/env bash
# Tests for hooks/flow-advance.sh — orchestrator workflow start + advance (Wave 0.3/0.8).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SB_ORCHESTRATOR_RUNTIME_SCHEDULER=0

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/flow-advance.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
PASS=0
FAIL=0

# shellcheck source=/dev/null
source "$LIB"

TEST_RUN_ID="$$"
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT:-/tmp}/.silver-bullet/flow-advance-${TEST_RUN_ID}"
mkdir -p "$SB_TEST_DIR"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
export SILVER_BULLET_STATE_FILE="$TMPSTATE"

cleanup() {
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/orchestrator.json" "${SB_TEST_DIR}/orchestrator-intent.txt" 2>/dev/null || true
  rm -rf "$WORK" "${SB_RUNTIME_HOME_ROOT:-/tmp}/.silver-bullet/flow-advance-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup EXIT

make_repo() {
  WORK=$(mktemp -d)
  git -C "$WORK" init -q
  git -C "$WORK" -c user.email="t@t.com" -c user.name="T" commit -q --allow-empty -m init
  mkdir -p "$WORK/.planning/workflows"
  cat >"$WORK/.silver-bullet.json" <<EOF
{"sb_initiated":true,"project":{"name":"t","src_pattern":"/src/","active_workflow":"full-dev-cycle"},"state":{"state_file":"${TMPSTATE}"}}
EOF
  mkdir -p "$WORK/.planning"
  cat >"$WORK/.planning/SPEC.md" <<'EOF'
spec-version: 1.0
# test spec
EOF
  echo "# SB" >"$WORK/silver-bullet.md"
  cp "$REPO_ROOT/scripts/workflows.sh" "$WORK/scripts/workflows.sh" 2>/dev/null || mkdir -p "$WORK/scripts" && cp "$REPO_ROOT/scripts/workflows.sh" "$WORK/scripts/"
  chmod +x "$WORK/scripts/workflows.sh"
}

run_hook() {
  local skill="$1"
  local workdir="$2"
  (cd "$workdir" && printf '{"tool_input":{"skill":"%s"}}' "$skill" | \
    SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" SB_RUNTIME_PRESERVE_STATE_DIR=1 bash "$HOOK" 2>/dev/null) || true
}

assert_contains() {
  local name="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF "$needle"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (missing: $needle)"
    FAIL=$((FAIL + 1))
  fi
}

make_repo
out="$(run_hook "silver-feature" "$WORK")"
assert_contains "composer starts workflow" "$out" "Workflow"
assert_contains "orchestrator state written" "$(test -f "${SB_TEST_DIR}/orchestrator.json" && echo yes)" "yes"
wf_count=$(find "$WORK/.planning/workflows" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
assert_contains "workflow file created" "$wf_count" "1"

out2="$(run_hook "silver-context" "$WORK")"
assert_contains "advance emits next flow" "$out2" "Next flow"

# QUALITY GATE row must complete when flow-advance records silver-quality-gates
# (dogfood: workflows.sh used to strip spaces on start but not on complete-flow match)
wid="$(find "$WORK/.planning/workflows" -maxdepth 1 -name '*.md' -print | head -1)"
wid="$(basename "$wid" .md)"
run_hook "silver-quality-gates" "$WORK" >/dev/null
qg_status="$(awk -F'|' '/QUALITY/ { gsub(/ /,"",$4); print $4; exit }' "$WORK/.planning/workflows/${wid}.md" 2>/dev/null || true)"
assert_contains "quality gate flow row completes" "$qg_status" "complete"

# Special workflow labels with spaces must complete from their atom skills.
rm -f "${SB_TEST_DIR}/orchestrator.json" "${SB_TEST_DIR}/orchestrator-intent.txt" 2>/dev/null || true
make_repo
run_hook "silver-release" "$WORK" >/dev/null
release_wid="$(find "$WORK/.planning/workflows" -maxdepth 1 -name '*.md' -print | head -1)"
release_wid="$(basename "$release_wid" .md)"
run_hook "security" "$WORK" >/dev/null
secure_status="$(awk -F'|' '/SECURITY/ { gsub(/ /,"",$4); print $4; exit }' "$WORK/.planning/workflows/${release_wid}.md" 2>/dev/null || true)"
assert_contains "security atom completes SECURITY row" "$secure_status" "complete"
run_hook "silver-branch-finish" "$WORK" >/dev/null
branch_status="$(awk -F'|' '/BRANCH FINISH/ { gsub(/ /,"",$4); print $4; exit }' "$WORK/.planning/workflows/${release_wid}.md" 2>/dev/null || true)"
assert_contains "branch-finish atom completes spaced row" "$branch_status" "complete"
run_hook "silver-completion-audit" "$WORK" >/dev/null
completion_status="$(awk -F'|' '/COMPLETION AUDIT/ { gsub(/ /,"",$4); print $4; exit }' "$WORK/.planning/workflows/${release_wid}.md" 2>/dev/null || true)"
assert_contains "completion-audit atom completes spaced row" "$completion_status" "complete"
run_hook "silver-create-release" "$WORK" >/dev/null
release_status="$(awk -F'|' '/CREATE RELEASE/ { gsub(/ /,"",$4); print $4; exit }' "$WORK/.planning/workflows/${release_wid}.md" 2>/dev/null || true)"
assert_contains "create-release atom completes spaced row" "$release_status" "complete"

# Worker sessions must not re-seed composer queue when re-reading composer skills
rm -f "${SB_TEST_DIR}/orchestrator.json" "${SB_TEST_DIR}/orchestrator-intent.txt" 2>/dev/null || true
make_repo
run_hook "silver-feature" "$WORK" >/dev/null
before_wid="$(jq -r '.workflow_id // ""' "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || true)"
before_len="$(jq '.flow_queue | length' "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || echo 0)"
( cd "$WORK" && \
  printf '{"tool_input":{"skill":"silver-feature"}}' | \
  SB_ORCHESTRATOR_WORKER=1 \
  SILVER_BULLET_STATE_FILE="$TMPSTATE" \
  SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" \
  SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  bash "$HOOK" >/dev/null 2>&1 ) || true
after_wid="$(jq -r '.workflow_id // ""' "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || true)"
after_len="$(jq '.flow_queue | length' "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || echo 0)"
if [[ "$before_wid" == "$after_wid" && "$before_len" == "$after_len" ]]; then
  echo "PASS: worker session does not re-seed composer queue"
  PASS=$((PASS + 1))
else
  echo "FAIL: worker session re-seeded composer (before=$before_wid/$before_len after=$after_wid/$after_len)"
  FAIL=$((FAIL + 1))
fi

# Composition log is written when .planning exists at composer start
log_file="$WORK/.planning/orchestrator-composition-log.jsonl"
assert_contains "composition log file created" "$(test -f "$log_file" && echo yes)" "yes"
log_tail="$(grep -F '"composer":"silver-feature"' "$log_file" 2>/dev/null | tail -1 || true)"
assert_contains "composition log records silver-feature" "$log_tail" '"composer":"silver-feature"'
assert_contains "composition log records autonomous mode" "$log_tail" '"mode":"autonomous"'

# Drain silver-fast queue — current_flow must end empty
rm -f "${SB_TEST_DIR}/orchestrator.json" "${SB_TEST_DIR}/orchestrator-intent.txt" "$log_file" 2>/dev/null || true
make_repo
run_hook "silver-fast" "$WORK" >/dev/null
fast_atoms=(silver-quality-gates silver-plan silver-validate silver-execute silver-verify)
for atom in "${fast_atoms[@]}"; do
  run_hook "$atom" "$WORK" >/dev/null
done
current_flow="$(jq -r '.current_flow // "<unset>"' "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || echo "<missing>")"
if [[ -z "$current_flow" || "$current_flow" == "null" ]]; then
  echo "PASS: orchestrator current_flow empty after queue drain"
  PASS=$((PASS + 1))
else
  echo "FAIL: orchestrator current_flow not empty after drain (got: $current_flow)"
  FAIL=$((FAIL + 1))
fi
last_completed="$(jq -r '.last_completed // ""' "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || true)"
assert_contains "last completed atom is silver-verify" "$last_completed" "silver-verify"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
