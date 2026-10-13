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

assert_contains "router handles non-trivial bare intent" "most non-trivial bare user" "$router"
assert_contains "router states SB lifecycle authority" "SB is the lifecycle and quality orchestration engine" "$router"
assert_contains "router lists SB context/plan/execute/verify/ship" "sb:context.*sb:plan.*sb:execute.*sb:verify.*sb:ship" "$router"
assert_contains "router protects semver through SB workflows" "Do not edit version, ROADMAP, STATE, MILESTONES" "$router"

assert_contains "contracts define atomic flow catalog" "Atomic Flow Catalog" "$contracts"
assert_contains "contracts canonical FLOW 3 CLARIFY" "FLOW 3[[:space:]]*\\| CLARIFY" "$contracts"
assert_contains "contracts canonical FLOW 4 DECIDE" "FLOW 4[[:space:]]*\\| DECIDE" "$contracts"
assert_contains "contracts keep SB lifecycle ownership" "Silver Bullet owns the default software-engineering lifecycle" "$contracts"
assert_contains "contracts make ship use SB branch finish before SB ship" "sb:branch-finish.*sb:ship" "$contracts"

for file in \
  "$REPO_ROOT/skills/silver-feature/SKILL.md" \
  "$REPO_ROOT/skills/silver-ui/SKILL.md" \
  "$REPO_ROOT/skills/silver-devops/SKILL.md" \
  "$REPO_ROOT/skills/silver-bugfix/SKILL.md" \
  "$REPO_ROOT/skills/silver-deep-research/SKILL.md" \
  "$REPO_ROOT/skills/silver-release/SKILL.md"; do
  assert_not_contains "no stale sb:intel in ${file#$REPO_ROOT/}" "sb:intel" "$file"
  assert_not_contains "no stale INTEL/BRAINSTORM flow labels in ${file#$REPO_ROOT/}" "FLOW 2 \\(INTEL\\)|FLOW 3 \\(BRAINSTORM\\)" "$file"
  assert_not_contains "no stale EXPLORE/IDEATE flow labels in ${file#$REPO_ROOT/}" "EXPLORE|IDEATE" "$file"
  assert_not_contains "no stale PATH wording in ${file#$REPO_ROOT/}" "Build Path Chain|propose which PATH" "$file"
  assert_not_contains "no numbered step lists in ${file#$REPO_ROOT/}" "^## Step [0-9]" "$file"
done

for file in \
  "$REPO_ROOT/skills/silver-feature/SKILL.md" \
  "$REPO_ROOT/skills/silver-ui/SKILL.md" \
  "$REPO_ROOT/skills/silver-devops/SKILL.md" \
  "$REPO_ROOT/skills/silver-bugfix/SKILL.md" \
  "$REPO_ROOT/skills/silver-deep-research/SKILL.md" \
  "$REPO_ROOT/skills/silver-release/SKILL.md"; do
  assert_contains "composer references flow contracts in ${file#$REPO_ROOT/}" "composable-flows-contracts" "$file"
done

for file in \
  "$REPO_ROOT/skills/silver-feature/SKILL.md" \
  "$REPO_ROOT/skills/silver-ui/SKILL.md" \
  "$REPO_ROOT/skills/silver-devops/SKILL.md" \
  "$REPO_ROOT/skills/silver-bugfix/SKILL.md" \
  "$REPO_ROOT/skills/silver-release/SKILL.md"; do
  assert_contains "composer declares standard chain in ${file#$REPO_ROOT/}" "Standard composition chain" "$file"
done

assert_contains "deep research declares standard composition chain" "Standard Composition Chain" "$REPO_ROOT/skills/silver-deep-research/SKILL.md"

for file in \
  "$REPO_ROOT/skills/silver-feature/SKILL.md" \
  "$REPO_ROOT/skills/silver-ui/SKILL.md" \
  "$REPO_ROOT/skills/silver-devops/SKILL.md" \
  "$REPO_ROOT/skills/silver-bugfix/SKILL.md" \
  "$REPO_ROOT/skills/silver-deep-research/SKILL.md" \
  "$REPO_ROOT/skills/silver-release/SKILL.md"; do
  assert_not_contains "no Invoke sb: bloat in ${file#$REPO_ROOT/}" "[Ii]nvoke \`sb:" "$file"
