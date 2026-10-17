#!/usr/bin/env bash
# hooks/completion-audit.sh delivery tier: enterprise/enforcement-tier blocks, release gates,
# composer/devops selection, release skill lists, pre-ship markers and jq-less behaviour.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

HOOK="$TL_REPO_ROOT/hooks/completion-audit.sh"
CFG_VERSION="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

SKILLS="$TL_TMP/skills"
for s in inst-a inst-b verify-tests devops-quality-gates silver-blast-radius; do
  mkdir -p "$SKILLS/skills/$s"; printf -- '---\nname: %s\n---\n' "$s" >"$SKILLS/skills/$s/SKILL.md"
done

STATE="$SB_RUNTIME_STATE_DIR/state-test"
QG="$SB_RUNTIME_STATE_DIR/quality-gate-test"
export SILVER_BULLET_STATE_FILE="$STATE"
export SILVER_BULLET_SKILL_ROOTS="$SKILLS"
export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
export SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/verify-tests-test"
export SILVER_BULLET_QUALITY_GATE_STATE_FILE="$QG"
printf 'verified\n' >"$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"

mkproj() {
  PROJ="$TL_TMP/$1"
  tl_git_repo "$PROJ"
  printf '# Silver Bullet\n' >"$PROJ/silver-bullet.md"
  jq -n --arg v "$CFG_VERSION" '{config_version:$v, sb_initiated:true,
      project:{active_workflow:"full-dev-cycle"},
      skills:{required_planning:["inst-a"], required_deploy:["inst-a","inst-b"]}}' \
    | jq "${2:-.}" >"$PROJ/.silver-bullet.json"
  GH_RUN_LIST_OVERRIDE="$(jq -cn --arg sha "$(git -C "$PROJ" rev-parse HEAD)" \
    '[{workflowName:"CI",status:"completed",conclusion:"success",headSha:$sha,createdAt:"2026-05-07T00:00:01Z"}]')"
  export GH_RUN_LIST_OVERRIDE
  : >"$STATE"
  rm -f "$SB_RUNTIME_STATE_DIR"/release-live-matrix "$SB_RUNTIME_STATE_DIR"/e2e-live-matrix "$SB_RUNTIME_STATE_DIR"/inline-e2e-matrix "$QG"
}
state() { printf '%s\n' "$@" >"$STATE"; }
run_ca() {
  local event="$1" cmd="$2"
  shift 2
  local json
  json="$(jq -cn --arg e "$event" --arg c "$cmd" '{hook_event_name:$e,tool_name:"Bash",tool_input:{command:$c}}')"
  tl_run_stdin "$json" env "$@" bash -c 'cd "$1" && exec bash "$2"' _ "${RUN_DIR:-$PROJ}" "$HOOK"
}
decision() {
  if [[ -z "$TL_OUT" ]]; then echo none; return; fi
  jq -r 'if .hookSpecificOutput.permissionDecision then .hookSpecificOutput.permissionDecision
         elif .decision then .decision else "allow" end' <<<"$TL_OUT" 2>/dev/null || echo invalid
}
message() { jq -r '.reason // .hookSpecificOutput.permissionDecisionReason // .hookSpecificOutput.message // ""' <<<"$TL_OUT"; }
release_ready() {
  printf 'matrix=claude-only\n' >"$SB_RUNTIME_STATE_DIR/release-live-matrix"
  printf 'matrix=claude-only\n' >"$SB_RUNTIME_STATE_DIR/e2e-live-matrix"
  printf 'matrix=inline-full-surface\n' >"$SB_RUNTIME_STATE_DIR/inline-e2e-matrix"
  printf '%s\n' adversarial-review-clean sentinel-skills-clean quality-gate-stage-3 full-test-suite-rerun >"$QG"
}
# write_exec <file> <exit-code>: install an executable validator atomically (write, chmod, rename)
# so an immediate exec cannot race an open writer ("Text file busy").
write_exec() {
  printf '#!/usr/bin/env bash\nexit %s\n' "$2" >"$1.tmp"
  chmod +x "$1.tmp"
  mv -f "$1.tmp" "$1"
}
PR='gh pr create --fill'

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
run_ca PreToolUse "export SB_WORKFLOW_ID=$WFID; $PR"
assert_eq "workflow id taken from the command assignment" "allow" "$(decision)"

