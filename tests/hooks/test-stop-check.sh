#!/usr/bin/env bash
# Tests for hooks/stop-check.sh
# Verifies Stop hook block/allow behavior for missing/complete skills.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/stop-check.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ~/.claude/ due to security path validation in hooks.
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() { rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"; }
trap cleanup_all EXIT

write_cfg() {
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist"],
    "all_tracked": ["silver-quality-gates","code-review"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

write_cfg_with_release() {
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release"],
    "all_tracked": ["silver-quality-gates","code-review"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPGIT="$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  git -C "$TMPGIT" init -q
  git -C "$TMPGIT" config user.email "test@test.com"
  git -C "$TMPGIT" config user.name "Test"
  touch "$TMPGIT/.gitkeep"
  git -C "$TMPGIT" add .gitkeep
  write_cfg
  # Commit config on the default branch BEFORE forking feature/test so that
  # feature/test does not appear as 1-ahead of main. Tests that need a clean
  # working tree rely on `git status --porcelain` being empty (HOOK-14).
  git -C "$TMPGIT" add .silver-bullet.json 2>/dev/null || true
  git -C "$TMPGIT" commit -q -m "init" 2>/dev/null || true
  git -C "$TMPGIT" checkout -q -b feature/test 2>/dev/null || true
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
}

run_hook() {
  local input='{"hook_event_name":"Stop"}'
  # Use subshell to set PWD to temp project dir (hook walks up from PWD)
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_blocked "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_blocked "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_empty() {
  local label="$1"
  local output="$2"
  if [[ -z "$output" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected empty output, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== stop-check.sh tests ==="

# Test 1: No config file -> exit 0, no output (project not using SB)
echo "--- Test 1: No config file ---"
setup
# Remove config file to simulate project not using SB
rm -f "$TMPCFG"
out=$(run_hook)
assert_empty "no config file -> silent exit, no output" "$out"
teardown

# Test 2: All required_deploy skills present -> exit 0, no block
echo "--- Test 2: All required skills present ---"
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
EOF
out=$(run_hook)
assert_passes "all required_deploy skills present -> no block" "$out"
teardown

# Test 3: Missing skills -> outputs block JSON with missing skill names
echo "--- Test 3: Missing skills -> block with skill names ---"
setup
# Only put one skill, leaving others missing
echo "silver-quality-gates" > "$TMPSTATE"
# Dirty the working tree so HOOK-14 does not short-circuit enforcement
# (this test validates completion gate behaviour for an actual dev session).
printf 'work-in-progress\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
out=$(run_hook)
assert_blocks "missing skills -> decision:block" "$out"
assert_contains "block output contains 'code-review'" "$out" "code-review"
teardown

# Test 4: Trivial file present -> exit 0, no block
echo "--- Test 4: Trivial bypass ---"
setup
# No skills recorded — would normally block
rm -f "$TMPSTATE"
# Create trivial file (not a symlink)
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook)
assert_passes "trivial file present -> no block" "$out"
teardown

# Test 5: On main branch -> finishing-a-development-branch not required
echo "--- Test 5: Main branch - finishing-a-development-branch not required ---"
setup
# Switch to main branch
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true
# Put all required skills EXCEPT finishing-a-development-branch
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
testing-strategy
documentation
deploy-checklist
EOF
out=$(run_hook)
assert_passes "on main branch: all skills except finishing-a-development-branch -> no block" "$out"
teardown

# Test 6: Empty state file -> exit silently, no block (HOOK-04)
echo "--- Test 6: Empty state file -> non-dev session, no block ---"
setup
# Do NOT write anything to the state file — leave it empty/non-existent
out=$(run_hook)
assert_passes "empty state file -> non-dev session -> no block" "$out"
teardown

# Test 7: HOOK-14 — clean tree + no commits ahead + non-empty state -> no block
# Regression for issue #14: a conversational/read-only session on a branch that
# carries state from a prior wrap-up should not be gated by completion skills.
echo "--- Test 7: HOOK-14 clean tree + no ahead commits -> no block ---"
setup
# Non-empty state with only one skill — would normally block (missing many)
echo "silver-quality-gates" > "$TMPSTATE"
# Working tree is clean (setup already committed .gitkeep) and branch has no
# commits ahead of its origin: the test repo has no upstream, no origin/main,
# no main (we are on feature/test). HOOK-14 should still treat this as a
# conversational session since the tree is clean and there's no comparison ref
# → nothing to deploy → skip.
out=$(run_hook)
assert_passes "clean tree + non-empty state -> conversational session -> no block" "$out"
teardown

# Test 8: HOOK-14 — dirty working tree + non-empty state + missing skills -> block
# Guardrail: a session with uncommitted changes should still enforce completion.
echo "--- Test 8: HOOK-14 dirty tree -> still enforces ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"
# Introduce an uncommitted change so `git diff --quiet` fails
printf 'dirty\n' > "$TMPDIR_TEST/dirty.txt"
git -C "$TMPDIR_TEST" add dirty.txt
out=$(run_hook)
assert_blocks "dirty tree + missing skills -> still blocks" "$out"
teardown

# Test 9: HOOK-14 — clean tree + commits ahead of origin -> still enforces
echo "--- Test 9: HOOK-14 commits ahead of origin -> still enforces ---"
setup
# Create a fake origin/main pointing at the initial commit, then add a new
# commit on feature/test so it's 1 ahead.
git -C "$TMPDIR_TEST" branch main 2>/dev/null || true
git -C "$TMPDIR_TEST" update-ref refs/remotes/origin/main "$(git -C "$TMPDIR_TEST" rev-parse HEAD)"
printf 'more\n' > "$TMPDIR_TEST/more.txt"
git -C "$TMPDIR_TEST" add more.txt
git -C "$TMPDIR_TEST" commit -q -m "work" 2>/dev/null || true
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook)
assert_blocks "clean tree but commits ahead -> still blocks" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
