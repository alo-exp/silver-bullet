#!/usr/bin/env bash
# completion-audit delivery tier: enterprise/tier blocks, verdicts, ordering, artifacts, pre-ship, composer.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-ca.sh"

# ── enterprise policy and enforcement tier ───────────────────────────────────
mkproj ep
state inst-a inst-b
run_ca PreToolUse "$PR" -u SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL
assert_eq "no human approval: enterprise policy denies PR creation" "deny" "$(decision)"
assert_contains "enterprise policy message" "$(message)" "ENTERPRISE POLICY BLOCK"
run_ca PreToolUse 'git commit -m x' -u SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL
assert_eq "enterprise policy does not apply to intermediate commits" "allow" "$(decision)"
run_ca PreToolUse "$PR"
assert_contains "approved delivery passes" "$(message)" "Workflow compliance verified"

mkproj tier '.sb_enforcement_tier=0'
state inst-a inst-b
run_ca PreToolUse "$PR" -u SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE
assert_eq "tier 0 blocks final delivery" "deny" "$(decision)"
assert_contains "tier block message" "$(message)" "enforcement inactive"

# ── verdict messages ─────────────────────────────────────────────────────────
mkproj verdict '.skills.required_deploy=["inst-a","inst-b","ghost-skill"]'
state inst-a
run_ca PreToolUse "$PR"
assert_contains "missing required skill blocks" "$(message)" "COMPLETION BLOCKED"
assert_contains "block names the missing skill" "$(message)" "/inst-b"
assert_contains "block names the change class" "$(message)" "Change class:"
assert_contains "block lists uninstalled skills as ignored" "$(message)" "ghost-skill (not installed anywhere invocable)"
state inst-a inst-b
run_ca PreToolUse "$PR"
assert_eq "all installed skills present: allowed" "allow" "$(decision)"
assert_contains "success mentions ignored skills" "$(message)" "Ignored required skills"

# ordering of the review triad
mkproj order '.skills.required_deploy=["inst-a"]'
state inst-a silver-review silver-review-request
mkdir -p "$PROJ/.planning"
printf '# Review\n\n## Findings\n\nNo issues found - review completed with evidence.\n\nstatus: passed\n' >"$PROJ/.planning/REVIEW.md"
printf '## Round 1\nFindings: advisory only - addressed.\n\n## Round 2\nNo findings - clean pass.\n' >"$PROJ/.planning/REVIEW-ROUNDS.md"
run_ca PreToolUse "$PR"
assert_contains "review before request is an ordering block" "$(message)" "ORDERING BLOCKED"
state inst-a silver-review-triage silver-review
run_ca PreToolUse "$PR"
assert_contains "triage before review is flagged" "$(message)" "silver-review-triage was run BEFORE /silver-review"
state inst-a silver-review-triage silver-review-request
run_ca PreToolUse "$PR"
assert_contains "triage before request is flagged" "$(message)" "silver-review-triage was run BEFORE /silver-review-request"

# artifact existence
mkproj artifact '.skills.required_deploy=["inst-a"]'
state inst-a silver-execute silver-verify silver-review silver-secure silver-validate
run_ca PreToolUse "$PR"
assert_contains "missing lifecycle artifacts block" "$(message)" "ARTIFACT BLOCKED"
for want in "STATE.md is absent" "UAT/VERIFICATION" "no REVIEW artifact" "no SECURITY artifact" "no VALIDATION artifact"; do
  assert_contains "artifact block: $want" "$(message)" "$want"
done
state inst-a
rm -f "$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
mkproj stale '.skills.required_deploy=["inst-a","verify-tests"]'
state inst-a verify-tests
run_ca PreToolUse "$PR"
assert_contains "stale verify-tests marker blocks" "$(message)" "TEST GATE STALE"
printf 'verified\n' >"$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"