# ── release gates ────────────────────────────────────────────────────────────
REL='gh release create v1.0.0'
mkproj rel '.release={require_plugin_runtime_matrix:true} | .skills.required_release=["inst-b"]'
state inst-a inst-b
run_ca PreToolUse "$REL"
assert_contains "no matrix files: release blocked" "$(message)" "plugin-runtime release matrix"
for f in release-live-matrix e2e-live-matrix inline-e2e-matrix; do printf 'something else\n' >"$SB_RUNTIME_STATE_DIR/$f"; done
run_ca PreToolUse "$REL"
assert_contains "matrix files without a matrix= line: blocked" "$(message)" "plugin-runtime release matrix"
ln -sf /dev/null "$SB_RUNTIME_STATE_DIR/release-live-matrix.lnk"
release_ready
run_ca PreToolUse "$REL"
assert_eq "complete matrix: release allowed" "allow" "$(decision)"
run_ca PreToolUse "$REL" -u GH_RUN_LIST_OVERRIDE
assert_contains "gh unavailable: cannot verify CI" "$(message)" "Unable to verify GitHub Actions status"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE='not json'
assert_contains "invalid CI payload" "$(message)" "payload for commit"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE='[]'
assert_contains "no CI runs for the commit" "$(message)" "No GitHub Actions runs were found"
SHA="$(git -C "$PROJ" rev-parse HEAD)"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="[{\"workflowName\":\"CI\",\"status\":\"in_progress\",\"conclusion\":\"\",\"headSha\":\"$SHA\",\"createdAt\":\"2026-05-07T00:00:01Z\"}]"
assert_contains "running CI is listed" "$(message)" "• CI — status=in_progress"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="[{\"workflowName\":\"\",\"status\":\"\",\"conclusion\":\"\",\"headSha\":\"$SHA\",\"createdAt\":\"\"}]"
assert_contains "run with an empty name is blocked without crashing" "$(message)" "still running or not green"

# release without any commit
EMPTY="$TL_TMP/nocommit"; mkdir -p "$EMPTY"
printf '# SB\n' >"$EMPTY/silver-bullet.md"; cp "$PROJ/.silver-bullet.json" "$EMPTY/"
RUN_DIR="$EMPTY" run_ca PreToolUse "$REL"
assert_contains "no git HEAD: release blocked" "$(message)" "Unable to determine the current HEAD commit"
EMPTYREPO="$TL_TMP/nocommit-repo"; mkdir -p "$EMPTYREPO"; git -C "$EMPTYREPO" init -q
printf '# SB\n' >"$EMPTYREPO/silver-bullet.md"; cp "$PROJ/.silver-bullet.json" "$EMPTYREPO/"
RUN_DIR="$EMPTYREPO" run_ca PreToolUse "$REL"
assert_eq "repository without commits: release still blocked" "deny" "$(decision)"
unset RUN_DIR

# pre-release quality sequence
mkproj qg '.release={require_pre_release_quality_gate:true}'
state inst-a inst-b silver-create-release
run_ca PreToolUse "$REL"
assert_contains "missing quality gate state" "$(message)" "pre-release quality sequence has not been completed"
printf 'adversarial-review-clean\n' >"$QG"
run_ca PreToolUse "$REL"
assert_contains "partial quality gate state" "$(message)" "pre-release quality sequence has not been completed"
release_ready
mkdir -p "$PROJ/scripts"
write_exec "$PROJ/scripts/validate-launch-review.sh" 1
run_ca PreToolUse "$REL"
assert_contains "failing LAUNCH-REVIEW validator blocks" "$(message)" "LAUNCH-REVIEW.md does not satisfy"
write_exec "$PROJ/scripts/validate-launch-review.sh" 0
write_exec "$PROJ/scripts/validate-sentinel-skills-manifest.sh" 1
run_ca PreToolUse "$REL"
assert_contains "failing SENTINEL validator blocks" "$(message)" "SENTINEL per-skill manifest is incomplete"
write_exec "$PROJ/scripts/validate-sentinel-skills-manifest.sh" 0
run_ca PreToolUse "$REL"
assert_eq "passing validators: release allowed" "allow" "$(decision)"
run_ca PreToolUse "$REL" SB_REQUIRE_PRE_RELEASE_QUALITY_GATE=1
assert_eq "env switch also enables the quality gate" "allow " "$(decision) $([[ "$(decision)" == allow ]] || message)"

