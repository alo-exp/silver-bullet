#!/usr/bin/env bash
# scripts/lib/install-cursor/{backend-cache,legacy-marketplace}.sh through the
# functions install-cursor.sh loads (SB_INSTALL_CURSOR_SOURCE_ONLY=1), from a
# disposable snapshot, with local repositories standing in for GitHub.
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
UPSTREAM="$TL_TMP/upstream.git"
SNAP_SHA="$(git -C "$SNAP" rev-parse HEAD)"
git init -q --bare "$UPSTREAM"
SHA_A="$(printf 'a%.0s' $(seq 1 40))"   # well-formed but unreachable
SHA_B="$(printf 'b%.0s' $(seq 1 40))"

# sub <function> [args]: source install-cursor.sh (functions only) and call one function
sub() { tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; shift; "$@"' _ "$SCRIPT" "$@"; }
# subr <function> [args]: same, with REPO_ROOT pointing at the snapshot (it already does) so
# reachability checks see the snapshot's commits
subr() { sub "$@"; }
# subx <pre-call code> <function> [args]: apply function overrides after sourcing
subx() {
  local PRE="$1"; shift; export PRE
  tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; shift; eval "$PRE"; "$@"' _ "$SCRIPT" "$@"
}
reset_home() { rm -rf "${CH:?}"; mkdir -p "$CH"; }
# make_dest <dir> <version>: a complete installed plugin tree
make_dest() {
  local d="$1" v="$2"
  mkdir -p "$d/commands" "$d/.cursor-plugin" "$d/skills/x" "$d/skill-source/y" "$d/agents/cursor"
  printf -- '---\nname: "sb"\n---\n' >"$d/commands/sb.md"
  printf -- '---\nname: "sb-init"\n---\n' >"$d/commands/sb-init.md"
  printf '{"version":"%s","commands":"./commands"}\n' "$v" >"$d/.cursor-plugin/plugin.json"
  echo '{}' >"$d/cursor-hooks.json"
}
CACHE_MP="$CH/plugins/cache/alo-labs-cursor/silver-bullet"
CACHE_BE="$CH/plugins/cache/alo-labs-agent-plugins/silver-bullet"
GPR="$CH/plugins/marketplaces/github.com/alo-exp/silver-bullet"

# ---- log locations and commit reachability
reset_home
sub cursor_cursor_logs_root
assert_eq "linux logs root" "$HOME/.config/Cursor/logs" "$TL_OUT"
tl_stub uname 'echo Darwin'
sub cursor_cursor_logs_root
assert_eq "macOS logs root" "$HOME/Library/Application Support/Cursor/logs" "$TL_OUT"
rm -f "${TL_BIN:?}/uname"
sub cursor_github_commit_reachable ""
assert_eq "empty sha is not reachable" 1 "$TL_STATUS"
sub cursor_github_commit_reachable "$SNAP_SHA" "$SNAP"
assert_eq "commit in the checkout is reachable" 0 "$TL_STATUS"
sub cursor_github_commit_reachable "$SHA_A" "$SNAP"
assert_eq "unknown commit is not reachable" 1 "$([[ $TL_STATUS -ne 0 ]] && echo 1 || echo 0)"

# a commit that exists only upstream (tip of a ref) is reachable and its checkout is kept
git clone -q "$UPSTREAM" "$TL_TMP/up-seed" 2>/dev/null
git -C "$TL_TMP/up-seed" config user.email t@example.invalid; git -C "$TL_TMP/up-seed" config user.name t; git -C "$TL_TMP/up-seed" config gc.auto 0
echo up >"$TL_TMP/up-seed/f"; git -C "$TL_TMP/up-seed" add -A
git -C "$TL_TMP/up-seed" -c commit.gpgsign=false commit -q -m up
git -C "$TL_TMP/up-seed" push -q origin HEAD 2>/dev/null
UP_ONLY="$(git -C "$TL_TMP/up-seed" rev-parse HEAD)"
sub cursor_github_commit_reachable "$UP_ONLY" "$SNAP"
assert_eq "upstream-only tip commit is reachable" 0 "$TL_STATUS"
reset_home
mkdir -p "$GPR/$UP_ONLY" "$CACHE_MP" "$TL_TMP/tgt"; ln -s "$TL_TMP/tgt" "$CACHE_MP/$UP_ONLY"
sub prune_stale_cursor_marketplace_gitpaths
sub prune_stale_cursor_marketplace_cache_links
assert_file_exists "upstream-only gitPath kept by pruning" "$GPR/$UP_ONLY"
assert_eq "upstream-only cache link kept by pruning" 1 "$([[ -L "$CACHE_MP/$UP_ONLY" ]] && echo 1 || echo 0)"
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$TL_TMP/no-such-remote.git" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; cursor_github_commit_reachable "$2" "$3"' _ "$SCRIPT" "$UP_ONLY" "$SNAP"
assert_eq "unreachable remote: reachability unknown (2)" 2 "$TL_STATUS"

# a non-tip upstream commit is found by fetching it; malformed shas are never reachable
echo up2 >>"$TL_TMP/up-seed/f"; git -C "$TL_TMP/up-seed" -c commit.gpgsign=false commit -q -am up2
git -C "$TL_TMP/up-seed" push -q origin HEAD 2>/dev/null
sub cursor_github_commit_reachable "$UP_ONLY" "$SNAP"
assert_eq "non-tip upstream commit is reachable" 0 "$TL_STATUS"
sub cursor_github_commit_reachable ".*" "$SNAP"
assert_eq "regex-like sha is not reachable" 1 "$TL_STATUS"
sub cursor_github_commit_reachable "${UP_ONLY:0:39}" "$SNAP"
assert_eq "39-character prefix is not reachable" 1 "$TL_STATUS"
sub cursor_github_commit_reachable "${UP_ONLY^^}" "$SNAP"
assert_eq "upper-case sha is not reachable" 1 "$TL_STATUS"
sub cursor_github_commit_reachable "$SHA_A" "$SNAP"
assert_eq "commit unknown to a reachable remote: not reachable (1)" 1 "$TL_STATUS"
# unknowable answers stay unknown (2)
REAL_GIT="$(command -v git)"
tl_stub git 'if [[ " $* " == *" fetch "* ]]; then echo "fatal: some transient failure" >&2; exit 1; fi; exec '"$REAL_GIT"' "$@"'
sub cursor_github_commit_reachable "$SHA_A" "$SNAP"
assert_eq "an unclassified fetch failure is unknown (2)" 2 "$TL_STATUS"
tl_stub git 'if [[ " $* " == *" init "* ]]; then exit 1; fi; exec '"$REAL_GIT"' "$@"'
sub cursor_github_commit_reachable "$SHA_A" "$SNAP"
assert_eq "no scratch repository: unknown (2)" 2 "$TL_STATUS"
rm -f "${TL_BIN:?}/git"
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" TMPDIR="$TL_TMP/no-such-tmp" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; cursor_github_commit_reachable "$2" "$3"' _ "$SCRIPT" "$SHA_A" "$SNAP"
assert_eq "no scratch directory: unknown (2)" 2 "$TL_STATUS"
# the scratch repository never outlives a call, whatever the answer
mkdir -p "$TL_TMP/scratch-tmp"
for who in "$UP_ONLY" "$SHA_A"; do
  tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" TMPDIR="$TL_TMP/scratch-tmp" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; cursor_github_commit_reachable "$2" "$3"' _ "$SCRIPT" "$who" "$SNAP"
done
tl_stub git 'if [[ " $* " == *" fetch "* ]]; then echo "fatal: some transient failure" >&2; exit 1; fi; exec '"$REAL_GIT"' "$@"'
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" TMPDIR="$TL_TMP/scratch-tmp" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; cursor_github_commit_reachable "$2" "$3"' _ "$SCRIPT" "$SHA_A" "$SNAP"
rm -f "${TL_BIN:?}/git"
assert_eq "no scratch repositories left behind" "" "$(ls -A "$TL_TMP/scratch-tmp")"
# pruning deletes only on a definite "no"
reset_home
mkdir -p "$GPR/$UP_ONLY" "$CACHE_MP" "$TL_TMP/tgt"; ln -s "$TL_TMP/tgt" "$CACHE_MP/$UP_ONLY"
mkdir -p "$GPR/$SHA_A"; ln -s "$TL_TMP/tgt" "$CACHE_MP/$SHA_A"
sub prune_stale_cursor_marketplace_gitpaths
sub prune_stale_cursor_marketplace_cache_links
assert_file_exists "non-tip upstream gitPath kept" "$GPR/$UP_ONLY"
assert_eq "non-tip upstream cache link kept" 1 "$([[ -L "$CACHE_MP/$UP_ONLY" ]] && echo 1 || echo 0)"
assert_file_absent "definitely-unknown gitPath pruned" "$GPR/$SHA_A"
assert_file_absent "definitely-unknown cache link pruned" "$CACHE_MP/$SHA_A"
mkdir -p "$GPR/$SHA_B"; ln -s "$TL_TMP/tgt" "$CACHE_MP/$SHA_B"
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$TL_TMP/no-such-remote.git" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; prune_stale_cursor_marketplace_gitpaths; prune_stale_cursor_marketplace_cache_links' _ "$SCRIPT"
assert_file_exists "offline: gitPath kept" "$GPR/$SHA_B"
assert_eq "offline: cache link kept" 1 "$([[ -L "$CACHE_MP/$SHA_B" ]] && echo 1 || echo 0)"
assert_file_exists "offline: every other gitPath kept" "$GPR/$UP_ONLY"

# ---- stale link / gitPath pruning (REPO_ROOT is the snapshot, which holds SNAP_SHA)
reset_home
sub prune_stale_cursor_marketplace_cache_links
assert_eq "no cache root: nothing to prune" 0 "$TL_STATUS"
mkdir -p "$CACHE_MP" "$TL_TMP/tgt"
ln -s "$TL_TMP/tgt" "$CACHE_MP/$SHA_A"; ln -s "$TL_TMP/tgt" "$CACHE_MP/$SHA_B"
ln -s "$TL_TMP/tgt" "$CACHE_MP/$SNAP_SHA"; ln -s "$TL_TMP/tgt" "$CACHE_MP/not-a-sha"
sub prune_stale_cursor_marketplace_cache_links "$SHA_B"
assert_file_absent "unreachable link pruned" "$CACHE_MP/$SHA_A"
assert_contains "pruning reported" "$TL_ERR" "pruned stale Cursor marketplace cache symlink for unreachable commit aaaaaaaa"
assert_file_exists "kept sha preserved" "$CACHE_MP/$SHA_B"
assert_file_exists "reachable link preserved" "$CACHE_MP/$SNAP_SHA"
assert_file_exists "non-sha names ignored" "$CACHE_MP/not-a-sha"
sub prune_stale_cursor_marketplace_cache_links
assert_file_absent "unreachable link pruned when nothing is kept" "$CACHE_MP/$SHA_B"

reset_home
sub prune_stale_cursor_marketplace_gitpaths
assert_eq "no gitPath root: nothing to prune" 0 "$TL_STATUS"
mkdir -p "$GPR/$SHA_A" "$GPR/$SHA_B" "$GPR/$SNAP_SHA" "$GPR/not-a-sha"
sub prune_stale_cursor_marketplace_gitpaths "$SHA_B"
assert_file_absent "unreachable gitPath pruned" "$GPR/$SHA_A"
assert_file_exists "kept sha preserved" "$GPR/$SHA_B"
assert_file_exists "reachable gitPath preserved" "$GPR/$SNAP_SHA"
assert_file_exists "non-sha names ignored" "$GPR/not-a-sha"
# the library alone (no install-cursor.sh): default gitPath root
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" CURSOR_BACKEND_MARKETPLACE_NAME=x REPO_ROOT="$SNAP" \
  bash -c 'source "$1"; prune_stale_cursor_marketplace_gitpaths' _ "$SNAP/scripts/lib/install-cursor/backend-cache.sh"
assert_eq "library alone resolves the default gitPath root" 0 "$TL_STATUS"
assert_file_absent "default-root unreachable entry pruned" "$GPR/$SHA_B"

# empty roots (the glob matches nothing) are fine
reset_home
mkdir -p "$CACHE_MP" "$GPR"
sub prune_stale_cursor_marketplace_cache_links
assert_eq "empty cache root tolerated" 0 "$TL_STATUS"
sub prune_stale_cursor_marketplace_gitpaths
assert_eq "empty gitPath root tolerated" 0 "$TL_STATUS"

# ---- Cursor Plugins log discovery
reset_home
sub discover_cursor_backend_plugin_shas
assert_eq "no logs dir: nothing discovered" 0 "$TL_STATUS"
LOGS="$HOME/.config/Cursor/logs/session1"
mkdir -p "$LOGS"
printf 'x Adding enabled plugin: silver-bullet from %s y\nunrelated\n' "$SHA_A" >"$LOGS/Cursor Plugins.log"
printf 'Adding enabled plugin: silver-bullet from %s\nAdding enabled plugin: silver-bullet from %s\n' "$SHA_B" "$SHA_A" >"$LOGS/Cursor Plugins 2.log"
sub discover_cursor_backend_plugin_shas
assert_contains "discovered shas listed" "$TL_OUT" "$SHA_A"
assert_contains "second sha listed" "$TL_OUT" "$SHA_B"
# logs without any SB line must not abort a caller running under errexit
printf 'nothing relevant\n' >"$LOGS/Cursor Plugins.log"; printf 'also nothing\n' >"$LOGS/Cursor Plugins 2.log"
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$UPSTREAM" SB_INSTALL_CURSOR_SOURCE_ONLY=1 \
  bash -c 'source "$1"; discover_cursor_backend_plugin_shas > "$2"; echo "alive:[$(<"$2")]"' _ "$SCRIPT" "$TL_TMP/discover.out"
assert_eq "no SB lines in the logs: discovery survives errexit" "alive:[]" "$TL_OUT"

# an unreachable remote yields no head sha instead of aborting
tl_run env CURSOR_HOME="$CH" CURSOR_GITHUB_REPO_URL="file://$TL_TMP/no-such.git" SB_INSTALL_CURSOR_SOURCE_ONLY=1 \
  bash -c 'source "$1"; head="$(resolve_remote_github_head_sha)"; echo "alive:[$head]"' _ "$SCRIPT"
assert_eq "unreachable remote: head lookup survives errexit" "alive:[]" "$TL_OUT"

# ---- required / verify sha collection
reset_home
mkdir -p "$CH/plugins"
printf '{"plugins":{"silver-bullet@alo-labs":[{"gitCommitSha":"%s"}]}}\n' "$SNAP_SHA" >"$CH/plugins/installed_plugins.json"
MPR="$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin"; mkdir -p "$MPR"
printf '{"plugins":[{"name":"silver-bullet","source":{"sha":"%s"}}]}\n' "$SHA_A" >"$MPR/marketplace.json"
sub collect_cursor_plugin_required_shas "" "$SHA_A"
assert_eq "required shas: only reachable ones, blanks skipped, deduplicated" "$SNAP_SHA" "$TL_OUT"
sub collect_cursor_plugin_verify_shas "$SNAP_SHA" "$SHA_B"
assert_eq "verify shas: reachable and deduplicated" "$SNAP_SHA" "$TL_OUT"
sub collect_cursor_plugin_verify_shas
assert_eq "verify shas fall back to the registry sha" "$SNAP_SHA" "$TL_OUT"

# ---- backend sha resolution
reset_home
sub resolve_cursor_backend_plugin_sha "$SNAP_SHA"
assert_eq "no discovery, no manifest: the install sha when reachable" "$SNAP_SHA" "$TL_OUT"
sub resolve_cursor_backend_plugin_sha "$SHA_B"
assert_eq "unreachable install sha is returned as given" "$SHA_B" "$TL_OUT"
sub resolve_cursor_backend_plugin_sha
assert_eq "no argument: empty answer" "" "$TL_OUT"
mkdir -p "$MPR"; printf '{"plugins":[{"name":"silver-bullet","source":{"sha":"%s"}}]}\n' "$SNAP_SHA" >"$MPR/marketplace.json"
sub resolve_cursor_backend_plugin_sha "$SHA_B"
assert_eq "reachable manifest sha preferred over the argument" "$SNAP_SHA" "$TL_OUT"
rm -f "${MPR:?}/marketplace.json"
mkdir -p "$HOME/.config/Cursor/logs/s"
printf 'Adding enabled plugin: silver-bullet from %s\n' "$SNAP_SHA" >"$HOME/.config/Cursor/logs/s/Cursor Plugins.log"
sub resolve_cursor_backend_plugin_sha "$SHA_B"
assert_eq "reachable sha from the Cursor log wins" "$SNAP_SHA" "$TL_OUT"
rm -rf "${HOME:?}/.config/Cursor"

# ---- picker surface pruning
reset_home
E="$TL_TMP/entry"; rm -rf "${E:?}"; mkdir -p "$E/agents" "$E/skills" "$E/plugins/silver-bullet/templates" "$E/commands"
sub prune_cursor_picker_surfaces_from_cache_dir "$E"
assert_file_absent "agents pruned" "$E/agents"
assert_file_absent "nested templates pruned" "$E/plugins/silver-bullet/templates"
assert_file_exists "commands kept" "$E/commands"
assert_contains "pruning reported with the short sha label" "$TL_ERR" "pruned agents from Cursor backend cache entry"
sub prune_agents_from_all_cursor_backend_caches
assert_eq "no backend cache: nothing to prune" 0 "$TL_STATUS"
mkdir -p "$CACHE_BE/$SHA_A/agents"; echo f >"$CACHE_BE/stray-file"
sub prune_agents_from_all_cursor_backend_caches
assert_file_absent "agents pruned from every backend cache" "$CACHE_BE/$SHA_A/agents"
assert_file_exists "stray files in the cache root ignored" "$CACHE_BE/stray-file"

# ---- seed sha collection (prunes first, then lists reachable shas)
reset_home
mkdir -p "$CACHE_MP" "$TL_TMP/tgt"
ln -s "$TL_TMP/tgt" "$CACHE_MP/$SHA_A"
sub collect_cursor_plugin_seed_shas "$SNAP_SHA" ""
assert_contains "seed shas include the primary sha" "$TL_OUT" "$SNAP_SHA"
assert_file_absent "stale marketplace link pruned while collecting" "$CACHE_MP/$SHA_A"

# ---- custom-agent cleanup keeps the installer's own sb-* agents and quarantines legacy ones
reset_home
mkdir -p "$HOME/.config/silver-bullet"
cp "$TL_REPO_ROOT/tests/fixtures/cursor-models-catalog.json" "$HOME/.config/silver-bullet/cursor-models-catalog.json"
tl_run env SB_CURSOR_SB_AGENTS_OFFLINE=1 CSBA_REPO_ROOT="$TL_TMP/csba-project" bash "$SNAP/scripts/install-cursor-sb-agents.sh" --global --non-interactive
assert_eq "real sb agents installed" 0 "$TL_STATUS"
AG="$HOME/.cursor/agents"
mkdir -p "$AG/silver-legacy"
printf -- '---\nname: silver-legacy\n---\nSilver Bullet legacy agent\n' >"$AG/silver-legacy/SKILL.md"
printf -- '---\nname: my-own\n---\nunrelated agent\n' >"$AG/my-own.md"
BEFORE_COUNT="$(find "$AG" -maxdepth 1 -name 'sb-*.md' | wc -l | tr -d ' ')"
tl_run env CURSOR_HOME="$HOME/.cursor" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; cleanup_cursor_custom_agents ""' _ "$SCRIPT"
assert_eq "cleanup exits 0" 0 "$TL_STATUS"
assert_eq "installer-managed sb-* agents stay" "$BEFORE_COUNT" "$(find "$AG" -maxdepth 1 -name 'sb-*.md' | wc -l | tr -d ' ')"
assert_file_absent "legacy Silver Bullet agent quarantined" "$AG/silver-legacy"
assert_file_exists "unrelated agent untouched" "$AG/my-own.md"
assert_file_exists "legacy agent kept in quarantine" "$(find "$HOME/.cursor/.silver-bullet-quarantine" -path '*silver-legacy*' -name SKILL.md | head -1)"

# marker evasion: only genuine installer output is exempt from the quarantine
AG2="$TL_TMP/agents2/agents"; rm -rf "${TL_TMP:?}/agents2"; mkdir -p "$AG2/sub"
MARK='<!-- sb-managed: cursor-sb-agents -->'
gen() { printf -- '---\nname: %s\ndescription: SB reusable ladder agent — x effort=high.\nmodel: m\nreadonly: false\n---\nYou are a Silver Bullet reusable review/verify agent.\n%s\n' "$1" "$MARK"; }
gen sb-ok-high >"$AG2/sb-ok-high.md"
gen sb:evil >"$AG2/sb-evil.md"
gen silver-fake >"$AG2/silver-fake.md"
printf -- '---\nname: sb-mid-high\ndescription: SB reusable ladder agent — x.\n---\n%s\nSilver Bullet trailing body\n' "$MARK" >"$AG2/sb-mid-high.md"
gen sb-nested-high >"$AG2/sub/sb-nested-high.md"
printf -- '---\nname: sb-other-high\ndescription: something else Silver Bullet.\n---\nbody\n%s\n' "$MARK" >"$AG2/sb-other-high.md"

render_real() { # render_real <dir>: real generator output for unusual names/prefixes
  python3 - "$TL_REPO_ROOT" "$1" <<'PY'
import sys, pathlib
sys.path.insert(0, sys.argv[1] + "/scripts/lib/cursor-sb-agents")
import cursor_sb_agents_lib as lib
tpl = pathlib.Path(sys.argv[1], "scripts/lib/install-cursor/templates/cursor-agents/sb-agent.md.template").read_text()
out = pathlib.Path(sys.argv[2])
for model, prefix in (("gpt-5", "team"), ("Claude-4.5-Sonnet", "sb"), ("gemini 3", "sb")):
    name = lib.agent_name(model, "high", prefix)
    (out / f"{name}.md").write_text(lib.render_agent_markdown(name, model, "high", model, tpl), encoding="utf-8")
PY
}
mkdir -p "$TL_TMP/ext-agents2"; gen sb-ext-high >"$TL_TMP/ext-agents2/sb-ext-high.md"
ln -s "$TL_TMP/ext-agents2/sb-ext-high.md" "$AG2/sb-ext-high.md"
gen sb@evil >"$AG2/sb@evil.md"
render_real "$AG2"
tl_run env CURSOR_HOME="$TL_TMP/agents2" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; cleanup_cursor_custom_agents ""' _ "$SCRIPT"
assert_file_exists "genuine generated agent stays" "$AG2/sb-ok-high.md"
for f in sb-evil silver-fake sb-mid-high sb-other-high; do
  assert_file_absent "$f quarantined" "$AG2/$f.md"
done
assert_file_absent "marker file in a subdirectory quarantined" "$AG2/sub/sb-nested-high.md"
assert_eq "symlinked agent quarantined" 0 "$([[ -L "$AG2/sb-ext-high.md" ]] && echo 1 || echo 0)"
assert_file_absent "filename outside the generator character set quarantined" "$AG2/sb@evil.md"
for f in team-gpt-5-high sb-Claude-4-5-Sonnet-high 'sb-gemini 3-high'; do
  assert_file_exists "real generator output $f stays" "$AG2/$f.md"
done

# ---- plugin surface materialization
reset_home
D="$TL_TMP/dest1"; rm -rf "${D:?}"; make_dest "$D" 3.0.0
T="$TL_TMP/target1"; rm -rf "${T:?}"; mkdir -p "$T/commands"; echo old >"$T/commands/stale.md"
sub materialize_cursor_plugin_surface_into_dir "$D" "$T"
assert_file_exists "commands mirrored" "$T/commands/sb.md"
assert_file_absent "stale commands removed by the mirror" "$T/commands/stale.md"
assert_file_exists "hooks file installed" "$T/cursor-hooks.json"
assert_file_exists "plugin manifest installed" "$T/.cursor-plugin/plugin.json"
assert_file_absent "skill-source never leaks into the target" "$T/skill-source"
D2="$TL_TMP/dest2"; rm -rf "${D2:?}"; mkdir -p "$D2"
T2="$TL_TMP/target2"; rm -rf "${T2:?}"; mkdir -p "$T2/commands"
sub materialize_cursor_plugin_surface_into_dir "$D2" "$T2"
assert_file_absent "no commands in the source: target commands removed" "$T2/commands"
assert_file_absent "no hooks file copied when absent" "$T2/cursor-hooks.json"

# local plugin link
reset_home
sub ensure_cursor_local_plugin_link ""
assert_eq "empty destination: no local plugin" 0 "$TL_STATUS"
assert_file_absent "nothing created for an empty destination" "$CH/plugins/local"
mkdir -p "$CH/plugins/local"; ln -s "$TL_TMP/tgt" "$CH/plugins/local/silver-bullet"
sub ensure_cursor_local_plugin_link "$D"
assert_eq "local plugin materialized" 0 "$TL_STATUS"
assert_eq "symlink replaced by a real directory" 0 "$([[ -L "$CH/plugins/local/silver-bullet" ]] && echo 1 || echo 0)"
assert_file_exists "local plugin commands present" "$CH/plugins/local/silver-bullet/commands/sb.md"
sub cursor_local_plugin_link_ready "$D"
assert_eq "local plugin ready" 0 "$TL_STATUS"

# readiness predicates
sub cursor_local_plugin_link_ready ""
assert_eq "no destination: not ready" 1 "$TL_STATUS"
sub cursor_local_plugin_link_ready "$TL_TMP/does-not-exist"
assert_eq "missing destination: not ready" 1 "$TL_STATUS"
LP="$CH/plugins/local/silver-bullet"
mv "$LP" "$LP.bak"
sub cursor_local_plugin_link_ready "$D"
assert_eq "missing local plugin: not ready" 1 "$TL_STATUS"
ln -s "$LP.bak" "$LP"
sub cursor_local_plugin_link_ready "$D"
assert_eq "symlinked local plugin: not ready" 1 "$TL_STATUS"
rm -f "${LP:?}"; mv "$LP.bak" "$LP"
rm -f "${LP:?}/commands/sb.md"
sub cursor_local_plugin_link_ready "$D"
assert_eq "local plugin without the router command: not ready" 1 "$TL_STATUS"
sub cursor_plugin_commands_surface_ready "$LP"
assert_eq "commands surface without sb.md" 1 "$TL_STATUS"
rm -f "${LP:?}/commands/sb-init.md"; printf -- '---\nname: "sb"\n---\n' >"$LP/commands/sb.md"
sub cursor_plugin_commands_surface_ready "$LP"
assert_eq "commands surface without sb-init.md" 1 "$TL_STATUS"
printf -- '---\nname: "other"\n---\n' >"$LP/commands/sb-init.md"
sub cursor_plugin_commands_surface_ready "$LP"
assert_eq "commands surface with a wrong sb-init name" 1 "$TL_STATUS"
printf -- '---\nname: "wrong"\n---\n' >"$LP/commands/sb.md"; printf -- '---\nname: "sb-init"\n---\n' >"$LP/commands/sb-init.md"
sub cursor_plugin_commands_surface_ready "$LP"
assert_eq "commands surface with a wrong sb name" 1 "$TL_STATUS"
printf -- '---\nname: "sb"\n---\n' >"$LP/commands/sb.md"
echo c >"$LP/commands/bad:name.md"
sub cursor_plugin_command_filename_colon_count "$LP"
assert_eq "colon filenames counted" 1 "$TL_OUT"
sub cursor_plugin_commands_surface_ready "$LP"
assert_eq "colon filenames make the surface not ready" 1 "$TL_STATUS"
rm -f "${LP:?}/commands/bad:name.md"
sub cursor_plugin_command_filename_colon_count "$TL_TMP/no-such-root"
assert_eq "no commands dir: zero colon names" 0 "$TL_OUT"
sub cursor_plugin_commands_surface_ready "$LP"
assert_eq "complete commands surface is ready" 0 "$TL_STATUS"
rm -f "${LP:?}/.cursor-plugin/plugin.json"
sub cursor_local_plugin_link_ready "$D"
assert_eq "local plugin without a manifest: not ready" 1 "$TL_STATUS"
printf '{"version":"3.0.0","commands":"./elsewhere"}\n' >"$LP/.cursor-plugin/plugin.json"
sub cursor_local_plugin_link_ready "$D"
assert_eq "local plugin manifest pointing elsewhere: not ready" 1 "$TL_STATUS"
printf '{"version":"2.0.0","commands":"./commands"}\n' >"$LP/.cursor-plugin/plugin.json"
sub cursor_local_plugin_link_ready "$D"
assert_eq "local plugin version mismatch: not ready" 1 "$TL_STATUS"

# ---- user marketplace manifest sync
reset_home
tl_run env CURSOR_HOME="$CH" NOMANIFEST="$TL_TMP/no-manifest-root" SB_INSTALL_CURSOR_SOURCE_ONLY=1 \
  bash -c 'source "$1"; shift; REPO_ROOT="$NOMANIFEST"; "$@"' _ "$SCRIPT" sync_cursor_user_marketplace_manifest "$SNAP_SHA" 1.0.0
assert_eq "no source manifest: nothing synced" 0 "$TL_STATUS"
MF="$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin/marketplace.json"
assert_file_absent "no manifest written without a source" "$MF"
sub sync_cursor_user_marketplace_manifest "$SNAP_SHA" 7.7.7
assert_eq "manifest sync with sha exits 0" 0 "$TL_STATUS"
assert_eq "manifest pinned to the sha" "$SNAP_SHA" "$(jq -r '.plugins[] | select(.name=="silver-bullet") | .source.sha' "$MF")"
assert_eq "manifest pinned to the version" 7.7.7 "$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$MF")"
sub sync_cursor_user_marketplace_manifest "" ""
assert_eq "manifest copied verbatim without a sha" "$(jq -S . "$SNAP/.cursor-plugin/marketplace.json")" "$(jq -S . "$MF")"

