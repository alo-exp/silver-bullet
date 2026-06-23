#!/usr/bin/env bash
# test-quality-gates-mode.sh — canonical QG mode detection (P1)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK_HELPERS="$(cd "$(dirname "$0")" && pwd)/helpers/common.sh"
if [[ -f "$HOOK_HELPERS" ]]; then
  # shellcheck source=helpers/common.sh
  source "$HOOK_HELPERS"
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../hooks/lib/quality-gates-mode.sh
source "$REPO_ROOT/hooks/lib/quality-gates-mode.sh"

PASS=0
FAIL=0
TMPDIR_TEST=""

setup_repo() {
  TMPDIR_TEST=$(mktemp -d)
  hook_test_stamp_sb_scaffold "$TMPDIR_TEST"
  mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
}

teardown() {
  [[ -n "$TMPDIR_TEST" ]] && rm -rf "$TMPDIR_TEST"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ok: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected=$expected actual=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "--- quality-gates-mode ---"

setup_repo
assert_eq "empty repo is design mode" "design" "$(sb_qg_detect_mode "$TMPDIR_TEST")"
teardown

setup_repo
cat >"$TMPDIR_TEST/.planning/phases/01-test/PLAN.md" <<'MD'
# Plan
Acceptance criteria and tasks for the phase.
MD
assert_eq "plan only is design mode" "design" "$(sb_qg_detect_mode "$TMPDIR_TEST")"
teardown

setup_repo
cat >"$TMPDIR_TEST/.planning/phases/01-test/PLAN.md" <<'MD'
# Plan
Acceptance criteria and tasks for the phase.
MD
cat >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md" <<'MD'
# Verification
Evidence from test runs.
MD
assert_eq "substantive verify without passed status stays design" "design" "$(sb_qg_detect_mode "$TMPDIR_TEST")"
teardown

setup_repo
cat >"$TMPDIR_TEST/.planning/phases/01-test/PLAN.md" <<'MD'
# Plan
Acceptance criteria and tasks for the phase.
MD
cat >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md" <<'MD'
# Verification
status: passed
Evidence from test runs with acceptance mapping.
MD
mode="$(sb_qg_detect_mode "$TMPDIR_TEST")"
assert_eq "plan + passed verification is adversarial" "adversarial" "$mode"
marker="$(sb_qg_mode_marker "$mode")"
assert_eq "adversarial marker name" "silver-quality-gates-adversarial" "$marker"
teardown

setup_repo
cat >"$TMPDIR_TEST/.planning/phases/01-test/VERIFICATION.md" <<'MD'
# Verification
status: passed
Evidence only.
MD
if sb_qg_repo_requires_pre_ship_marker "$TMPDIR_TEST"; then
  echo "  FAIL: pre-ship required without substantive plan"
  FAIL=$((FAIL + 1))
else
  echo "  ok: pre-ship not required without substantive plan"
  PASS=$((PASS + 1))
fi
teardown

state="silver-quality-gates-design
silver-plan"
if sb_qg_preplan_marker_recorded "$state"; then
  echo "  ok: design marker satisfies pre-plan"
  PASS=$((PASS + 1))
else
  echo "  FAIL: design marker should satisfy pre-plan"
  FAIL=$((FAIL + 1))
fi

state="silver-quality-gates-adversarial"
if sb_dqg_pre_ship_marker_recorded "$state"; then
  echo "  FAIL: product adversarial should not satisfy devops pre-ship"
  FAIL=$((FAIL + 1))
else
  echo "  ok: devops pre-ship requires devops adversarial marker"
  PASS=$((PASS + 1))
fi

state="devops-quality-gates-adversarial"
if sb_dqg_pre_ship_marker_recorded "$state"; then
  echo "  ok: devops adversarial marker satisfies devops pre-ship"
  PASS=$((PASS + 1))
else
  echo "  FAIL: devops adversarial marker should satisfy devops pre-ship"
  FAIL=$((FAIL + 1))
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