# pre-ship adversarial marker
mkpreship() {
  mkdir -p "$PROJ/.planning/phases/01-x"
  printf '# Plan\n\nreal plan body\n' >"$PROJ/.planning/phases/01-x/PLAN.md"
  printf '# Verification\n\nstatus: passed\n\nreal output\n' >"$PROJ/.planning/phases/01-x/VERIFICATION.md"
}
mkproj preship '.skills.required_deploy=["inst-a"]'
mkpreship
state inst-a
run_ca PreToolUse "$PR"
assert_contains "pre-ship marker missing, quality gates never run" "$(message)" "/silver-quality-gates"
state inst-a silver-quality-gates
run_ca PreToolUse "$PR"
assert_contains "pre-ship marker missing after quality gates ran" "$(message)" "/silver-quality-gates-adversarial"
state inst-a silver-quality-gates-adversarial
run_ca PreToolUse "$PR"
assert_eq "pre-ship marker recorded: allowed" "allow" "$(decision)"
mkproj preship-devops '.skills.required_deploy=["inst-a"] | .project.active_workflow="devops-cycle"'
mkpreship
state inst-a
run_ca PreToolUse "$PR"
assert_contains "devops pre-ship: quality gates never run" "$(message)" "/devops-quality-gates"
assert_not_contains "devops pre-ship: not the adversarial variant yet" "$(message)" "devops-quality-gates-adversarial"
state inst-a devops-quality-gates
run_ca PreToolUse "$PR"
assert_contains "devops pre-ship: adversarial marker missing" "$(message)" "/devops-quality-gates-adversarial"

# main branch drops branch-finishing skills
mkproj onmain '.skills.required_deploy=["inst-a","silver-branch-finish","finishing-a-development-branch"]'
git -C "$PROJ" checkout -q main
state inst-a
run_ca PreToolUse "$PR"
assert_eq "branch finishing is not required on main" "allow" "$(decision)"
assert_not_contains "no branch-finish demand on main" "$(message)" "branch-finish"

# ── composer / devops selection ──────────────────────────────────────────────
WFID=20260101T000000Z-abc123-silver-devops
mkproj composer '.skills.required_deploy=["inst-a"] | .skills.required_deploy_devops=["inst-b"]'
mkdir -p "$PROJ/.planning/workflows"
printf 'composer: silver-devops\n## Flow Log\n| 1 | a | complete |\n' >"$PROJ/.planning/workflows/$WFID.md"
state inst-a
run_ca PreToolUse "$PR" SB_WORKFLOW_ID="$WFID"
assert_contains "devops composer switches to the devops deploy list" "$(message)" "/inst-b"
assert_not_contains "devops list replaces the standard one" "$(message)" "/inst-a"
printf 'composer: sb:Devops\n## Flow Log\n| 1 | a | complete |\n' >"$PROJ/.planning/workflows/$WFID.md"
run_ca PreToolUse "$PR" SB_WORKFLOW_ID="$WFID"
assert_contains "composer slug is normalised (namespace, case)" "$(message)" "/inst-b"
printf 'composer: silver-feature\n## Flow Log\n| 1 | a | complete |\n' >"$PROJ/.planning/workflows/$WFID.md"
state inst-b
run_ca PreToolUse "$PR" SB_WORKFLOW_ID="$WFID"
assert_contains "other composers keep the standard list" "$(message)" "/inst-a"
state inst-a
printf 'composer: silver-devops\n## Flow Log\n| 1 | a | complete |\n' >"$PROJ/.planning/workflows/$WFID.md"
REAL_AWK="$(command -v awk)"; export REAL_AWK
tl_stub awk '[[ "$*" == *'^composer'* ]] && exit 1; exec "$REAL_AWK" "$@"'
state inst-b
run_ca PreToolUse "$PR" SB_WORKFLOW_ID="$WFID"
assert_contains "failing awk while reading the composer keeps the standard list" "$(message)" "/inst-a"
rm -f "$TL_BIN/awk"
run_ca PreToolUse "$PR" SB_WORKFLOW_ID="$WFID"
assert_eq "with awk working the same devops composer uses its own list" "allow" "$(decision)"
printf 'composer: silver-feature\n## Flow Log\n| 1 | a | complete |\n' >"$PROJ/.planning/workflows/$WFID.md"
state inst-a
run_ca PreToolUse "export SB_WORKFLOW_ID=$WFID; $PR"
assert_eq "workflow id taken from the command assignment" "allow" "$(decision)"