# RC matrix
mkproj rc '.release={require_rc_matrix:true}'
state inst-a inst-b silver-create-release
run_ca PreToolUse "$REL"
assert_contains "rc matrix required, helper missing" "$(message)" "RC validation matrix incomplete"
mkdir -p "$PROJ/scripts/lib"
printf 'sb_smoke_rc_markers_complete() { return 1; }\n' >"$PROJ/scripts/lib/pre-release-host-isolation.sh"
run_ca PreToolUse "$REL"
assert_contains "rc markers incomplete" "$(message)" "RC validation matrix incomplete"
printf 'sb_smoke_rc_markers_complete() { return 0; }\n' >"$PROJ/scripts/lib/pre-release-host-isolation.sh"
run_ca PreToolUse "$REL"
assert_eq "rc markers complete: allowed" "allow" "$(decision)"
run_ca PreToolUse "$REL" SB_REQUIRE_RC_MATRIX=1
assert_eq "env switch enables rc matrix" "allow" "$(decision)"

# release skill lists
mkproj relskills '.skills.required_release=["inst-b"]'
state inst-a
run_ca PreToolUse "$REL"
assert_contains "configured release skill is required" "$(message)" "/inst-b"
mkproj relbad '.skills.required_release="oops"'
state inst-a inst-b
run_ca PreToolUse "$REL"
assert_contains "unreadable release list falls back to the default" "$(message)" "silver-create-release"
mkproj reldevops '.project.active_workflow="devops-cycle" | .skills.required_deploy_devops=["inst-a"] | .skills.required_release_devops=["inst-b"]'
state inst-a
run_ca PreToolUse "$REL"
assert_contains "devops release list is used" "$(message)" "/inst-b"
mkproj reldevopsbad '.project.active_workflow="devops-cycle" | .skills.required_deploy_devops=["inst-a"] | .skills.required_release_devops="oops"'
state inst-a
run_ca PreToolUse "$REL"
assert_contains "unreadable devops release list falls back to the default" "$(message)" "silver-create-release"
mkproj reldevopsdefault '.project.active_workflow="devops-cycle" | .skills.required_deploy_devops=["inst-a"]'
state inst-a
run_ca PreToolUse "$REL"
assert_contains "devops release default list applies" "$(message)" "silver-create-release"

# ── more release matrix variants and CI listings ─────────────────────────────
mkproj matrices '.release={require_plugin_runtime_matrix:true} | .skills.required_release=["inst-b"]'
state inst-a inst-b
set_matrix() { printf 'matrix=%s\n' "$1" >"$SB_RUNTIME_STATE_DIR/release-live-matrix"; printf 'matrix=%s\n' "$2" >"$SB_RUNTIME_STATE_DIR/e2e-live-matrix"; printf 'matrix=%s\n' "$3" >"$SB_RUNTIME_STATE_DIR/inline-e2e-matrix"; }
set_matrix full-claude-codex full-claude-codex inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "full claude+codex matrix accepted" "allow" "$(decision)"
set_matrix codex-only codex-only inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "codex-only matrix accepted" "allow" "$(decision)"
set_matrix cursor-smoke codex-only inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "cursor smoke + codex e2e accepted" "allow" "$(decision)"
set_matrix cursor-smoke claude-only inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "inconsistent matrix pair rejected" "deny" "$(decision)"
set_matrix claude-only claude-only inline-partial
run_ca PreToolUse "$REL"; assert_eq "inline matrix must be the full surface" "deny" "$(decision)"
set_matrix claude-only claude-only inline-full-surface
SHA="$(git -C "$PROJ" rev-parse HEAD)"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="[{\"workflowName\":\"CI\",\"status\":\"in_progress\",\"headSha\":\"$SHA\",\"createdAt\":\"1\"},{\"workflowName\":\"Lint\",\"status\":\"completed\",\"conclusion\":\"failure\",\"headSha\":\"$SHA\",\"createdAt\":\"2\"},{\"workflowName\":\"Old\",\"status\":\"completed\",\"conclusion\":\"failure\",\"headSha\":\"other\",\"createdAt\":\"3\"}]"
assert_contains "several non-green workflows are all listed" "$(message)" "• Lint — status=completed conclusion=failure"
assert_contains "first non-green workflow listed" "$(message)" "• CI — status=in_progress"
assert_not_contains "runs for other commits are ignored" "$(message)" "• Old"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="[{\"workflowName\":\"CI\",\"status\":\"completed\",\"conclusion\":\"failure\",\"headSha\":\"$SHA\",\"createdAt\":\"1\"},{\"workflowName\":\"CI\",\"status\":\"completed\",\"conclusion\":\"success\",\"headSha\":\"$SHA\",\"createdAt\":\"2\"}]"
assert_eq "only the latest run per workflow counts" "allow" "$(decision)"

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

