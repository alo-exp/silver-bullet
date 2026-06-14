#!/usr/bin/env bash
# Tests for hooks/flow-advance.sh — orchestrator workflow start + advance (Wave 0.3/0.8).
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/flow-advance.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT:-/tmp}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
export SILVER_BULLET_STATE_FILE="$TMPSTATE"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"

cleanup() {
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/orchestrator.json" "${SB_TEST_DIR}/orchestrator-intent.txt" 2>/dev/null || true
  rm -rf "$WORK" 2>/dev/null || true
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

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