done

assert_contains "release uses FLOW 18 vocabulary" "FLOW 18" "$REPO_ROOT/skills/silver-release/SKILL.md"
assert_not_contains "release avoids legacy UAT AUDIT label" "UAT AUDIT -> MILESTONE AUDIT" "$REPO_ROOT/skills/silver-release/SKILL.md"
assert_contains "contracts document RELEASE-UAT-AUDIT artifact" "RELEASE-UAT-AUDIT" "$contracts"
assert_contains "contracts document RELEASE-MILESTONE-AUDIT artifact" "RELEASE-MILESTONE-AUDIT" "$contracts"
assert_contains "release references RELEASE-UAT-AUDIT" "RELEASE-UAT-AUDIT" "$REPO_ROOT/skills/silver-release/SKILL.md"
assert_contains "release references RELEASE-MILESTONE-AUDIT" "RELEASE-MILESTONE-AUDIT" "$REPO_ROOT/skills/silver-release/SKILL.md"
assert_contains "release UAT audit maps to FLOW 12" "UAT audit.*12.*RELEASE-UAT-AUDIT" "$REPO_ROOT/skills/silver-release/SKILL.md"
assert_contains "release milestone audit maps to FLOW 18" "Milestone audit.*18.*RELEASE-MILESTONE-AUDIT" "$REPO_ROOT/skills/silver-release/SKILL.md"

assert_contains "contracts document runtime queue tokens" "Runtime Queue Tokens" "$contracts"

for file in "$REPO_ROOT/skills/silver-migrate/SKILL.md"; do
  assert_not_contains "no stale sb:intel in ${file#$REPO_ROOT/}" "sb:intel" "$file"
  assert_not_contains "no stale INTEL/BRAINSTORM flow labels in ${file#$REPO_ROOT/}" "FLOW 2 \\(INTEL\\)|FLOW 3 \\(BRAINSTORM\\)" "$file"
  assert_not_contains "no stale PATH wording in ${file#$REPO_ROOT/}" "Build Path Chain|propose which PATH" "$file"
done

for file in "$template" "$root_rules"; do
  assert_contains "template states SB lifecycle authority in ${file#$REPO_ROOT/}" "Silver Bullet owns the default lifecycle through SB-owned skills" "$file"
  assert_contains "template uses sb:scan in ${file#$REPO_ROOT/}" "sb:scan" "$file"
  assert_contains "template names search-cli for deep research in ${file#$REPO_ROOT/}" "search-cli" "$file"
  assert_not_contains "template has no sb:intel in ${file#$REPO_ROOT/}" "sb:intel" "$file"
done

assert_contains "deep research skill records nested V-loop discipline" "Nested SB Flow Discipline" "$REPO_ROOT/skills/silver-deep-research/SKILL.md"
assert_contains "deep research skill forbids Documents output" "FORBIDDEN: writing research output" "$REPO_ROOT/skills/silver-deep-research/SKILL.md"
assert_contains "DECIDE worker removes MultAI branch" "There is no MultAI branch" "$REPO_ROOT/templates/orchestrator-workers/DECIDE.md"

for file in \
  "$REPO_ROOT/skills/silver-feature/SKILL.md" \
  "$REPO_ROOT/skills/silver-ui/SKILL.md" \
  "$REPO_ROOT/skills/silver-devops/SKILL.md" \
  "$REPO_ROOT/skills/silver-bugfix/SKILL.md" \
  "$REPO_ROOT/skills/silver-deep-research/SKILL.md" \
  "$REPO_ROOT/skills/silver-release/SKILL.md"; do
  assert_not_contains "workflow does not route to missing SB-local MultAI skill in ${file#$REPO_ROOT/}" "sb:multai" "$file"
done

assert_contains "local backlog item SB-B-1 resolved" "SB-B-1.*reconcile FLOW table" "$REPO_ROOT/docs/issues/BACKLOG.md"
assert_contains "local backlog item marked resolved" "Status:\\*\\* resolved in Phase 92" "$REPO_ROOT/docs/issues/BACKLOG.md"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
