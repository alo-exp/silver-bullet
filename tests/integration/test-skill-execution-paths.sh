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

# External skills that are NOT in skills/ directory — optional legacy/provider
# extension skills or historical aliases. SB-owned lifecycle skills must resolve
# to local skill directories below.
EXTERNAL_SKILLS=(
  gsd-intel gsd-scan gsd-map-codebase gsd-explore gsd-discuss-phase gsd-analyze-dependencies
  gsd-plan-phase gsd-execute-phase gsd-autonomous gsd-verify-work gsd-add-tests
  gsd-code-review gsd-code-review-fix gsd-review gsd-secure-phase gsd-validate-phase
  gsd-ship gsd-pr-branch gsd-complete-milestone gsd-audit-uat gsd-audit-milestone
  gsd-plan-milestone-gaps gsd-fast gsd-multai gsd-debug gsd-forensics
  gsd-docs-update gsd-milestone-summary gsd-ui-phase gsd-ui-review
  "gsd-review --all"
  "requesting-code-review" "receiving-code-review"
  "superpowers:test-driven-development" "superpowers:writing-plans"
  "superpowers:finishing-a-development-branch"
  "superpowers:requesting-code-review" "superpowers:receiving-code-review"
  "superpowers:systematic-debugging"
  "multai:orchestrator" "multai:landscape-researcher" "multai:consolidator"
  "multai:comparator" "multai:solution-researcher"
  "testing-strategy" "/artifact-reviewer"
  "episodic-memory:remembering-conversations"
  "design:design-system" "design:ux-copy" "design:accessibility-review"
  "design:design-critique" "design:design-handoff"
  "documentation" "/compact"
)

BUILTIN_WHITELIST=(
  compact clear help
  bash scripts/workflows.sh
  code-review tech-debt deploy-checklist
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
  local cmd="${name%% *}"
  case "$cmd" in
    silver:intel)               echo "gsd-intel" ;;
    silver:scan)                echo "silver-scan" ;;
    silver:spec)                echo "silver-spec" ;;
    silver:clarify)             echo "silver-clarify" ;;
    silver:context)             echo "silver-context" ;;
    silver:plan)                echo "silver-plan" ;;
    silver:execute)             echo "silver-execute" ;;
    silver:verify)              echo "silver-verify" ;;
    silver:ship)                echo "silver-ship" ;;
    silver:review-request)      echo "silver-review-request" ;;
    silver:review)              echo "silver-review" ;;
    silver:review-triage)       echo "silver-review-triage" ;;
    silver:secure)              echo "silver-secure" ;;
    silver:ui-contract)         echo "silver-ui-contract" ;;
    silver:ui-review)           echo "silver-ui-review" ;;
    silver:debug)               echo "silver-debug" ;;
    silver:completion-audit)    echo "silver-completion-audit" ;;
    silver:branch-finish)       echo "silver-branch-finish" ;;
    silver:ensure-docs)         echo "silver-ensure-docs" ;;
    silver:handoff)             echo "silver-handoff" ;;
    silver:tdd)                 echo "tdd" ;;
    silver:request-review)      echo "silver-review-request" ;;
    silver:receive-review)      echo "silver-review-triage" ;;
    silver:multai)              echo "multai:orchestrator" ;;
    silver:quality-gates)       echo "silver-quality-gates" ;;
    silver:silver-quality-gates) echo "silver-quality-gates" ;;
    silver:security)            echo "security" ;;
    silver:fast)                echo "silver-fast" ;;
    silver:feature)             echo "silver-feature" ;;
    silver:devops)              echo "silver-devops" ;;
    silver:bugfix)              echo "silver-bugfix" ;;
    silver:research)            echo "silver-research" ;;
    silver:release)             echo "silver-release" ;;
    silver:test)                echo "silver-test" ;;
    silver:deploy)              echo "silver-deploy" ;;
    silver:canary)              echo "silver-canary" ;;
    silver:incident)            echo "silver-incident" ;;
    silver:retro)               echo "silver-retro" ;;
    silver:benchmark)           echo "silver-benchmark" ;;
    silver:content)             echo "silver-content" ;;
    silver:refactor)            echo "silver-refactor" ;;
    silver:worktree)            echo "silver-worktree" ;;
    silver:forensics)           echo "silver-forensics" ;;
    silver:silver-forensics)    echo "silver-forensics" ;;
    silver:validate)            echo "silver-validate" ;;
    silver:blast-radius)        echo "silver-blast-radius" ;;
    silver:silver-blast-radius) echo "silver-blast-radius" ;;
    silver:devops-skill-router) echo "devops-skill-router" ;;
    silver:devops-quality-gates) echo "devops-quality-gates" ;;
    silver:create-release)      echo "silver-create-release" ;;
    silver:silver-create-release) echo "silver-create-release" ;;
    *)                          echo "$cmd" ;;
  esac
}