# ---- backend cache dirs
reset_home
sub ensure_cursor_backend_plugin_cache_dir "$D" ""
assert_eq "empty sha: no backend cache" 0 "$TL_STATUS"
mkdir -p "$CACHE_BE"; ln -s "$TL_TMP/tgt" "$CACHE_BE/$SHA_A"; echo f >"$CACHE_BE/$SHA_B"
sub ensure_cursor_backend_plugin_cache_dir "$D" "$SHA_A"
assert_eq "symlinked entry replaced" 0 "$([[ -L "$CACHE_BE/$SHA_A" ]] && echo 1 || echo 0)"
assert_file_exists "cache marked complete" "$CACHE_BE/$SHA_A/.cache-complete"
sub ensure_cursor_backend_plugin_cache_dir "$D" "$SHA_B"
assert_file_exists "file entry replaced by a cache dir" "$CACHE_BE/$SHA_B/.cache-complete"
sub cursor_backend_plugin_cache_ready "$D" "$SHA_A"
assert_eq "complete backend cache is ready" 0 "$TL_STATUS"
sub cursor_backend_plugin_cache_ready "$D" ""
assert_eq "empty sha: backend cache not ready" 1 "$TL_STATUS"
sub cursor_backend_plugin_cache_ready "$D" "$SNAP_SHA"
assert_eq "missing backend cache: not ready" 1 "$TL_STATUS"
rm -f "${CACHE_BE:?}/${SHA_A:?}/.cache-complete"
sub cursor_backend_plugin_cache_ready "$D" "$SHA_A"
assert_eq "incomplete backend cache: not ready" 1 "$TL_STATUS"
: >"$CACHE_BE/$SHA_A/.cache-complete"; rm -f "${CACHE_BE:?}/${SHA_A:?}/commands/sb.md"
sub cursor_backend_plugin_cache_ready "$D" "$SHA_A"
assert_eq "backend cache without the router: not ready" 1 "$TL_STATUS"
printf -- '---\nname: "sb"\n---\n' >"$CACHE_BE/$SHA_A/commands/sb.md"; rm -f "${CACHE_BE:?}/${SHA_A:?}/.cursor-plugin/plugin.json"
sub cursor_backend_plugin_cache_ready "$D" "$SHA_A"
assert_eq "backend cache without a manifest: not ready" 1 "$TL_STATUS"
printf '{"version":"3.0.0","commands":"./commands"}\n' >"$CACHE_BE/$SHA_A/.cursor-plugin/plugin.json"; mkdir -p "$CACHE_BE/$SHA_A/skill-source"
sub cursor_backend_plugin_cache_ready "$D" "$SHA_A"
assert_eq "backend cache with skill-source: not ready" 1 "$TL_STATUS"
rmdir "$CACHE_BE/$SHA_A/skill-source"; printf '{"version":"3.0.0","commands":"./elsewhere"}\n' >"$CACHE_BE/$SHA_A/.cursor-plugin/plugin.json"
sub cursor_backend_plugin_cache_ready "$D" "$SHA_A"
assert_eq "backend manifest pointing elsewhere: not ready" 1 "$TL_STATUS"
printf '{"version":"1.0.0","commands":"./commands"}\n' >"$CACHE_BE/$SHA_A/.cursor-plugin/plugin.json"
sub cursor_backend_plugin_cache_ready "$D" "$SHA_A"
assert_eq "backend version mismatch: not ready" 1 "$TL_STATUS"

