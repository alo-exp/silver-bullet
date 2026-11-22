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
  for h in codex claude; do for m in fresh upgrade; do
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
set_matrix() { printf 'matrix=%s\n' "$1" >"$SB_RUNTIME_STATE_DIR/release-live-matrix"; printf 'matrix=%s\n' "$2" >"$SB_RUNTIME_STATE_DIR/e2e-live-matrix"; printf 'matrix=%s\ncommit=%s\n' "$3" "$(git -C "$PROJ" rev-parse HEAD)" >"$SB_RUNTIME_STATE_DIR/inline-e2e-matrix"; }
set_matrix full-claude-codex full-claude-codex inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "full claude+codex matrix accepted" "allow" "$(decision)"
set_matrix codex-only codex-only inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "codex-only matrix accepted" "allow" "$(decision)"
set_matrix cursor-smoke codex-only inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "the retired cursor-smoke release marker is rejected" "deny" "$(decision)"
set_matrix codex-only claude-only inline-full-surface
run_ca PreToolUse "$REL"; assert_eq "inconsistent matrix pair rejected" "deny" "$(decision)"
set_matrix claude-only claude-only inline-partial
run_ca PreToolUse "$REL"; assert_eq "inline matrix must be the full surface" "deny" "$(decision)"
# ── R14-16: the inline marker must be bound to the tree being released ─────────────────────────────
INL="$SB_RUNTIME_STATE_DIR/inline-e2e-matrix"
GC=(git -C "$PROJ" -c user.email=t@e.x -c user.name=t)
# a project carrying the release-surface files at the version the matrix ran on
mkdir -p "$PROJ/.claude-plugin" "$PROJ/plugins/silver-bullet/.codex-plugin" "$PROJ/templates" "$PROJ/hooks" "$PROJ/site/x" "$PROJ/docs" "$PROJ/.planning/enterprise-e2e"
printf '{"name":"sb","version":"1.0.0"}\n' >"$PROJ/package.json"
printf '{"name":"sb","version":"1.0.0","skills":"./skills"}\n' >"$PROJ/.claude-plugin/plugin.json"
printf '{"plugins":[{"name":"silver-bullet","version":"1.0.0","source":{"ref":"v1.0.0","path":"."}}]}\n' >"$PROJ/.claude-plugin/marketplace.json"
printf '{"version":"1.0.0","config_version":"1.0.0","hooks":"./hooks/hooks.json"}\n' >"$PROJ/plugins/silver-bullet/.codex-plugin/plugin.json"
printf '{"config_version":"1.0.0","skills":{"required_planning":["a"]}}\n' >"$PROJ/templates/silver-bullet.config.json.default"
printf '#!/bin/sh\n' >"$PROJ/hooks/gate.sh"; printf '<html>1.0.0</html>\n' >"$PROJ/site/x/index.html"; printf '#!/bin/sh\n' >"$PROJ/site/x/run.sh"
printf 'notes\n' >"$PROJ/CHANGELOG.md"
"${GC[@]}" add -A; "${GC[@]}" commit -q -m "release surface baseline"
set_matrix claude-only claude-only inline-full-surface
OLD_SHA="$(git -C "$PROJ" rev-parse HEAD)"
BASE_BRANCH="$(git -C "$PROJ" rev-parse --abbrev-ref HEAD)"
printf 'matrix=inline-full-surface\n' >"$INL"
run_ca PreToolUse "$REL"; assert_eq "marker without commit= is rejected (fail closed)" "deny" "$(decision)"
assert_contains "the block says the commit is required" "$(message)" "commit= naming the commit the matrix ran on"
printf 'matrix=inline-full-surface\ncommit=HEAD\n' >"$INL"
run_ca PreToolUse "$REL"; assert_eq "malformed commit= (not a sha) is rejected" "deny" "$(decision)"
printf 'matrix=inline-full-surface\ncommit=%s\n' "${OLD_SHA:0:12}" >"$INL"
run_ca PreToolUse "$REL"; assert_eq "abbreviated commit= is rejected" "deny" "$(decision)"
printf 'matrix=inline-full-surface\ncommit=%s\n' "$OLD_SHA" >"$INL"
green() { printf '[{"workflowName":"CI","status":"completed","conclusion":"success","headSha":"%s","createdAt":"1"}]' "$(git -C "$PROJ" rev-parse HEAD)"; }
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="$(green)"; assert_eq "commit= equal to the released commit is accepted" "allow" "$(decision)"
# variant NAME EXPECT SETUP: a release commit on a throw-away branch from the matrix commit, judged by the real gate
variant() {
  local name="$1" expect="$2" setup="$3"
  git -C "$PROJ" checkout -q -b "variant-$$-$RANDOM" "$OLD_SHA"
  ( cd "$PROJ" && eval "$setup" )
  "${GC[@]}" add -A; "${GC[@]}" commit -q -m "variant" --allow-empty
  printf 'matrix=inline-full-surface\ncommit=%s\n' "$OLD_SHA" >"$INL"
  run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="$(green)"
  assert_eq "$name" "$expect" "$(decision)"
  git -C "$PROJ" checkout -q -f "$BASE_BRANCH"
}
# accepted: what the release process itself rewrites
variant "a version-only bump of every manifest, the changelog, a site page and the ledger is accepted" allow '
jq ".version=\"1.1.0\"" package.json >p.tmp && mv p.tmp package.json
jq ".version=\"1.1.0\"" .claude-plugin/plugin.json >p.tmp && mv p.tmp .claude-plugin/plugin.json
jq ".plugins[0].version=\"1.1.0\" | .plugins[0].source.ref=\"v1.1.0\"" .claude-plugin/marketplace.json >p.tmp && mv p.tmp .claude-plugin/marketplace.json
jq ".version=\"1.1.0\" | .config_version=\"1.1.0\"" plugins/silver-bullet/.codex-plugin/plugin.json >p.tmp && mv p.tmp plugins/silver-bullet/.codex-plugin/plugin.json
jq ".config_version=\"1.1.0\"" templates/silver-bullet.config.json.default >p.tmp && mv p.tmp templates/silver-bullet.config.json.default
printf "more notes\n" >>CHANGELOG.md; printf "<html>1.1.0</html>\n" >site/x/index.html
printf "ledger\n" >.planning/enterprise-e2e/ROUND-9-LEDGER.md'
variant "a release commit with an empty file diff is accepted" allow ':'
# rejected: anything else, however it is dressed up
variant "a hook moved into site/ (a rename shows only the new path) is rejected" deny 'mkdir -p site/y && git mv hooks/gate.sh site/y/gate.sh'
variant "a Codex manifest whose hooks path is redirected into site/ is rejected" deny 'jq ".version=\"1.1.0\" | .hooks=\"./site/hooks.json\"" plugins/silver-bullet/.codex-plugin/plugin.json >p.tmp && mv p.tmp plugins/silver-bullet/.codex-plugin/plugin.json'
variant "a plugin manifest whose skills path is redirected is rejected" deny 'jq ".skills=\"./site/skills\"" .claude-plugin/plugin.json >p.tmp && mv p.tmp .claude-plugin/plugin.json'
variant "a config template default change (required skills) is rejected" deny 'jq ".skills.required_planning=[]" templates/silver-bullet.config.json.default >p.tmp && mv p.tmp templates/silver-bullet.config.json.default'
variant "a marketplace source path change is rejected" deny 'jq ".plugins[0].source.path=\"./elsewhere\"" .claude-plugin/marketplace.json >p.tmp && mv p.tmp .claude-plugin/marketplace.json'
variant "an allowlisted JSON file turned into a symlink is rejected" deny 'rm package.json && ln -s site/x/index.html package.json'
variant "a mode change on an allowlisted prose file is rejected" deny 'chmod +x CHANGELOG.md'
variant "a script edited under site/ is rejected" deny 'echo "rm -rf /" >>site/x/run.sh'
variant "a new script added under site/ is rejected" deny 'echo x >site/x/new.sh'
variant "a deleted manifest is rejected" deny 'git rm -q package.json'
variant "an added unlisted JSON file is rejected" deny 'echo {} >site/x/hooks.json'
variant "a hook change after the matrix is rejected" deny 'echo x >>hooks/gate.sh'
# a new symlink or submodule entry is never release surface, even at a path the prose allowlist (site/*.html) would
# accept: an add has no old mode, so only the symlink/gitlink check rejects it
variant "a symlink added at an allowlisted prose path is rejected" deny 'ln -s ../../hooks/gate.sh site/x/evil.html'
git -C "$PROJ" config advice.addEmbeddedRepo false
variant "a submodule (gitlink) added at an allowlisted prose path is rejected" deny 'git init -q site/sub.html && git -C site/sub.html -c user.email=t@e.x -c user.name=t commit -q --allow-empty -m sub'
rm -rf "$PROJ/site/sub.html"   # the nested repository the variant created is untracked on the base branch: keep it out of later variants
# fail closed: the diff file cannot be created (mktemp fails for it only), the marker is rejected
GIT_REAL="$(command -v git)"
MKTEMP_REAL="$(command -v mktemp)"
tl_stub mktemp "case \"\$*\" in *sb-surface-diff*) exit 1 ;; esac; exec $MKTEMP_REAL \"\$@\""
variant "an uncreatable surface-diff temp file rejects the marker (fail closed)" deny 'echo more >>CHANGELOG.md'
rm -f "$TL_BIN/mktemp"
# fail closed: the allowlisted JSON cannot be read at the marker's commit, or at the released commit
variant_json_bump='jq ".version=\"1.1.0\"" package.json >p.tmp && mv p.tmp package.json'
tl_stub git "if [[ \"\$*\" == *' show ${OLD_SHA}:package.json'* ]]; then exit 1; fi; exec $GIT_REAL \"\$@\""
variant "an allowlisted JSON unreadable at the marker's commit rejects the marker (fail closed)" deny "$variant_json_bump"
tl_stub git "if [[ \"\$*\" == *' show '*':package.json'* && \"\$*\" != *' show ${OLD_SHA}:package.json'* ]]; then exit 1; fi; exec $GIT_REAL \"\$@\""
variant "an allowlisted JSON unreadable at the released commit rejects the marker (fail closed)" deny "$variant_json_bump"
rm -f "$TL_BIN/git"
variant "the same JSON bump with working git is still accepted" allow "$variant_json_bump"
# fail closed: when git cannot produce the diff since the marker's commit, the marker is rejected
tl_stub git "if [[ \"\$*\" == *'diff '* ]]; then exit 1; fi; exec $GIT_REAL \"\$@\""
printf 'matrix=inline-full-surface\ncommit=%s\n' "$OLD_SHA" >"$INL"
"${GC[@]}" commit -q --allow-empty -m "next"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="$(green)"; assert_eq "an unreadable diff since the marker's commit is rejected (fail closed)" "deny" "$(decision)"
rm -f "$TL_BIN/git"
# a squash/rebase equivalent: a new commit with the same tree and no ancestry is accepted
SQ="$("${GC[@]}" commit-tree "HEAD^{tree}" -m squash)"
git -C "$PROJ" checkout -q --detach "$SQ"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="$(green)"; assert_eq "a squash-equivalent commit (same tree, no ancestry) is accepted" "allow" "$(decision)"
git -C "$PROJ" checkout -q -f "$BASE_BRANCH"
# a marker from an unrelated history (different code) is rejected
git -C "$PROJ" checkout -q -b side "$OLD_SHA"; printf 'side\n' >"$PROJ/side.txt"; "${GC[@]}" add side.txt
"${GC[@]}" commit -q -m side; SIDE_SHA="$(git -C "$PROJ" rev-parse HEAD)"
git -C "$PROJ" checkout -q -f "$BASE_BRANCH"
printf 'matrix=inline-full-surface\ncommit=%s\n' "$SIDE_SHA" >"$INL"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="$(green)"; assert_eq "a commit on a diverged branch with different code is rejected" "deny" "$(decision)"
# a marker commit that is not in this checkout (shallow clone) fails closed with a clear instruction
printf 'matrix=inline-full-surface\ncommit=%s\n' "$(printf '%040d' 1)" >"$INL"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="$(green)"; assert_eq "a marker commit missing locally is rejected" "deny" "$(decision)"
assert_contains "the block tells the operator to fetch full history" "$(message)" "git fetch --unshallow"
# the limits are stated: the gate binds the marker to a tree, it cannot prove a matrix ran
assert_contains "the block states what the gate does not prove" "$(message)" "does not prove that a matrix ran"
# the tamper guard is lexical: a shell redirect to the marker is denied, but the gate's trust comes from re-verifying commit/tree
TAMPER_CMD="printf 'matrix=inline-full-surface\\ncommit=$OLD_SHA\\n' > $INL"
tl_run_hook hooks/dev-cycle-check.sh "$(jq -nc --arg c "$TAMPER_CMD" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}')"
assert_contains "dev-cycle-check denies a shell redirect into the inline marker" "$TL_OUT" "STATE TAMPER BLOCKED"
set_matrix claude-only claude-only inline-full-surface
set_matrix claude-only claude-only inline-full-surface
set_matrix claude-only claude-only inline-full-surface
SHA="$(git -C "$PROJ" rev-parse HEAD)"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="[{\"workflowName\":\"CI\",\"status\":\"in_progress\",\"headSha\":\"$SHA\",\"createdAt\":\"1\"},{\"workflowName\":\"Lint\",\"status\":\"completed\",\"conclusion\":\"failure\",\"headSha\":\"$SHA\",\"createdAt\":\"2\"},{\"workflowName\":\"Old\",\"status\":\"completed\",\"conclusion\":\"failure\",\"headSha\":\"other\",\"createdAt\":\"3\"}]"
assert_contains "several non-green workflows are all listed" "$(message)" "• Lint — status=completed conclusion=failure"
assert_contains "first non-green workflow listed" "$(message)" "• CI — status=in_progress"
assert_not_contains "runs for other commits are ignored" "$(message)" "• Old"
run_ca PreToolUse "$REL" GH_RUN_LIST_OVERRIDE="[{\"workflowName\":\"CI\",\"status\":\"completed\",\"conclusion\":\"failure\",\"headSha\":\"$SHA\",\"createdAt\":\"1\"},{\"workflowName\":\"CI\",\"status\":\"completed\",\"conclusion\":\"success\",\"headSha\":\"$SHA\",\"createdAt\":\"2\"}]"
assert_eq "only the latest run per workflow counts" "allow" "$(decision)"


# the release lists of a live install come from the verified record, plain and devops
mkproj mkkey
sb_integrity_baseline "$(cd "$PROJ" && pwd -P)" session
mkproj relrec '.skills.required_release=["inst-b"] | .skills.required_deploy=["inst-a"]'
state inst-a
run_ca PreToolUse "$REL"
assert_contains "recorded release skill is required" "$(message)" "/inst-b"
jq '.skills.required_release=[]' "$PROJ/.silver-bullet.json" >"$PROJ/t.json" && mv "$PROJ/t.json" "$PROJ/.silver-bullet.json"
run_ca PreToolUse "$REL"
assert_contains "an emptied live release list does not lift it: the drift stops delivery" "$(message)" "ENFORCEMENT CONTRACT CHANGED"
assert_contains "and tells the agent to ask the user" "$(message)" "Ask the user"
mkproj reldevopsrec '.project.active_workflow="devops-cycle" | .skills.required_deploy_devops=["inst-a"] | .skills.required_release_devops=["inst-b"]'
state inst-a
run_ca PreToolUse "$REL"
assert_contains "recorded devops release list is used" "$(message)" "/inst-b"

tl_results
