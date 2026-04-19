#!/usr/bin/env bash
# Tests for hooks/completion-audit.sh
# Tests TWO-TIER enforcement: intermediate commits (planning only) vs final delivery (full check)

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/completion-audit.sh"
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
  local workflow="${1:-full-dev-cycle}"
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "${workflow}" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"],
    "all_tracked": ["silver-quality-gates","code-review"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

setup() {
  # Initialize git directly in TMPDIR_TEST so the hook finds .silver-bullet.json
  # before hitting the .git boundary (both are in the same directory).
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPGIT="$TMPDIR_TEST"   # git repo IS the project dir
  rm -f "$TMPSTATE"
  git -C "$TMPGIT" init -q
  git -C "$TMPGIT" config user.email "test@test.com"
  git -C "$TMPGIT" config user.name "Test"
  # Create initial commit so branch name is set
  touch "$TMPGIT/.gitkeep"
  git -C "$TMPGIT" add .gitkeep
  git -C "$TMPGIT" commit -q -m "init" 2>/dev/null || true
  git -C "$TMPGIT" checkout -q -b feature/test 2>/dev/null || true
  write_cfg "full-dev-cycle"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
}

run_hook() {
  local event="$1"
  local cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  # Use subshell to prevent CWD leak into test script
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  # A block occurs when output contains "block" decision or "deny" permissionDecision
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== completion-audit.sh tests ==="

# Test 1: Unrelated command passes silently
echo "--- Group 1: Command classification ---"
setup
out=$(run_hook "PreToolUse" "ls -la")
assert_passes "unrelated command passes" "$out"
teardown

# Test 2: git commit blocked without planning (intermediate tier, empty state)
setup
out=$(run_hook "PreToolUse" "git commit -m 'test'")
assert_blocks "git commit blocked without silver-quality-gates" "$out"
assert_contains "block message mentions planning" "$out" "COMMIT BLOCKED"
teardown

# Test 3: git commit allowed with planning complete (intermediate tier)
setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "git commit -m 'test'")
assert_passes "git commit allowed with silver-quality-gates done" "$out"
teardown

# Test 4: git push blocked without planning
setup
out=$(run_hook "PreToolUse" "git push origin feature/test")
assert_blocks "git push blocked without silver-quality-gates" "$out"
teardown

# Test 5: git push allowed with planning — even without finalization skills
setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "git push origin feature/test")
assert_passes "git push allowed with silver-quality-gates (no finalization needed)" "$out"
teardown

# Test 6: gh pr create blocked without full required_deploy
echo "--- Group 2: Final delivery tier ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"  # only planning done, not full workflow
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "gh pr create blocked with only silver-quality-gates" "$out"
assert_contains "block message mentions COMPLETION BLOCKED" "$out" "COMPLETION BLOCKED"
teardown

# Test 7: gh pr create passes with all required_deploy skills
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_passes "gh pr create passes with all required skills" "$out"
teardown

# Test 8: deploy command blocked
setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "npm run deploy")
assert_blocks "deploy command blocked without full workflow" "$out"
teardown

# Test 9: gh release create blocked without required workflow skills
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
EOF
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked without full workflow skills" "$out"
assert_contains "release block message mentions COMPLETION BLOCKED" "$out" "COMPLETION BLOCKED"
teardown

# Test 10: gh release create passes with all required workflow skills (no §9 stages needed)
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "release passes with all required workflow skills" "$out"
teardown

# Test 11: finishing-a-development-branch NOT required when on main
echo "--- Group 3: Main branch handling ---"
setup
# Put all required skills EXCEPT finishing-a-development-branch
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
# Ensure we're on main
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true
out=$(run_hook "PreToolUse" "gh pr create --title 'hotfix'")
assert_passes "gh pr create passes on main without finishing-a-development-branch" "$out"
teardown

# Test 12: Code review triad ordering detected (requesting before code)
echo "--- Group 4: Ordering enforcement ---"
setup
# Put skills with requesting-code-review BEFORE code-review in the state file
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_contains "ordering issue detected for wrong sequence" "$out" "wrong order"
teardown

