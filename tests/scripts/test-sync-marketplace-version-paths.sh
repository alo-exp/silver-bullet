#!/usr/bin/env bash
# sync-marketplace-version.sh (Claude marketplace) against local git remotes.
# Default mode aligns only this repository's .claude-plugin/marketplace.json; --publish
# updates the unified marketplace repository, only once the release tag exists, commits
# only the manifest, pushes and confirms the push. Manifests that do not describe
# silver-bullet, or a marketplace checkout holding someone else's work, are refused.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=tests/lib/j-install-sync-helpers.sh
source "$TL_REPO_ROOT/tests/lib/j-install-sync-helpers.sh"
# shellcheck source=tests/lib/offline-tools.sh
source "$TL_REPO_ROOT/tests/lib/offline-tools.sh"
sb_offline_tools_install "$TL_TMP/offline-bin"
j_git_identity
cd "$TL_TMP"

T="$TL_TMP/tree"
MF=.claude-plugin/marketplace.json
# new_tree [tag]: the script and its library in a git repository at plugin version 2.0.0;
# with a tag argument the release commit is tagged.
# push_tag TAG: give the source tree an origin that holds TAG, as after `git push origin TAG`.
push_tag() {
  local o="$TL_TMP/srcorigin.$$.$RANDOM.git"
  git init -q --bare "$o"
  git -C "$T" remote remove origin 2>/dev/null || true
  git -C "$T" remote add origin "$o"
  git -C "$T" push -q origin "$1"
}
new_tree() {
  rm -rf "$T"
  mkdir -p "$T/scripts/lib" "$T/.claude-plugin"
  cp "$TL_REPO_ROOT/scripts/sync-marketplace-version.sh" "$T/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh" "$T/scripts/lib/"
  # CI gate stub: exits CI_RC (default 0) and records that it ran for the tag commit.
  printf '#!/usr/bin/env bash\necho "ci $*" >>"${CI_LOG:-/dev/null}"\nexit "${CI_RC:-0}"\n' >"$T/scripts/verify-release-commit-ci.sh"
  chmod +x "$T/scripts/verify-release-commit-ci.sh"
  jq -n '{name: "silver-bullet", version: "2.0.0"}' >"$T/.claude-plugin/plugin.json"
  j_marketplace_json '{"source":"github","repo":"o/sb"}' >"$T/$MF"
  chmod 644 "$T/$MF"
  git init -q -b main "$T"
  git -C "$T" add -A
  git -C "$T" commit -q -m release
  [[ -z "${1:-}" ]] || { git -C "$T" tag -a "$1" -m release; push_tag "$1"; }
}
# prepared_tree TAG: a tree whose in-repo manifest is already at 2.0.0, tagged TAG.
prepared_tree() {
  new_tree
  sync_run bash "$SCRIPT" >/dev/null
  git -C "$T" commit -q -am "align manifests"
  [[ -z "${1:-}" ]] || { git -C "$T" tag -a "$1" -m release; push_tag "$1"; }
}
SCRIPT="$T/scripts/sync-marketplace-version.sh"
sync_run() { tl_run env -u AGENT_PLUGINS_REPO_ROOT -u MARKETPLACE_REPO_ROOT -u AGENT_PLUGINS_REPO_URL -u MARKETPLACE_REPO_URL -u AGENT_PLUGINS_SKIP_PUSH timeout 60 "$@"; }
sb_get() { jq -r --arg k "$2" '.plugins[] | select(.name=="silver-bullet") | .source[$k]' "$1"; }
sb_version() { jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$1"; }
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
remote_get() { j_remote_show "$MF" | jq -r --arg k "$1" '.plugins[] | select(.name=="silver-bullet") | .source[$k]'; }
remote_version() { j_remote_show "$MF" | jq -r '.plugins[] | select(.name=="silver-bullet") | .version'; }

# --- default mode: this repository only ----------------------------------------------------------
j_make_remote "$TL_TMP/mk"
j_clone_remote "$TL_TMP/work"
new_tree
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
# Even with a marketplace checkout configured, the default mode never touches it.
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" v2.0.0
assert_eq "in-repo sync exits 0" 0 "$TL_STATUS"
assert_contains "in-repo manifest update reported" "$TL_OUT" "Updated in-repo marketplace.json: 0.0.1 → 2.0.0"
assert_contains "in-repo banner" "$TL_OUT" "This repository's Claude marketplace manifest is at v2.0.0."
assert_eq "in-repo version bumped" "2.0.0" "$(sb_version "$T/$MF")"
# R13-02: the entry installs the release tag, never the default branch. No tag exists yet
# (the release is about to create it), so only the ref is pinned and no stale sha is written.
assert_eq "in-repo source pinned to the release tag" "v2.0.0" "$(sb_get "$T/$MF" ref)"
assert_eq "no tag yet: no sha pinned" "null" "$(sb_get "$T/$MF" sha)"
assert_eq "source repo preserved" "o/sb" "$(sb_get "$T/$MF" repo)"
assert_eq "in-repo manifest keeps mode 644 (R13-28)" "644" "$(mode_of "$T/$MF")"
assert_eq "marketplace checkout untouched" "" "$(git -C "$TL_TMP/work" status --porcelain)"
assert_eq "remote untouched" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "no temporary file left next to the manifest" "marketplace.json
plugin.json" "$(ls -A "$T/.claude-plugin")"

sync_run bash "$SCRIPT"
assert_eq "second in-repo sync exits 0" 0 "$TL_STATUS"
assert_contains "versions already in sync" "$TL_OUT" "Versions already in sync: 2.0.0"

# Version already right but the source unpinned (the pre-fix manifest): the sync pins it.
new_tree
jq '(.plugins[] | select(.name=="silver-bullet") | .version) = "2.0.0"' "$T/$MF" >"$TL_TMP/v.json" && cp "$TL_TMP/v.json" "$T/$MF"
sync_run bash "$SCRIPT"
assert_eq "unpinned source with a current version exits 0" 0 "$TL_STATUS"
assert_contains "pin reported" "$TL_OUT" "Pinned in-repo marketplace.json to v2.0.0"
assert_eq "unpinned source gets the tag ref" "v2.0.0" "$(sb_get "$T/$MF" ref)"

# Once the release is tagged, the tag's commit is pinned too, and a stale sha is replaced.
new_tree v2.0.0
TAGGED="$(git -C "$T" rev-parse 'v2.0.0^{commit}')"
jq '(.plugins[] | select(.name=="silver-bullet") | .source.sha) = "0000000000000000000000000000000000000000"' "$T/$MF" >"$TL_TMP/v.json" && cp "$TL_TMP/v.json" "$T/$MF"
sync_run bash "$SCRIPT"
assert_eq "tagged: exits 0" 0 "$TL_STATUS"
assert_eq "tagged: sha is the tag commit" "$TAGGED" "$(sb_get "$T/$MF" sha)"
assert_eq "tagged: ref is the tag" "v2.0.0" "$(sb_get "$T/$MF" ref)"
sync_run bash "$SCRIPT"
assert_contains "tagged: second sync is a no-op" "$TL_OUT" "Versions already in sync: 2.0.0"

new_tree
chmod 640 "$T/$MF"
sync_run bash "$SCRIPT"
assert_eq "in-repo manifest keeps a non-default mode" "640" "$(mode_of "$T/$MF")"

# --- --publish: needs the release tag --------------------------------------------------------------
prepared_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "publish without the release tag exits 1" 1 "$TL_STATUS"
assert_contains "missing tag explained" "$TL_ERR" "release tag v2.0.0 does not exist"
assert_eq "nothing published without the tag" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "checkout untouched without the tag" "" "$(git -C "$TL_TMP/work" status --porcelain)"

prepared_tree
git -C "$T" tag -a v2.0.0 -m release
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "publish with the tag only local exits 1" 1 "$TL_STATUS"
assert_contains "tag not on origin explained" "$TL_ERR" "release tag v2.0.0 is not on origin"
assert_eq "nothing published for a local-only tag" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

prepared_tree v2.0.0
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" CI_RC=1 CI_LOG="$TL_TMP/ci.log" bash "$SCRIPT" --publish 2.0.0
assert_eq "publish on red CI exits 1" 1 "$TL_STATUS"
assert_contains "red CI explained" "$TL_ERR" "CI is not green for v2.0.0"
assert_eq "nothing published on red CI" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_contains "CI consulted for the tag commit" "$(cat "$TL_TMP/ci.log")" "ci $(git -C "$T" rev-parse 'v2.0.0^{commit}')"

new_tree v2.0.0
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "publish with an unaligned in-repo manifest exits 1" 1 "$TL_STATUS"
assert_contains "unaligned in-repo manifest explained" "$TL_ERR" "is 0.0.1, not 2.0.0: run scripts/sync-marketplace-version.sh 2.0.0 and commit"
assert_eq "nothing published for an unaligned tree" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

# --- --publish with the tag: commit only the manifest, push, confirm -------------------------------
prepared_tree v2.0.0
echo "maintainer notes" >"$TL_TMP/work/scratch-untracked.txt"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish v2.0.0
assert_eq "publish exits 0" 0 "$TL_STATUS"
assert_contains "remote manifest update reported" "$TL_OUT" "Updated Claude marketplace manifest: 0.0.1 → 2.0.0"
assert_contains "push reported" "$TL_OUT" "Pushed 1 commit(s) to origin/main"
assert_contains "publish banner" "$TL_OUT" "The agent-plugins Claude manifest now offers silver-bullet v2.0.0."
assert_eq "remote version bumped and pushed (R13-01)" "2.0.0" "$(remote_version)"
assert_eq "remote source pinned to the release tag (R13-02)" "v2.0.0" "$(remote_get ref)"
assert_eq "remote source pinned to the tagged commit (R13-02)" "$(git -C "$T" rev-parse 'v2.0.0^{commit}')" "$(remote_get sha)"
assert_eq "remote source repo preserved" "o/sb" "$(remote_get repo)"
assert_eq "bump commit message" "Bump silver-bullet Claude manifest to 2.0.0" "$(git -C "$J_REMOTE" log -1 --format=%s main)"
assert_eq "bump commit holds only the manifest (R8-19)" "$MF" "$(git -C "$J_REMOTE" show --name-only --format= main)"
assert_eq "untracked file stays local" "?? scratch-untracked.txt" "$(git -C "$TL_TMP/work" status --porcelain)"
assert_eq "foreign plugin preserved in the remote" "$(jq -c '.plugins[0]' "$J_SEED/$MF")" "$(j_remote_show "$MF" | jq -c '.plugins[0]')"
assert_eq "other fields of the entry preserved" '"keep me"' "$(j_remote_show "$MF" | jq -c '.plugins[1].description')"
assert_eq "JSON nulls preserved" 'null' "$(j_remote_show "$MF" | jq -c '.metadata.note')"
assert_eq "in-repo manifest untouched by --publish" "" "$(git -C "$T" status --porcelain)"
rm -f "$TL_TMP/work/scratch-untracked.txt"

# Idempotent second publish: nothing to commit, remote unchanged.
before="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish
assert_eq "second publish exits 0" 0 "$TL_STATUS"
assert_contains "remote already current" "$TL_OUT" "Claude marketplace manifest already at silver-bullet 2.0.0"
assert_eq "second publish pushes nothing" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# MARKETPLACE_REPO_ROOT is the legacy spelling of the root variable.
j_clone_remote "$TL_TMP/work2"
sync_run env MARKETPLACE_REPO_ROOT="$TL_TMP/work2" bash "$SCRIPT" --publish
assert_eq "legacy root variable honoured" 0 "$TL_STATUS"
assert_contains "legacy root: nothing to bump remotely" "$TL_OUT" "already at silver-bullet 2.0.0"

# --- a marketplace checkout holding someone else's work ------------------------------------------------
j_make_remote "$TL_TMP/mkw"
j_clone_remote "$TL_TMP/wip"
jq '.plugins[0].version = "9.9.10"' "$TL_TMP/wip/$MF" >"$TL_TMP/wip.json" && cp "$TL_TMP/wip.json" "$TL_TMP/wip/$MF"
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/wip" bash "$SCRIPT" --publish
assert_eq "uncommitted edit to the manifest refused" 1 "$TL_STATUS"
assert_contains "uncommitted edit explained" "$TL_ERR" "$TL_TMP/wip/$MF has uncommitted changes"
assert_eq "work in progress kept" "9.9.10" "$(jq -r '.plugins[0].version' "$TL_TMP/wip/$MF")"
assert_eq "work in progress not published" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
git -C "$TL_TMP/wip" commit -q -am "local work"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/wip" bash "$SCRIPT" --publish
assert_eq "unpushed local commit refused" 1 "$TL_STATUS"
assert_contains "unpushed commit explained" "$TL_ERR" "has 1 unpushed commit(s) on top of origin/main"
assert_eq "unpushed local commit not published" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

# --- clone path ---------------------------------------------------------------------------------------
j_make_remote "$TL_TMP/mk2"
mkdir -p "$TL_TMP/tmpdir"
sync_run env TMPDIR="$TL_TMP/tmpdir" AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish
assert_eq "clone-based publish exits 0" 0 "$TL_STATUS"
assert_eq "clone-based publish pushed the bump" "2.0.0" "$(remote_version)"
assert_eq "temporary clone removed" "" "$(ls -A "$TL_TMP/tmpdir")"

# Legacy URL variable takes precedence over the unified one.
j_make_remote "$TL_TMP/mk3"
sync_run env TMPDIR="$TL_TMP/tmpdir" MARKETPLACE_REPO_URL="$J_REMOTE" AGENT_PLUGINS_REPO_URL="$TL_TMP/does-not-exist" bash "$SCRIPT" --publish
assert_eq "legacy URL variable wins" 0 "$TL_STATUS"
assert_eq "legacy URL remote bumped" "2.0.0" "$(remote_version)"

# --- argument and prerequisite errors ----------------------------------------------------
new_tree
sync_run bash "$SCRIPT" 3.0.0
assert_eq "version differing from plugin.json exits 1" 1 "$TL_STATUS"
assert_contains "mismatch explained" "$TL_ERR" "is 2.0.0 but the release version is 3.0.0. Bump the plugin manifest first."
assert_eq "manifest untouched on mismatch" "0.0.1" "$(sb_version "$T/$MF")"

sync_run bash "$SCRIPT" --bogus
assert_eq "unknown option exits 1" 1 "$TL_STATUS"
assert_contains "unknown option named" "$TL_ERR" "unknown option: --bogus"

sync_run env PATH="$(tl_path_without jq)" bash "$SCRIPT"
assert_eq "missing jq exits 1" 1 "$TL_STATUS"
assert_contains "missing jq reported" "$TL_OUT" "jq required"

# Marketplace repo root that is not a git repo / lacks the manifest.
prepared_tree v2.0.0
mkdir -p "$TL_TMP/notgit"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/notgit" bash "$SCRIPT" --publish
assert_eq "non-git marketplace root exits 1" 1 "$TL_STATUS"
assert_contains "non-git root named" "$TL_ERR" "marketplace repo root is not a git repository: $TL_TMP/notgit"
git init -q -b main "$TL_TMP/nomanifest"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/nomanifest" bash "$SCRIPT" --publish
assert_eq "marketplace repo without manifest exits 1" 1 "$TL_STATUS"
assert_contains "missing remote manifest named" "$TL_ERR" "Claude marketplace manifest not found in repo: $TL_TMP/nomanifest/$MF"

# --- manifests without a silver-bullet entry ---------------------------------------------------
# Nothing may be reported as synced, committed or pushed when there is no entry to bump.
j_make_remote "$TL_TMP/mk4"
j_clone_remote "$TL_TMP/work4"
jq 'del(.plugins[] | select(.name=="silver-bullet"))' "$TL_TMP/work4/$MF" >"$TL_TMP/no-sb.json"
cp "$TL_TMP/no-sb.json" "$TL_TMP/work4/$MF"
git -C "$TL_TMP/work4" commit -q -am "drop silver-bullet" && git -C "$TL_TMP/work4" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work4" bash "$SCRIPT" --publish
assert_eq "remote manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing remote entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false success for the remote" "$TL_OUT" "already at silver-bullet"
assert_eq "nothing pushed" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "remote file byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$TL_TMP/work4/$MF")"