# ---- agent-plugins marketplace clone
reset_home
AP="$TL_TMP/agent-plugins.git"
git init -q --bare "$AP"
git clone -q "$AP" "$TL_TMP/ap-seed" 2>/dev/null
git -C "$TL_TMP/ap-seed" config user.email t@example.invalid; git -C "$TL_TMP/ap-seed" config user.name t
git -C "$TL_TMP/ap-seed" config gc.auto 0
echo ap >"$TL_TMP/ap-seed/f"; git -C "$TL_TMP/ap-seed" add -A; git -C "$TL_TMP/ap-seed" -c commit.gpgsign=false commit -q -m ap
git -C "$TL_TMP/ap-seed" push -q origin HEAD 2>/dev/null
AP_SHA="$(git -C "$TL_TMP/ap-seed" rev-parse HEAD)"
APDIR="$CH/plugins/marketplaces/github.com/alo-labs/agent-plugins"
tl_run env CURSOR_HOME="$CH" CURSOR_AGENT_PLUGINS_REPO_URL="file://$TL_TMP/no-such.git" SB_INSTALL_CURSOR_SOURCE_ONLY=1 \
  bash -c 'source "$1"; ensure_agent_plugins_marketplace_clone' _ "$SCRIPT"
assert_eq "unreachable agent-plugins repo tolerated" 0 "$TL_STATUS"
assert_file_absent "nothing cloned for an unreachable repo" "$APDIR"
run_ap() { tl_run env CURSOR_HOME="$CH" CURSOR_AGENT_PLUGINS_REPO_URL="file://$AP" SB_INSTALL_CURSOR_SOURCE_ONLY=1 bash -c 'source "$1"; ensure_agent_plugins_marketplace_clone' _ "$SCRIPT"; }
run_ap
assert_file_exists "agent-plugins cloned at HEAD" "$APDIR/$AP_SHA/.git"
run_ap
assert_eq "existing clone reused" 0 "$TL_STATUS"
rm -rf "${APDIR:?}/${AP_SHA:?}/.git"; echo junk >"$APDIR/$AP_SHA/junk"
run_ap
assert_file_absent "broken clone replaced" "$APDIR/$AP_SHA/junk"
assert_file_exists "fresh clone present" "$APDIR/$AP_SHA/.git"
rm -rf "${APDIR:?}"
REAL_GIT="$(command -v git)"
tl_stub git 'if [[ " $* " == *" clone "* ]]; then exit 1; fi; exec '"$REAL_GIT"' "$@"'
run_ap
assert_eq "all clones failing tolerated" 0 "$TL_STATUS"
tl_stub git 'if [[ " $* " == *" clone "* && ! -f "'"$TL_TMP"'/clone-failed" ]]; then touch "'"$TL_TMP"'/clone-failed"; exit 1; fi; exec '"$REAL_GIT"' "$@"'
run_ap
assert_file_exists "temp-dir fallback clone moved into place" "$APDIR/$AP_SHA/.git"
rm -f "${TL_BIN:?}/git"

