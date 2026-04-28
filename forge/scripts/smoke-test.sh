#!/usr/bin/env bash
# Forge SB smoke test — structural verification of installed skill/agent set.
# Run on any project after `forge-sb-install.sh` to confirm the install is intact.
#
# Usage:
#   bash forge/scripts/smoke-test.sh              # check global install
#   bash forge/scripts/smoke-test.sh --project    # also check project-local .forge/

set -uo pipefail

FORGE_HOME="${FORGE_HOME:-$HOME/forge}"
CHECK_PROJECT=false
[[ "${1:-}" == "--project" ]] && CHECK_PROJECT=true

PASS=0
FAIL=0

ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); }

echo "=== Silver Bullet for Forge — Smoke Test ==="
echo "Forge home: $FORGE_HOME"
echo ""

# 1. Global skill set
echo "[1/8] Global skill set ($FORGE_HOME/skills)"
if [[ -d "$FORGE_HOME/skills" ]]; then
  N=$(find "$FORGE_HOME/skills" -name SKILL.md | wc -l | tr -d ' ')
  if [[ "$N" -ge 100 ]]; then ok "$N skills present (≥100 expected)"; else fail "only $N skills (expected ≥100)"; fi
else
  fail "$FORGE_HOME/skills does not exist"
fi

# 2. Global agent set
echo "[2/8] Global agent set ($FORGE_HOME/agents)"
if [[ -d "$FORGE_HOME/agents" ]]; then
  N=$(find "$FORGE_HOME/agents" -name "*.md" | wc -l | tr -d ' ')
  if [[ "$N" -ge 35 ]]; then ok "$N agents present (≥35 expected)"; else fail "only $N agents (expected ≥35)"; fi
else
  fail "$FORGE_HOME/agents does not exist"
fi

# 3. Hook-equivalent agents (10 expected)
echo "[3/8] Hook-equivalent agents (forge-*)"
HOOK_AGENTS=(
  forge-pre-commit-audit forge-pre-pr-audit forge-task-complete-check
  forge-roadmap-freshness forge-spec-floor-check forge-uat-gate
  forge-pr-traceability forge-ci-status-check forge-forbidden-skill-check
  forge-session-init
)
for a in "${HOOK_AGENTS[@]}"; do
  if [[ -f "$FORGE_HOME/agents/$a.md" ]]; then ok "$a present"; else fail "$a MISSING"; fi
done

# 4. GSD subagent-equivalent agents (33 expected post-v0.31.0)
echo "[4/8] GSD subagent-equivalent agents (gsd-*)"
GSD_AGENTS=(
  gsd-roadmapper gsd-planner gsd-plan-checker gsd-phase-researcher
  gsd-pattern-mapper gsd-project-researcher gsd-research-synthesizer
  gsd-executor gsd-verifier gsd-integration-checker gsd-nyquist-auditor
  gsd-code-reviewer gsd-code-fixer gsd-security-auditor
  gsd-doc-writer gsd-doc-verifier gsd-doc-classifier gsd-doc-synthesizer
  gsd-debugger gsd-codebase-mapper
  gsd-intel-updater gsd-user-profiler gsd-eval-auditor gsd-eval-planner
  gsd-domain-researcher gsd-ai-researcher gsd-framework-selector
  gsd-ui-auditor gsd-ui-checker gsd-ui-researcher
  gsd-advisor-researcher gsd-assumptions-analyzer gsd-debug-session-manager
)
N_OK=0
for a in "${GSD_AGENTS[@]}"; do
  if [[ -f "$FORGE_HOME/agents/$a.md" ]]; then N_OK=$((N_OK+1)); fi
done
if [[ "$N_OK" -ge 33 ]]; then ok "$N_OK/33 GSD agents present"; else fail "only $N_OK/33 GSD agents present"; fi

# Superpowers code-reviewer agent (new in v0.31.0)
if [[ -f "$FORGE_HOME/agents/code-reviewer.md" ]]; then ok "code-reviewer agent present (Superpowers)"; else fail "code-reviewer agent missing"; fi

