#!/usr/bin/env bash
# scripts/install-cursor.sh helper functions, called one at a time: the script
# is sourced with SB_INSTALL_CURSOR_SOURCE_ONLY=1 from a disposable snapshot of
# the checkout (the installer writes next to itself), under a sandboxed HOME,
# with local bare repositories standing in for GitHub.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
# shellcheck source=tests/lib/repo-snapshot.sh
source "$TL_REPO_ROOT/tests/lib/repo-snapshot.sh"
# shellcheck source=tests/lib/offline-tools.sh
source "$TL_REPO_ROOT/tests/lib/offline-tools.sh"
sb_offline_tools_install "$TL_TMP/offline-bin"

SNAP="$(sb_repo_snapshot --git "$TL_REPO_ROOT" "$TL_TMP/snap")"
SCRIPT="$SNAP/scripts/install-cursor.sh"
CH="$TL_TMP/cursor-home"
mkdir -p "$CH"
UPSTREAM="$TL_TMP/upstream.git"

# Upstream "GitHub": a bare repo with one commit.
git init -q --bare "$UPSTREAM"
git clone -q "$UPSTREAM" "$TL_TMP/seed" 2>/dev/null
git -C "$TL_TMP/seed" config user.email t@example.invalid
git -C "$TL_TMP/seed" config user.name t
git -C "$TL_TMP/seed" config gc.auto 0
git -C "$TL_TMP/seed" config maintenance.auto false
echo upstream >"$TL_TMP/seed/file"
git -C "$TL_TMP/seed" add -A
git -C "$TL_TMP/seed" -c commit.gpgsign=false commit -q -m upstream
git -C "$TL_TMP/seed" push -q origin HEAD 2>/dev/null
UP_SHA="$(git -C "$TL_TMP/seed" rev-parse HEAD)"
SNAP_SHA="$(git -C "$SNAP" rev-parse HEAD)"

sub() { # sub <function> [args...]
  tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" SB_INSTALL_CURSOR_SOURCE_ONLY=1 \
    bash -c 'source "$1"; shift; "$@"' _ "$SCRIPT" "$@"
}
reset_home() { rm -rf "$CH"; mkdir -p "$CH"; }

# ---- entry point flags run the real script
tl_run bash "$SCRIPT" --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "Usage: scripts/install-cursor.sh"
tl_run env CURSOR_HOME="$CH" bash "$SCRIPT" --bogus
assert_eq "unknown option exits 2" 2 "$TL_STATUS"
assert_contains "unknown option named" "$TL_ERR" "Unknown option: --bogus"

# ---- version fallback when package.json is unreadable
cp "$SNAP/package.json" "$TL_TMP/package.json.bak"
printf 'not json' >"$SNAP/package.json"
tl_run env CURSOR_HOME="$CH" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; echo "$VERSION"' _ "$SCRIPT"
assert_eq "unparseable package.json falls back to 0.0.0" 0.0.0 "$TL_OUT"
cp "$TL_TMP/package.json.bak" "$SNAP/package.json"

# ---- resolve_cursor_install_dest
reset_home
CACHE="$CH/plugins/cache/alo-labs/silver-bullet"
sub resolve_cursor_install_dest
assert_eq "nothing installed: nothing resolved" "" "$TL_OUT"
mkdir -p "$CACHE/1.2.0" "$CACHE/1.10.0" "$CACHE/not-a-version"
sub resolve_cursor_install_dest
assert_eq "no current link: newest version directory" "$CACHE/1.10.0" "$TL_OUT"
ln -s "$CACHE/1.2.0" "$CACHE/current"
sub resolve_cursor_install_dest
assert_eq "current symlink resolved to its target" "$CACHE/1.2.0" "$TL_OUT"
sub resolve_cursor_install_dest "$CACHE/current"
assert_eq "explicit current path resolved to its target" "$CACHE/1.2.0" "$TL_OUT"
sub resolve_cursor_install_dest "$CACHE/1.10.0"
assert_eq "explicit versioned directory kept" "$CACHE/1.10.0" "$TL_OUT"
rm -f "$CACHE/current"
ln -s "$TL_TMP/missing-target" "$CACHE/current"
sub resolve_cursor_install_dest
assert_eq "dangling current link falls back to the newest version" "$CACHE/1.10.0" "$TL_OUT"
rm -f "$CACHE/current"
mkdir -p "$CACHE/current"
sub resolve_cursor_install_dest
assert_eq "current as a real directory is used directly" "$CACHE/current" "$TL_OUT"
rmdir "$CACHE/current"

