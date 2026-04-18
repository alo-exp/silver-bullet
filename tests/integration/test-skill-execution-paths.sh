#!/usr/bin/env bash
# Integration test: skill execution path validation
# Tests sub-skill references, non-skippable gates, step ordering, quality-gate dimension coverage,
# and skill name consistency for all orchestration skills.
set -euo pipefail

PASS=0; FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Allowlists
# ---------------------------------------------------------------------------

# External skills that are NOT in skills/ directory — from GSD, Superpowers, MultAI, design, etc.
EXTERNAL_SKILLS=(
  gsd-intel gsd-scan gsd-explore gsd-discuss-phase gsd-analyze-dependencies
  gsd-plan-phase gsd-execute-phase gsd-autonomous gsd-verify-work gsd-add-tests
  gsd-code-review gsd-code-review-fix gsd-review gsd-secure-phase gsd-validate-phase
  gsd-ship gsd-pr-branch gsd-complete-milestone gsd-audit-uat gsd-audit-milestone
  gsd-plan-milestone-gaps gsd-fast gsd-multai gsd-debug gsd-forensics
  gsd-docs-update gsd-milestone-summary gsd-ui-phase gsd-ui-review
  "gsd-review --all"
  "superpowers:brainstorming" "superpowers:writing-plans" "superpowers:test-driven-development"
  "superpowers:finishing-a-development-branch" "superpowers:requesting-code-review"
  "superpowers:receiving-code-review" "superpowers:systematic-debugging"
  "multai:orchestrator" "multai:landscape-researcher" "multai:consolidator"
  "multai:comparator" "multai:solution-researcher"
  "/product-brainstorming" "/testing-strategy" "/artifact-reviewer"
  "episodic-memory:remembering-conversations"
  "design:design-system" "design:ux-copy" "design:accessibility-review"
  "design:design-critique" "design:design-handoff"
  "/documentation" "/compact"
)

is_internal_skill() {
  local name="$1"
  [[ -d "$SKILLS_DIR/$name" ]]
}

is_external_skill() {
  local name="$1"
  for ext in "${EXTERNAL_SKILLS[@]}"; do
    [[ "$ext" == "$name" ]] && return 0
  done
  return 1
}

# Resolve silver: alias to the real skill name (internal or external)
resolve_silver_alias() {
  local name="$1"
  case "$name" in
    silver:intel)               echo "gsd-intel" ;;
    silver:scan)                echo "gsd-scan" ;;
    silver:explore)             echo "gsd-explore" ;;
    silver:brainstorm)          echo "superpowers:brainstorming" ;;
    silver:writing-plans)       echo "superpowers:writing-plans" ;;
    silver:tdd)                 echo "superpowers:test-driven-development" ;;
    silver:finishing-branch)    echo "superpowers:finishing-a-development-branch" ;;
    silver:request-review)      echo "superpowers:requesting-code-review" ;;
    silver:receive-review)      echo "superpowers:receiving-code-review" ;;
    silver:multai)              echo "multai:orchestrator" ;;
    silver:silver-quality-gates)       echo "silver-quality-gates" ;;
    silver:security)            echo "security" ;;
    silver:fast)                echo "silver-fast" ;;
    silver:feature)             echo "silver-feature" ;;
    silver:devops)              echo "silver-devops" ;;
    silver:bugfix)              echo "silver-bugfix" ;;
    silver:research)            echo "silver-research" ;;
    silver:release)             echo "silver-release" ;;
    silver:silver-forensics)           echo "silver-forensics" ;;
    silver:validate)            echo "silver-validate" ;;
    silver:silver-blast-radius)        echo "silver-blast-radius" ;;
    silver:devops-skill-router) echo "devops-skill-router" ;;
    silver:devops-quality-gates) echo "devops-quality-gates" ;;
    silver:silver-create-release)      echo "silver-create-release" ;;
    *)                          echo "$name" ;;
  esac
}

# Extract backtick-quoted invoke targets from a SKILL.md
extract_skill_refs() {
  local file="$1"
  grep -oE 'invoke `[^`]+`' "$file" | sed 's/invoke `//;s/`//' || true
}

