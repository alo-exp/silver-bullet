#!/usr/bin/env bash
set -euo pipefail
FORGE_HOME="${FORGE_HOME:-$HOME/forge}"
PASS=0; FAIL=0

check() {
  local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "✅ $desc"; ((PASS++))
  else echo "❌ $desc"; ((FAIL++)); fi
}

# === SKILLS EXIST ===
for skill in silver silver-feature silver-bugfix silver-ui silver-devops silver-research \
             quality-gates modularity reusability scalability security reliability \
             usability testability extensibility ai-llm-safety \
             tdd brainstorming writing-plans requesting-code-review receiving-code-review finishing-branch \
             gsd-discuss gsd-plan gsd-execute gsd-verify gsd-ship gsd-review \
             gsd-review-fix gsd-secure gsd-validate gsd-intel gsd-progress gsd-brainstorm; do
  check "Skill exists: $skill" "[ -f 'forge/skills/$skill/SKILL.md' ]"
done

# === VALID YAML FRONTMATTER ===
for skill_md in forge/skills/*/SKILL.md; do
  sname=$(basename "$(dirname "$skill_md")")
  check "$sname: has YAML frontmatter" "grep -q '^---$' '$skill_md'"
  check "$sname: has trigger field" "grep -q '^trigger' '$skill_md'"
  check "$sname: has id field" "grep -q '^id:' '$skill_md'"
done

# === NO FORBIDDEN TOOL NAMES ===
for skill_md in forge/skills/*/SKILL.md; do
  sname=$(basename "$(dirname "$skill_md")")
  check "$sname: no Claude Code tool names" \
    "! grep -qE 'TodoWrite|AskUserQuestion|NotebookEdit' '$skill_md'"
done

# === AGENTS.MD TEMPLATES ===
check "Global AGENTS.md template exists" "[ -f 'forge/AGENTS.md.template' ]"
check "Project AGENTS.md template exists" "[ -f 'forge/AGENTS.project.template' ]"
check "AGENTS.md.template has 'On Session Start'" "grep -q 'On Session Start' forge/AGENTS.md.template"
check "AGENTS.md.template has 'Quality Gate Triggers'" "grep -q 'Quality Gate Triggers' forge/AGENTS.md.template"
check "AGENTS.md.template has 'TDD'" "grep -q 'TDD' forge/AGENTS.md.template"

# === INSTALLER ===
check "forge-sb-install.sh exists" "[ -f 'forge-sb-install.sh' ]"
check "forge-sb-install.sh is executable" "[ -x 'forge-sb-install.sh' ]"
check "forge-sb-install.sh has --dry-run" "grep -q 'dry.run' forge-sb-install.sh"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "✅ All smoke tests passed!" || { echo "❌ $FAIL tests failed"; exit 1; }