# ---- commands source
mkdir -p "$TL_TMP/src1/plugins/silver-bullet/commands" "$TL_TMP/src2"
sub cursor_plugin_commands_src "$TL_TMP/src1"
assert_eq "commands dir located" "$TL_TMP/src1/plugins/silver-bullet/commands" "$TL_OUT"
sub cursor_plugin_commands_src "$TL_TMP/src2"
assert_eq "no commands dir: nothing printed" "" "$TL_OUT"

# ---- marketplace checkout and manifest
reset_home
MPR="$CH/plugins/marketplaces/alo-labs-cursor"
sub ensure_marketplace_checkout "file://$UPSTREAM"
assert_eq "marketplace cloned" 0 "$TL_STATUS"
assert_file_exists "marketplace checkout present" "$MPR/file"
mkdir -p "$TL_TMP/lonely" && git -C "$TL_TMP/lonely" init -q
rm -rf "$MPR"; mkdir -p "$(dirname "$MPR")"; cp -R "$TL_TMP/lonely" "$MPR"
sub ensure_marketplace_checkout "file://$UPSTREAM"
assert_eq "existing checkout without a remote: failures tolerated" 0 "$TL_STATUS"
rm -rf "$MPR"
sub read_marketplace_version
assert_eq "missing manifest aborts" 1 "$TL_STATUS"
assert_contains "missing manifest explained" "$TL_ERR" "Cursor marketplace manifest not found at $MPR/.cursor-plugin/marketplace.json"
sub read_marketplace_manifest_sha
assert_eq "missing manifest: no sha, no error" 0 "$TL_STATUS"
mkdir -p "$MPR/.cursor-plugin"
printf '{"plugins":[{"name":"other","version":"0"},{"name":"silver-bullet","version":"4.5.6","source":{"sha":"abc123"}}]}\n' >"$MPR/.cursor-plugin/marketplace.json"
sub read_marketplace_version
assert_eq "version read from the manifest" 4.5.6 "$TL_OUT"
sub read_marketplace_manifest_sha
assert_eq "sha read from the manifest" abc123 "$TL_OUT"
printf 'not json' >"$MPR/.cursor-plugin/marketplace.json"
sub read_marketplace_manifest_sha
assert_eq "unparseable manifest: sha lookup tolerated" 0 "$TL_STATUS"

