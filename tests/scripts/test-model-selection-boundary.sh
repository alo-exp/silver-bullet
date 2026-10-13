#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass() {
  echo "PASS: $1"
  (( PASS++ )) || true
}

fail() {
  echo "FAIL: $1"
  (( FAIL++ )) || true
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qE "$needle" "$file"; then
    pass "$desc"
  else
    fail "$desc -- missing [$needle] in ${file#$REPO_ROOT/}"
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2"
  shift 2
  local tmp="/tmp/sb-model-boundary.$$"
  if ! grep -R -n -E "$needle" "$@" >"$tmp" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc -- unexpected matches:"
    sed 's/^/  /' "$tmp"
  fi
  rm -f -- "$tmp"
}

CURRENT_SURFACES=(
  "$REPO_ROOT/silver-bullet.md"
  "$REPO_ROOT/templates/silver-bullet.md.base"
  "$REPO_ROOT/docs/RUNTIME-COMPATIBILITY.md"
  "$REPO_ROOT/docs/workflows/full-dev-cycle.md"
  "$REPO_ROOT/templates/workflows/full-dev-cycle.md"
  "$REPO_ROOT/docs/workflows/devops-cycle.md"
  "$REPO_ROOT/templates/workflows/devops-cycle.md"
  "$REPO_ROOT/skills/silver-quality-gates/SKILL.md"
)

assert_contains "runtime compatibility documents model boundary" "Model Selection Boundary" "$REPO_ROOT/docs/RUNTIME-COMPATIBILITY.md"
assert_contains "full dev workflow documents host model boundary" "HOST MODEL BOUNDARY" "$REPO_ROOT/docs/workflows/full-dev-cycle.md"
assert_contains "template workflow documents host model boundary" "HOST MODEL BOUNDARY" "$REPO_ROOT/templates/workflows/full-dev-cycle.md"
assert_contains "devops workflow documents host model boundary" "HOST MODEL BOUNDARY" "$REPO_ROOT/docs/workflows/devops-cycle.md"
assert_contains "template devops workflow documents host model boundary" "HOST MODEL BOUNDARY" "$REPO_ROOT/templates/workflows/devops-cycle.md"

assert_not_contains "current docs do not encode explicit Claude/Codex model ladders" \
  "claude-(sonnet|opus)-4-6|GPT-5\\.[2345]|gpt-5\\.[2345]|Haiku" \
  "${CURRENT_SURFACES[@]}"

assert_not_contains "current docs do not promise SB automatic model routing" \
  "Model Routing|MODEL ROUTING|pre-assigned to models|silent escalation|session ladder" \
  "${CURRENT_SURFACES[@]}"

_legacy_profile_pattern=$'model_profile.*balanced|'"gs"'d-set-profile balanced|planner_model|researcher_model|checker_model'
assert_not_contains "current docs do not require external model_profile routing" \
  "$_legacy_profile_pattern" \
  "${CURRENT_SURFACES[@]}"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
