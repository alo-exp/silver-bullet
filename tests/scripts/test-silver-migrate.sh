#!/usr/bin/env bash
# Verify sb:migrate skill documents the full upgrade path to current SB.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/silver-migrate/SKILL.md"
PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qE "$needle" "$file"; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if ! grep -qE "$needle" "$file"; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — unexpected [$needle] in $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" file="$2"
  if [[ -f "$file" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing file $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists "silver-migrate skill exists" "$SKILL"

# Legacy migrations (existing contract)
assert_contains "documents lessons to learnings migration" "docs/lessons/" "$SKILL"
assert_contains "documents per-instance workflow tracking" "SB_WORKFLOWS_BIN.*start" "$SKILL"
assert_contains "retires WORKFLOW.md" "Do not create.*WORKFLOW\\.md" "$SKILL"

# v0.40.0 upgrade surface
assert_contains "documents silver-bullet.md template refresh" "silver-bullet\\.md\\.base" "$SKILL"
assert_contains "documents config_version merge" "config_version" "$SKILL"
assert_contains "documents sb-migrate-config script" "sb-migrate-config" "$SKILL"
assert_contains "documents sb-migrate-project surface script" "sb-migrate-project" "$SKILL"
assert_contains "documents silver-bullet.config.json.default" "silver-bullet\\.config\\.json\\.default" "$SKILL"
assert_contains "documents orchestrator parent mode" "orchestrator_mode" "$SKILL"
assert_contains "documents required_release merge" "required_release" "$SKILL"
assert_contains "documents workflows.sh install" "scripts/workflows\\.sh" "$SKILL"
assert_contains "documents gitignore workflows entry" "planning/workflows/" "$SKILL"
assert_contains "documents instruction file reconciliation" "CLAUDE\\.md|AGENTS\\.md" "$SKILL"
assert_contains "documents RUNTIME-COMPATIBILITY pointers" "RUNTIME-COMPATIBILITY" "$SKILL"
assert_contains "documents merge-hooks for all hosts" "merge-hooks\\.py" "$SKILL"
assert_contains "documents merge-cursor-hooks for Cursor" "merge-cursor-hooks" "$SKILL"
assert_contains "documents sb-diagnostics probe" "sb-diagnostics" "$SKILL"
assert_contains "documents sb-bootstrap probe" "sb-bootstrap" "$SKILL"
assert_contains "documents evidence-schema awareness" "evidence-schema" "$SKILL"
assert_contains "documents doc-scheme refresh via ensure-docs" "sb:ensure-docs" "$SKILL"
assert_contains "documents interface STATE for UI projects" "interface/STATE\\.md" "$SKILL"
assert_contains "documents stamp-interface-state script" "stamp-interface-state" "$SKILL"

# SB-native artifact layout (F-02)
assert_contains "inference includes SB phases/*/PLAN.md" "phases/\\*/PLAN\\.md" "$SKILL"
assert_contains "inference includes SB phases/*/VERIFICATION.md" "phases/\\*/VERIFICATION\\.md" "$SKILL"

# Host-neutral canonical skill (no agent leaks)
assert_not_contains "canonical migrate skill has no AskUserQuestion" "AskUserQuestion" "$SKILL"
assert_not_contains "canonical migrate skill has no Skill tool literal" "Skill tool" "$SKILL"
assert_not_contains "canonical migrate skill has no Claude plugin root" '\\$\\{CLAUDE_PLUGIN_ROOT\\}' "$SKILL"

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
