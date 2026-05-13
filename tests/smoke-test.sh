#!/usr/bin/env bash
set -euo pipefail
FORGE_HOME="${FORGE_HOME:-$HOME/forge}"
PASS=0; FAIL=0

check() {
  local desc="$1"; local condition="$2"
  if eval "$condition"; then echo "✅ $desc"; PASS=$((PASS+1))
  else echo "❌ $desc"; FAIL=$((FAIL+1)); fi
}

# === SURFACE COUNTS ===
check "Forge skill count is current" "[ \$(find forge/skills -name SKILL.md | wc -l | tr -d ' ') -ge 109 ]"
check "Forge agent count is current" "[ \$(find forge/agents -maxdepth 1 -name '*.md' | wc -l | tr -d ' ') -ge 50 ]"
check "Forge command count is current" "[ \$(find forge/commands -maxdepth 1 -name '*.md' | wc -l | tr -d ' ') -ge 50 ]"

# === SKILLS EXIST ===
for skill in silver silver-feature silver-bugfix silver-ui silver-devops silver-research silver-clarify \
             silver-ensure-docs silver-handoff silver-quality-gates silver-blast-radius \
             modularity reusability scalability security reliability \
             usability testability extensibility ai-llm-safety \
             tdd writing-plans requesting-code-review receiving-code-review finishing-branch \
             gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-verify-work gsd-ship gsd-code-review \
             gsd-code-review-fix gsd-secure-phase gsd-validate-phase gsd-intel gsd-progress; do
  check "Skill exists: $skill" "[ -f 'forge/skills/$skill/SKILL.md' ]"
done

# === VALID YAML FRONTMATTER ===
for skill_md in forge/skills/*/SKILL.md; do
  sname=$(basename "$(dirname "$skill_md")")
  check "$sname: has YAML frontmatter" "head -1 '$skill_md' | grep -q '^---$'"
  check "$sname: has name field" "grep -q '^name:' '$skill_md'"
  check "$sname: has description field" "grep -q '^description:' '$skill_md'"
done

# === HOOK-EQUIVALENT AGENTS EXIST ===
for agent in forge-pre-commit-audit forge-pre-pr-audit forge-task-complete-check \
             forge-roadmap-freshness forge-spec-floor-check forge-uat-gate \
             forge-pr-traceability forge-ci-status-check forge-forbidden-skill-check \
             forge-session-init forge-claim-phase forge-heartbeat-phase forge-release-phase \
             forge-dependency-skill-check forge-instruction-file-guard forge-workflow-chain-guard; do
  check "Hook-equivalent agent exists: $agent" "[ -f 'forge/agents/$agent.md' ]"
done

for agent_md in forge/agents/*.md; do
  aname=$(basename "$agent_md" .md)
  check "$aname: has YAML frontmatter" "head -1 '$agent_md' | grep -q '^---$'"
  check "$aname: has id field" "grep -q '^id:' '$agent_md'"
  check "$aname: has description field" "grep -q '^description:' '$agent_md'"
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
