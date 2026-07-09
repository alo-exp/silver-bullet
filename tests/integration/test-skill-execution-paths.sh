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
  "requesting-code-review" "receiving-code-review"
  "superpowers:test-driven-development" "superpowers:writing-plans"
  "superpowers:finishing-a-development-branch"
  "superpowers:requesting-code-review" "superpowers:receiving-code-review"
  "superpowers:systematic-debugging"
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
    silver:quality-gates)       echo "silver-quality-gates" ;;
    silver:silver-quality-gates) echo "silver-quality-gates" ;;
    silver:security)            echo "security" ;;
    silver:fast)                echo "silver-fast" ;;
    silver:feature)             echo "silver-feature" ;;
    silver:devops)              echo "silver-devops" ;;
    silver:bugfix)              echo "silver-bugfix" ;;
    silver:deep-research)       echo "silver-deep-research" ;;
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
    silver:agent-codex)         echo "silver-agent-codex" ;;
    silver:agent-cursor)        echo "silver-agent-cursor" ;;
    silver:agent-claude)        echo "silver-agent-claude" ;;
    silver:agent-opencode)      echo "silver-agent-opencode" ;;
    silver:agent-pi)            echo "silver-agent-pi" ;;
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
  silver-feature silver-devops silver-bugfix silver-ui silver-deep-research silver-release silver-clarify
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
# GROUP 2: Composition-chain gate presence (non-skippable + enforcement)
# ===========================================================================

echo ""
echo "=== Group 2: Composition-Chain Gate Presence ==="

ORCH_LIB="${REPO_ROOT}/hooks/lib/orchestrator-state.sh"
# shellcheck source=/dev/null
source "$ORCH_LIB"

COMPOSER_SKILLS=(
  silver-feature silver-ui silver-devops silver-bugfix silver-deep-research silver-release silver-fast
)

for skill in "${COMPOSER_SKILLS[@]}"; do
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  [[ -f "$skill_file" ]] || { check "$skill: SKILL.md exists" "fail"; continue; }

  if [[ "$skill" == "silver-fast" ]]; then
    check "$skill: documents Tier 2 composition slice" \
      "$([[ "$(grep -F 'quality-gates' "$skill_file" | grep -F 'silver:plan' | head -1)" ]] && echo pass || echo fail)"
  else
    check "$skill: declares Standard composition chain" \
      "$([[ "$(grep -F 'Standard composition chain' "$skill_file" | head -1)" ]] && echo pass || echo fail)"
  fi

  if grep -qi 'non-skippable' "$skill_file"; then
    check "$skill: non-skippable section mentions security" \
      "$([[ "$(grep -i 'security' "$skill_file" | head -1)" ]] && echo pass || echo fail)"
    check "$skill: non-skippable section mentions verify" \
      "$([[ "$(grep -iE 'silver:verify|silver-verify|verify-tests' "$skill_file" | head -1)" ]] && echo pass || echo fail)"
    check "$skill: non-skippable section mentions quality gates" \
      "$([[ "$(grep -iE 'quality-gates|devops-quality-gates' "$skill_file" | head -1)" ]] && echo pass || echo fail)"
  fi

  if grep -qi 'Enforcement queue' "$skill_file"; then
    check "$skill: references orchestrator enforcement hooks" \
      "$([[ "$(grep -E 'orchestrator-state\.sh|workflow-chain-guard|orchestrator\.json|Parent orchestrator' "$skill_file" | head -1)" ]] && echo pass || echo fail)"
  fi

  if grep -qi 'Post-execution' "$skill_file"; then
    check "$skill: documents post-execution sequencing" \
      "$([[ "$(grep -iE 'review|verify|secure|ship' "$skill_file" | head -1)" ]] && echo pass || echo fail)"
  elif [[ "$skill" == "silver-fast" ]]; then
    check "$skill: documents Tier 2 post-verify deploy gap" \
      "$([[ "$(grep -F 'post-execution deploy chain' "$skill_file" | head -1)" ]] && echo pass || echo fail)"
  fi
done

SF="$SKILLS_DIR/silver-feature/SKILL.md"
check "silver-feature: documents conditional silver:spec when SPEC.md absent" \
  "$([[ "$(grep -F 'silver:spec' "$SF" | grep -iE 'SPEC\.md|SPEC absent' | head -1)" ]] && echo pass || echo fail)"

SUI="$SKILLS_DIR/silver-ui/SKILL.md"
check "silver-ui: documents conditional silver:spec when SPEC absent" \
  "$([[ "$(grep -F 'silver:spec' "$SUI" | grep -iE 'SPEC\.md|SPEC absent' | head -1)" ]] && echo pass || echo fail)"

SFAST="$SKILLS_DIR/silver-fast/SKILL.md"
check "silver-fast: Tier 2 always requires silver:validate" \
  "$([[ "$(grep -F 'silver:validate' "$SFAST" | grep -E 'Always invoke|always invoke' | head -1)" ]] && echo pass || echo fail)"
check "silver-fast: SessionStart clears trivial marker (not creates)" \
  "$([[ "$(grep -F 'SessionStart clears any stale' "$SFAST")" ]] && echo pass || echo fail)"
check "silver-fast: Tier 2 deploy chain documents security and completion-audit" \
  "$([[ "$(grep -F 'security → silver:secure' "$SFAST")" && "$(grep -F 'silver:completion-audit' "$SFAST")" ]] && echo pass || echo fail)"