# ── ordering and review states in more combinations ──────────────────────────
mkproj combos '.skills.required_deploy=["inst-a","ghost-skill"]'
printf '# Review\n\n## Findings\n\nNo issues found - review completed with evidence.\n\nstatus: passed\n' >"$PROJ/.planning-review.tmp" && mkdir -p "$PROJ/.planning" && mv "$PROJ/.planning-review.tmp" "$PROJ/.planning/REVIEW.md"
printf '## Round 1\nFindings: advisory only - addressed.\n\n## Round 2\nNo findings - clean pass.\n' >"$PROJ/.planning/REVIEW-ROUNDS.md"
state inst-a silver-review-request
run_ca PreToolUse "$PR"
assert_eq "request without review is not an ordering issue" "allow" "$(decision)"
state inst-a silver-review
run_ca PreToolUse "$PR"
assert_eq "review without triage is not an ordering issue" "allow" "$(decision)"
state inst-a silver-review-request silver-review-triage
run_ca PreToolUse "$PR"
assert_eq "request then triage is in order" "allow" "$(decision)"
state inst-a silver-review silver-review-request
run_ca PreToolUse "$PR"
assert_contains "ordering block lists ignored skills" "$(message)" "ghost-skill"
assert_contains "ordering block header" "$(message)" "ORDERING BLOCKED"
mkproj combos2 '.skills.required_deploy=["inst-a","inst-b"]'
printf '# Review\n\n## Findings\n\nNo issues found - review completed with evidence.\n\nstatus: passed\n' >"$TL_TMP/rev.md"; mkdir -p "$PROJ/.planning"; cp "$TL_TMP/rev.md" "$PROJ/.planning/REVIEW.md"
printf '## Round 1\nFindings: advisory only - addressed.\n\n## Round 2\nNo findings - clean pass.\n' >"$PROJ/.planning/REVIEW-ROUNDS.md"
state inst-a silver-review silver-review-request
run_ca PreToolUse "$PR"
assert_contains "missing skills block also reports ordering issues" "$(message)" "Ordering issues detected"

# stale marker and artifact blocks with ignored skills in the message
mkproj stale2 '.skills.required_deploy=["inst-a","verify-tests","ghost-skill"]'
rm -f "$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
state inst-a verify-tests
run_ca PreToolUse "$PR"
assert_contains "stale marker block lists ignored skills" "$(message)" "ghost-skill"
assert_contains "stale marker block header" "$(message)" "TEST GATE STALE"
printf 'verified\n' >"$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
mkproj art2 '.skills.required_deploy=["inst-a","ghost-skill"]'
state inst-a silver-execute
run_ca PreToolUse "$PR"
assert_contains "artifact block lists ignored skills" "$(message)" "ghost-skill"
assert_contains "artifact block header" "$(message)" "ARTIFACT BLOCKED"

# find_planning_artifact against a real .planning tree
mkproj find1 '.skills.required_deploy=["inst-a"]'
mkdir -p "$PROJ/.planning/phases/01-x"
state inst-a silver-verify silver-secure silver-validate
run_ca PreToolUse "$PR"
assert_contains "empty .planning still lacks artifacts" "$(message)" "ARTIFACT BLOCKED"
echo ok >"$PROJ/.planning/phases/01-x/01-UAT.md"
echo ok >"$PROJ/.planning/phases/01-x/01-SECURITY.md"
echo ok >"$PROJ/.planning/phases/01-x/01-VALIDATION.md"
run_ca PreToolUse "$PR"
assert_eq "phase artifacts found by pattern satisfy the markers" "allow" "$(decision)"
rm -f "$PROJ/.planning/phases/01-x/01-UAT.md"
printf '# Verification\n\n```bash\n$ npm test\nTests: 3 passed, 3 total\n```\n' >"$PROJ/.planning/VERIFICATION.md"
run_ca PreToolUse "$PR"
assert_eq "VERIFICATION.md satisfies the verify marker" "allow" "$(decision)"
mkproj find2 '.skills.required_deploy=["inst-a"]'
mkdir -p "$PROJ/.planning"
echo ok >"$PROJ/.planning/UAT.md"
echo ok >"$PROJ/.planning/SECURITY.md"
echo ok >"$PROJ/.planning/VALIDATION.md"
state inst-a silver-verify silver-secure silver-validate
run_ca PreToolUse "$PR"
assert_eq "top-level artifacts satisfy the markers" "allow" "$(decision)"


tl_results
