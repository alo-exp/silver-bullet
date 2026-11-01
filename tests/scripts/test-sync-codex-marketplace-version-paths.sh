#!/usr/bin/env bash
# sync-codex-marketplace-version.sh against local git remotes and a stubbed package sync.
# Default mode aligns the in-repo Codex plugin manifest (version and config_version) with
# package.json and refuses any other version (R8-18); --publish pins the unified
# marketplace entry to the release tag, only once that tag exists, commits only the
# manifest, pushes and confirms the push.
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
PJ=plugins/silver-bullet/.codex-plugin/plugin.json
MF=.agents/plugins/marketplace.json
# new_tree [tag]: package.json 2.0.0, a stale Codex plugin manifest, a stub package sync
# (STUB_PKG_VERSION makes it rewrite .version the way sync-codex-package.sh does).
new_tree() {
  rm -rf "$T"
  mkdir -p "$T/scripts/lib" "$T/plugins/silver-bullet/.codex-plugin"
  cp "$TL_REPO_ROOT/scripts/sync-codex-marketplace-version.sh" "$T/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh" "$T/scripts/lib/"
  jq -n '{version: "2.0.0"}' >"$T/package.json"
  jq -n '{name: "silver-bullet", version: "1.0.0", config_version: "1.0.0", keep: {x: null}}' >"$T/$PJ"
  chmod 644 "$T/$PJ"
  cat >"$T/scripts/sync-codex-package.sh" <<PKG
#!/usr/bin/env bash
echo package-sync-ran >>"$PKG_LOG"
root="\$(cd "\$(dirname "\$0")/.." && pwd)"
if [[ -n "\${STUB_PKG_VERSION:-}" ]]; then
  jq --arg v "\$STUB_PKG_VERSION" '.version = \$v' "\$root/$PJ" >"\$root/pj.tmp" && mv "\$root/pj.tmp" "\$root/$PJ"
fi
PKG
  chmod +x "$T/scripts/sync-codex-package.sh"
  : >"$PKG_LOG"
  git init -q -b main "$T"
  git -C "$T" add -A
  git -C "$T" commit -q -m release
  [[ -z "${1:-}" ]] || git -C "$T" tag -a "$1" -m release
}
# prepared_tree TAG: the in-repo manifest already aligned and committed, tagged TAG.
prepared_tree() {
  new_tree
  sync_run bash "$SCRIPT" >/dev/null
  git -C "$T" commit -q -am "align manifests"
  [[ -z "${1:-}" ]] || git -C "$T" tag -a "$1" -m release
  : >"$PKG_LOG"
}
SCRIPT="$T/scripts/sync-codex-marketplace-version.sh"
sync_run() { tl_run env -u AGENT_PLUGINS_REPO_ROOT -u CODEX_MARKETPLACE_REPO_ROOT -u AGENT_PLUGINS_REPO_URL -u CODEX_MARKETPLACE_REPO_URL -u AGENT_PLUGINS_SKIP_PUSH timeout 60 "$@"; }
remote_field() { j_remote_show "$MF" | jq -r --arg k "$1" '.plugins[] | select(.name=="silver-bullet") | getpath($k | split("."))'; }

# --- default mode: this repository only ----------------------------------------------------
j_make_remote "$TL_TMP/mk"
j_clone_remote "$TL_TMP/work"
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
new_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" v2.0.0
assert_eq "in-repo sync exits 0" 0 "$TL_STATUS"
assert_contains "plugin manifest update reported" "$TL_OUT" "Updated version/config_version: 1.0.0/1.0.0 → 2.0.0"
assert_contains "in-repo banner" "$TL_OUT" "This repository's Codex plugin manifest is at v2.0.0."
assert_eq "plugin.json version" "2.0.0" "$(jq -r .version "$T/$PJ")"
assert_eq "plugin.json config_version" "2.0.0" "$(jq -r .config_version "$T/$PJ")"
assert_eq "plugin.json nulls preserved" 'null' "$(jq -c .keep.x "$T/$PJ")"
assert_eq "plugin.json keeps mode 644 (R13-28)" "644" "$(stat -c %a "$T/$PJ" 2>/dev/null || stat -f %Lp "$T/$PJ")"
assert_eq "package sync ran once" "package-sync-ran" "$(<"$PKG_LOG")"
assert_eq "marketplace checkout untouched" "" "$(git -C "$TL_TMP/work" status --porcelain)"
assert_eq "remote untouched" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

sync_run bash "$SCRIPT" 2.0.0
assert_eq "second in-repo sync exits 0" 0 "$TL_STATUS"
assert_contains "plugin manifest already in sync" "$TL_OUT" "Version and config_version already in sync: 2.0.0"

# Without an argument the version comes from package.json; only a stale config_version is rewritten.
new_tree
jq '.version = "2.0.0"' "$T/$PJ" >"$TL_TMP/p.json" && cp "$TL_TMP/p.json" "$T/$PJ"
sync_run bash "$SCRIPT"
assert_eq "no-argument sync exits 0" 0 "$TL_STATUS"
assert_contains "stale config_version rewritten" "$TL_OUT" "Updated version/config_version: 2.0.0/1.0.0 → 2.0.0"
assert_eq "config_version synced" "2.0.0" "$(jq -r .config_version "$T/$PJ")"

