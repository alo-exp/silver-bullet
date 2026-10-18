#!/usr/bin/env bash
# sync-marketplace-version.sh (Claude marketplace) against local git remotes:
# in-repo manifest update, remote clone/bump/push, idempotence, and refusal to
# touch anything when the manifests do not describe silver-bullet.
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
new_tree() {
  rm -rf "$T"
  mkdir -p "$T/scripts/lib" "$T/.claude-plugin"
  cp "$TL_REPO_ROOT/scripts/sync-marketplace-version.sh" "$T/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh" "$T/scripts/lib/"
  jq -n '{name: "silver-bullet", version: "2.0.0"}' >"$T/.claude-plugin/plugin.json"
  j_marketplace_json '{"source":"github","repo":"o/sb"}' >"$T/.claude-plugin/marketplace.json"
}
SCRIPT="$T/scripts/sync-marketplace-version.sh"
sync_run() { tl_run env -u AGENT_PLUGINS_REPO_ROOT -u MARKETPLACE_REPO_ROOT -u AGENT_PLUGINS_REPO_URL -u MARKETPLACE_REPO_URL timeout 60 "$@"; }
sb_version() { jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$1"; }

# --- explicit marketplace repo root ------------------------------------------------
j_make_remote "$TL_TMP/mk"
j_clone_remote "$TL_TMP/work"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" v2.0.0
assert_eq "sync exits 0" 0 "$TL_STATUS"
assert_contains "in-repo manifest update reported" "$TL_OUT" "Updated in-repo marketplace.json: 0.0.1 → 2.0.0"
assert_contains "remote manifest update reported" "$TL_OUT" "Updated Claude marketplace manifest: 0.0.1 → 2.0.0"
assert_contains "completion banner" "$TL_OUT" "The agent-plugins Claude manifest was updated for v2.0.0."
assert_eq "in-repo version bumped" "2.0.0" "$(sb_version "$T/.claude-plugin/marketplace.json")"
assert_eq "remote version bumped and pushed" "2.0.0" "$(j_remote_show .claude-plugin/marketplace.json | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"
assert_eq "foreign plugin preserved in the remote" "$(jq -c '.plugins[0]' "$J_SEED/.claude-plugin/marketplace.json")" "$(j_remote_show .claude-plugin/marketplace.json | jq -c '.plugins[0]')"
assert_eq "other fields of the entry preserved" '"keep me"' "$(j_remote_show .claude-plugin/marketplace.json | jq -c '.plugins[1].description')"
assert_eq "JSON nulls preserved" 'null' "$(j_remote_show .claude-plugin/marketplace.json | jq -c '.metadata.note')"
assert_eq "bump committed once" "Bump silver-bullet to 2.0.0" "$(git -C "$J_REMOTE" log -1 --format=%s main)"

# Idempotent second run: nothing to commit, remote unchanged.
before="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "second sync exits 0" 0 "$TL_STATUS"
assert_contains "versions already in sync" "$TL_OUT" "Versions already in sync: 2.0.0"
assert_contains "remote already current" "$TL_OUT" "Claude marketplace manifest already at silver-bullet 2.0.0"
assert_eq "second sync pushes nothing" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# MARKETPLACE_REPO_ROOT is the legacy spelling of the root variable.
j_clone_remote "$TL_TMP/work2"
new_tree
sync_run env MARKETPLACE_REPO_ROOT="$TL_TMP/work2" bash "$SCRIPT"
assert_eq "legacy root variable honoured" 0 "$TL_STATUS"
assert_contains "legacy root: nothing to bump remotely" "$TL_OUT" "already at silver-bullet 2.0.0"

# --- clone path ---------------------------------------------------------------------
j_make_remote "$TL_TMP/mk2"
new_tree
mkdir -p "$TL_TMP/tmpdir"
sync_run env TMPDIR="$TL_TMP/tmpdir" AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT"
assert_eq "clone-based sync exits 0" 0 "$TL_STATUS"
assert_eq "clone-based sync pushed the bump" "2.0.0" "$(j_remote_show .claude-plugin/marketplace.json | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"
assert_eq "temporary clone removed" "" "$(ls -A "$TL_TMP/tmpdir")"

# Legacy URL variable takes precedence over the unified one.
j_make_remote "$TL_TMP/mk3"
new_tree
sync_run env TMPDIR="$TL_TMP/tmpdir" MARKETPLACE_REPO_URL="$J_REMOTE" AGENT_PLUGINS_REPO_URL="$TL_TMP/does-not-exist" bash "$SCRIPT"
assert_eq "legacy URL variable wins" 0 "$TL_STATUS"
assert_eq "legacy URL remote bumped" "2.0.0" "$(j_remote_show .claude-plugin/marketplace.json | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"

# --- argument and prerequisite errors ----------------------------------------------------
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" 3.0.0
assert_eq "version differing from plugin.json exits 1" 1 "$TL_STATUS"
assert_contains "mismatch explained" "$TL_ERR" "is 2.0.0 but the release version is 3.0.0. Bump the plugin manifest first."
assert_eq "manifest untouched on mismatch" "0.0.1" "$(sb_version "$T/.claude-plugin/marketplace.json")"

sync_run env PATH="$(tl_path_without jq)" AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "missing jq exits 1" 1 "$TL_STATUS"
assert_contains "missing jq reported" "$TL_OUT" "jq required"

# Marketplace repo root that is not a git repo / lacks the manifest.
mkdir -p "$TL_TMP/notgit"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/notgit" bash "$SCRIPT"
assert_eq "non-git marketplace root exits 1" 1 "$TL_STATUS"
assert_contains "non-git root named" "$TL_ERR" "marketplace repo root is not a git repository: $TL_TMP/notgit"
new_tree
git init -q -b main "$TL_TMP/nomanifest"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/nomanifest" bash "$SCRIPT"
assert_eq "marketplace repo without manifest exits 1" 1 "$TL_STATUS"
assert_contains "missing remote manifest named" "$TL_ERR" "Claude marketplace manifest not found in repo: $TL_TMP/nomanifest/.claude-plugin/marketplace.json"

# --- manifests without a silver-bullet entry ---------------------------------------------------
# Nothing may be reported as synced, committed or pushed when there is no entry to bump.
j_make_remote "$TL_TMP/mk4"
j_clone_remote "$TL_TMP/work4"
jq 'del(.plugins[] | select(.name=="silver-bullet"))' "$TL_TMP/work4/.claude-plugin/marketplace.json" >"$TL_TMP/no-sb.json"
cp "$TL_TMP/no-sb.json" "$TL_TMP/work4/.claude-plugin/marketplace.json"
git -C "$TL_TMP/work4" commit -q -am "drop silver-bullet" && git -C "$TL_TMP/work4" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work4" bash "$SCRIPT"
assert_eq "remote manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing remote entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false success for the remote" "$TL_OUT" "already at silver-bullet"
assert_eq "nothing pushed" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "remote file byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$TL_TMP/work4/.claude-plugin/marketplace.json")"

new_tree
cp "$TL_TMP/no-sb.json" "$T/.claude-plugin/marketplace.json"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "in-repo manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing in-repo entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false update message" "$TL_OUT" "Updated in-repo"
assert_eq "in-repo manifest byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$T/.claude-plugin/marketplace.json")"

tl_results
