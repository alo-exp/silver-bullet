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

# ── Composed-workflow gate (Pass 1: deferred — gate falls through to legacy) ──
# The legacy single-file `.planning/WORKFLOW.md` gate was retired (see
# completion-audit.sh for full rationale). v0.29.x replaces it with per-instance
# `.planning/workflows/<id>.md` files; Pass 2 will implement strict
# per-workflow gating. Pass 1 simply ignores WORKFLOW.md and all `.planning/
# workflows/*.md` files and falls through to the legacy required-skills gate.
echo ""
echo "=== Composed-workflow gate (Pass 1: WORKFLOW.md ignored) ==="

# WF-PASS1-A: a stale WORKFLOW.md showing all paths complete must NOT bypass
# the legacy required-skills gate when state is empty.
echo "--- WF-PASS1-A: stale WORKFLOW.md does not bypass empty-state legacy gate ---"
setup
write_cfg
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 13 | SHIP | complete |
WFEOF
# Empty state file (no skills recorded) — legacy gate would normally allow
# (zero state = no enforcement target), so the test specifically asserts that
# the stale WORKFLOW.md doesn't trigger a "delivery allowed" message. Use
# `gh pr create` so legacy completion path also fires.
out=$(run_hook "PreToolUse" "git commit -m test")
# Empty state = legacy gate exits 0 silently. Confirm the stale-WF message is
# NOT in the output (would prove the old gate is gone).
if printf '%s' "$out" | grep -q 'WORKFLOW\.md.*Intermediate commit allowed\|WORKFLOW\.md.*Delivery allowed'; then
  echo "  ❌ WF-PASS1-A: stale WORKFLOW.md still being read — Pass 1 hotfix incomplete"
  FAIL=$((FAIL+1))
else
  echo "  ✅ WF-PASS1-A: stale WORKFLOW.md correctly ignored"
  PASS=$((PASS+1))
fi
teardown

# WF-PASS1-B: `.planning/workflows/<id>.md` files (future format) are also
# ignored by Pass 1 — gate falls through to legacy required-skills check.
echo "--- WF-PASS1-B: workflows/ dir does not bypass legacy gate ---"
setup
write_cfg
mkdir -p "$TMPDIR_TEST/.planning/workflows"
cat > "$TMPDIR_TEST/.planning/workflows/20260428T015523Z-K4F7QA-silver-feature.md" << 'WFEOF'
**Composer:** /silver:feature
**Status:** active
### Flow Log
| # | Flow | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
WFEOF
# Empty state: missing silver-quality-gates → legacy gate must block git commit
echo > "$TMPSTATE"
out=$(run_hook "PreToolUse" "git commit -m test")
# With empty state, completion-audit's legacy gate exits 0 silently
# (see HOOK-04 empty-state behavior). The key assertion: no WORKFLOW.md
# message in the output proves Pass 1 hotfix is engaged.
if printf '%s' "$out" | grep -q 'flows complete\|Delivery allowed\|Intermediate commit allowed'; then
  echo "  ❌ WF-PASS1-B: workflows/ dir incorrectly bypassed legacy gate"
  FAIL=$((FAIL+1))
else
  echo "  ✅ WF-PASS1-B: workflows/ dir correctly ignored (Pass 2 will add gating)"
  PASS=$((PASS+1))
fi
teardown

# ── WF-PASS2: strict SB_WORKFLOW_ID-matched final-delivery gate ──────────────
# When `.planning/workflows/<id>.md` files are present AND the command is a
# final-delivery operation, completion-audit must require:
#   • SB_WORKFLOW_ID env var set
#   • value matches an active workflow file
#   • all Flow Log rows in that file marked complete
# Intermediate commits (`git commit`, `git push`) are unaffected — strict gate
# is final-delivery only.

# Helper to create an active workflow file with given flow rows
_make_workflow() {
  local id="$1"
  local rows="$2"
  mkdir -p "$TMPDIR_TEST/.planning/workflows"
  cat > "$TMPDIR_TEST/.planning/workflows/$id.md" << WFEOF
---
workflow_id: $id
composer: silver-feature
status: active
---
## Flow Log
| # | Path/Skill | Status | Started | Completed |
|---|------------|--------|---------|-----------|
$rows
WFEOF
}

# Full required-deploy state (used to isolate the strict gate from the legacy gate)
_full_state() {
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
}