# R8-18: a version other than package.json is refused before anything is written.
new_tree
sync_run bash "$SCRIPT" 9.9.9
assert_eq "version differing from package.json exits 1" 1 "$TL_STATUS"
assert_contains "mismatch explained" "$TL_ERR" "package.json is 2.0.0 but the release version is 9.9.9. Bump package.json first."
assert_eq "plugin manifest untouched on mismatch" "1.0.0/1.0.0" "$(jq -r '"\(.version)/\(.config_version)"' "$T/$PJ")"
assert_eq "package sync not run on mismatch" "" "$(<"$PKG_LOG")"

# R8-18: a package sync that leaves another version behind fails the run.
new_tree
sync_run env STUB_PKG_VERSION=1.9.9 bash "$SCRIPT" 2.0.0
assert_eq "manifest drift after the package sync exits 1" 1 "$TL_STATUS"
assert_contains "drift explained" "$TL_ERR" "$PJ is 1.9.9 (config_version 2.0.0) after the package sync, expected 2.0.0"
assert_not_contains "no success banner after drift" "$TL_OUT" "is at v2.0.0"

# --- --publish ---------------------------------------------------------------------------------
prepared_tree
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "publish without the release tag exits 1" 1 "$TL_STATUS"
assert_contains "missing tag explained" "$TL_ERR" "release tag v2.0.0 does not exist"
assert_eq "nothing published without the tag" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

new_tree v2.0.0
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "publish with an unaligned plugin manifest exits 1" 1 "$TL_STATUS"
assert_contains "unaligned plugin manifest explained" "$TL_ERR" "$PJ is 1.0.0 (config_version 1.0.0), not 2.0.0: run scripts/sync-codex-marketplace-version.sh 2.0.0 and commit"
assert_eq "no package sync when publishing" "" "$(<"$PKG_LOG")"

prepared_tree v2.0.0
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish v2.0.0
assert_eq "publish exits 0" 0 "$TL_STATUS"
assert_contains "remote update reported" "$TL_OUT" "Updated Codex marketplace manifest: 0.0.1 → 2.0.0"
assert_contains "push reported" "$TL_OUT" "Pushed 1 commit(s) to origin/main"
assert_contains "publish banner" "$TL_OUT" "The agent-plugins Codex manifest now offers silver-bullet v2.0.0."
assert_eq "remote version pushed" "2.0.0" "$(remote_field version)"
assert_eq "remote ref pinned to the release tag" "v2.0.0" "$(remote_field source.ref)"
assert_eq "remote source repo preserved" "o/sb" "$(remote_field source.repo)"
assert_eq "foreign plugin preserved" "$(jq -c '.plugins[0]' "$J_SEED/$MF")" "$(j_remote_show "$MF" | jq -c '.plugins[0]')"
assert_eq "JSON nulls preserved in the remote" 'null' "$(j_remote_show "$MF" | jq -c '.metadata.note')"
assert_eq "commit message" "Bump silver-bullet Codex manifest to 2.0.0" "$(git -C "$J_REMOTE" log -1 --format=%s main)"
assert_eq "commit holds only the manifest" "$MF" "$(git -C "$J_REMOTE" show --name-only --format= main)"
assert_eq "no package sync when publishing" "" "$(<"$PKG_LOG")"
assert_eq "in-repo tree untouched by --publish" "" "$(git -C "$T" status --porcelain)"

# Idempotent second publish; CODEX_MARKETPLACE_REPO_ROOT is the legacy root variable.
before="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env CODEX_MARKETPLACE_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "second publish exits 0" 0 "$TL_STATUS"
assert_contains "remote already current" "$TL_OUT" "Codex marketplace manifest already at silver-bullet 2.0.0"
assert_eq "second publish pushes nothing" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# --- clone path -------------------------------------------------------------------------
j_make_remote "$TL_TMP/mk2"
mkdir -p "$TL_TMP/tmpdir"
sync_run env TMPDIR="$TL_TMP/tmpdir" AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "clone-based publish exits 0" 0 "$TL_STATUS"
assert_eq "clone-based publish pushed" "v2.0.0" "$(remote_field source.ref)"
assert_eq "temporary clone removed" "" "$(ls -A "$TL_TMP/tmpdir")"

# --- prerequisites and errors -----------------------------------------------------------------
new_tree
sync_run env PATH="$(tl_path_without jq)" bash "$SCRIPT" 2.0.0
assert_eq "missing jq exits 1" 1 "$TL_STATUS"
assert_contains "missing jq reported" "$TL_OUT" "jq required"

sync_run bash "$SCRIPT" --bogus
assert_eq "unknown option exits 1" 1 "$TL_STATUS"
assert_contains "unknown option named" "$TL_ERR" "unknown option: --bogus"