check "silver-fast: Tier 2 documents plan-only validate without SPEC" \
  "$([[ "$(grep -F 'plan-only mode' "$SFAST")" ]] && echo pass || echo fail)"

SVAL="$SKILLS_DIR/silver-validate/SKILL.md"
check "silver-validate: documents plan-only mode when SPEC absent" \
  "$([[ "$(grep -F 'Plan-only mode' "$SVAL")" ]] && echo pass || echo fail)"

SDEV="$SKILLS_DIR/silver-devops/SKILL.md"
check "silver-devops: references plan-only validate without SPEC" \
  "$([[ "$(grep -F 'plan-only' "$SDEV" || grep -F 'plan-only mode' "$SVAL")" ]] && echo pass || echo fail)"

SREL="$SKILLS_DIR/silver-release/SKILL.md"
check "silver-release: non-skippable gates section present" \
  "$([[ "$(grep -i 'Non-skippable' "$SREL" | head -1)" ]] && echo pass || echo fail)"
check "silver-release: references create-release marketplace sync" \
  "$([[ "$(grep -F 'sync-release-marketplace-versions.sh' "$SREL" | head -1)" ]] && echo pass || echo fail)"


# ===========================================================================
# GROUP 3: Orchestrator queue ordering (composition model)
# ===========================================================================

echo ""
echo "=== Group 3: Orchestrator Queue Ordering ==="

feature_q="$(sb_orchestrator_default_queue_for_composer silver-feature)"
check "silver-feature: quality-gates before execute in orchestrator queue" \
  "$(printf '%s' "$feature_q" | grep -q 'FLOW-QUALITY-GATE,silver-context,silver-plan,silver-validate,silver-execute' && echo pass || echo fail)"
check "silver-feature: review before verify in orchestrator queue" \
  "$(printf '%s' "$feature_q" | grep -q 'silver-review-request,silver-review,silver-review-triage,silver-verify' && echo pass || echo fail)"

ui_q="$(sb_orchestrator_default_queue_for_composer silver-ui)"
check "silver-ui: ui-contract before execute in orchestrator queue" \
  "$(printf '%s' "$ui_q" | grep -q 'silver-ui-contract,silver-validate,silver-execute' && echo pass || echo fail)"
check "silver-ui: ui-review immediately after execute" \
  "$(printf '%s' "$ui_q" | grep -q 'silver-execute,silver-ui-review' && echo pass || echo fail)"

devops_q="$(sb_orchestrator_default_queue_for_composer silver-devops)"
check "silver-devops: validate before execute in orchestrator queue" \
  "$(printf '%s' "$devops_q" | grep -q 'silver-validate,silver-execute' && echo pass || echo fail)"
check "silver-devops: security before ship segment" \
  "$(printf '%s' "$devops_q" | grep -q 'security,silver-secure' && echo pass || echo fail)"

bugfix_q="$(sb_orchestrator_default_queue_for_composer silver-bugfix)"
bugfix_pre="${bugfix_q%%,silver-execute*}"
check "silver-bugfix: debug before plan in orchestrator queue" \
  "$(printf '%s' "$bugfix_q" | grep -q 'silver-debug,silver-plan' && echo pass || echo fail)"
check "silver-bugfix: no pre-plan quality-gates in orchestrator queue" \
  "$([[ "$(printf '%s' "$bugfix_pre" | grep -c 'FLOW-QUALITY-GATE')" -eq 0 ]] && echo pass || echo fail)"

release_q="$(sb_orchestrator_default_queue_for_composer silver-release)"
check "silver-release: branch-finish before ship in orchestrator queue" \
  "$(printf '%s' "$release_q" | grep -q 'silver-branch-finish,silver-completion-audit,silver-ship' && echo pass || echo fail)"
check "silver-release: create-release is queue tail" \
  "$([[ "$(printf '%s' "$release_q" | awk -F, '{print $NF}')" == "silver-create-release" ]] && echo pass || echo fail)"

fast_q="$(sb_orchestrator_default_queue_for_composer silver-fast)"
check "silver-fast: Tier 2 orchestrator queue ends at verify" \
  "$([[ "$(printf '%s' "$fast_q" | awk -F, '{print $NF}')" == "silver-verify" ]] && echo pass || echo fail)"

SBF="$SKILLS_DIR/silver-bugfix/SKILL.md"
check "silver-bugfix: documents debug before plan in enforcement queue" \
  "$([[ "$(grep -F 'silver:debug' "$SBF" | head -1)" && "$(grep -F 'silver:plan' "$SBF" | head -1)" ]] && echo pass || echo fail)"

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

rel_allow_git_add_line=$(grep -nE 'git add CHANGELOG\.md README\.md .*(marketplace\.json|host plugin manifest).*plugin\.json' "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: marketplace manifests are staged by the allowed git add command (line $rel_allow_git_add_line > 0)" \
  "$([[ "$rel_allow_git_add_line" -gt 0 ]] && echo pass || echo fail)"

rel_announce_line=$(grep -n ".github/workflows/announce-release.yml" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: release announcement workflow is mandatory (line $rel_announce_line > 0)" \
  "$([[ "$rel_announce_line" -gt 0 ]] && echo pass || echo fail)"

rel_optional_gchat_line=$(grep -n "notification is optional" "$SCL" | head -1 | cut -d: -f1 || echo 0)
check "silver-create-release: Google Chat notification is no longer optional" \
  "$([[ "$rel_optional_gchat_line" -eq 0 ]] && echo pass || echo fail)"

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
  "silver:deep-research"
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
  "silver-deep-research"
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
