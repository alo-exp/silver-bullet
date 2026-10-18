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

# A trimmed snapshot keeps the many local clones below cheap: the installer functions need
# scripts/, hooks/, skills/, templates/ and the plugin manifests, not tests, docs or sites.
SNAP="$(sb_repo_snapshot "$TL_REPO_ROOT" "$TL_TMP/snap")"
for _d in tests docs site agents host-bundles .agentmemory .github research; do rm -rf "${SNAP:?}/$_d"; done
(
  cd "$SNAP"
  export GIT_AUTHOR_NAME="SB Test" GIT_AUTHOR_EMAIL="sb-test@example.invalid" GIT_COMMITTER_NAME="SB Test" GIT_COMMITTER_EMAIL="sb-test@example.invalid"
  git -c init.defaultBranch=main init -q
  git config gc.auto 0
  git config maintenance.auto false
  git add -A
  git -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "test snapshot"
)
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
SHA_X="$(printf 'c%.0s' $(seq 1 40))"
SHA_Y="$(printf 'd%.0s' $(seq 1 40))"

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
ln -sfn "$TL_TMP/tgt-old" "$LINKROOT/$SNAP_SHA"
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

# ---- gitPath surface helpers
REAL_RM="$(command -v rm)"
make_dest() {
  local d="$1" v="$2"
  mkdir -p "$d/commands" "$d/.cursor-plugin" "$d/skills/x"
  printf -- '---\nname: "sb"\n---\n' >"$d/commands/sb.md"
  printf -- '---\nname: "sb-init"\n---\n' >"$d/commands/sb-init.md"
  printf '{"version":"%s","commands":"./commands"}\n' "$v" >"$d/.cursor-plugin/plugin.json"
  echo '{}' >"$d/cursor-hooks.json"
}
reset_home
DP="$TL_TMP/dest-p"; rm -rf "${DP:?}"; make_dest "$DP" 4.0.0
G="$TL_TMP/gitpath-root"; rm -rf "${G:?}"; mkdir -p "$G/skills/old" "$G/plugins/silver-bullet/skills" "$G/.agents" "$G/.cursor/agents" "$G/host-bundles" "$G/agents/cursor" "$G/templates/workflows" "$G/commands"
sub prune_cursor_gitpath_picker_skills "$DP" "$G"
assert_file_exists "dest skills mirrored into the gitPath" "$G/skills/x"
assert_file_absent "old gitPath skills replaced" "$G/skills/old"
assert_file_absent "nested plugin skills removed" "$G/plugins/silver-bullet/skills"
assert_file_absent ".agents removed" "$G/.agents"
sub prune_cursor_gitpath_extra_picker_surfaces "$G"
assert_file_absent "host-bundles removed" "$G/host-bundles"
assert_file_absent "agents removed" "$G/agents"
assert_file_absent "workflow templates removed" "$G/templates/workflows"
mkdir -p "$G/skills/old" "$G/host-bundles" "$G/agents/cursor"
tl_stub rm 'exit 1'
sub prune_cursor_gitpath_picker_skills "$DP" "$G"
assert_eq "undeletable gitPath skills tolerated" 0 "$TL_STATUS"
sub prune_cursor_gitpath_extra_picker_surfaces "$G"
assert_eq "undeletable extra surfaces tolerated" 0 "$TL_STATUS"
sub materialize_cursor_plugin_surface_at_root "$DP" "$G"
assert_eq "materialization tolerates undeletable agents" 0 "$TL_STATUS"
"$REAL_RM" -f "${TL_BIN:?}/rm"
sub materialize_cursor_plugin_surface_at_root "$DP" "$G"
assert_file_exists "commands materialized at the root" "$G/commands/sb.md"
assert_file_exists "hooks file materialized" "$G/cursor-hooks.json"
assert_file_exists "manifest materialized" "$G/.cursor-plugin/plugin.json"
# the gitPath-level wrapper
sub materialize_cursor_plugin_surface_in_gitpath "$DP" ""
assert_eq "empty sha: nothing materialized" 0 "$TL_STATUS"
sub materialize_cursor_plugin_surface_in_gitpath "$DP" "$SHA_X"
assert_eq "no gitPath checkout: nothing materialized" 0 "$TL_STATUS"
sub ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
sub materialize_cursor_plugin_surface_in_gitpath "$DP" "$SNAP_SHA"
assert_file_exists "gitPath checkout got the commands" "$GPR/$SNAP_SHA/commands/sb.md"
sub cursor_plugin_gitpath_ready ""
assert_eq "empty sha: gitPath not ready" 1 "$TL_STATUS"
sub cursor_plugin_gitpath_ready "$SNAP_SHA"
assert_eq "cloned gitPath ready" 0 "$TL_STATUS"
sub cursor_plugin_gitpath_surface_ready "$SHA_X"
assert_eq "missing gitPath: surface not ready" 1 "$TL_STATUS"

