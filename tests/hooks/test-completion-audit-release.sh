#!/usr/bin/env bash
# completion-audit release gates: matrices, CI status, quality sequence, RC matrix, release skill lists.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-ca.sh"

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
# validators come from the plugin root, never from the project tree (R1-15, R13-10)
write_exec "$PLUGIN/scripts/validate-launch-review.sh" 1
run_ca PreToolUse "$REL"
assert_contains "failing LAUNCH-REVIEW validator blocks" "$(message)" "LAUNCH-REVIEW.md does not satisfy"
write_exec "$PLUGIN/scripts/validate-launch-review.sh" 0
write_exec "$PLUGIN/scripts/validate-sentinel-skills-manifest.sh" 1
run_ca PreToolUse "$REL"
assert_contains "failing SENTINEL validator blocks" "$(message)" "SENTINEL per-skill manifest is incomplete"
write_exec "$PLUGIN/scripts/validate-sentinel-skills-manifest.sh" 0
run_ca PreToolUse "$REL"
assert_eq "passing validators: release allowed" "allow" "$(decision)"
run_ca PreToolUse "$REL" SB_REQUIRE_PRE_RELEASE_QUALITY_GATE=1
assert_eq "env switch also enables the quality gate" "allow " "$(decision) $([[ "$(decision)" == allow ]] || message)"
# a project-local validator that exits 0 cannot stand in for the plugin's, and a failing plugin one still blocks
mkdir -p "$PROJ/scripts"
write_exec "$PROJ/scripts/validate-launch-review.sh" 0
write_exec "$PLUGIN/scripts/validate-launch-review.sh" 1
run_ca PreToolUse "$REL"
assert_contains "project-tree validator does not replace the plugin validator" "$(message)" "LAUNCH-REVIEW.md does not satisfy"
write_exec "$PLUGIN/scripts/validate-launch-review.sh" 0
chmod -x "$PLUGIN/scripts/validate-launch-review.sh"
run_ca PreToolUse "$REL"
assert_contains "a non-executable plugin validator blocks instead of skipping" "$(message)" "validate-launch-review.sh is missing or not executable"
write_exec "$PLUGIN/scripts/validate-launch-review.sh" 0
chmod -x "$PLUGIN/scripts/validate-sentinel-skills-manifest.sh"
run_ca PreToolUse "$REL"
assert_contains "a non-executable SENTINEL validator blocks instead of skipping" "$(message)" "validate-sentinel-skills-manifest.sh is missing or not executable"
write_exec "$PLUGIN/scripts/validate-sentinel-skills-manifest.sh" 0

# RC matrix: the predicate is the plugin's own; markers must be live passes for the commit being released
mkproj rc '.release={require_rc_matrix:true}'
state inst-a inst-b silver-create-release
mkdir -p "$PROJ/scripts/lib"
printf 'sb_smoke_rc_markers_complete() { return 0; }\n' >"$PROJ/scripts/lib/pre-release-host-isolation.sh"
run_ca PreToolUse "$REL"
assert_contains "project-tree predicate that returns 0 does not satisfy the RC gate" "$(message)" "RC validation matrix incomplete"
SHA="$(git -C "$PROJ" rev-parse HEAD)"
RCDIR="$SB_RUNTIME_STATE_DIR/rc-validation"
rc_markers() { # rc_markers STATUS COMMIT
  mkdir -p "$RCDIR"
  local h m
  for h in cursor codex claude; do for m in fresh upgrade; do
    printf 'host=%s\nmode=%s\nstatus=%s\ncommit=%s\n' "$h" "$m" "$1" "$2" >"$RCDIR/$h-$m"
  done; done
}
rc_markers dry-run "$SHA"
run_ca PreToolUse "$REL"
assert_contains "dry-run markers do not satisfy the RC gate (R13-09)" "$(message)" "RC validation matrix incomplete"
rc_markers skip "$SHA"
run_ca PreToolUse "$REL"
assert_contains "all-skip markers do not satisfy the RC gate (R8-13)" "$(message)" "RC validation matrix incomplete"
rc_markers pass "0000000000000000000000000000000000000000"
run_ca PreToolUse "$REL"
assert_contains "markers for another commit do not satisfy the RC gate" "$(message)" "RC validation matrix incomplete"
rc_markers pass "$SHA"
run_ca PreToolUse "$REL"
assert_eq "live pass markers for this commit: allowed" "allow" "$(decision)"
run_ca PreToolUse "$REL" SB_REQUIRE_RC_MATRIX=1
assert_eq "env switch enables rc matrix" "allow" "$(decision)"
rc_markers skip "$SHA"
printf 'commit=%s\n' "$SHA" >"$RCDIR/skip-waiver"
run_ca PreToolUse "$REL"
assert_eq "skip markers with a waiver for this commit: allowed" "allow" "$(decision)"
rm -rf "$RCDIR"

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


tl_results
