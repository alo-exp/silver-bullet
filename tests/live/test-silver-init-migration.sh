#!/usr/bin/env bash
# Live tests for silver:init Step 3.5.5 documentation migration
# Tests that silver:init correctly detects, proposes, and handles migration of existing docs.
#
# Design note: These tests invoke /silver:init in isolated temp projects.
# Prompts are direct and specific — asking Claude to perform just the migration
# step rather than full silver:init (which triggers many enforcement hooks).
# This focuses coverage on the migration logic itself.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Migration step logic is tested by injecting the Step 3.5.5 instructions inline
# rather than loading the full silver:init skill via --plugin-dir (too expensive).
# This is the correct approach: we test the migration LOGIC, not skill discovery.
MIGRATION_STEP="$(sed -n '/#### 3\.5\.5/,/#### 3\.6/p' "${SCRIPT_DIR}/../../skills/silver-init/SKILL.md" | head -100)"

# Lightweight invoker: no plugin loaded, migration instructions injected inline.
# Much cheaper than invoke_claude_permissive with --plugin-dir.
invoke_migration() {
  local context="$1"
  local prompt="$2"
  local output
  # Run from a bare temp dir (not WORK_DIR) to avoid loading the SB plugin
  # via .silver-bullet.json, which would make each call exceed the budget.
  local bare_dir
  bare_dir=$(mktemp -d)
  output=$(cd "$bare_dir" && "$CLAUDE_BIN" -p \
    "CONTEXT: ${context}

MIGRATION INSTRUCTIONS (Step 3.5.5 of silver:init):
${MIGRATION_STEP}

TASK: ${prompt}" \
    --output-format text \
    --model claude-haiku-4-5-20251001 \
    --max-budget-usd 1.00 \
    --dangerously-skip-permissions \
    --verbose 2>&1) || true
  rm -rf "$bare_dir"
  printf '%s' "$output"
}

echo "=== Live: silver:init Documentation Migration Tests ==="

# ── S1: No docs directory — migration step skipped ───────────────────────────
echo "--- S1: No docs directory — migration skipped ---"
response=$(invoke_migration "Project root: /tmp/test-proj-s1. No docs/ directory exists in the project." \
  "Check whether a docs/ directory exists. If it does not exist, state that the migration step is not needed.")
assert_response_contains "S1: states no migration needed" "$response" "no.*doc|not.*exist|skip|migration.*not needed|no.*migrat|docs.*not found|no docs"

# ── S2: docs/ with only unrecognized files — no migration candidates ──────────
echo "--- S2: docs/ with unrecognized files — no migration candidates ---"
response=$(invoke_migration \
  "The docs/ directory has been scanned. The only file found is: notes.txt. This filename does not match any known SB documentation naming convention (architecture, testing, knowledge, changelog, CI/CD, PRD, API, security)." \
  "Based on the scan above, state whether any migration candidates were found and what action to take.")
assert_response_contains "S2: reports no recognizable migration candidates" "$response" "no.*candidate|no.*recogni|no.*match|none.*found|not.*recogni|notes\.txt.*not|skip|nothing|no.*file"

# ── S3: Architecture doc detected — migration plan presented ──────────────────
echo "--- S3: Architecture doc detected — migration plan proposed ---"
response=$(invoke_migration "Project root: /tmp/test-proj-s3. docs/ contains: Architecture-and-Design.md" \
  "Run Step A and Step B: detect Architecture-and-Design.md as a migration candidate and describe the migration plan (what SB scheme target it maps to). Do not move any files.")
assert_response_contains "S3: detects Architecture-and-Design.md" "$response" "Architecture.*Design|Architecture-and-Design"
assert_response_contains "S3: proposes a migration action" "$response" "migrat|rename|move|DESIGN\.md|knowledge"

# ── S4: Skip migration — no files modified, no backups created ───────────────
echo "--- S4: Skip migration (option C) — no files modified ---"
S4_DIR=$(mktemp -d)
mkdir -p "$S4_DIR/docs"
printf '# Architecture and Design\n\nThis document describes the system architecture.\n' \
  > "$S4_DIR/docs/Architecture-and-Design.md"
response=$(invoke_migration "Project root: $S4_DIR. docs/ contains: Architecture-and-Design.md. The user has chosen option C (skip entire migration)." \
  "The user has chosen to skip the migration. Do not move, rename, copy, or create any files. Confirm the migration is skipped.")
assert_response_contains "S4: confirms skip" "$response" "skip|skipp|no.*migrat|not.*migrat|left.*unchanged|unchanged|no.*chang"
backup_count=$(find "$S4_DIR/docs" -name "*.pre-sb-backup" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$backup_count" -eq 0 ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: S4: no .pre-sb-backup files created when migration skipped\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: S4: .pre-sb-backup files found unexpectedly (%s)\n' "$backup_count"
fi
rm -rf "$S4_DIR"

# ── S5: Migration approved — backup created before rename ────────────────────
echo "--- S5: Migration approved — .pre-sb-backup file created ---"
S5_DIR=$(mktemp -d)
mkdir -p "$S5_DIR/docs"
printf '# Architecture and Design\n\nThis is the architecture document.\n\n## Overview\n\nKey decisions made during initial design.\n' \
  > "$S5_DIR/docs/Architecture-and-Design.md"
response=$(invoke_migration "Project root: $S5_DIR. docs/ contains: Architecture-and-Design.md. The user has approved the migration." \
  "Execute Step D for $S5_DIR/docs/Architecture-and-Design.md: first copy it to $S5_DIR/docs/Architecture-and-Design.md.pre-sb-backup using the Bash tool, then rename $S5_DIR/docs/Architecture-and-Design.md to $S5_DIR/docs/DESIGN.md using the Bash tool. Confirm when done.")
backup_exists=$(find "$S5_DIR/docs" -name "*.pre-sb-backup" 2>/dev/null | head -1 || true)
if [[ -n "$backup_exists" ]]; then
  PASS=$((PASS + 1))
  printf 'PASS: S5: .pre-sb-backup file created before migration\n'
else
  FAIL=$((FAIL + 1))
  printf 'FAIL: S5: no .pre-sb-backup file found after approved migration\n'
  printf '  docs/ contents: %s\n' "$(find "$S5_DIR/docs" -type f 2>/dev/null | tr '\n' ' ')"
fi
# Verify backup content matches original
if [[ -n "$backup_exists" ]]; then
  orig_content=$(cat "$backup_exists" 2>/dev/null || true)
  if printf '%s' "$orig_content" | grep -q "Architecture and Design"; then
    PASS=$((PASS + 1))
    printf 'PASS: S5: backup file preserves original content\n'
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: S5: backup file content does not match original\n'
  fi
fi
rm -rf "$S5_DIR"

print_results
