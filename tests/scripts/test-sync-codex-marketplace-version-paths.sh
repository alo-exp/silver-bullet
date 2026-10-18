#!/usr/bin/env bash
# sync-codex-marketplace-version.sh against local git remotes and a stubbed
# package sync: version/config_version update, release-ref pinning, remote
# bump and push, idempotence and refusal to report success without an entry.
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
PKG_LOG="$TL_TMP/package-sync.log"
new_tree() {
  rm -rf "$T"
  mkdir -p "$T/scripts/lib" "$T/plugins/silver-bullet/.codex-plugin"
  cp "$TL_REPO_ROOT/scripts/sync-codex-marketplace-version.sh" "$T/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh" "$T/scripts/lib/"
  jq -n '{version: "2.0.0"}' >"$T/package.json"
  jq -n '{name: "silver-bullet", version: "1.0.0", config_version: "1.0.0", keep: {x: null}}' >"$T/plugins/silver-bullet/.codex-plugin/plugin.json"
  printf '#!/usr/bin/env bash\necho package-sync-ran >>"%s"\n' "$PKG_LOG" >"$T/scripts/sync-codex-package.sh"
  chmod +x "$T/scripts/sync-codex-package.sh"
  : >"$PKG_LOG"
}
SCRIPT="$T/scripts/sync-codex-marketplace-version.sh"
sync_run() { tl_run env -u AGENT_PLUGINS_REPO_ROOT -u CODEX_MARKETPLACE_REPO_ROOT -u AGENT_PLUGINS_REPO_URL -u CODEX_MARKETPLACE_REPO_URL timeout 60 "$@"; }
MF=.agents/plugins/marketplace.json

# --- explicit marketplace repo root ------------------------------------------------
j_make_remote "$TL_TMP/mk"
j_clone_remote "$TL_TMP/work"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" v2.0.0
assert_eq "sync exits 0" 0 "$TL_STATUS"
assert_contains "plugin manifest update reported" "$TL_OUT" "Updated version/config_version: 1.0.0/1.0.0 → 2.0.0"
assert_contains "remote update reported" "$TL_OUT" "Updated Codex marketplace manifest: 0.0.1 → 2.0.0"
assert_contains "completion banner" "$TL_OUT" "The agent-plugins Codex manifest was updated for v2.0.0."
assert_eq "plugin.json version" "2.0.0" "$(jq -r .version "$T/plugins/silver-bullet/.codex-plugin/plugin.json")"
assert_eq "plugin.json config_version" "2.0.0" "$(jq -r .config_version "$T/plugins/silver-bullet/.codex-plugin/plugin.json")"
assert_eq "plugin.json nulls preserved" 'null' "$(jq -c .keep.x "$T/plugins/silver-bullet/.codex-plugin/plugin.json")"
assert_eq "package sync ran once" "package-sync-ran" "$(<"$PKG_LOG")"
assert_eq "remote version pushed" "2.0.0" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .version')"
assert_eq "remote ref pinned to the release tag" "v2.0.0" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .source.ref')"
assert_eq "remote source repo preserved" "o/sb" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .source.repo')"
assert_eq "foreign plugin preserved" "$(jq -c '.plugins[0]' "$J_SEED/$MF")" "$(j_remote_show $MF | jq -c '.plugins[0]')"
assert_eq "JSON nulls preserved in the remote" 'null' "$(j_remote_show $MF | jq -c '.metadata.note')"
assert_eq "commit message" "Bump silver-bullet Codex manifest to 2.0.0" "$(git -C "$J_REMOTE" log -1 --format=%s main)"

# Idempotent second run.
before="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" 2.0.0
assert_eq "second sync exits 0" 0 "$TL_STATUS"
assert_contains "plugin manifest already in sync" "$TL_OUT" "Version and config_version already in sync: 2.0.0"
assert_contains "remote already current" "$TL_OUT" "Codex marketplace manifest already at silver-bullet 2.0.0"
assert_eq "second sync pushes nothing" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# Without an argument the version comes from package.json; only a stale
# config_version is rewritten; CODEX_MARKETPLACE_REPO_ROOT is the legacy root variable.
new_tree
jq '.version = "2.0.0"' "$T/plugins/silver-bullet/.codex-plugin/plugin.json" >"$TL_TMP/p.json" && cp "$TL_TMP/p.json" "$T/plugins/silver-bullet/.codex-plugin/plugin.json"
sync_run env CODEX_MARKETPLACE_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT"
assert_eq "no-argument sync exits 0" 0 "$TL_STATUS"
assert_contains "stale config_version rewritten" "$TL_OUT" "Updated version/config_version: 2.0.0/1.0.0 → 2.0.0"
assert_eq "config_version synced" "2.0.0" "$(jq -r .config_version "$T/plugins/silver-bullet/.codex-plugin/plugin.json")"