new_tree
rm -f "$T/scripts/sync-codex-package.sh"
sync_run bash "$SCRIPT" 2.0.0
assert_eq "missing package sync script exits 1" 1 "$TL_STATUS"
assert_contains "missing package sync script named" "$TL_ERR" "Codex package sync script not found or not executable: $T/scripts/sync-codex-package.sh"

new_tree
printf '#!/usr/bin/env bash\nexit 9\n' >"$T/scripts/sync-codex-package.sh"
sync_run bash "$SCRIPT" 2.0.0
assert_eq "failing package sync fails the run" 1 "$TL_STATUS"
assert_not_contains "no success banner after a failed package sync" "$TL_OUT" "is at v2.0.0"

prepared_tree v2.0.0
mkdir -p "$TL_TMP/notgit"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/notgit" bash "$SCRIPT" --publish 2.0.0
assert_eq "non-git marketplace root exits 1" 1 "$TL_STATUS"
assert_contains "non-git root named" "$TL_ERR" "marketplace repo root is not a git repository: $TL_TMP/notgit"
git init -q -b main "$TL_TMP/nomanifest"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/nomanifest" bash "$SCRIPT" --publish 2.0.0
assert_eq "marketplace repo without manifest exits 1" 1 "$TL_STATUS"
assert_contains "missing manifest named" "$TL_ERR" "Codex marketplace manifest not found in repo: $TL_TMP/nomanifest/$MF"

# A marketplace checkout with uncommitted edits to the manifest is refused.
j_make_remote "$TL_TMP/mkw"
j_clone_remote "$TL_TMP/wip"
jq '.plugins[0].version = "9.9.10"' "$TL_TMP/wip/$MF" >"$TL_TMP/wip.json" && cp "$TL_TMP/wip.json" "$TL_TMP/wip/$MF"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/wip" bash "$SCRIPT" --publish 2.0.0
assert_eq "uncommitted manifest edit refused" 1 "$TL_STATUS"
assert_contains "uncommitted edit explained" "$TL_ERR" "$TL_TMP/wip/$MF has uncommitted changes"

# Manifest without a silver-bullet entry: no success report, no commit, no push.
j_make_remote "$TL_TMP/mk3"
j_clone_remote "$TL_TMP/work3"
jq 'del(.plugins[] | select(.name=="silver-bullet"))' "$TL_TMP/work3/$MF" >"$TL_TMP/no-sb.json"
cp "$TL_TMP/no-sb.json" "$TL_TMP/work3/$MF"
git -C "$TL_TMP/work3" commit -q -am "drop silver-bullet" && git -C "$TL_TMP/work3" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work3" bash "$SCRIPT" --publish 2.0.0
assert_eq "manifest without silver-bullet exits 1" 1 "$TL_STATUS"
assert_contains "missing entry explained" "$TL_ERR" "no silver-bullet entry"
assert_not_contains "no false success" "$TL_OUT" "already at silver-bullet"
assert_eq "nothing pushed" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "manifest byte-identical" "$(<"$TL_TMP/no-sb.json")" "$(<"$TL_TMP/work3/$MF")"

# Wrong-typed source: jq refuses, the manifest stays byte-identical and no temporary file is left.
j_make_remote "$TL_TMP/mk4"
j_clone_remote "$TL_TMP/work4"
jq '(.plugins[] | select(.name=="silver-bullet") | .source) = "github:o/sb"' "$TL_TMP/work4/$MF" >"$TL_TMP/str-src.json"
cp "$TL_TMP/str-src.json" "$TL_TMP/work4/$MF"
git -C "$TL_TMP/work4" commit -q -am "string source" && git -C "$TL_TMP/work4" push -q origin main
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work4" bash "$SCRIPT" --publish 2.0.0
assert_eq "string-valued source fails the run" 1 "$([[ "$TL_STATUS" -ne 0 ]] && echo 1 || echo 0)"
assert_eq "string-valued source manifest byte-identical" "$(<"$TL_TMP/str-src.json")" "$(<"$TL_TMP/work4/$MF")"
assert_eq "no temporary file left after a jq failure" "" "$(git -C "$TL_TMP/work4" status --porcelain)"

# A manifest that is not valid JSON is reported as such, not as a missing entry.
j_make_remote "$TL_TMP/mkjs"
j_clone_remote "$TL_TMP/workjs"
printf '%s' '{"plugins": [' >"$TL_TMP/workjs/$MF"
git -C "$TL_TMP/workjs" commit -q -am "corrupt manifest" && git -C "$TL_TMP/workjs" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
sync_run env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/workjs" bash "$SCRIPT" --publish 2.0.0
assert_eq "invalid remote JSON exits 1" 1 "$TL_STATUS"
assert_contains "invalid remote JSON named as such" "$TL_ERR" "workjs/$MF is not valid JSON"
assert_not_contains "invalid JSON is not reported as a missing entry" "$TL_ERR" "no silver-bullet entry"
assert_eq "nothing pushed for invalid remote JSON" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "invalid remote file byte-identical" '{"plugins": [' "$(<"$TL_TMP/workjs/$MF")"

tl_results