# marketplace cache link readiness
sub cursor_marketplace_cache_link_ready "$DP" ""
assert_eq "empty sha: cache link not ready" 1 "$TL_STATUS"
sub cursor_marketplace_cache_link_ready "$DP" "$SNAP_SHA"
assert_eq "no cache link: not ready" 1 "$TL_STATUS"
LK="$CH/plugins/cache/alo-labs-cursor/silver-bullet"
mkdir -p "$LK"; ln -s "$TL_TMP/vanished" "$LK/$SNAP_SHA"
sub cursor_marketplace_cache_link_ready "$DP" "$SNAP_SHA"
assert_eq "dangling cache link: not ready" 1 "$TL_STATUS"
"$REAL_RM" -f "${LK:?}/$SNAP_SHA"; ln -s "$DP" "$LK/$SNAP_SHA"
sub cursor_marketplace_cache_link_ready "$DP" "$SNAP_SHA"
assert_eq "cache link to the install: ready" 0 "$TL_STATUS"

# seeding loops
"$REAL_RM" -rf "${GPR:?}" "${LK:?}"
subx_env 'collect_cursor_plugin_seed_shas() { printf "\n%s\n%s\n" "'"$SHA_X"'" "'"$SNAP_SHA"'"; }; ensure_cursor_github_marketplace_gitpath() { [[ "$1" == "'"$SNAP_SHA"'" ]]; }' seed_cursor_marketplace_gitpaths "$DP" "$SNAP_SHA" "$SNAP"
assert_eq "seeding skips blank lines and unmaterializable shas" 0 "$TL_STATUS"
assert_eq "seeded sha linked" "$DP" "$(readlink "$LK/$SNAP_SHA")"
assert_file_absent "skipped sha not linked" "$LK/$SHA_X"

# rematerialization
reset_home
sub rematerialize_all_reachable_cursor_gitpaths "$DP"
assert_eq "no gitPath root: nothing to rematerialize" 0 "$TL_STATUS"
mkdir -p "$GPR/$SHA_X" "$GPR/not-a-sha" "$GPR/$SHA_Y/.git"
echo f >"$GPR/stray-file"
sub ensure_cursor_github_marketplace_gitpath "$SNAP_SHA" "$SNAP"
sub rematerialize_all_reachable_cursor_gitpaths "$DP"
assert_eq "rematerialization exits 0" 0 "$TL_STATUS"
assert_file_exists "valid gitPath rematerialized" "$GPR/$SNAP_SHA/commands/sb.md"
assert_file_exists "marketplace cache link refreshed" "$CH/plugins/cache/alo-labs-cursor/silver-bullet/$SNAP_SHA"
assert_file_exists "backend cache refreshed" "$CH/plugins/cache/alo-labs-agent-plugins/silver-bullet/$SNAP_SHA/.cache-complete"
assert_file_absent "sha dir without .git left alone" "$GPR/$SHA_X/commands"
assert_file_absent "broken checkout left alone" "$GPR/$SHA_Y/commands"

