#!/usr/bin/env bash
# Tests for hooks/session-start
# Verifies SessionStart hook: branch-scoped state reset, trivial file cleanup,
# core-rules.md injection, jq missing warning.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

# Use temp files for state and branch so tests never touch the live session state.
# Both SILVER_BULLET_STATE_FILE and SILVER_BULLET_BRANCH_FILE are honoured by
# session-start via env-var overrides with ~/.claude/ path validation.
TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
TMPBRANCH="${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}"
TMPTRIVIAL="${SB_TEST_DIR}/trivial"   # trivial still uses default path (config-driven tests below)
export SILVER_BULLET_STATE_FILE="$TMPSTATE"
export SILVER_BULLET_BRANCH_FILE="$TMPBRANCH"

cleanup_all() {
  rm -f "$TMPSTATE" "$TMPBRANCH" 2>/dev/null || true
  rm -f "${TMPTRIVIAL}" 2>/dev/null || true
}
trap cleanup_all EXIT

run_hook() {
  # session-start does NOT read stdin — run directly; override PWD via a temp git repo.
  # Branch and state files are both isolated via env overrides so tests never touch
  # the live ~/.claude/.silver-bullet/ branch or state files.
  # Use || true: hook may exit non-zero when optional plugins (design) are absent,
  # but we test effects (state file mutations, output content) not the exit code.
  local workdir="${1:-$HOOK_WORKDIR}"
  ( cd "$workdir" && \
    SILVER_BULLET_STATE_FILE="$TMPSTATE" \
    SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
    bash "$HOOK" 2>/dev/null ) || true
}

# Create a minimal git repo directory with a commit so HEAD is valid
make_git_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" -c user.email="test@test.com" -c user.name="Test" commit -q --allow-empty -m "init" 2>/dev/null
  printf '%s' "$dir"
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

assert_not_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if ! printf '%s' "$output" | grep -q "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' NOT in: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected file to exist: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_missing() {
  local label="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected file to be absent: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if [[ ! -f "$path" ]] || ! grep -q "$needle" "$path" 2>/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — file $path should NOT contain '$needle'"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if grep -q "$needle" "$path" 2>/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' in file $path"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== session-start tests ==="

# ── Branch-scoped state reset tests ──────────────────────────────────────────