new_tree
cp "$TL_TMP/no-sb.json" "$T/$MF"
sync_run bash "$SCRIPT"
assert_eq "in-repo manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing in-repo entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false update message" "$TL_OUT" "Updated in-repo"
assert_eq "in-repo manifest byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$T/$MF")"

# A manifest that is not valid JSON is reported as such, not as a missing entry.
j_make_remote "$TL_TMP/mkjs"
j_clone_remote "$TL_TMP/workjs"
printf '%s' '{"plugins": [' >"$TL_TMP/workjs/$MF"
git -C "$TL_TMP/workjs" commit -q -am "corrupt manifest" && git -C "$TL_TMP/workjs" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
prepared_tree v2.0.0
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/workjs" bash "$SCRIPT" --publish
assert_eq "invalid remote JSON exits 1" 1 "$TL_STATUS"
assert_contains "invalid remote JSON named as such" "$TL_ERR" "workjs/$MF is not valid JSON"
assert_not_contains "invalid JSON is not reported as a missing entry" "$TL_ERR" "no silver-bullet entry"
assert_eq "nothing pushed for invalid remote JSON" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "invalid remote file byte-identical" '{"plugins": [' "$(<"$TL_TMP/workjs/$MF")"

new_tree
printf '%s' '{"plugins": [' >"$T/$MF"
sync_run bash "$SCRIPT"
assert_eq "invalid in-repo JSON exits 1" 1 "$TL_STATUS"
assert_contains "invalid in-repo JSON named as such" "$TL_ERR" "$MF is not valid JSON"
assert_not_contains "in-repo invalid JSON is not a missing entry" "$TL_ERR" "no silver-bullet entry"

tl_results
