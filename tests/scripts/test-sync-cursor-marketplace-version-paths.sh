#!/usr/bin/env bash
# sync-cursor-marketplace-version.sh against local git remotes and a stubbed
# package sync: release commit/ref resolution (tag at HEAD, tag behind HEAD,
# no tag, odd tags), in-repo and remote manifest updates, idempotence and
# refusal to report success without a silver-bullet entry.
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
MF=.cursor-plugin/marketplace.json
new_tree() {
  rm -rf "$T"
  mkdir -p "$T/scripts/lib" "$T/.cursor-plugin" "$T/plugins/silver-bullet/.cursor-plugin"
  cp "$TL_REPO_ROOT/scripts/sync-cursor-marketplace-version.sh" "$T/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh" "$T/scripts/lib/"
  jq -n '{name: "silver-bullet", version: "2.0.0"}' >"$T/.cursor-plugin/plugin.json"
  j_marketplace_json '{"source":"github","repo":"o/sb","ref":"main","sha":"0000","path":"x"}' >"$T/$MF"
  # Stub package sync: derives the package manifest from the root one, unless told otherwise.
  cat >"$T/scripts/sync-cursor-package.sh" <<'PKG'
#!/usr/bin/env bash
root="$(cd "$(dirname "$0")/.." && pwd)"
v="${STUB_PKG_VERSION:-$(jq -r .version "$root/.cursor-plugin/plugin.json")}"
jq -n --arg v "$v" '{name: "silver-bullet", version: $v}' >"$root/plugins/silver-bullet/.cursor-plugin/plugin.json"
PKG
  chmod +x "$T/scripts/sync-cursor-package.sh"
  git init -q -b main "$T"
  git -C "$T" add -A
  git -C "$T" commit -q -m first
}
SCRIPT="$T/scripts/sync-cursor-marketplace-version.sh"
sync_run() { tl_run env -u AGENT_PLUGINS_REPO_ROOT -u CURSOR_MARKETPLACE_REPO_ROOT -u AGENT_PLUGINS_REPO_URL -u CURSOR_MARKETPLACE_REPO_URL timeout 60 "$@"; }
sb_get() { jq -r --arg k "$2" '.plugins[] | select(.name=="silver-bullet") | .source[$k]' "$1"; }
sb_version() { jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$1"; }

# --- explicit marketplace repo root, no release tag ---------------------------------
j_make_remote "$TL_TMP/mk"
j_clone_remote "$TL_TMP/work"
new_tree
HEAD1="$(git -C "$T" rev-parse HEAD)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" v2.0.0
assert_eq "sync exits 0" 0 "$TL_STATUS"
assert_contains "in-repo update reported" "$TL_OUT" "Updated in-repo marketplace.json: 0.0.1 → 2.0.0"
assert_contains "remote update reported" "$TL_OUT" "Updated Cursor marketplace manifest: 0.0.1 → 2.0.0"
assert_contains "completion banner" "$TL_OUT" "The agent-plugins Cursor manifest was updated for v2.0.0."
assert_eq "in-repo version" "2.0.0" "$(sb_version "$T/$MF")"
# (git echoes an unknown tag name on stdout, so "no tag" resolves like "tag behind HEAD")
assert_eq "no tag: ref is main" "main" "$(sb_get "$T/$MF" ref)"
assert_eq "no tag: sha is HEAD" "$HEAD1" "$(sb_get "$T/$MF" sha)"
assert_eq "path pinned to the package dir" "plugins/silver-bullet" "$(sb_get "$T/$MF" path)"
assert_eq "in-repo manifest is world-readable" "644" "$(stat -c %a "$T/$MF" 2>/dev/null || stat -f %Lp "$T/$MF")"
assert_eq "package manifest regenerated" "2.0.0" "$(jq -r .version "$T/plugins/silver-bullet/.cursor-plugin/plugin.json")"
assert_eq "remote version pushed" "2.0.0" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"
assert_eq "remote sha follows HEAD" "$HEAD1" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .source.sha')"
assert_eq "remote source repo preserved" "o/sb" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .source.repo')"
assert_eq "foreign plugin preserved" "$(jq -c '.plugins[0]' "$J_SEED/$MF")" "$(j_remote_show $MF | jq -c '.plugins[0]')"
assert_eq "JSON nulls preserved" 'null' "$(j_remote_show $MF | jq -c '.metadata.note')"
assert_eq "commit message" "Bump silver-bullet to 2.0.0" "$(git -C "$J_REMOTE" log -1 --format=%s main)"

# Idempotent second run (same HEAD).
before="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "second sync exits 0" 0 "$TL_STATUS"
assert_contains "versions already in sync" "$TL_OUT" "Versions already in sync: 2.0.0"
assert_contains "remote already current" "$TL_OUT" "Cursor marketplace manifest already at silver-bullet 2.0.0"
assert_eq "second sync pushes nothing" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# --- tag handling ---------------------------------------------------------------------------
# Tag on HEAD: the tag commit is the release commit, ref is the tag.
new_tree
git -C "$T" tag -a v2.0.0 -m release
j_clone_remote "$TL_TMP/work-tag"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work-tag" bash "$SCRIPT"
assert_eq "tag at HEAD: exits 0" 0 "$TL_STATUS"
assert_eq "tag at HEAD: sha is the tagged commit" "$(git -C "$T" rev-parse 'v2.0.0^{commit}')" "$(sb_get "$T/$MF" sha)"
assert_eq "tag at HEAD: ref is the tag" "v2.0.0" "$(sb_get "$T/$MF" ref)"

# Tag behind HEAD: development continues on main, so pin main at HEAD.
new_tree
git -C "$T" tag v2.0.0
echo more >"$T/more.txt"
git -C "$T" add more.txt && git -C "$T" commit -q -m second
HEAD2="$(git -C "$T" rev-parse HEAD)"
j_clone_remote "$TL_TMP/work-tag2"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work-tag2" bash "$SCRIPT"
assert_eq "tag behind HEAD: exits 0" 0 "$TL_STATUS"
assert_eq "tag behind HEAD: sha is HEAD" "$HEAD2" "$(sb_get "$T/$MF" sha)"
assert_eq "tag behind HEAD: ref is main" "main" "$(sb_get "$T/$MF" ref)"

# A tag that is not a commit (points at a tree) falls back to the plain rev-parse.
new_tree
git -C "$T" tag v2.0.0 "$(git -C "$T" rev-parse 'HEAD^{tree}')"
HEAD3="$(git -C "$T" rev-parse HEAD)"
j_clone_remote "$TL_TMP/work-tag3"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work-tag3" bash "$SCRIPT"
assert_eq "non-commit tag: exits 0" 0 "$TL_STATUS"
assert_eq "non-commit tag: sha is HEAD" "$HEAD3" "$(sb_get "$T/$MF" sha)"
assert_eq "non-commit tag: ref is main" "main" "$(sb_get "$T/$MF" ref)"

# --- clone path ----------------------------------------------------------------------------------
j_make_remote "$TL_TMP/mk2"
new_tree
mkdir -p "$TL_TMP/tmpdir"
sync_run env TMPDIR="$TL_TMP/tmpdir" AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" 2.0.0
assert_eq "clone-based sync exits 0" 0 "$TL_STATUS"
assert_eq "clone-based sync pushed" "2.0.0" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"
assert_eq "temporary clone removed" "" "$(ls -A "$TL_TMP/tmpdir")"

# --- arguments, prerequisites, errors --------------------------------------------------------------
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" 3.0.0
assert_eq "version differing from plugin.json exits 1" 1 "$TL_STATUS"
assert_contains "mismatch explained" "$TL_ERR" "is 2.0.0 but the release version is 3.0.0. Bump the plugin manifest first."
assert_eq "manifest untouched on mismatch" "0.0.1" "$(sb_version "$T/$MF")"

sync_run env PATH="$(tl_path_without jq)" AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "missing jq exits 1" 1 "$TL_STATUS"
assert_contains "missing jq reported" "$TL_OUT" "jq required"

new_tree
rm -f "$T/scripts/sync-cursor-package.sh"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "missing package sync script exits 1" 1 "$TL_STATUS"
assert_contains "missing package sync script named" "$TL_ERR" "Cursor package sync script not found or not executable: $T/scripts/sync-cursor-package.sh"

new_tree
sync_run env STUB_PKG_VERSION=1.2.3 AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "stale package manifest exits 1" 1 "$TL_STATUS"
assert_contains "package manifest mismatch explained" "$TL_ERR" "plugins/silver-bullet/.cursor-plugin/plugin.json is 1.2.3 but release version is 2.0.0"

new_tree
mkdir -p "$TL_TMP/notgit"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/notgit" bash "$SCRIPT"
assert_eq "non-git marketplace root exits 1" 1 "$TL_STATUS"
assert_contains "non-git root named" "$TL_ERR" "marketplace repo root is not a git repository: $TL_TMP/notgit"
rm -rf "$TL_TMP/nomanifest"; git init -q -b main "$TL_TMP/nomanifest"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/nomanifest" bash "$SCRIPT"
assert_eq "marketplace repo without manifest exits 1" 1 "$TL_STATUS"
assert_contains "missing manifest named" "$TL_ERR" "Cursor marketplace manifest not found in repo: $TL_TMP/nomanifest/$MF"

# --- manifests without a silver-bullet entry ---------------------------------------------------------
j_make_remote "$TL_TMP/mk3"
j_clone_remote "$TL_TMP/work3"
jq 'del(.plugins[] | select(.name=="silver-bullet"))' "$TL_TMP/work3/$MF" >"$TL_TMP/no-sb.json"
cp "$TL_TMP/no-sb.json" "$TL_TMP/work3/$MF"
git -C "$TL_TMP/work3" commit -q -am "drop silver-bullet" && git -C "$TL_TMP/work3" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work3" bash "$SCRIPT"
assert_eq "remote manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing remote entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false success for the remote" "$TL_OUT" "already at silver-bullet"
assert_eq "nothing pushed" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "remote manifest byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$TL_TMP/work3/$MF")"

new_tree
cp "$TL_TMP/no-sb.json" "$T/$MF"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "in-repo manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing in-repo entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false update message" "$TL_OUT" "Updated in-repo"
assert_eq "in-repo manifest byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$T/$MF")"

tl_results
