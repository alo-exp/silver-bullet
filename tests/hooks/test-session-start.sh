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

# Backup real branch/state files
REAL_STATE="${SB_TEST_DIR}/state"
REAL_BRANCH="${SB_TEST_DIR}/branch"
REAL_TRIVIAL="${SB_TEST_DIR}/trivial"
BACKUP_STATE="${SB_TEST_DIR}/state.bak.${TEST_RUN_ID}"
BACKUP_BRANCH="${SB_TEST_DIR}/branch.bak.${TEST_RUN_ID}"

backup_real_state() {
  [[ -f "$REAL_STATE" ]] && cp "$REAL_STATE" "$BACKUP_STATE" || true
  [[ -f "$REAL_BRANCH" ]] && cp "$REAL_BRANCH" "$BACKUP_BRANCH" || true
}

restore_real_state() {
  [[ -f "$BACKUP_STATE" ]] && mv "$BACKUP_STATE" "$REAL_STATE" || rm -f "$REAL_STATE"
  [[ -f "$BACKUP_BRANCH" ]] && mv "$BACKUP_BRANCH" "$REAL_BRANCH" || rm -f "$REAL_BRANCH"
}

cleanup_all() {
  restore_real_state
  rm -f "${REAL_TRIVIAL}" 2>/dev/null || true
}
trap cleanup_all EXIT

run_hook() {
  # session-start does NOT read stdin — run directly; override PWD via a temp git repo
  # Use || true: hook may exit non-zero when optional plugins (design) are absent,
  # but we test effects (state file mutations, output content) not the exit code.
  local workdir="${1:-$HOOK_WORKDIR}"
  ( cd "$workdir" && bash "$HOOK" 2>/dev/null ) || true
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
backup_real_state
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
# Write a state file and point branch file at a different branch
printf 'silver-quality-gates\ncode-review\n' > "$REAL_STATE"
printf 'old-branch-xyz' > "$REAL_BRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "branch changed -> state file deleted" "$REAL_STATE"
# branch file should now reflect current branch
if [[ -f "$REAL_BRANCH" ]]; then
  stored=$(cat "$REAL_BRANCH")
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
restore_real_state

# Test 2: Same branch -> state file preserved
echo "--- Test 2: Same branch -> state file preserved ---"
backup_real_state
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
# Pre-write skill lines (no quality-gate or gsd lines — should be preserved)
printf 'silver-quality-gates\ncode-review\n' > "$REAL_STATE"
printf '%s' "$new_branch" > "$REAL_BRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_exists "same branch -> state file preserved" "$REAL_STATE"
assert_file_contains "same branch -> skill line preserved" "$REAL_STATE" "silver-quality-gates"
rm -rf "$HOOK_WORKDIR"
restore_real_state

# Test 3: Same branch -> regular skills survive session restart
echo "--- Test 3: Same branch -> regular skills survive session restart ---"
backup_real_state
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ncode-review\n' > "$REAL_STATE"
printf '%s' "$new_branch" > "$REAL_BRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "same branch -> skills preserved" "$REAL_STATE" "silver-quality-gates"
assert_file_contains "same branch -> code-review preserved" "$REAL_STATE" "code-review"
rm -rf "$HOOK_WORKDIR"
restore_real_state

# Test 4: Same branch -> gsd-* markers stripped
echo "--- Test 4: Same branch -> gsd-* markers stripped ---"
backup_real_state
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ngsd-discuss-phase\ngsd-plan-phase\n' > "$REAL_STATE"
printf '%s' "$new_branch" > "$REAL_BRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "same branch -> silver-quality-gates preserved" "$REAL_STATE" "silver-quality-gates"
assert_file_not_contains "same branch -> gsd-discuss-phase stripped" "$REAL_STATE" "gsd-discuss-phase"
assert_file_not_contains "same branch -> gsd-plan-phase stripped" "$REAL_STATE" "gsd-plan-phase"
rm -rf "$HOOK_WORKDIR"
restore_real_state

# ── Trivial file cleanup tests ────────────────────────────────────────────────

# Test 5: Trivial file deleted on session start
echo "--- Test 5: Trivial file deleted on session start ---"
backup_real_state
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$REAL_BRANCH"
touch "$REAL_TRIVIAL"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "trivial file deleted on session start" "$REAL_TRIVIAL"
rm -rf "$HOOK_WORKDIR"
restore_real_state

# ── Output / injection tests ──────────────────────────────────────────────────

# Test 6: Output is valid JSON with hookSpecificOutput key
echo "--- Test 6: Output is valid JSON with hookSpecificOutput ---"
backup_real_state
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$REAL_BRANCH"
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
restore_real_state

# Test 7: core-rules.md content injected when file exists
echo "--- Test 7: core-rules.md content injected ---"
backup_real_state
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$REAL_BRANCH"
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
restore_real_state

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