# ---- sync_plugin_tree_from_checkout against a fabricated source tree
make_source() { # make_source <root> [with-commands] [with-skill-source] [with-generator]
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root/hooks" "$root/scripts" "$root/templates" "$root/skills/silver-init/scripts" "$root/.cursor-plugin"
  echo h >"$root/hooks/h.sh"; echo s >"$root/scripts/s.sh"; echo t >"$root/templates/t"; echo i >"$root/skills/silver-init/scripts/i.sh"
  printf '{"name":"silver-bullet","version":"0","skills":"./skills","commands":"./old"}\n' >"$root/.cursor-plugin/plugin.json"
  if [[ "${2:-}" == with-commands ]]; then mkdir -p "$root/plugins/silver-bullet/commands"; echo c >"$root/plugins/silver-bullet/commands/sb.md"; fi
  if [[ "${3:-}" == with-skill-source ]]; then mkdir -p "$root/plugins/silver-bullet/skill-source/x"; echo y >"$root/plugins/silver-bullet/skill-source/x/SILVER_SOURCE"; fi
  if [[ "${4:-}" == with-generator ]]; then
    printf 'import pathlib\npathlib.Path(__file__).resolve().parent.parent.joinpath("hooks","cursor-hooks.json").write_text("{}\\n")\n' >"$root/scripts/generate-cursor-hooks.py"
    chmod +x "$root/scripts/generate-cursor-hooks.py"
  fi
}
reset_home
make_source "$TL_TMP/srcA" with-commands with-skill-source with-generator
sub sync_plugin_tree_from_checkout "$TL_TMP/srcA" 9.1.0
assert_eq "tree sync exits 0" 0 "$TL_STATUS"
D="$CACHE/9.1.0"
assert_eq "tree sync prints the destination" "$D" "$TL_OUT"
assert_file_exists "hooks synced" "$D/hooks/h.sh"
assert_file_exists "generated cursor hooks installed" "$D/hooks/cursor-hooks.json"
assert_file_exists "silver-init scripts kept" "$D/skills/silver-init/scripts/i.sh"
assert_file_exists "skill-source synced" "$D/skill-source/x/SILVER_SOURCE"
assert_file_exists "commands synced" "$D/commands/sb.md"
assert_eq "manifest version stamped" 9.1.0 "$(jq -r .version "$D/.cursor-plugin/plugin.json")"
assert_eq "manifest points at the commands dir" "./commands" "$(jq -r .commands "$D/.cursor-plugin/plugin.json")"
assert_eq "manifest drops skills" null "$(jq -c .skills "$D/.cursor-plugin/plugin.json")"
# second tree without commands/skill-source: stale copies are removed, manifest loses commands
make_source "$TL_TMP/srcB" "" "" with-generator
sub sync_plugin_tree_from_checkout "$TL_TMP/srcB" 9.1.0
assert_eq "second sync exits 0" 0 "$TL_STATUS"
assert_file_absent "stale skill-source removed" "$D/skill-source"
assert_file_absent "stale commands removed" "$D/commands"
assert_eq "manifest drops commands without a commands dir" null "$(jq -c .commands "$D/.cursor-plugin/plugin.json")"
# generator missing in the source tree: the checkout's generator is used
make_source "$TL_TMP/srcC" with-commands
sub sync_plugin_tree_from_checkout "$TL_TMP/srcC" 9.2.0
assert_eq "falls back to the installer's own generator" 0 "$TL_STATUS"
assert_file_exists "fallback generator output installed into the cache" "$CACHE/9.2.0/hooks/cursor-hooks.json"
# ...and fails when neither generator is available
mv "$SNAP/scripts/generate-cursor-hooks.py" "$TL_TMP/generator.bak"
make_source "$TL_TMP/srcD"
sub sync_plugin_tree_from_checkout "$TL_TMP/srcD" 9.3.0
assert_eq "no generator anywhere aborts" 1 "$TL_STATUS"
assert_contains "missing generator explained" "$TL_ERR" "missing scripts/generate-cursor-hooks.py"
mv "$TL_TMP/generator.bak" "$SNAP/scripts/generate-cursor-hooks.py"
# plugin manifest fallbacks
make_source "$TL_TMP/srcE" "" "" with-generator
rm -f "$TL_TMP/srcE/.cursor-plugin/plugin.json"
sub sync_plugin_tree_from_checkout "$TL_TMP/srcE" 9.4.0
assert_eq "manifest taken from the installer checkout when the source has none" 0 "$TL_STATUS"
assert_eq "fallback manifest stamped" 9.4.0 "$(jq -r .version "$CACHE/9.4.0/.cursor-plugin/plugin.json")"
mv "$SNAP/.cursor-plugin/plugin.json" "$TL_TMP/plugin.json.bak"
sub sync_plugin_tree_from_checkout "$TL_TMP/srcE" 9.5.0
assert_eq "no manifest anywhere aborts" 1 "$TL_STATUS"
assert_contains "missing manifest explained" "$TL_ERR" "missing Cursor plugin manifest at $SNAP/.cursor-plugin/plugin.json"
mv "$TL_TMP/plugin.json.bak" "$SNAP/.cursor-plugin/plugin.json"

# ---- commit resolution
sub resolve_install_commit_sha "$SNAP"
assert_eq "commit of a git source" "$SNAP_SHA" "$TL_OUT"
mkdir -p "$TL_TMP/plain-dir"
sub resolve_install_commit_sha "$TL_TMP/plain-dir"
assert_eq "non-git source falls back to the installer checkout" "$SNAP_SHA" "$TL_OUT"
sub cursor_git_common_dir "$SNAP"
assert_eq "git common dir made absolute" "$SNAP/.git" "$TL_OUT"
sub cursor_git_common_dir "$TL_TMP/plain-dir"
assert_eq "no git dir: failure" 1 "$TL_STATUS"
git clone -q --separate-git-dir "$TL_TMP/sep.git" "$UPSTREAM" "$TL_TMP/sepwork" 2>/dev/null
sub cursor_git_common_dir "$TL_TMP/sepwork"
assert_eq "separate git dir resolved" "$TL_TMP/sep.git" "$TL_OUT"