# ---- gitPath surface readiness
reset_home
sub cursor_plugin_gitpath_root_surface_ready "$SHA_A"
assert_eq "no gitPath: surface not ready" 1 "$TL_STATUS"
git clone -q --local "$SNAP" "$GPR/$SNAP_SHA" 2>/dev/null
G1="$GPR/$SNAP_SHA"
sub cursor_plugin_gitpath_root_surface_ready "$SNAP_SHA"
assert_eq "checkout without a commands surface: not ready" 1 "$TL_STATUS"
make_dest "$G1" 3.0.0
rm -rf "${G1:?}/.cursor-plugin" "${G1:?}/skills"
sub cursor_plugin_gitpath_root_surface_ready "$SNAP_SHA"
assert_eq "commands without a manifest: not ready" 1 "$TL_STATUS"
mkdir -p "$G1/.cursor-plugin"; printf '{"version":"3.0.0","commands":"./elsewhere"}\n' >"$G1/.cursor-plugin/plugin.json"
sub cursor_plugin_gitpath_root_surface_ready "$SNAP_SHA"
assert_eq "manifest pointing elsewhere: not ready" 1 "$TL_STATUS"
printf '{"version":"3.0.0","commands":"./commands"}\n' >"$G1/.cursor-plugin/plugin.json"
mkdir -p "$G1/skills/silver-feature"; echo s >"$G1/skills/silver-feature/SKILL.md"
sub cursor_plugin_gitpath_root_surface_ready "$SNAP_SHA"
assert_eq "canonical skills still present: not ready" 1 "$TL_STATUS"
rm -rf "${G1:?}/skills"
sub cursor_plugin_gitpath_root_surface_ready "$SNAP_SHA"
assert_eq "clean commands-only surface: ready" 0 "$TL_STATUS"

