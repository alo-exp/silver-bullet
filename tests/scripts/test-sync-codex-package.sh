#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

assert_path_absent() {
  local desc="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — should be absent: $path"
    (( FAIL++ )) || true
  fi
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qF -- "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" path="$3"
  if rg -n --hidden -S -- "$needle" "$path" >/dev/null 2>&1; then
    echo "FAIL: $desc — found [$needle] under $path"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

assert_not_symlink() {
  local desc="$1" path="$2"
  if [[ ! -L "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — still a symlink: $path"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-codex-package.sh"
PACKAGE_ROOT="$REPO_ROOT/plugins/silver-bullet"

bash "$SCRIPT" >/dev/null

SOURCE_ASK_USER_FILES=(
  skills/silver-update/SKILL.md
  skills/silver-release/SKILL.md
  skills/silver-bugfix/SKILL.md
  skills/silver-fast/SKILL.md
  skills/silver-init/SKILL.md
  skills/silver-init/references/scaffold-steps.md
  skills/silver-init/references/doc-migration.md
  templates/silver-bullet.md.base
)

assert_file_exists "Codex manifest present" "$PACKAGE_ROOT/.codex-plugin/plugin.json"
assert_file_exists "Silver Bullet skill router available" "$PACKAGE_ROOT/skills/silver/SKILL.md"
assert_file_exists "Silver Bullet init skill available" "$PACKAGE_ROOT/skills/silver-init/SKILL.md"
assert_file_exists "Silver Bullet ensure-docs skill available" "$PACKAGE_ROOT/skills/silver-ensure-docs/SKILL.md"
assert_file_exists "Silver Bullet feature skill available" "$PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_file_exists "Silver Bullet handoff skill available" "$PACKAGE_ROOT/skills/silver-handoff/SKILL.md"
assert_file_exists "Silver Bullet scan helper available" "$PACKAGE_ROOT/scripts/silver-scan.sh"
assert_file_exists "Silver Bullet package sanitizer helper available" "$PACKAGE_ROOT/scripts/codex-sanitize-package.sh"
assert_file_exists "Silver Bullet Claude agent bundle available" "$REPO_ROOT/agents/claude/silver-scan/SKILL.md"
assert_file_exists "Silver Bullet Codex agent bundle available" "$REPO_ROOT/agents/codex/silver-scan/SKILL.md"
assert_file_exists "Silver Bullet Claude agent bundle exposed in package" "$PACKAGE_ROOT/agents/claude/silver-scan/SKILL.md"
assert_file_exists "Silver Bullet agent bundle directory exposed in package" "$PACKAGE_ROOT/agents/codex/silver-scan/SKILL.md"
assert_file_exists "Silver Bullet scan generated skill available" "$PACKAGE_ROOT/.generated-skills/silver-scan/SKILL.md"
assert_file_exists "Stamped template present" "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_not_symlink "Codex templates directory materialized" "$PACKAGE_ROOT/templates"
assert_contains "Silver router skill has silver name" "name: silver" "$PACKAGE_ROOT/skills/silver/SKILL.md"
assert_contains "Silver init skill uses silver prefix" "name: silver:init" "$PACKAGE_ROOT/skills/silver-init/SKILL.md"
assert_contains "Silver ensure-docs skill uses silver prefix" "name: silver:ensure-docs" "$PACKAGE_ROOT/skills/silver-ensure-docs/SKILL.md"
assert_contains "Silver feature skill uses silver prefix" "name: silver:feature" "$PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_contains "Silver handoff skill uses silver prefix" "name: silver:handoff" "$PACKAGE_ROOT/skills/silver-handoff/SKILL.md"
assert_contains "Silver scan Codex agent bundle uses silver prefix" "name: silver:scan" "$PACKAGE_ROOT/agents/codex/silver-scan/SKILL.md"
assert_contains "Silver scan generated skill uses silver prefix" "name: silver:scan" "$PACKAGE_ROOT/.generated-skills/silver-scan/SKILL.md"
assert_contains "Silver feature skill wires TDD into execute boundary" "gsd-execute-phase --tdd" "$PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_contains "Silver feature skill documents hidden TDD gate" "Internal TDD gate" "$PACKAGE_ROOT/skills/silver-feature/SKILL.md"
assert_contains "Silver UI skill wires TDD into execute boundary" "gsd-execute-phase --tdd" "$PACKAGE_ROOT/skills/silver-ui/SKILL.md"
assert_contains "Silver bugfix skill uses SB TDD wrapper" "Invoke \`tdd\`" "$PACKAGE_ROOT/skills/silver-bugfix/SKILL.md"
assert_contains "Silver bugfix skill executes with TDD flag" "gsd-execute-phase --tdd" "$PACKAGE_ROOT/skills/silver-bugfix/SKILL.md"
assert_not_contains "Codex package does not contain AskUserQuestion" "AskUserQuestion" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain ~/.claude paths" "~/.claude" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain /compact commands" "/compact" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain model_profile routing" 'model_profile: "balanced"' "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain auto-routing wording" "auto-select the correct model for the current host" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain manual routing wording" "Handled automatically via \`model_profile: \"balanced\"\`" "$PACKAGE_ROOT"
assert_contains "Codex package uses ~/.codex state paths" "~/.codex/.silver-bullet/state" "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_contains "Codex package uses ~/.codex plugin cache paths" '$HOME/.codex/plugins/installed_plugins.json' "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_contains "Codex package tracks gsd-scan in config" '"gsd-scan"' "$PACKAGE_ROOT/templates/silver-bullet.config.json.default"
assert_contains "TDD skill hidden from picker" "user-invocable: false" "$PACKAGE_ROOT/skills/tdd/SKILL.md"
assert_contains "TDD skill delegates to Superpowers TDD" "superpowers:test-driven-development" "$PACKAGE_ROOT/skills/tdd/SKILL.md"
assert_path_absent "Third-party plugins excluded from SB bundle" "$PACKAGE_ROOT/third-party-plugins"
assert_path_absent "Project planning tree excluded from SB bundle" "$PACKAGE_ROOT/.planning"

for rel_path in "${SOURCE_ASK_USER_FILES[@]}"; do
  assert_contains "Source retains AskUserQuestion in $rel_path" "AskUserQuestion" "$REPO_ROOT/$rel_path"
done

assert_not_contains "Codex package does not contain AskUserQuestion" "AskUserQuestion" "$PACKAGE_ROOT"

LEGACY_GSD_WRAPPERS=(
  gsd-brainstorm
  gsd-discuss
  gsd-execute
  gsd-intel
  gsd-plan
  gsd-progress
  gsd-review
  gsd-review-fix
  gsd-secure
  gsd-ship
  gsd-validate
  gsd-verify
)

for skill in "${LEGACY_GSD_WRAPPERS[@]}"; do
  assert_path_absent "Legacy GSD wrapper excluded from SB bundle: $skill" "$PACKAGE_ROOT/.generated-skills/$skill"
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