# Extract backtick-quoted invoke targets from a SKILL.md
extract_skill_refs() {
  local file="$1"
  grep -oiE 'invoke `[^`]+`' "$file" | sed -E 's/^[Ii]nvoke `//;s/`//' || true
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
    elif [[ " ${BUILTIN_WHITELIST[*]} " == *" $ref "* ]]; then
      check "$label: ref '$raw_ref' -> built-in command '$ref'" "pass"
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
  silver-feature silver-devops silver-bugfix silver-ui silver-research silver-release silver-clarify
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
  "$([[ "$(grep -i 'non-skippable' "$SF" | grep -i 'silver:quality-gates' | head -1)" ]] && echo pass || echo fail)"

check "silver-feature: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SF" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-feature: silver:verify listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SF" | grep -i 'silver:verify' | head -1)" ]] && echo pass || echo fail)"

check "silver-feature: pre-build validate has NON-SKIPPABLE GATE marker" \
  "$([[ "$(grep -i 'NON-SKIPPABLE GATE' "$SF" | head -1)" ]] && echo pass || echo fail)"

SDEV="$SKILLS_DIR/silver-devops/SKILL.md"
check "silver-devops: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SDEV" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-devops: silver:verify listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SDEV" | grep -i 'silver:verify' | head -1)" ]] && echo pass || echo fail)"

check "silver-devops: devops-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SDEV" | grep -i 'devops-quality-gates' | head -1)" ]] && echo pass || echo fail)"

SBF="$SKILLS_DIR/silver-bugfix/SKILL.md"
check "silver-bugfix: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SBF" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-bugfix: silver-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SBF" | grep -i 'silver:quality-gates' | head -1)" ]] && echo pass || echo fail)"

check "silver-bugfix: silver:verify listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SBF" | grep -i 'silver:verify' | head -1)" ]] && echo pass || echo fail)"

SUI="$SKILLS_DIR/silver-ui/SKILL.md"
check "silver-ui: security listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SUI" | grep -i 'security' | head -1)" ]] && echo pass || echo fail)"

check "silver-ui: silver-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SUI" | grep -i 'silver:quality-gates' | head -1)" ]] && echo pass || echo fail)"

check "silver-ui: silver:verify listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SUI" | grep -i 'silver:verify' | head -1)" ]] && echo pass || echo fail)"

SREL="$SKILLS_DIR/silver-release/SKILL.md"
check "silver-release: silver-quality-gates listed as non-skippable" \
  "$([[ "$(grep -i 'non-skippable' "$SREL" | grep -i 'silver:quality-gates' | head -1)" ]] && echo pass || echo fail)"

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