# ---- ensure_cursor_github_marketplace_gitpath
echo second >>"$TL_TMP/seed/file"
git -C "$TL_TMP/seed" -c commit.gpgsign=false commit -q -am second
git -C "$TL_TMP/seed" push -q origin HEAD 2>/dev/null
UP_SHA2="$(git -C "$TL_TMP/seed" rev-parse HEAD)"
GPR="$CH/plugins/marketplaces/github.com/alo-exp/silver-bullet"
# subx_env <pre-call shell code> <function> [args...]: run with function overrides applied after sourcing
subx() {
  tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="${REPO_URL:-file://$UPSTREAM}" SB_INSTALL_CURSOR_SOURCE_ONLY=1 \
    bash -c 'source "$1"; shift; eval "$PRE"; "$@"' _ "$SCRIPT" "$@"
}
subx_env() { local PRE="$1"; shift; export PRE; subx "$@"; }
reset_home
sub ensure_cursor_github_marketplace_gitpath "" "$SNAP"
assert_eq "empty sha is a no-op" 0 "$TL_STATUS"
assert_file_absent "nothing cloned for an empty sha" "$GPR"
sub ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
assert_eq "local checkout cloned for its own HEAD" 0 "$TL_STATUS"
assert_file_exists "gitPath checkout created" "$GPR/$SNAP_SHA/.git"
assert_eq "gitPath checked out at the sha" "$SNAP_SHA" "$(git -C "$GPR/$SNAP_SHA" rev-parse HEAD)"
sub ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
assert_eq "existing gitPath reused" 0 "$TL_STATUS"
# checkout failure on an existing gitPath is tolerated
REAL_GIT="$(command -v git)"
tl_stub git 'if [[ "$*" == *" checkout "* ]]; then exit 1; fi; exec '"$REAL_GIT"' "$@"'
sub ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
assert_eq "failing checkout of an existing gitPath tolerated" 0 "$TL_STATUS"
rm -rf "${GPR:?}/$SNAP_SHA"
sub ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
assert_eq "failing checkout after a fresh local clone tolerated" 0 "$TL_STATUS"
rm -f "$TL_BIN/git"
# a plain directory squatting on the gitPath is replaced
rm -rf "${GPR:?}/$SNAP_SHA"; mkdir -p "$GPR/$SNAP_SHA"; echo junk >"$GPR/$SNAP_SHA/junk"
sub ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
assert_file_absent "squatting directory replaced" "$GPR/$SNAP_SHA/junk"
assert_file_exists "fresh clone in place" "$GPR/$SNAP_SHA/.git"
# common dir unusable -> clone straight from the source; no common dir -> same
rm -rf "${GPR:?}/$SNAP_SHA"
subx_env 'cursor_git_common_dir() { echo /nonexistent/git-dir; }' ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
assert_eq "unusable common dir: clone from the checkout" 0 "$TL_STATUS"
assert_file_exists "clone from the checkout present" "$GPR/$SNAP_SHA/.git"
rm -rf "${GPR:?}/$SNAP_SHA"
subx_env 'cursor_git_common_dir() { return 1; }' ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
assert_eq "no common dir: clone from the checkout" 0 "$TL_STATUS"
assert_file_exists "clone without a common dir present" "$GPR/$SNAP_SHA/.git"
# a sha that is not the checkout's HEAD comes from the upstream repo
sub ensure_cursor_github_marketplace_gitpath "$UP_SHA2" "$SNAP"
assert_eq "upstream HEAD cloned" 0 "$TL_STATUS"
assert_eq "upstream checkout at the sha" "$UP_SHA2" "$(git -C "$GPR/$UP_SHA2" rev-parse HEAD)"
rm -rf "${GPR:?}/$UP_SHA"
sub ensure_cursor_github_marketplace_gitpath "$UP_SHA" "$SNAP"
assert_eq "older upstream commit fetched on demand" 0 "$TL_STATUS"
assert_eq "older commit checked out" "$UP_SHA" "$(git -C "$GPR/$UP_SHA" rev-parse HEAD)"
# shallow clone refused by the remote -> full clone
rm -rf "${GPR:?}/$UP_SHA2"
tl_stub git 'if [[ "$*" == *"--depth"* && "$*" == *" clone "* ]]; then exit 1; fi; exec '"$REAL_GIT"' "$@"'
sub ensure_cursor_github_marketplace_gitpath "$UP_SHA2" "$SNAP"
assert_eq "full clone used when the shallow clone fails" 0 "$TL_STATUS"
assert_file_exists "full clone present" "$GPR/$UP_SHA2/.git"
rm -f "$TL_BIN/git"
# unreachable commit: cleaned up, reported, failure status
BOGUS="$(printf 'a%.0s' $(seq 1 40))"
sub ensure_cursor_github_marketplace_gitpath "$BOGUS" "$SNAP"
assert_eq "unreachable commit fails" 1 "$TL_STATUS"
assert_contains "unreachable commit reported" "$TL_ERR" "skipped unreachable Cursor gitPath commit aaaaaaaa"
assert_file_absent "unreachable checkout removed" "$GPR/$BOGUS"
# both clones fail
tl_stub git 'if [[ " $* " == *" clone "* ]]; then exit 1; fi; exec '"$REAL_GIT"' "$@"'
sub ensure_cursor_github_marketplace_gitpath "$BOGUS" "$SNAP"
assert_eq "failing clones propagate" 1 "$([[ $TL_STATUS -ne 0 ]] && echo 1 || echo 0)"
rm -f "$TL_BIN/git"

