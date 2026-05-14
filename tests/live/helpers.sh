#!/usr/bin/env bash
# Shared helpers for live AI E2E tests
# These tests invoke real claude CLI with stored credentials.
# Each invocation costs ~$0.01-0.05.

set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_TEST_TODO_APP_ROOT="$(cd "${SB_ROOT}/../.." && pwd)/test-todo-app"
MAX_BUDGET="1.00"
PASS=0
FAIL=0
TEST_RUN_ID="$$"
LIVE_RUNTIME="${SB_LIVE_RUNTIME:-claude}"

RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/runtimes" && pwd)"
case "$LIVE_RUNTIME" in
  claude)
    # shellcheck source=tests/live/runtimes/claude.sh
    source "$RUNTIME_DIR/claude.sh"
    ;;
  codex)
    # shellcheck source=tests/live/runtimes/codex.sh
    source "$RUNTIME_DIR/codex.sh"
    ;;
  *)
    printf 'ERROR: unsupported live runtime: %s\n' "$LIVE_RUNTIME" >&2
    exit 2
    ;;
esac

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
  runtime_preflight
  # Reset per-scenario Claude session state so fresh workspaces do not
  # accidentally inherit `--continue` from a previous live setup.
  CLAUDE_PROMPT_COUNT=0
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
  cat > "$WORK_DIR/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  touch "$WORK_DIR/.gitkeep"
  git -C "$WORK_DIR" add .gitkeep
  git -C "$WORK_DIR" commit -q -m "init"
  git -C "$WORK_DIR" checkout -q -b feature/live-test

  # Copy todo-app src into workspace from the sibling fixture repo when available.
  if [[ -d "${SB_TEST_TODO_APP_ROOT:-${DEFAULT_TEST_TODO_APP_ROOT}}/src" ]]; then
    cp -r "${SB_TEST_TODO_APP_ROOT:-${DEFAULT_TEST_TODO_APP_ROOT}}/src" "${WORK_DIR}/src"
  else
    mkdir -p "${WORK_DIR}/src"
    echo "// placeholder" > "${WORK_DIR}/src/index.js"
  fi

  # Write .silver-bullet.json pointing to REAL state paths
  cat > "${WORK_DIR}/.silver-bullet.json" << EOJSON
{
  "project": {"name":"live-test","src_pattern":"/src/","src_exclude_pattern":"__tests__|\\\\.test\\\\.","active_workflow":"full-dev-cycle"},
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","gsd-code-review","requesting-code-review","receiving-code-review","finishing-a-development-branch","silver-create-release","verification-before-completion","test-driven-development","verify-tests"],
    "all_tracked": ["silver-quality-gates","silver-init","silver-ingest","silver-scan","silver-research","silver-blast-radius","silver-spec","silver-add","silver-feature","silver-ui","silver-fast","silver-forensics","silver-bugfix","silver-validate","silver-create-release","silver-release","silver-update","silver-remove","silver-rem","silver-ensure-docs","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","verification-before-completion","test-driven-development","tech-debt","gsd-discuss-phase","gsd-plan-phase","gsd-execute-phase","gsd-verify-work","gsd-ui-phase","gsd-ui-review"]
  },
  "state": {"state_file":"${REAL_STATE}","trivial_file":"${REAL_TRIVIAL}"}
}
EOJSON

  # Commit the config
  git -C "$WORK_DIR" add -A
  git -C "$WORK_DIR" commit -q -m "setup"

  if [[ "$LIVE_RUNTIME" == "codex" && "${SB_LIVE_CODEX_GUARD:-0}" == "1" ]]; then
    cat > "$WORK_DIR/AGENTS.md" <<'EOF'
# Silver Bullet Live Test Override

This workspace is governed by Silver Bullet. Before any direct file edit, inspect
`.silver-bullet.json` and the current state file.

If the planning state does not yet include the required planning skill(s), refuse
the edit and say that planning is incomplete or blocked.

If the planning state shows the required planning skill(s) have been recorded for
the scenario, proceed with the requested edit normally.

Do not guess about the state. Do not edit first and check later.
EOF
    cat > "$WORK_DIR/AGENTS.override.md" <<'EOF'
# Silver Bullet Live Test Override

This workspace is governed by Silver Bullet. Before any direct file edit, inspect
`.silver-bullet.json` and the current state file.

If the planning state does not yet include the required planning skill(s), refuse
the edit and say that planning is incomplete or blocked.

If the planning state shows the required planning skill(s) have been recorded for
the scenario, proceed with the requested edit normally.

Do not guess about the state. Do not edit first and check later.
EOF
  fi
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
  runtime_invoke default "$prompt"
}

# invoke_claude_permissive: bypasses file-read permission prompts.
# Use this for skill-invocation tests where the skill reads files (silver-quality-gates, etc.)
# but hook deny decisions (permissionDecision:deny) are also bypassed — do NOT use
# for enforcement tests.
invoke_claude_permissive() {
  local prompt="$1"
  runtime_invoke permissive "$prompt"
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

capture_mtime() {
  stat -f "%m" "$1" 2>/dev/null || stat --format="%Y" "$1" 2>/dev/null || echo "0"
}

capture_digest() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || sha256sum "$1" 2>/dev/null | awk '{print $1}' || echo ""
}

assert_file_contains() {
  local label="$1" filepath="$2" needle="$3"
  if grep -qiE "$needle" "$filepath" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (expected pattern "%s" in %s)\n' "$label" "$needle" "$filepath"
    printf '  File snippet: %s\n' "$(head -c 400 "$filepath" 2>/dev/null || echo '(file not found)')"
  fi
}

assert_file_not_contains() {
  local label="$1" filepath="$2" needle="$3"
  if ! grep -qiE "$needle" "$filepath" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (unexpected pattern "%s" found in %s)\n' "$label" "$needle" "$filepath"
    printf '  File snippet: %s\n' "$(head -c 400 "$filepath" 2>/dev/null)"
  fi
}

assert_file_modified() {
  local label="$1" filepath="$2" mtime_before="$3"
  local mtime_after
  mtime_after=$(capture_mtime "$filepath")
  if [[ "$mtime_after" -gt "$mtime_before" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (file mtime not updated: before=%s after=%s)\n' "$label" "$mtime_before" "$mtime_after"
  fi
}

assert_file_not_modified() {
  local label="$1" filepath="$2" digest_before="$3"
  local digest_after
  digest_after=$(capture_digest "$filepath")
  if [[ -n "$digest_before" ]] && [[ "$digest_after" == "$digest_before" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  (file contents changed unexpectedly)\n' "$label"
  fi
}

seed_state() {
  # Write given skill names (one per line) to the real state file
  mkdir -p "$(dirname "$REAL_STATE")"
  : > "$REAL_STATE"
  for skill in "$@"; do
    printf '%s\n' "$skill" >> "$REAL_STATE"
  done
}