check_skill_refs_in_file() {
  local label="$1" file="$2"
  local refs
  refs=$(extract_skill_refs "$file")
  [[ -z "$refs" ]] && return 0
  while IFS= read -r raw_ref; do
    [[ -z "$raw_ref" ]] && continue
    local ref
    ref="$(resolve_silver_alias "$raw_ref")"
    if is_internal_skill "$ref"; then
      check "$label: ref '$raw_ref' -> internal skill '$ref'" "pass"
    elif is_external_skill "$ref"; then
      check "$label: ref '$raw_ref' -> external skill '$ref'" "pass"
    else
      check "$label: ref '$raw_ref' (resolved: '$ref') is a known skill" "fail"
    fi
  done <<< "$refs"
}

# ===========================================================================
# GROUP 1: Sub-skill reference integrity
# ===========================================================================

echo ""
echo "=== Group 1: Sub-skill Reference Integrity ==="

ORCHESTRATION_SKILLS=(
  silver-feature silver-devops silver-bugfix silver-ui silver-research silver-release
  silver-quality-gates artifact-reviewer
)

for skill in "${ORCHESTRATION_SKILLS[@]}"; do
  echo "--- $skill ---"
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  if [[ ! -f "$skill_file" ]]; then
    check "$skill: SKILL.md exists for reference check" "fail"
    continue
  fi
  check_skill_refs_in_file "$skill" "$skill_file"
done

# ===========================================================================
# GROUP 2: Non-skippable gate presence
# ===========================================================================

echo ""
echo "=== Group 2: Non-Skippable Gate Presence ==="

SF="$SKILLS_DIR/silver-feature/SKILL.md"

nonsk=$(grep -i "non-skippable" "$SF" || true)
check "silver-feature: has non-skippable gates section" \
  "$([[ -n "$nonsk" ]] && echo pass || echo fail)"

check "silver-feature: silver-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SF" | grep -i 'silver-quality-gates' | head -1)" ]] && echo pass || echo fail)"

check "silver-feature: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SF" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-feature: gsd-verify-work listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SF" | grep -i 'gsd-verify-work' | head -1)" ]] && echo pass || echo fail)"

check "silver-feature: pre-build validate has NON-SKIPPABLE GATE marker" \
  "$([[ "$(grep -i 'NON-SKIPPABLE GATE' "$SF" | head -1)" ]] && echo pass || echo fail)"

SDEV="$SKILLS_DIR/silver-devops/SKILL.md"
check "silver-devops: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SDEV" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-devops: gsd-verify-work listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SDEV" | grep -i 'gsd-verify-work' | head -1)" ]] && echo pass || echo fail)"

check "silver-devops: devops-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SDEV" | grep -i 'devops-quality-gates' | head -1)" ]] && echo pass || echo fail)"

SBF="$SKILLS_DIR/silver-bugfix/SKILL.md"
check "silver-bugfix: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SBF" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-bugfix: silver-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SBF" | grep -i 'silver-quality-gates' | head -1)" ]] && echo pass || echo fail)"

check "silver-bugfix: gsd-verify-work listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SBF" | grep -i 'gsd-verify-work' | head -1)" ]] && echo pass || echo fail)"

SUI="$SKILLS_DIR/silver-ui/SKILL.md"
check "silver-ui: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SUI" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-ui: silver-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SUI" | grep -i 'silver-quality-gates' | head -1)" ]] && echo pass || echo fail)"

check "silver-ui: gsd-verify-work listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SUI" | grep -i 'gsd-verify-work' | head -1)" ]] && echo pass || echo fail)"

SREL="$SKILLS_DIR/silver-release/SKILL.md"
check "silver-release: silver-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SREL" | grep -i 'silver-quality-gates' | head -1)" ]] && echo pass || echo fail)"

check "silver-release: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SREL" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

# ===========================================================================
# GROUP 3: Required step ordering
# ===========================================================================

echo ""
echo "=== Group 3: Required Step Ordering ==="

line_of() {
  grep -n "$1" "$2" | head -1 | cut -d: -f1
}

SF="$SKILLS_DIR/silver-feature/SKILL.md"

