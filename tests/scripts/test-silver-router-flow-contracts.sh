#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qE "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if ! grep -qE "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — unexpected [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

router="$REPO_ROOT/skills/silver/SKILL.md"
contracts="$REPO_ROOT/docs/composable-flows-contracts.md"
template="$REPO_ROOT/templates/silver-bullet.md.base"
root_rules="$REPO_ROOT/silver-bullet.md"
forge_template="$REPO_ROOT/forge/templates/silver-bullet.md.base"

assert_contains "router handles non-trivial bare intent" "most non-trivial bare user" "$router"
assert_contains "router states GSD lifecycle authority" "GSD remains the lifecycle authority" "$router"
assert_contains "router delegates GSD lifecycle to gsd:do" "gsd:do" "$router"
assert_contains "router protects semver via GSD" "semver, milestone, and phase management" "$router"

assert_contains "contracts define atomic flow catalog" "Atomic Flow Catalog" "$contracts"
assert_contains "contracts canonical FLOW 2 CLARIFY" "FLOW 2[[:space:]]*\\| CLARIFY" "$contracts"
assert_contains "contracts canonical FLOW 3 DECIDE" "FLOW 3[[:space:]]*\\| DECIDE" "$contracts"
assert_contains "contracts keep GSD semver ownership" "GSD owns the project lifecycle" "$contracts"
assert_contains "contracts make release use GSD complete before SB release" "gsd:complete-milestone.*silver:create-release" "$contracts"

for file in \
  "$REPO_ROOT/skills/silver-feature/SKILL.md" \
  "$REPO_ROOT/skills/silver-ui/SKILL.md" \
  "$REPO_ROOT/skills/silver-devops/SKILL.md" \
  "$REPO_ROOT/skills/silver-bugfix/SKILL.md" \
  "$REPO_ROOT/skills/silver-research/SKILL.md" \
  "$REPO_ROOT/skills/silver-release/SKILL.md" \
  "$REPO_ROOT/skills/silver-migrate/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-feature/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-ui/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-devops/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-bugfix/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-research/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-release/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-migrate/SKILL.md"; do
  assert_not_contains "no stale silver:intel in ${file#$REPO_ROOT/}" "silver:intel" "$file"
  assert_not_contains "no stale INTEL/BRAINSTORM flow labels in ${file#$REPO_ROOT/}" "FLOW 2 \\(INTEL\\)|FLOW 3 \\(BRAINSTORM\\)" "$file"
  assert_not_contains "no stale EXPLORE/IDEATE flow labels in ${file#$REPO_ROOT/}" "EXPLORE|IDEATE" "$file"
  assert_not_contains "no stale PATH wording in ${file#$REPO_ROOT/}" "Build Path Chain|propose which PATH" "$file"
done

for file in "$template" "$root_rules" "$forge_template"; do
  assert_contains "template states GSD authority in ${file#$REPO_ROOT/}" "GSD remains the lifecycle authority" "$file"
  assert_contains "template uses gsd-scan in ${file#$REPO_ROOT/}" "gsd-scan" "$file"
  assert_contains "template keeps MultAI optional for research in ${file#$REPO_ROOT/}" "optional multi-AI only when user-requested" "$file"
  assert_not_contains "template has no silver:intel in ${file#$REPO_ROOT/}" "silver:intel" "$file"
done

for file in \
  "$REPO_ROOT/skills/silver-research/SKILL.md" \
  "$REPO_ROOT/forge/skills/silver-research/SKILL.md"; do
  assert_contains "research skill defaults to direct research in ${file#$REPO_ROOT/}" "Default mode is direct research" "$file"
  assert_contains "research skill keeps MultAI opt-in in ${file#$REPO_ROOT/}" "Only opt into MultAI" "$file"
  assert_contains "research skill requires current-task explicit request in ${file#$REPO_ROOT/}" "current task" "$file"
  assert_not_contains "research skill ignores stored-preference MultAI activation in ${file#$REPO_ROOT/}" "stored preference opts in|stored user workflow preference explicitly opts into MultAI for research" "$file"
  assert_not_contains "research skill no longer treats MultAI as mandatory in ${file#$REPO_ROOT/}" "Run the relevant MultAI research path" "$file"
done

assert_contains "local backlog item SB-B-1 resolved" "SB-B-1.*reconcile FLOW table" "$REPO_ROOT/docs/issues/BACKLOG.md"
assert_contains "local backlog item marked resolved" "Status:\\*\\* resolved in Phase 92" "$REPO_ROOT/docs/issues/BACKLOG.md"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