# 5. Frontmatter validity (sample check)
echo "[5/8] Skill+agent frontmatter validity (sampling)"
SAMPLE_SKILLS=(silver-feature silver-bugfix silver-quality-gates engineering-code-review)
for s in "${SAMPLE_SKILLS[@]}"; do
  f="$FORGE_HOME/skills/$s/SKILL.md"
  if [[ -f "$f" ]] && head -1 "$f" | grep -q "^---$" && grep -q "^name: " "$f" && grep -q "^description: " "$f"; then
    ok "$s frontmatter valid"
  else
    fail "$s frontmatter invalid or missing"
  fi
done
SAMPLE_AGENTS=(forge-pre-commit-audit gsd-planner gsd-roadmapper)
for a in "${SAMPLE_AGENTS[@]}"; do
  f="$FORGE_HOME/agents/$a.md"
  if [[ -f "$f" ]] && head -1 "$f" | grep -q "^---$" && grep -q "^id: " "$f" && grep -q "^description: " "$f" && grep -q "^tool_supported: true" "$f"; then
    ok "$a agent frontmatter valid (id + description + tool_supported)"
  else
    fail "$a agent frontmatter invalid or missing required fields"
  fi
done

# 6. Forge slash commands (new in v0.31.0)
echo "[6/8] Slash commands ($FORGE_HOME/commands)"
if [[ -d "$FORGE_HOME/commands" ]]; then
  N=$(find "$FORGE_HOME/commands" -name "*.md" | wc -l | tr -d ' ')
  if [[ "$N" -ge 40 ]]; then ok "$N commands present (≥40 expected)"; else fail "only $N commands (expected ≥40)"; fi
  # Spot-check critical workflow commands
  for c in gsd-new-project gsd-new-milestone gsd-execute-phase gsd-complete-milestone brainstorm; do
    if [[ -f "$FORGE_HOME/commands/${c}.md" ]]; then ok "command :${c} present"; else fail "command :${c} MISSING"; fi
  done
else
  fail "$FORGE_HOME/commands directory does not exist"
fi

# 7. SB templates (new in v0.31.0)
echo "[7/8] SB templates ($FORGE_HOME/silver-bullet/templates)"
if [[ -d "$FORGE_HOME/silver-bullet/templates" ]]; then
  for t in silver-bullet.md.base workflow.md.base silver-bullet.config.json.default; do
    if [[ -f "$FORGE_HOME/silver-bullet/templates/$t" ]]; then ok "template $t present"; else fail "template $t MISSING"; fi
  done
else
  fail "$FORGE_HOME/silver-bullet/templates directory does not exist"
fi

# 8. AGENTS.md present (must mention Silver Bullet OR a separate SB AGENTS.md must exist)
echo "[8/8] AGENTS.md (global)"
if [[ -f "$FORGE_HOME/AGENTS.md" ]]; then
  if grep -q "Silver Bullet" "$FORGE_HOME/AGENTS.md"; then
    ok "global AGENTS.md present and references Silver Bullet"
  else
    echo "  ⚠ $FORGE_HOME/AGENTS.md exists but does not mention Silver Bullet."
    echo "    The installer skips overwriting an existing AGENTS.md. To use SB, either:"
    echo "    • merge contents from forge/AGENTS.md.template into your existing AGENTS.md, or"
    echo "    • move your existing AGENTS.md and re-run forge-sb-install.sh"
    PASS=$((PASS+1))   # warning, not fail
  fi
else
  fail "$FORGE_HOME/AGENTS.md does not exist"
fi

# Optional project check
if $CHECK_PROJECT; then
  echo ""
  echo "[+] Project-level (.forge/agents)"
  if [[ -d ".forge/agents" ]]; then
    N=$(find .forge/agents -name "*.md" | wc -l | tr -d ' ')
    if [[ "$N" -ge 35 ]]; then ok "$N agents present at .forge/agents"; else fail ".forge/agents has only $N (expected ≥35)"; fi
  else
    fail ".forge/agents does not exist (run forge-sb-install.sh in this project)"
  fi
  if [[ -f "AGENTS.md" ]]; then ok "project AGENTS.md present"; else fail "project AGENTS.md missing"; fi
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  echo "✓ Smoke test PASSED — Silver Bullet for Forge is structurally sound."
  exit 0
else
  echo "✗ Smoke test FAILED — re-run forge-sb-install.sh and try again."
  exit 1
fi
