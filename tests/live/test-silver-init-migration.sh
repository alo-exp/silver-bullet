#!/usr/bin/env bash
# Live tests for sb:init Step 3.5.5 docs bootstrap delegation
# Tests that sb:init delegates docs bootstrap/reconciliation to sb:ensure-docs.
#
# Design note: These tests invoke /sb:init in isolated temp projects.
# Prompts are direct and specific — asking Claude to perform just the migration
# step rather than full sb:init (which triggers many enforcement hooks).
# This focuses coverage on the migration logic itself.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Bootstrap step logic is tested by injecting Step 3.5.5/3.6 instructions inline
# rather than loading the full sb:init skill via --plugin-dir (too expensive).
MIGRATION_STEP="$(sed -n '/### 3\.5\.5/,/### 3\.6/p' "${SCRIPT_DIR}/../../skills/silver-init/references/scaffold-steps.md" | head -120)"

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
  output=$(cd "$bare_dir" && WORK_DIR="$bare_dir" invoke_claude_permissive \
    "CONTEXT: ${context}

MIGRATION INSTRUCTIONS (Step 3.5.5 of sb:init):
${MIGRATION_STEP}

TASK: ${prompt}" \
    2>&1) || true
  rm -rf "$bare_dir"
  printf '%s' "$output"
}

echo "=== Live: sb:init Docs Bootstrap Delegation Tests ==="

# ── S1: Delegation signal is explicit ─────────────────────────────────────────
echo "--- S1: Step 3.5.5 explicitly delegates to sb:ensure-docs ---"
response=$(invoke_migration "Project root: /tmp/test-proj-s1. No docs/ directory exists in the project." \
  "Explain what Step 3.5.5 does and which skill it invokes.")
assert_response_contains "S1: mentions sb:ensure-docs" "$response" "sb:ensure-docs|ensure-docs"

# ── S2: Greenfield behavior summary ───────────────────────────────────────────
echo "--- S2: greenfield bootstrap behavior ---"
response=$(invoke_migration \
  "The repo is greenfield with no existing docs and sb:init just reached Step 3.5.5." \
  "State what docs bootstrap action should happen now.")
assert_response_contains "S2: mentions skeleton or scaffold creation" "$response" "skeleton|scaffold|bootstrap|doc-scheme\\.json|task-doc-checklist"

# ── S3: Brownfield behavior summary ───────────────────────────────────────────
echo "--- S3: brownfield preserve vs switch behavior ---"
response=$(invoke_migration "Project root: /tmp/test-proj-s3. docs/ contains Architecture-and-Design.md and custom runbooks." \
  "Describe how Step 3.5.5 handles preserve-vs-switch decisions for existing docs.")
assert_response_contains "S3: mentions preserve vs switch decision" "$response" "preserve|switch"
assert_response_contains "S3: mentions archive move on switch" "$response" "docs/archive|move"

# ── S4: Recovery path is explicit ─────────────────────────────────────────────
echo "--- S4: recovery path mentions --recover-scheme ---"
response=$(invoke_migration "Project root: /tmp/test-proj-s4. docs/doc-scheme.json is missing." \
  "What command should be used to recover the docs scheme contract?")
assert_response_contains "S4: mentions recover command" "$response" "recover-scheme|sb:ensure-docs"

# ── S5: Hook remediation route is explicit ────────────────────────────────────
echo "--- S5: from-hook remediation path ---"
response=$(invoke_migration "Project root: /tmp/test-proj-s5. stop-check produced a docs gap report path and task id." \
  "Describe which ensure-docs mode should be used to remediate hook gaps.")
assert_response_contains "S5: mentions hook-gap remediation mode" "$response" "from-hook|hook-gap|remediation|gaps|task|zero-miss|sb:ensure-docs"

print_results