qg_line=$(grep -n "silver:silver-quality-gates" "$SF" | head -1 | cut -d: -f1 || echo 0)
exec_line=$(grep -n "gsd-execute-phase\|gsd-autonomous" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: silver-quality-gates step before execute step (line $qg_line < $exec_line)" \
  "$([[ "$qg_line" -gt 0 && "$exec_line" -gt 0 && "$qg_line" -lt "$exec_line" ]] && echo pass || echo fail)"

sec_line=$(grep -n "silver:security" "$SF" | head -1 | cut -d: -f1 || echo 0)
ship_line=$(grep -n "gsd-ship" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: security step before ship step (line $sec_line < $ship_line)" \
  "$([[ "$sec_line" -gt 0 && "$ship_line" -gt 0 && "$sec_line" -lt "$ship_line" ]] && echo pass || echo fail)"

tdd_line=$(grep -n "silver:tdd" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: TDD step after first execute step (line $exec_line < $tdd_line)" \
  "$([[ "$exec_line" -gt 0 && "$tdd_line" -gt 0 && "$exec_line" -lt "$tdd_line" ]] && echo pass || echo fail)"

verify_line=$(grep -n "gsd-verify-work" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: gsd-verify-work before gsd-ship (line $verify_line < $ship_line)" \
  "$([[ "$verify_line" -gt 0 && "$ship_line" -gt 0 && "$verify_line" -lt "$ship_line" ]] && echo pass || echo fail)"

SDEV="$SKILLS_DIR/silver-devops/SKILL.md"
dev_sec_line=$(grep -n "silver:security" "$SDEV" | head -1 | cut -d: -f1 || echo 0)
dev_ship_line=$(grep -n "gsd-ship" "$SDEV" | head -1 | cut -d: -f1 || echo 0)
check "silver-devops: security before ship (line $dev_sec_line < $dev_ship_line)" \
  "$([[ "$dev_sec_line" -gt 0 && "$dev_ship_line" -gt 0 && "$dev_sec_line" -lt "$dev_ship_line" ]] && echo pass || echo fail)"

dev_verify_line=$(grep -n "gsd-verify-work" "$SDEV" | head -1 | cut -d: -f1 || echo 0)
check "silver-devops: gsd-verify-work before ship (line $dev_verify_line < $dev_ship_line)" \
  "$([[ "$dev_verify_line" -gt 0 && "$dev_ship_line" -gt 0 && "$dev_verify_line" -lt "$dev_ship_line" ]] && echo pass || echo fail)"

SBF="$SKILLS_DIR/silver-bugfix/SKILL.md"
bf_tdd_line=$(grep -n "silver:tdd" "$SBF" | head -1 | cut -d: -f1 || echo 0)
bf_plan_line=$(grep -n "gsd-plan-phase" "$SBF" | head -1 | cut -d: -f1 || echo 0)
check "silver-bugfix: TDD before plan/execute step (line $bf_tdd_line < $bf_plan_line)" \
  "$([[ "$bf_tdd_line" -gt 0 && "$bf_plan_line" -gt 0 && "$bf_tdd_line" -lt "$bf_plan_line" ]] && echo pass || echo fail)"

bf_sec_line=$(grep -n "silver:security" "$SBF" | head -1 | cut -d: -f1 || echo 0)
bf_ship_line=$(grep -n "gsd-ship" "$SBF" | head -1 | cut -d: -f1 || echo 0)
check "silver-bugfix: security before ship (line $bf_sec_line < $bf_ship_line)" \
  "$([[ "$bf_sec_line" -gt 0 && "$bf_ship_line" -gt 0 && "$bf_sec_line" -lt "$bf_ship_line" ]] && echo pass || echo fail)"

SREL="$SKILLS_DIR/silver-release/SKILL.md"
rel_qg_line=$(grep -n "silver:silver-quality-gates" "$SREL" | head -1 | cut -d: -f1 || echo 0)
# Match the actual invoke line for gsd-ship (case-insensitive, not frontmatter description references)
rel_ship_line=$(grep -in "invoke \`gsd-ship\`" "$SREL" | head -1 | cut -d: -f1 || echo 0)
check "silver-release: silver-quality-gates before ship (line $rel_qg_line < $rel_ship_line)" \
  "$([[ "$rel_qg_line" -gt 0 && "$rel_ship_line" -gt 0 && "$rel_qg_line" -lt "$rel_ship_line" ]] && echo pass || echo fail)"

rel_sec_line=$(grep -n "silver:security" "$SREL" | head -1 | cut -d: -f1 || echo 0)
check "silver-release: security before ship (line $rel_sec_line < $rel_ship_line)" \
  "$([[ "$rel_sec_line" -gt 0 && "$rel_ship_line" -gt 0 && "$rel_sec_line" -lt "$rel_ship_line" ]] && echo pass || echo fail)"

# ===========================================================================
# GROUP 4: Quality-gates dimension completeness
# ===========================================================================

echo ""
echo "=== Group 4: Quality-Gates Dimension Completeness ==="

QG="$SKILLS_DIR/silver-quality-gates/SKILL.md"

DIMENSIONS=(modularity reusability scalability security reliability usability testability extensibility ai-llm-safety)
for dim in "${DIMENSIONS[@]}"; do
  check "silver-quality-gates: references dimension skill '$dim'" \
    "$([[ "$(grep -i "$dim" "$QG" | head -1)" ]] && echo pass || echo fail)"
done

for dim in "${DIMENSIONS[@]}"; do
  check "silver-quality-gates: dimension skill directory '$dim' exists" \
    "$([[ -d "$SKILLS_DIR/$dim" ]] && echo pass || echo fail)"
done

check "silver-quality-gates: uses PLUGIN_ROOT path pattern for loading dimension files" \
  "$([[ "$(grep 'PLUGIN_ROOT' "$QG" | head -1)" ]] && echo pass || echo fail)"

# ===========================================================================
# GROUP 5: Skill name consistency
# ===========================================================================

echo ""
echo "=== Group 5: Skill Name Consistency ==="

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  fm_name=$(awk '/^---$/{count++; if(count==2) exit} count==1 && /^name:/' "$skill_file" | head -1)
  [[ -z "$fm_name" ]] && continue

  name_value=$(echo "$fm_name" | sed 's/^name:[[:space:]]*//' | tr -d '"'"'" | tr -d '[:space:]')
  check "$skill_name: frontmatter name '$name_value' matches directory '$skill_name'" \
    "$([[ "$name_value" == "$skill_name" ]] && echo pass || echo fail)"
done

echo ""
echo "--- silver: alias -> skill directory checks ---"

# Use parallel arrays to avoid associative array key issues with colons
ALIAS_NAMES=(
  "silver:silver-quality-gates"
  "silver:security"
  "silver:fast"
  "silver:feature"
  "silver:devops"
  "silver:bugfix"
  "silver:research"
  "silver:release"
  "silver:silver-forensics"
  "silver:validate"
  "silver:silver-blast-radius"
  "silver:devops-skill-router"
  "silver:devops-quality-gates"
  "silver:silver-create-release"
)
ALIAS_TARGETS=(
  "silver-quality-gates"
  "security"
  "silver-fast"
  "silver-feature"
  "silver-devops"
  "silver-bugfix"
  "silver-research"
  "silver-release"
  "silver-forensics"
  "silver-validate"
  "silver-blast-radius"
  "devops-skill-router"
  "devops-quality-gates"
  "silver-create-release"
)

for i in "${!ALIAS_NAMES[@]}"; do
  alias_name="${ALIAS_NAMES[$i]}"
  resolved="${ALIAS_TARGETS[$i]}"
  check "alias '$alias_name' -> existing skill dir '$resolved'" \
    "$([[ -d "$SKILLS_DIR/$resolved" ]] && echo pass || echo fail)"
done

# ===========================================================================
# GROUP 6: Circular reference detection (direct self-invocation)
# ===========================================================================

echo ""
echo "=== Group 6: Circular Reference Detection ==="

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  self_ref=$(grep -oE "invoke \`[^\`]+\`" "$skill_file" | grep -i "$skill_name" | head -1 || true)
  check "$skill_name: does not directly invoke itself" \
    "$([[ -z "$self_ref" ]] && echo pass || echo fail)"
done

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo "TOTAL: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