# ================================================================ legacy-marketplace.sh
reset_home
LEG="$CH/plugins/marketplaces/github.com/alo-labs/alo-labs-cursor-marketplace"
sub legacy_cursor_marketplace_active
assert_eq "no legacy clone: inactive" 1 "$TL_STATUS"
sub remove_legacy_cursor_marketplace_clones
assert_eq "removal without a legacy clone is a no-op" 0 "$TL_STATUS"
mkdir -p "$LEG/sub"
sub legacy_cursor_marketplace_active
assert_eq "legacy clone detected" 0 "$TL_STATUS"
sub remove_legacy_cursor_marketplace_clones
assert_file_absent "legacy clone removed" "$LEG"
assert_contains "removal reported" "$TL_ERR" "Removed legacy Cursor marketplace clone at $LEG"
sub print_cursor_marketplace_migration_notice
assert_contains "migration notice names the unified marketplace" "$TL_ERR" "Add marketplace: https://github.com/alo-labs/agent-plugins"

# cache sha collection
reset_home
sub collect_cursor_marketplace_cache_shas
assert_eq "no cache root: no shas" "" "$TL_OUT"
mkdir -p "$CACHE_MP"; ln -s "$TL_TMP/tgt" "$CACHE_MP/$SHA_A"; ln -s "$TL_TMP/tgt" "$CACHE_MP/not-a-sha"; ln -s "$TL_TMP/gone" "$CACHE_MP/$SHA_B"
sub collect_cursor_marketplace_cache_shas
assert_eq "only live sha-named entries collected" "$SHA_A" "$TL_OUT"