echo "--- WF-PASS2-A: gh release create with no SB_WORKFLOW_ID is BLOCKED ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |"
unset SB_WORKFLOW_ID
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-A: missing SB_WORKFLOW_ID blocks release" "$out"
assert_contains "WF-PASS2-A: error names env var" "$out" "SB_WORKFLOW_ID"
teardown

echo "--- WF-PASS2-B: invalid SB_WORKFLOW_ID format is BLOCKED ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |"
out=$(SB_WORKFLOW_ID="../../etc/passwd" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-B: malformed id blocked" "$out"
assert_contains "WF-PASS2-B: error mentions invalid format" "$out" "invalid format"
teardown

echo "--- WF-PASS2-C: incomplete workflow blocks release ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |
| 2 | plan | pending | - | - |
| 3 | execute | pending | - | - |"
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-C: incomplete workflow blocks" "$out"
assert_contains "WF-PASS2-C: error reports 1 of 3" "$out" "1 of 3"
teardown

echo "--- WF-PASS2-D: fully-complete workflow + full skills passes ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |
| 2 | plan | complete | - | now |
| 3 | execute | complete | - | now |
| 4 | ship | complete | - | now |"
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-D: complete workflow + skills allows release" "$out"
teardown

echo "--- WF-PASS2-E: nonexistent SB_WORKFLOW_ID blocks ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |"
out=$(SB_WORKFLOW_ID="20260101T000000Z-zzzzzz-silver-bugfix" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-E: id not matching any file blocks" "$out"
assert_contains "WF-PASS2-E: error mentions no match" "$out" "No active workflow file matches"
teardown

echo "--- WF-PASS2-F: intermediate commit unaffected by strict gate ---"
setup
# Only planning skill recorded (intermediate-tier requirement)
echo "silver-quality-gates" > "$TMPSTATE"
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | pending | - | - |"
unset SB_WORKFLOW_ID
out=$(run_hook "PreToolUse" "git commit -m test")
assert_passes "WF-PASS2-F: incomplete workflow does not block git commit" "$out"
teardown

echo "--- WF-PASS2-G: no workflows dir → falls through to legacy gate ---"
setup
_full_state
# No .planning/workflows/ created
unset SB_WORKFLOW_ID
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-G: absent workflows dir → legacy gate (passes with full skills)" "$out"
teardown

echo "--- WF-PASS2-H: digit-row inflation guard — non-Flow-Log digit rows ignored ---"
# S4 regression guard: phase-iteration tables (e.g. | 01 | started | …) must
# NOT be counted as Flow Log rows. Only "^\| <digits> \|" rows count.
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
mkdir -p "$TMPDIR_TEST/.planning/workflows"
cat > "$TMPDIR_TEST/.planning/workflows/$ID.md" << 'WFEOF'
---
workflow_id: 20260428T120000Z-abc123-silver-feature
status: active
---
## Flow Log
| # | Path/Skill | Status | Started | Completed |
|---|------------|--------|---------|-----------|
| 1 | explore | complete | - | now |
| 2 | ship | complete | - | now |

## Phase Iterations (must NOT inflate counts)
| 01 | started | ... |
| 02 | finished | ... |

## Autonomous Decisions (must NOT inflate counts)
| 2026-04-28T12:00 | chose path A | ... |
WFEOF
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-H: extraneous digit rows ignored — release passes" "$out"
teardown

echo "--- WF-PASS2-I (#86): mixed complete+skipped workflow allows release ---"
# Issue #86: 'skipped' is a valid terminal state for non-applicable flows
# (e.g. FLOW 8 UI QUALITY for a CLI-only tool). Previously the count regex
# matched only 'complete', so skipped rows were treated as incomplete and
# blocked release indefinitely.
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | bootstrap | complete | - | now |
| 2 | orient    | skipped  | - | -   |
| 3 | explore   | skipped  | - | -   |
| 4 | plan      | complete | - | now |
| 5 | execute   | complete | - | now |
| 6 | ui-quality | skipped | - | -   |
| 7 | ship      | complete | - | now |"
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-I (#86): mixed complete/skipped workflow allows release" "$out"
teardown

echo "--- WF-PASS2-J (#86): all-skipped workflow is treated as terminal ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | bootstrap | skipped | - | - |
| 2 | orient    | skipped | - | - |"
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-J (#86): all-skipped flows pass terminal-state check" "$out"
teardown

echo "--- WF-PASS2-K (#86): pending row still blocks (skipped fix didn't loosen) ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | bootstrap | complete | - | now |
| 2 | orient    | skipped  | - | -   |
| 3 | execute   | pending  | - | -   |"
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-K (#86): pending row still blocks even with skipped present" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