# --- clone path -------------------------------------------------------------------------
j_make_remote "$TL_TMP/mk2"
new_tree
mkdir -p "$TL_TMP/tmpdir"
sync_run env TMPDIR="$TL_TMP/tmpdir" AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" 2.0.0
assert_eq "clone-based sync exits 0" 0 "$TL_STATUS"
assert_eq "clone-based sync pushed" "v2.0.0" "$(j_remote_show $MF | jq -r '.plugins[] | select(.name=="silver-bullet") | .source.ref')"
assert_eq "temporary clone removed" "" "$(ls -A "$TL_TMP/tmpdir")"

# --- prerequisites and errors -----------------------------------------------------------------
new_tree
sync_run env PATH="$(tl_path_without jq)" AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" 2.0.0
assert_eq "missing jq exits 1" 1 "$TL_STATUS"
assert_contains "missing jq reported" "$TL_OUT" "jq required"

new_tree
rm -f "$T/scripts/sync-codex-package.sh"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" 2.0.0
assert_eq "missing package sync script exits 1" 1 "$TL_STATUS"
assert_contains "missing package sync script named" "$TL_ERR" "Codex package sync script not found or not executable: $T/scripts/sync-codex-package.sh"

new_tree
printf '#!/usr/bin/env bash\nexit 9\n' >"$T/scripts/sync-codex-package.sh"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" 3.0.0
assert_eq "failing package sync fails the run" 1 "$TL_STATUS"
assert_not_contains "no remote update after a failed package sync" "$TL_OUT" "Codex marketplace manifest"

new_tree
mkdir -p "$TL_TMP/notgit"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/notgit" bash "$SCRIPT" 2.0.0
assert_eq "non-git marketplace root exits 1" 1 "$TL_STATUS"
assert_contains "non-git root named" "$TL_ERR" "marketplace repo root is not a git repository: $TL_TMP/notgit"
git init -q -b main "$TL_TMP/nomanifest"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/nomanifest" bash "$SCRIPT" 2.0.0
assert_eq "marketplace repo without manifest exits 1" 1 "$TL_STATUS"
assert_contains "missing manifest named" "$TL_ERR" "Codex marketplace manifest not found in repo: $TL_TMP/nomanifest/$MF"

# Manifest without a silver-bullet entry: no success report, no commit, no push.
j_make_remote "$TL_TMP/mk3"
j_clone_remote "$TL_TMP/work3"
jq 'del(.plugins[] | select(.name=="silver-bullet"))' "$TL_TMP/work3/$MF" >"$TL_TMP/no-sb.json"
cp "$TL_TMP/no-sb.json" "$TL_TMP/work3/$MF"
git -C "$TL_TMP/work3" commit -q -am "drop silver-bullet" && git -C "$TL_TMP/work3" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work3" bash "$SCRIPT" 2.0.0
assert_eq "manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false success" "$TL_OUT" "already at silver-bullet"
assert_eq "nothing pushed" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "manifest byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$TL_TMP/work3/$MF")"

# Wrong-typed source: jq refuses, the manifest stays byte-identical.
j_make_remote "$TL_TMP/mk4"
j_clone_remote "$TL_TMP/work4"
jq '(.plugins[] | select(.name=="silver-bullet") | .source) = "github:o/sb"' "$TL_TMP/work4/$MF" >"$TL_TMP/str-src.json"
cp "$TL_TMP/str-src.json" "$TL_TMP/work4/$MF"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work4" bash "$SCRIPT" 2.0.0
assert_eq "string-valued source fails the run" 1 "$([[ "$TL_STATUS" -ne 0 ]] && echo 1 || echo 0)"
assert_eq "string-valued source manifest byte-identical" "$(<"$TL_TMP/str-src.json")" "$(<"$TL_TMP/work4/$MF")"

# A manifest that is not valid JSON is reported as such, not as a missing entry.
j_make_remote "$TL_TMP/mkjs"
j_clone_remote "$TL_TMP/workjs"
printf '%s' '{"plugins": [' >"$TL_TMP/workjs/$MF"
git -C "$TL_TMP/workjs" commit -q -am "corrupt manifest" && git -C "$TL_TMP/workjs" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/workjs" bash "$SCRIPT" 2.0.0
assert_eq "invalid remote JSON exits 1" 1 "$TL_STATUS"
assert_contains "invalid remote JSON named as such" "$TL_ERR" "workjs/$MF is not valid JSON"
assert_not_contains "invalid JSON is not reported as a missing entry" "$TL_ERR" "no silver-bullet entry"
assert_eq "nothing pushed for invalid remote JSON" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "invalid remote file byte-identical" '{"plugins": [' "$(<"$TL_TMP/workjs/$MF")"

tl_results