# registry sha resolution
reset_home
mkdir -p "$CH/plugins"
sub resolve_cursor_registry_git_commit_sha "$SHA_A" 0
assert_eq "fresh install sha wins" "$SHA_A" "$TL_OUT"
subx 'resolve_remote_github_head_sha() { echo; }' resolve_cursor_registry_git_commit_sha "" 0
assert_eq "nothing known: empty answer" "" "$TL_OUT"
mkdir -p "$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin"
printf '{"plugins":[{"name":"silver-bullet","source":{"sha":"%s"}}]}\n' "$SHA_B" >"$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin/marketplace.json"
sub resolve_cursor_registry_git_commit_sha "" 0
assert_eq "manifest sha used when there is no install sha" "$SHA_B" "$TL_OUT"
rm -f "${CH:?}/plugins/marketplaces/alo-labs-cursor/.cursor-plugin/marketplace.json"
mkdir -p "$HOME/.config/Cursor/logs/l"
printf 'Adding enabled plugin: silver-bullet from %s\n' "$SNAP_SHA" >"$HOME/.config/Cursor/logs/l/Cursor Plugins.log"
sub resolve_cursor_registry_git_commit_sha "" 0
assert_eq "reachable backend sha used when there is no install sha" "$SNAP_SHA" "$TL_OUT"
rm -rf "${HOME:?}/.config/Cursor"
# legacy mode
subx 'cursor_plugin_gitpath_ready() { [[ "$1" == "'"$SHA_A"'" ]]; }; resolve_remote_github_head_sha() { echo; }' resolve_cursor_registry_git_commit_sha "$SHA_A" 1
assert_eq "legacy mode: install sha when its gitPath is ready" "$SHA_A" "$TL_OUT"
mkdir -p "$CACHE_MP"; rm -f "${CACHE_MP:?}"/*; ln -s "$TL_TMP/tgt" "$CACHE_MP/$SHA_B"
subx 'cursor_plugin_gitpath_ready() { [[ "$1" == "'"$SHA_B"'" ]]; }; resolve_remote_github_head_sha() { echo; }' resolve_cursor_registry_git_commit_sha "$SHA_A" 1
assert_eq "legacy mode: ready cached sha preferred" "$SHA_B" "$TL_OUT"
subx 'cursor_plugin_gitpath_ready() { return 1; }; resolve_remote_github_head_sha() { echo remote-sha; }' resolve_cursor_registry_git_commit_sha "$SHA_A" 1
assert_eq "legacy mode: remote head when nothing is ready" remote-sha "$TL_OUT"
subx 'cursor_plugin_gitpath_ready() { return 1; }; resolve_remote_github_head_sha() { echo; }' resolve_cursor_registry_git_commit_sha "$SHA_A" 1
assert_eq "legacy mode: install sha as the last resort" "$SHA_A" "$TL_OUT"
subx 'resolve_remote_github_head_sha() { echo remote-sha; }' resolve_cursor_registry_git_commit_sha "" 0
assert_eq "no local sha: remote head" remote-sha "$TL_OUT"

# extended seeding skips shas it cannot materialize and blank lines
reset_home
D3="$TL_TMP/dest3"; rm -rf "${D3:?}"; make_dest "$D3" 3.0.0
subx 'collect_cursor_plugin_seed_shas() { printf "%s\n\n" "'"$SHA_A"'" "'"$SNAP_SHA"'"; }; ensure_cursor_github_marketplace_gitpath() { [[ "$1" == "'"$SNAP_SHA"'" ]]; }' seed_cursor_marketplace_gitpaths_extended "$D3" "$SNAP_SHA" "$SNAP"
assert_eq "extended seeding skips unmaterializable shas" 0 "$TL_STATUS"
assert_eq "cache symlink created for the seeded sha" "$D3" "$(readlink "$CACHE_MP/$SNAP_SHA")"
assert_file_absent "no cache symlink for the skipped sha" "$CACHE_MP/$SHA_A"

tl_results