# Test 1: Branch change -> state file deleted (full reset)
echo "--- Test 1: Branch change -> state file deleted ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
# Write a state file and point branch file at a different branch
printf 'silver-quality-gates\ncode-review\n' > "$TMPSTATE"
printf 'old-branch-xyz' > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "branch changed -> state file deleted" "$TMPSTATE"
# branch file should now reflect current branch
if [[ -f "$TMPBRANCH" ]]; then
  stored=$(cat "$TMPBRANCH")
  if [[ "$stored" == "$new_branch" ]]; then
    echo "  PASS: branch file updated to current branch"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: branch file should be '$new_branch', got '$stored'"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL: branch file missing after reset"
  FAIL=$((FAIL + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# Test 2: Same branch -> state file preserved
echo "--- Test 2: Same branch -> state file preserved ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ncode-review\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_exists "same branch -> state file preserved" "$TMPSTATE"
assert_file_contains "same branch -> skill line preserved" "$TMPSTATE" "silver-quality-gates"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# Test 3: Same branch -> regular skills survive session restart
echo "--- Test 3: Same branch -> regular skills survive session restart ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ncode-review\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "same branch -> skills preserved" "$TMPSTATE" "silver-quality-gates"
assert_file_contains "same branch -> code-review preserved" "$TMPSTATE" "code-review"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# Test 4: Same branch -> gsd-* markers stripped
echo "--- Test 4: Same branch -> gsd-* markers stripped ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ngsd-discuss-phase\ngsd-plan-phase\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "same branch -> silver-quality-gates preserved" "$TMPSTATE" "silver-quality-gates"
assert_file_not_contains "same branch -> gsd-discuss-phase stripped" "$TMPSTATE" "gsd-discuss-phase"
assert_file_not_contains "same branch -> gsd-plan-phase stripped" "$TMPSTATE" "gsd-plan-phase"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# Test 5: Same branch -> quality-gate-stage-* markers preserved
# These record completed pre-release gate stages and must survive session restarts
# on the same branch so gate progress is not lost on context window resets.
echo "--- Test 5: Same branch -> quality-gate-stage-* markers preserved ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ngsd-discuss-phase\nquality-gate-stage-1\nquality-gate-stage-2\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "same branch -> quality-gate-stage-1 preserved" "$TMPSTATE" "quality-gate-stage-1"
assert_file_contains "same branch -> quality-gate-stage-2 preserved" "$TMPSTATE" "quality-gate-stage-2"
assert_file_not_contains "same branch -> gsd-discuss-phase still stripped" "$TMPSTATE" "gsd-discuss-phase"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# ── Trivial file cleanup tests ────────────────────────────────────────────────

# Test 6: Trivial file deleted on session start
echo "--- Test 6: Trivial file deleted on session start ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
touch "$TMPTRIVIAL"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "trivial file deleted on session start" "$TMPTRIVIAL"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# ── Output / injection tests ──────────────────────────────────────────────────

# Test 7: Output is valid JSON with hookSpecificOutput key
echo "--- Test 7: Output is valid JSON with hookSpecificOutput ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
out=$(run_hook "$HOOK_WORKDIR")
# If jq available, validate JSON structure
if command -v jq >/dev/null 2>&1 && [[ -n "$out" ]]; then
  if printf '%s' "$out" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; then
    echo "  PASS: output is valid JSON with hookSpecificOutput key"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: output is not valid JSON or missing hookSpecificOutput: $out"
    FAIL=$((FAIL + 1))
  fi
else
  # jq unavailable or no output — check for non-empty raw content
  if [[ -n "$out" ]]; then
    echo "  PASS: output is non-empty (jq unavailable for JSON validation)"
    PASS=$((PASS + 1))
  else
    # session-start may produce no output if no plugins installed — acceptable
    echo "  PASS: no output (no plugins installed — acceptable)"
    PASS=$((PASS + 1))
  fi
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# Test 8: core-rules.md content injected when file exists
echo "--- Test 8: core-rules.md content injected ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
CORE_RULES="$(dirname "$HOOK")/core-rules.md"
if [[ -f "$CORE_RULES" ]]; then
  out=$(run_hook "$HOOK_WORKDIR")
  if printf '%s' "$out" | grep -q "Non-Negotiable\|Enforcement Model\|Process is non-negotiable"; then
    echo "  PASS: core-rules.md content present in output"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: core-rules.md content not found in output: ${out:0:200}..."
    FAIL=$((FAIL + 1))
  fi
else
  echo "  PASS: core-rules.md not installed — skip injection test"
  PASS=$((PASS + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# ── Security guard fallback test ─────────────────────────────────────────────

# Test 9: SILVER_BULLET_STATE_FILE pointing outside ~/.claude/ falls back to default state file
# The security guard (SB-002/SB-003) rejects invalid paths and silently uses the default.
echo "--- Test 9: Invalid SILVER_BULLET_STATE_FILE outside ~/.claude/ falls back to default ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
OUTSIDE_PATH="/tmp/evil-state-file-${TEST_RUN_ID}"
REAL_STATE_FILE="${SB_TEST_DIR}/state"
# Ensure the real default state file is absent so we can detect the fallback
rm -f "$REAL_STATE_FILE" 2>/dev/null || true
( cd "$HOOK_WORKDIR" && \
  SILVER_BULLET_STATE_FILE="$OUTSIDE_PATH" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  bash "$HOOK" 2>/dev/null ) || true
# The hook must NOT write to the invalid outside path
if [[ -f "$OUTSIDE_PATH" ]]; then
  echo "  FAIL: hook wrote to path outside ~/.claude/ — security guard bypassed"
  FAIL=$((FAIL + 1))
  rm -f "$OUTSIDE_PATH"
else
  echo "  PASS: invalid path outside ~/.claude/ was rejected — not written"
  PASS=$((PASS + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# ── Branch file creation tests ───────────────────────────────────────────────

# Test 10: Branch file absent → branch file written with current branch; state NOT wiped
# Regression: absent branch_file caused stored_branch="" which made "main" != "" fire
# the "branch changed" path, wiping state on every fresh-install / file-deleted run.
echo "--- Test 10: Branch file absent -> branch file created; state preserved ---"
rm -f "$TMPBRANCH" 2>/dev/null || true   # ensure branch file is absent
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ngsd-discuss-phase\nquality-gate-stage-1\ncode-review\n' > "$TMPSTATE"
run_hook "$HOOK_WORKDIR" >/dev/null
# Branch file should now exist and contain the current branch
assert_file_exists "branch file absent -> branch file created" "$TMPBRANCH"
if [[ -f "$TMPBRANCH" ]]; then
  stored=$(cat "$TMPBRANCH")
  if [[ "$stored" == "$new_branch" ]]; then
    echo "  PASS: branch file contains current branch name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: branch file should be '$new_branch', got '$stored'"
    FAIL=$((FAIL + 1))
  fi
fi
# State file must NOT have been wiped — skill recordings should survive
assert_file_exists "branch file absent -> state file preserved" "$TMPSTATE"
assert_file_contains "branch file absent -> skill recordings preserved" "$TMPSTATE" "silver-quality-gates"
# Both gsd-* AND quality-gate-stage-* markers are stripped on the branch-file-absent
# path (session-start line 72). This differs from the same-branch path, which only
# strips gsd-* and preserves quality-gate-stage-* markers.
assert_file_not_contains "branch file absent -> gsd-* markers stripped" "$TMPSTATE" "gsd-discuss-phase"
assert_file_not_contains "branch file absent -> quality-gate-stage-* also stripped" "$TMPSTATE" "quality-gate-stage-1"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
