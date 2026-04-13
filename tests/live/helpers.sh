#!/usr/bin/env bash
# Shared helpers for live AI E2E tests
# These tests invoke real claude CLI with stored credentials.
# Each invocation costs ~$0.01-0.05.

set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_BIN="/Users/shafqat/.local/bin/claude"
MAX_BUDGET="1.00"
PASS=0
FAIL=0
TEST_RUN_ID="$$"

# The REAL state path that hooks always write to (Claude does not pass
# SILVER_BULLET_STATE_FILE env var to hook subprocesses, so hooks always use
# the default path regardless of env var override).
REAL_STATE="${HOME}/.claude/.silver-bullet/state"
REAL_STATE_BACKUP="${HOME}/.claude/.silver-bullet/state.live-test-backup-${TEST_RUN_ID}"
REAL_TRIVIAL="${HOME}/.claude/.silver-bullet/trivial"
REAL_TRIVIAL_BACKUP="${HOME}/.claude/.silver-bullet/trivial.live-test-backup-${TEST_RUN_ID}"

# Paths set by live_setup (kept for compatibility but assertions use REAL_STATE)
WORK_DIR=""
TMPSTATE=""
TMPTRIVIAL=""

live_setup() {
  WORK_DIR=$(mktemp -d)
  # TMPSTATE points to REAL_STATE so assert_state_* helpers work correctly
  TMPSTATE="$REAL_STATE"
  TMPTRIVIAL="$REAL_TRIVIAL"

  # Backup and clear the real state file so each test starts clean
  mkdir -p "${HOME}/.claude/.silver-bullet"
  if [[ -f "$REAL_STATE" ]]; then
    cp "$REAL_STATE" "$REAL_STATE_BACKUP"
  fi
  : > "$REAL_STATE"

  if [[ -f "$REAL_TRIVIAL" ]]; then
    cp "$REAL_TRIVIAL" "$REAL_TRIVIAL_BACKUP"
    rm -f "$REAL_TRIVIAL"
  fi

  # Initialize git repo in workspace
  git -C "$WORK_DIR" init -q
  git -C "$WORK_DIR" config user.email "live-test@silver-bullet.test"
  git -C "$WORK_DIR" config user.name "Live Test"
  touch "$WORK_DIR/.gitkeep"
  git -C "$WORK_DIR" add .gitkeep
  git -C "$WORK_DIR" commit -q -m "init"
  git -C "$WORK_DIR" checkout -q -b feature/live-test

  # Copy test-app src into workspace
  if [[ -d "${SB_ROOT}/tests/test-app/src" ]]; then
    cp -r "${SB_ROOT}/tests/test-app/src" "${WORK_DIR}/src"
  else
    mkdir -p "${WORK_DIR}/src"
    echo "// placeholder" > "${WORK_DIR}/src/index.js"
  fi

  # Write .silver-bullet.json pointing to REAL state paths
  cat > "${WORK_DIR}/.silver-bullet.json" << EOJSON
{
  "project": {"name":"live-test","src_pattern":"/src/","src_exclude_pattern":"__tests__|\\\\.test\\\\.","active_workflow":"full-dev-cycle"},
  "skills": {
    "required_planning": ["quality-gates"],
    "required_deploy": ["quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release","verification-before-completion","test-driven-development","tech-debt"],
    "all_tracked": ["quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release","verification-before-completion","test-driven-development","tech-debt"]
  },
  "state": {"state_file":"${REAL_STATE}","trivial_file":"${REAL_TRIVIAL}"}
}
EOJSON

  # Commit the config
  git -C "$WORK_DIR" add -A
  git -C "$WORK_DIR" commit -q -m "setup"
}

live_teardown() {
  rm -rf "$WORK_DIR"

  # Restore backed-up state file (or remove if it didn't exist before)
  if [[ -f "$REAL_STATE_BACKUP" ]]; then
    mv "$REAL_STATE_BACKUP" "$REAL_STATE"
  else
    rm -f "$REAL_STATE"
  fi

  if [[ -f "$REAL_TRIVIAL_BACKUP" ]]; then
    mv "$REAL_TRIVIAL_BACKUP" "$REAL_TRIVIAL"
  fi

  rm -f "${HOME}/.claude/.silver-bullet/config-cache-"*
}

# invoke_claude: default invocation — hook denials (permissionDecision:deny) are enforced.
# Use this for enforcement tests (S1, S2, S3, S4) where blocking behavior must be observed.
invoke_claude() {
  local prompt="$1"
  local output
  output=$(cd "$WORK_DIR" && "$CLAUDE_BIN" -p "$prompt" \
    --plugin-dir "$SB_ROOT" \
    --output-format text \
    --model claude-haiku-4-5-20251001 \
    --max-budget-usd "$MAX_BUDGET" \
    --verbose 2>&1) || true
  printf '%s' "$output"
}

# invoke_claude_permissive: bypasses file-read permission prompts.
# Use this for skill-invocation tests where the skill reads files (quality-gates, etc.)
# but hook deny decisions (permissionDecision:deny) are also bypassed — do NOT use
# for enforcement tests.
invoke_claude_permissive() {
  local prompt="$1"
  local output
  output=$(cd "$WORK_DIR" && "$CLAUDE_BIN" -p "$prompt" \
    --plugin-dir "$SB_ROOT" \
    --output-format text \
    --model claude-haiku-4-5-20251001 \
    --max-budget-usd "$MAX_BUDGET" \
    --dangerously-skip-permissions \
    --verbose 2>&1) || true
  printf '%s' "$output"
}

assert_response_contains() {
  local label="$1"
  local response="$2"
  local needle="$3"
  if printf '%s' "$response" | grep -iE "$needle" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (expected pattern "%s" in response)\n' "$label" "$needle"
    printf '  Response snippet: %s\n' "$(printf '%s' "$response" | head -c 400)"
  fi
}

assert_response_not_contains() {
  local label="$1"
  local response="$2"
  local needle="$3"
  if ! printf '%s' "$response" | grep -iE "$needle" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (unexpected pattern "%s" found in response)\n' "$label" "$needle"
    printf '  Response snippet: %s\n' "$(printf '%s' "$response" | head -c 400)"
  fi
}

assert_state_contains() {
  local label="$1"
  local skill_name="$2"
  if [[ -f "$TMPSTATE" ]] && grep -qx "$skill_name" "$TMPSTATE" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (skill "%s" not found in state file %s)\n' "$label" "$skill_name" "$TMPSTATE"
    if [[ -f "$TMPSTATE" ]]; then
      printf '  State contents: %s\n' "$(cat "$TMPSTATE")"
    else
      printf '  State file does not exist.\n'
    fi
  fi
}

assert_state_not_contains() {
  local label="$1"
  local skill_name="$2"
  if [[ ! -f "$TMPSTATE" ]] || ! grep -qx "$skill_name" "$TMPSTATE" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (unexpected skill "%s" found in state file)\n' "$label" "$skill_name"
  fi
}

assert_file_exists() {
  local label="$1"
  local filepath="$2"
  if [[ -e "$filepath" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (file/dir not found: %s)\n' "$label" "$filepath"
  fi
}

print_results() {
  printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
  [[ $FAIL -eq 0 ]] && exit 0 || exit 1
}

seed_state() {
  # Write given skill names (one per line) to the real state file
  mkdir -p "$(dirname "$REAL_STATE")"
  : > "$REAL_STATE"
  for skill in "$@"; do
    printf '%s\n' "$skill" >> "$REAL_STATE"
  done
}