qg_line=$(grep -n "Invoke \`silver:quality-gates\`" "$SF" | head -1 | cut -d: -f1 || echo 0)
exec_line=$(grep -n "invoke \`silver:execute\`" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: silver-quality-gates step before execute step (line $qg_line < $exec_line)" \
  "$([[ "$qg_line" -gt 0 && "$exec_line" -gt 0 && "$qg_line" -lt "$exec_line" ]] && echo pass || echo fail)"

sec_line=$(grep -n "Invoke \`security\`" "$SF" | head -1 | cut -d: -f1 || echo 0)
ship_line=$(grep -n "Invoke \`silver:ship\`" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: security step before ship step (line $sec_line < $ship_line)" \
  "$([[ "$sec_line" -gt 0 && "$ship_line" -gt 0 && "$sec_line" -lt "$ship_line" ]] && echo pass || echo fail)"

tdd_line=$(grep -n "^\*\*Internal TDD gate" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: TDD step after first execute step (line $exec_line < $tdd_line)" \
  "$([[ "$exec_line" -gt 0 && "$tdd_line" -gt 0 && "$exec_line" -lt "$tdd_line" ]] && echo pass || echo fail)"

verify_line=$(grep -n "Invoke \`silver:verify\`" "$SF" | head -1 | cut -d: -f1 || echo 0)
ship_line=$(grep -n "Invoke \`silver:ship\`" "$SF" | head -1 | cut -d: -f1 || echo 0)
check "silver-feature: silver:verify before silver:ship (line $verify_line < $ship_line)" \
  "$([[ "$verify_line" -gt 0 && "$ship_line" -gt 0 && "$verify_line" -lt "$ship_line" ]] && echo pass || echo fail)"

SDEV="$SKILLS_DIR/silver-devops/SKILL.md"
dev_sec_line=$(grep -n "Invoke \`security\`" "$SDEV" | head -1 | cut -d: -f1 || echo 0)
dev_ship_line=$(grep -n "silver:ship" "$SDEV" | head -1 | cut -d: -f1 || echo 0)
check "silver-devops: security before ship (line $dev_sec_line < $dev_ship_line)" \
  "$([[ "$dev_sec_line" -gt 0 && "$dev_ship_line" -gt 0 && "$dev_sec_line" -lt "$dev_ship_line" ]] && echo pass || echo fail)"

dev_verify_line=$(grep -n "silver:verify" "$SDEV" | head -1 | cut -d: -f1 || echo 0)
check "silver-devops: silver:verify before ship (line $dev_verify_line < $dev_ship_line)" \
  "$([[ "$dev_verify_line" -gt 0 && "$dev_ship_line" -gt 0 && "$dev_verify_line" -lt "$dev_ship_line" ]] && echo pass || echo fail)"

SBF="$SKILLS_DIR/silver-bugfix/SKILL.md"
bf_tdd_line=$(grep -n "Invoke \`tdd\`" "$SBF" | head -1 | cut -d: -f1 || echo 0)
bf_plan_line=$(grep -n "silver:plan" "$SBF" | head -1 | cut -d: -f1 || echo 0)
# Canonical bugfix pre-execution chain is DEBUG → PLAN → TDD (B1): planning is
# recorded before the regression test so workflow-chain-guard's (silver-debug
# silver-plan) markers exist before the first fix/test edit. PLAN must precede TDD.
check "silver-bugfix: plan step before TDD step (line $bf_plan_line < $bf_tdd_line)" \
  "$([[ "$bf_plan_line" -gt 0 && "$bf_tdd_line" -gt 0 && "$bf_plan_line" -lt "$bf_tdd_line" ]] && echo pass || echo fail)"

bf_sec_line=$(grep -n "Invoke \`security\`" "$SBF" | head -1 | cut -d: -f1 || echo 0)
bf_ship_line=$(grep -n "silver:ship" "$SBF" | head -1 | cut -d: -f1 || echo 0)
check "silver-bugfix: security before ship (line $bf_sec_line < $bf_ship_line)" \
  "$([[ "$bf_sec_line" -gt 0 && "$bf_ship_line" -gt 0 && "$bf_sec_line" -lt "$bf_ship_line" ]] && echo pass || echo fail)"

SREL="$SKILLS_DIR/silver-release/SKILL.md"
rel_qg_line=$(grep -n "silver:quality-gates" "$SREL" | head -1 | cut -d: -f1 || echo 0)
# Match the actual invoke line for silver:ship (case-insensitive, not frontmatter description references)
rel_ship_line=$(grep -in "invoke \`silver:ship\`" "$SREL" | head -1 | cut -d: -f1 || echo 0)
check "silver-release: silver-quality-gates before ship (line $rel_qg_line < $rel_ship_line)" \
  "$([[ "$rel_qg_line" -gt 0 && "$rel_ship_line" -gt 0 && "$rel_qg_line" -lt "$rel_ship_line" ]] && echo pass || echo fail)"

rel_sec_line=$(grep -n "Invoke \`security\`" "$SREL" | head -1 | cut -d: -f1 || echo 0)
check "silver-release: security before ship (line $rel_sec_line < $rel_ship_line)" \
  "$([[ "$rel_sec_line" -gt 0 && "$rel_ship_line" -gt 0 && "$rel_sec_line" -lt "$rel_ship_line" ]] && echo pass || echo fail)"

SCL="$SKILLS_DIR/silver-create-release/SKILL.md"
rel_ci_gate_line=$(grep -n "verify-release-commit-ci.sh" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: release CI gate is required before tagging (line $rel_ci_gate_line > 0)" \
  "$([[ "$rel_ci_gate_line" -gt 0 ]] && echo pass || echo fail)"

rel_allow_sync_line=$(grep -n "bash scripts/sync-release-marketplace-versions.sh" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: marketplace sync wrapper is allowed (line $rel_allow_sync_line > 0)" \
  "$([[ "$rel_allow_sync_line" -gt 0 ]] && echo pass || echo fail)"

rel_allow_live_line=$(grep -n "bash scripts/run-release-live-matrix.sh" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: release matrix wrapper is allowed (line $rel_allow_live_line > 0)" \
  "$([[ "$rel_allow_live_line" -gt 0 ]] && echo pass || echo fail)"

rel_allow_ci_line=$(grep -n "bash scripts/verify-release-commit-ci.sh" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: release CI wait script is allowed (line $rel_allow_ci_line > 0)" \
  "$([[ "$rel_allow_ci_line" -gt 0 ]] && echo pass || echo fail)"

rel_allow_refresh_line=$(grep -n "bash scripts/post-release-refresh.sh" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: post-release refresh wrapper is allowed (line $rel_allow_refresh_line > 0)" \
  "$([[ "$rel_allow_refresh_line" -gt 0 ]] && echo pass || echo fail)"

rel_allow_git_add_line=$(grep -n "git add CHANGELOG.md README.md .claude-plugin/marketplace.json plugins/silver-bullet/.codex-plugin/plugin.json" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: marketplace manifests are staged by the allowed git add command (line $rel_allow_git_add_line > 0)" \
  "$([[ "$rel_allow_git_add_line" -gt 0 ]] && echo pass || echo fail)"

rel_announce_line=$(grep -n ".github/workflows/announce-release.yml" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: release announcement workflow is mandatory (line $rel_announce_line > 0)" \
  "$([[ "$rel_announce_line" -gt 0 ]] && echo pass || echo fail)"

rel_optional_gchat_line=$(grep -n "notification is optional" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: Google Chat notification is no longer optional" \
  "$([[ "$rel_optional_gchat_line" -eq 0 ]] && echo pass || echo fail)"

market_sync_result=fail
if python3 - "$SREL" <<'PY' >/dev/null 2>&1
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
raise SystemExit(0 if "bash scripts/sync-release-marketplace-versions.sh" in text else 1)
PY
then
  market_sync_result=pass
fi
check "silver-release: marketplace sync wrapper is referenced in release contract" "$market_sync_result"

market_commit_result=fail
if python3 - "$SREL" <<'PY' >/dev/null 2>&1
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
raise SystemExit(0 if "git add CHANGELOG.md README.md .claude-plugin/marketplace.json plugins/silver-bullet/.codex-plugin/plugin.json" in text else 1)
PY
then
  market_commit_result=pass
fi
check "silver-release: marketplace manifests are committed in release contract" "$market_commit_result"

market_push_result=fail
if python3 - "$SREL" <<'PY' >/dev/null 2>&1
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
raise SystemExit(0 if "upstream marketplace repo" in text and "pushed" in text else 1)
PY
then
  market_push_result=pass
fi
check "silver-release: upstream marketplace repo push is required in release contract" "$market_push_result"

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
  "silver:handoff"
  "silver:context"
  "silver:plan"
  "silver:execute"
  "silver:verify"
  "silver:ship"
  "silver:review-request"
  "silver:review"
  "silver:review-triage"
  "silver:secure"
  "silver:completion-audit"
  "silver:branch-finish"
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
  "silver-handoff"
  "silver-context"
  "silver-plan"
  "silver-execute"
  "silver-verify"
  "silver-ship"
  "silver-review-request"
  "silver-review"
  "silver-review-triage"
  "silver-secure"
  "silver-completion-audit"
  "silver-branch-finish"
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