# Test 13: Correct triad order passes cleanly
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_passes "correct triad order passes without ordering warning" "$out"
# Should NOT contain "wrong order"
if ! printf '%s' "$out" | grep -q "wrong order"; then
  echo "  ✅ no false ordering warning on correct sequence"
  PASS=$((PASS + 1))
else
  echo "  ❌ false ordering warning on correct sequence: $out"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 14: DevOps workflow uses silver-blast-radius for intermediate check
echo "--- Group 5: DevOps workflow ---"
setup
write_cfg "devops-cycle"
# With empty state, git commit should fail requiring silver-blast-radius + devops-quality-gates
out=$(run_hook "PreToolUse" "git commit -m 'infra'")
assert_blocks "devops: git commit blocked without silver-blast-radius/devops-quality-gates" "$out"
teardown

# Test 15: Trivial file bypass
echo "--- Group 6: Bypass mechanisms ---"
setup
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook "PreToolUse" "git commit -m 'test'")
assert_passes "trivial file bypasses completion check" "$out"
teardown

# Test 16: gh pr merge blocked when skills missing (Tier 2 delivery gate)
echo "--- Group 7: gh pr merge delivery gate ---"
setup
# Only planning done
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "gh pr merge --squash")
assert_blocks "gh pr merge blocked with only silver-quality-gates" "$out"
assert_contains "gh pr merge block mentions COMPLETION BLOCKED" "$out" "COMPLETION BLOCKED"
teardown

# Test 17: gh pr merge passes when all required skills present (review-loop-pass markers
# are NOT required — removed from required_deploy in v0.23.6 — but must not cause
# spurious failures if present in state (e.g. from a pre-upgrade session).
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook "PreToolUse" "gh pr merge --squash")
assert_passes "gh pr merge passes with all required skills (no review-loop-pass needed)" "$out"
teardown

# ── WORKFLOW.md-first gate tests ─────────────────────────────────────────────
echo ""
echo "=== WORKFLOW.md-first gate ==="

# WF1: WORKFLOW.md with all paths complete -> allow commit
echo "--- WF1: all workflow paths complete -> allow commit ---"
setup
write_cfg
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 9 | REVIEW | complete |
| 11 | VERIFY | complete |
| 13 | SHIP | complete |
WFEOF
out=$(run_hook "PreToolUse" "git commit -m test")
assert_passes "WF1: all workflow paths complete -> allow" "$out"
teardown

# WF2: WORKFLOW.md with partial paths -> blocks final delivery
echo "--- WF2: partial paths -> blocks final delivery ---"
setup
write_cfg
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | in_progress |
WFEOF
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "WF2: partial paths -> block final delivery" "$out"
teardown

# WF3: Bug-2 regression — Phase Iterations and Autonomous Decisions rows don't inflate total
echo "--- WF3: Bug-2 regression — digit-starting rows in other sections don't inflate total ---"
setup
write_cfg
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Flow | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 9 | REVIEW | complete |
| 11 | VERIFY | complete |
| 13 | SHIP | complete |

## Phase Iterations
| Phase | Status |
|-------|--------|
| 01 (feature-phase) | FLOW 5 complete, FLOW 7 complete |

## Autonomous Decisions
| Timestamp | Decision | Rationale |
|-----------|----------|-----------|
| 2026-04-15T10:00:00Z | Skipped FLOW 4 | No SPEC.md found |
| 2026-04-15T10:05:00Z | Auto-confirmed | autonomous mode |
WFEOF
# All 6 Flow Log rows complete — should allow final delivery despite extra digit-starting rows
# Must use gh pr create (is_completion=true) — git commit is intermediate and doesn't trigger the total check
out=$(run_hook "PreToolUse" "gh pr create --title 'release'")
assert_passes "WF3: Phase Iterations and Autonomous Decisions rows don't inflate total (Bug-2 regression)" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