# discovery verification: every failure branch is reported
verify() { # verify <overrides>
  subx_env "$1" verify_cursor_plugin_discovery_paths "$DP" "$SNAP"
}
BASE_OVR='collect_cursor_plugin_verify_shas() { echo "'"$SNAP_SHA"'"; }; resolve_cursor_backend_plugin_sha() { echo; }; cursor_local_plugin_link_ready() { return 0; }; '
verify "$BASE_OVR"'cursor_plugin_gitpath_ready() { return 1; }'
assert_eq "missing gitPath fails the verification" 1 "$TL_STATUS"
assert_contains "missing gitPath reported" "$TL_ERR" "Cursor gitPath missing for $SNAP_SHA"
verify "$BASE_OVR"'cursor_plugin_gitpath_ready() { return 0; }; cursor_plugin_gitpath_surface_ready() { return 1; }'
assert_contains "incomplete gitPath surface reported" "$TL_ERR" "gitPath plugin surface incomplete"
verify "$BASE_OVR"'cursor_plugin_gitpath_ready() { return 0; }; cursor_plugin_gitpath_surface_ready() { return 0; }; cursor_marketplace_cache_link_ready() { return 1; }'
assert_contains "missing marketplace cache link reported" "$TL_ERR" "Cursor marketplace cache symlink missing for $SNAP_SHA"
verify "$BASE_OVR"'cursor_plugin_gitpath_ready() { return 0; }; cursor_plugin_gitpath_surface_ready() { return 0; }; cursor_marketplace_cache_link_ready() { return 0; }; cursor_backend_plugin_cache_ready() { return 1; }'
assert_contains "missing backend cache reported" "$TL_ERR" "Cursor backend marketplace cache missing for $SNAP_SHA"
verify "${BASE_OVR/cursor_local_plugin_link_ready() \{ return 0; \}/cursor_local_plugin_link_ready() \{ return 1; \}}"'cursor_plugin_gitpath_ready() { return 0; }; cursor_plugin_gitpath_surface_ready() { return 0; }; cursor_marketplace_cache_link_ready() { return 0; }; cursor_backend_plugin_cache_ready() { return 0; }'
assert_eq "missing local plugin fails the verification" 1 "$TL_STATUS"
assert_contains "missing local plugin reported" "$TL_ERR" "Cursor local plugin surface missing"
verify "$BASE_OVR"'cursor_plugin_gitpath_ready() { return 0; }; cursor_plugin_gitpath_surface_ready() { return 0; }; cursor_marketplace_cache_link_ready() { return 0; }; cursor_backend_plugin_cache_ready() { return 0; }'
assert_eq "everything present passes the verification" 0 "$TL_STATUS"
verify "$BASE_OVR"'collect_cursor_plugin_verify_shas() { printf "\n%s\n" "'"$SNAP_SHA"'"; }; cursor_plugin_gitpath_ready() { return 0; }; cursor_plugin_gitpath_surface_ready() { return 0; }; cursor_marketplace_cache_link_ready() { return 0; }; cursor_backend_plugin_cache_ready() { return 0; }'
assert_eq "blank sha lines skipped in verification" 0 "$TL_STATUS"

# path canonicalization and identity verification
sub cursor_canonical_physical_path ""
assert_eq "empty path: nothing printed" "" "$TL_OUT"
echo f >"$TL_TMP/a-file"
sub cursor_canonical_physical_path "$TL_TMP/a-file"
assert_eq "file paths keep their name" "$TL_TMP/a-file" "$TL_OUT"
sub cursor_canonical_physical_path "/private/var/folders/x"
assert_eq "macOS /private/var normalized" "/var/folders/x" "$TL_OUT"
sub cursor_canonical_physical_path "$TL_TMP//double///slash"
assert_eq "duplicate separators collapsed" "$TL_TMP/double/slash" "$TL_OUT"
reset_home
mkdir -p "$CACHE/6.0.0"
sub verify_cursor_install_identity "$CACHE/6.0.0" 6.0.0 "$SNAP_SHA"
assert_eq "an uninstalled tree fails identity verification" 1 "$TL_STATUS"
assert_contains "missing current link reported" "$TL_ERR" "Cursor current symlink resolves to"
mkdir -p "$TL_TMP/other-name"
sub verify_cursor_install_identity "$TL_TMP/other-name" 9.9.9 ""
assert_eq "a destination not named after the version fails" 1 "$TL_STATUS"
assert_contains "unmaterialized version reported" "$TL_ERR" "Cursor cache claimed version 9.9.9 is not materialized at $TL_TMP/other-name"
assert_contains "missing claimed cache version reported" "$TL_ERR" "Cursor claimed cache version is missing: $CACHE/9.9.9"

# ---- public-release sync, with GitHub redirected to local repositories
reset_home
MKT="$TL_TMP/marketplace-src"
mkdir -p "$MKT/.cursor-plugin"
printf '{"plugins":[{"name":"silver-bullet","version":"5.5.5"}]}\n' >"$MKT/.cursor-plugin/marketplace.json"
git -C "$MKT" init -q; git -C "$MKT" config user.email t@example.invalid; git -C "$MKT" config user.name t; git -C "$MKT" config gc.auto 0
git -C "$MKT" add -A; git -C "$MKT" -c commit.gpgsign=false commit -q -m m
git config --global url."file://$SNAP".insteadOf https://github.com/alo-exp/silver-bullet.git
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE="file://$MKT" SB_INSTALL_CURSOR_SOURCE_ONLY=1 \
  bash -c 'source "$1"; sync_plugin_tree_from_public_release; echo "version=$VERSION dest=$DEST_ROOT"' _ "$SCRIPT"
assert_eq "public-release sync exits 0" 0 "$TL_STATUS"
assert_contains "release version adopted" "$TL_OUT" "version=5.5.5 dest=$CACHE/5.5.5"
assert_file_exists "release plugin tree materialized" "$CACHE/5.5.5/.cursor-plugin/plugin.json"
assert_eq "release manifest stamped" 5.5.5 "$(jq -r .version "$CACHE/5.5.5/.cursor-plugin/plugin.json")"
assert_file_exists "release commands synced" "$CACHE/5.5.5/commands/sb.md"
git config --global --unset-all url."file://$SNAP".insteadOf

tl_results