# ── evidence schema warn-first mode ──────────────────────────────────────────
mkproj evidence '.skills.required_deploy=["inst-a"]'
mkdir -p "$PROJ/scripts/lib" "$PROJ/.planning/phases/056-test"
cp "$TL_REPO_ROOT/scripts/validate-evidence-findings.py" "$TL_REPO_ROOT/scripts/validate-evidence-findings.sh" "$PROJ/scripts/"
cp "$TL_REPO_ROOT/scripts/lib/evidence_common.py" "$PROJ/scripts/lib/"
cat >"$PROJ/.planning/phases/056-test/DOMAIN-AUDIT.md" <<'MD'
# Domain Audit

## Findings

| domain | scope | severity | confidence | evidence | finding |
|--------|-------|----------|------------|----------|---------|
| code-health | src/app.ts | BLOCK | HIGH | src/app.ts:1 | missing required columns |
MD
state inst-a
run_ca PreToolUse "$PR" SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=0
assert_eq "warn mode does not block" "allow" "$(decision)"
assert_contains "warning is appended to the success message" "$(message)" "EVIDENCE SCHEMA"
assert_contains "success headline kept" "$(message)" "Workflow compliance verified"
run_ca PreToolUse "$PR" SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1
assert_contains "strict mode blocks" "$(message)" "EVIDENCE SCHEMA GATE"
jq '.skills.required_deploy=["inst-a","ghost-skill"]' "$PROJ/.silver-bullet.json" >"$PROJ/c.tmp" && mv "$PROJ/c.tmp" "$PROJ/.silver-bullet.json"
run_ca PreToolUse "$PR" SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=0
assert_contains "warning joins the ignored-skills note" "$(message)" "ghost-skill"
assert_contains "warning text follows the ignored note" "$(message)" "finding tables deviate"

# ── jq missing ───────────────────────────────────────────────────────────────
mkproj nojq
NOJQ="$(tl_path_without jq)"
run_ca PostToolUse "$PR" PATH="$NOJQ"
assert_eq "initiated project without jq: delivery blocked (post event format)" "block" "$(decision)"
assert_contains "jq block explains the cause" "$(message)" "jq is required"
run_ca PreToolUse 'git commit -m x' PATH="$NOJQ"
assert_eq "event type cannot be read without jq: block format is used" "block" "$(decision)"
NOJQPY="$(tl_path_without jq python3)"
run_ca PostToolUse "$PR" PATH="$NOJQPY"
assert_contains "no jq and no python3: static block reason" "$TL_OUT" '"enforcement blocked"'
RUN_DIR="$TL_TMP/noproj-nojq"; mkdir -p "$RUN_DIR"
run_ca PostToolUse 'git commit -m x' PATH="$NOJQ"
assert_eq "uninitiated dir, delivery text without jq: still blocked" "block" "$(decision)"
run_ca PostToolUse 'ls -la' PATH="$NOJQ"
assert_contains "uninitiated dir, other command: inactive notice" "$TL_OUT" "ENFORCEMENT INACTIVE"
unset RUN_DIR
mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q
RUN_DIR="$TL_TMP/gitonly/sub" run_ca PostToolUse 'ls' PATH="$NOJQ"
assert_contains "no config under a git root without jq: inactive notice" "$TL_OUT" "ENFORCEMENT INACTIVE"
mkdir -p "$PROJ/deep/er"
RUN_DIR="$PROJ/deep/er" run_ca PostToolUse "$PR" PATH="$NOJQ"
assert_eq "config found by walking up without jq" "block" "$(decision)"

tl_results