# ---- marketplace cache symlink
reset_home
DESTX="$TL_TMP/dest-x"; mkdir -p "$DESTX/commands" "$DESTX/.cursor-plugin"
echo '{"version":"1","commands":"./commands"}' >"$DESTX/.cursor-plugin/plugin.json"
sub ensure_cursor_marketplace_plugin_cache_symlink "$DESTX" ""
assert_eq "empty sha: no link" 0 "$TL_STATUS"
LINKROOT="$CH/plugins/cache/alo-labs-cursor/silver-bullet"
mkdir -p "$LINKROOT/$SNAP_SHA/stale"
sub ensure_cursor_marketplace_plugin_cache_symlink "$DESTX" "$SNAP_SHA"
assert_eq "link created over a real directory" 0 "$TL_STATUS"
assert_eq "cache entry is a symlink to the install" "$DESTX" "$(readlink "$LINKROOT/$SNAP_SHA")"
tl_stub ln 'exit 1'
sub ensure_cursor_marketplace_plugin_cache_symlink "$DESTX" "$SNAP_SHA"
assert_eq "failing ln reported" 1 "$TL_STATUS"
assert_contains "failing ln explained" "$TL_ERR" "failed to link Cursor marketplace cache"
rm -f "$TL_BIN/ln"
# rm that cannot clear the old entry is tolerated
tl_stub rm '[[ "$*" == *"alo-labs-cursor/silver-bullet/"* ]] && exit 1; exec /bin/rm "$@"'
sub ensure_cursor_marketplace_plugin_cache_symlink "$DESTX" "$SNAP_SHA"
assert_eq "failing removal of the old link tolerated" 0 "$TL_STATUS"
rm -f "$TL_BIN/rm"

# ---- registry git sha
reset_home
sub read_installed_plugins_git_sha
assert_eq "no registry: nothing" "" "$TL_OUT"
mkdir -p "$CH/plugins"
REG="$CH/plugins/installed_plugins.json"
printf '{"plugins":{"silver-bullet@alo-labs":[{"gitCommitSha":"aaa"}]}}\n' >"$REG"
sub read_installed_plugins_git_sha
assert_eq "array entry sha" aaa "$TL_OUT"
printf '{"plugins":{"silver-bullet@alo-labs":{"gitCommitSha":"bbb"}}}\n' >"$REG"
sub read_installed_plugins_git_sha
assert_eq "object entry sha" bbb "$TL_OUT"
printf '{"plugins":{}}\n' >"$REG"
sub read_installed_plugins_git_sha
assert_eq "absent entry: nothing" "" "$TL_OUT"
printf 'not json' >"$REG"
sub read_installed_plugins_git_sha
assert_eq "unparseable registry tolerated" 0 "$TL_STATUS"

# ---- remote head
sub resolve_remote_github_head_sha
assert_eq "remote HEAD resolved from the upstream" "$UP_SHA2" "$TL_OUT"

tl_results
