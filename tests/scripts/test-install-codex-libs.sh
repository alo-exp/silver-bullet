#!/usr/bin/env bash
# scripts/lib/install-codex/*.sh exercised function by function: every call
# runs in a fresh bash that sources the real modules with a sandboxed
# CODEX_HOME_ROOT, a fabricated checkout and fabricated marketplace/cache trees.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

LIBDIR="$TL_REPO_ROOT/scripts"
CH="$TL_TMP/codex-home"                      # CODEX_HOME_ROOT
CFG="$CH/.codex/config.toml"
MP="$CH/.codex/.tmp/marketplaces/alo-labs-codex"   # default marketplace root
CACHE="$CH/.codex/plugins/cache/alo-labs-codex/silver-bullet"
FAKE_REPO="$TL_TMP/repo"
mkdir -p "$CH/.codex" "$FAKE_REPO"

HARNESS='
set -euo pipefail
SCRIPT_DIR="${SDX:-$LIBDIR}"
REPO_ROOT="$RR"
CODEX_HOME_ROOT="$CH"
AGENT_RENDERER="$LIBDIR/render-agent-bundle.py"
MERGE_USER_HOOKS="${MERGE_USER_HOOKS:-0}"
source "$LIBDIR/lib/agent-bundle-paths.sh"
for _m in config marketplace package cache legacy skill-mirror plugin registry hooks path-rewrite; do
  source "$LIBDIR/lib/install-codex/$_m.sh"
done
"$@"'
# sub <function> [args]: run one module function in a fresh shell
sub() { tl_run env LIBDIR="$LIBDIR" RR="${RR:-$FAKE_REPO}" CH="$CH" bash -c "$HARNESS" _ "$@"; }

make_pkg() { # make_pkg <root> [version]
  local root="$1" version="${2-1.2.3}"
  mkdir -p "$root/.codex-plugin" "$root/hooks" "$root/scripts"
  if [[ -n "$version" ]]; then printf '{"version":"%s"}\n' "$version" >"$root/.codex-plugin/plugin.json"
  else printf '{}\n' >"$root/.codex-plugin/plugin.json"; fi
  local s
  for s in sb-init sb sb-feature; do
    mkdir -p "$root/skill-source/$s"
    printf -- '---\nname: %s\n---\nbody\n' "$s" >"$root/skill-source/$s/SILVER_SOURCE"
  done
  printf 'Claude rules\n' >"$root/hooks/core-rules.md"
  printf '{"hooks":{}}\n' >"$root/hooks/hooks.json"
  printf '#!/usr/bin/env bash\necho sb\n' >"$root/scripts/silver-bullet"
}
reset_home() { rm -rf "$CH"; mkdir -p "$CH/.codex"; }
set_marketplace_source() { printf '[marketplaces.alo-labs-codex]\nsource_type = "local"\nsource = "%s"\n' "$1" >"$CFG"; }

# ---------------------------------------------------------------- config.sh
reset_home
sub resolve_codex_config_file
assert_eq "config path resolved even when absent" "$CFG" "$TL_OUT"
printf 'x = 1\n' >"$CFG"
sub resolve_codex_config_file
assert_eq "existing config path returned" "$CFG" "$TL_OUT"
sub codex_marketplace_root
assert_eq "default marketplace root without a registration" "$MP" "$TL_OUT"
mkdir -p "$TL_TMP/local-mp"
set_marketplace_source "$TL_TMP/local-mp"
sub codex_marketplace_root
assert_eq "registered local marketplace root" "$TL_TMP/local-mp" "$TL_OUT"
set_marketplace_source "$TL_TMP/missing-mp"
sub codex_marketplace_root
assert_eq "registered root that does not exist falls back" "$MP" "$TL_OUT"
sub usage
assert_contains "usage text" "$TL_OUT" "Usage: scripts/install-codex.sh"
mkdir -p "$TL_TMP/proj/sub/deeper"
printf '{}' >"$TL_TMP/proj/.silver-bullet.json"; : >"$TL_TMP/proj/silver-bullet.md"
tl_run bash -c "cd '$TL_TMP/proj/sub/deeper' && env LIBDIR='$LIBDIR' RR='$FAKE_REPO' CH='$CH' bash -c '$HARNESS' _ find_silver_bullet_project_root"
assert_eq "project root found from a subdirectory" "$TL_TMP/proj" "$TL_OUT"
mkdir -p "$TL_TMP/nogit/.git/inner"
tl_run bash -c "cd '$TL_TMP/nogit/.git/inner' && env LIBDIR='$LIBDIR' RR='$FAKE_REPO' CH='$CH' bash -c '$HARNESS' _ find_silver_bullet_project_root"
assert_eq "search stops at the git directory" 1 "$TL_STATUS"

# ------------------------------------------------------------ cache.sh pin
mkdir -p "$TL_TMP/hk"
sub regenerate_core_rules_pin "$TL_TMP/hk"
assert_eq "no core-rules.md: nothing to pin" 0 "$TL_STATUS"
assert_file_absent "no pin written" "$TL_TMP/hk/core-rules.sha256"
printf 'rules\n' >"$TL_TMP/hk/core-rules.md"
EXPECT="$(sha256sum "$TL_TMP/hk/core-rules.md" | awk '{print $1}')"
tl_stub shasum 'sha256sum "${@:3}"'
sub regenerate_core_rules_pin "$TL_TMP/hk"
assert_eq "pin via shasum" "$EXPECT" "$(<"$TL_TMP/hk/core-rules.sha256")"
rm -f "$TL_BIN/shasum" "$TL_TMP/hk/core-rules.sha256"
tl_run env PATH="$(tl_path_without shasum)" LIBDIR="$LIBDIR" RR="$FAKE_REPO" CH="$CH" bash -c "$HARNESS" _ regenerate_core_rules_pin "$TL_TMP/hk"
assert_eq "pin via sha256sum" "$EXPECT" "$(<"$TL_TMP/hk/core-rules.sha256")"
rm -f "$TL_TMP/hk/core-rules.sha256"
tl_run env PATH="$(tl_path_without shasum sha256sum)" LIBDIR="$LIBDIR" RR="$FAKE_REPO" CH="$CH" bash -c "$HARNESS" _ regenerate_core_rules_pin "$TL_TMP/hk"
assert_eq "no hash tool: pinning fails" 1 "$TL_STATUS"

# ----------------------------------------------- cache.sh: sanitize + cache sync
reset_home
make_pkg "$MP/plugins/silver-bullet"
printf 'Use the Agent tool\n' >"$MP/plugins/silver-bullet/hooks/core-rules.md"
sub sanitize_codex_package_surface
assert_eq "fat marketplace sanitized" 0 "$TL_STATUS"
assert_contains "package text rewritten for Codex" "$(<"$MP/plugins/silver-bullet/hooks/core-rules.md")" "active runtime delegation mechanism"
assert_eq "pin refreshed after sanitizing" "$(sha256sum "$MP/plugins/silver-bullet/hooks/core-rules.md" | awk '{print $1}')" "$(<"$MP/plugins/silver-bullet/hooks/core-rules.sha256")"
# thin marketplace: manifest names the version, the package lives in the cache
reset_home
mkdir -p "$MP/.agents/plugins"
printf '{"plugins":[{"name":"silver-bullet","version":"1.2.3"}]}\n' >"$MP/.agents/plugins/marketplace.json"
make_pkg "$CACHE/1.2.3"
printf 'Use the Agent tool\n' >"$CACHE/1.2.3/hooks/core-rules.md"
sub sanitize_codex_package_surface
assert_contains "cache package sanitized when the marketplace is thin" "$(<"$CACHE/1.2.3/hooks/core-rules.md")" "active runtime delegation mechanism"
# nothing anywhere: no-op
reset_home
sub sanitize_codex_package_surface
assert_eq "no package: sanitizing is a no-op" 0 "$TL_STATUS"
# missing sanitizer helper
reset_home
make_pkg "$MP/plugins/silver-bullet"
mkdir -p "$TL_TMP/no-helper"
tl_run env SDX="$TL_TMP/no-helper" LIBDIR="$LIBDIR" RR="$FAKE_REPO" CH="$CH" bash -c "$HARNESS" _ sanitize_codex_package_surface
assert_eq "missing sanitizer helper aborts" 1 "$TL_STATUS"
assert_contains "missing sanitizer helper reported" "$TL_ERR" "codex sanitizer helper missing at $TL_TMP/no-helper/codex-sanitize-package.sh"

reset_home
sub sync_codex_cache_package_surface
assert_eq "thin marketplace without a cache dir: no-op" 0 "$TL_STATUS"
mkdir -p "$MP/.agents/plugins"
printf '{"plugins":[{"name":"silver-bullet","version":"1.2.3"}]}\n' >"$MP/.agents/plugins/marketplace.json"
make_pkg "$CACHE/1.2.3"
sub sync_codex_cache_package_surface
assert_eq "thin marketplace with a cache dir validates it" 0 "$TL_STATUS"
assert_file_exists "pin regenerated for the cache copy" "$CACHE/1.2.3/hooks/core-rules.sha256"
rm -rf "$CACHE/1.2.3/skill-source/sb"
sub sync_codex_cache_package_surface
assert_eq "invalid cached package aborts" 1 "$TL_STATUS"
assert_contains "invalid cached package reported" "$TL_ERR" "missing required skill surface sb"

reset_home
make_pkg "$MP/plugins/silver-bullet" 3.0.0
printf 'not json' >"$MP/plugins/silver-bullet/.codex-plugin/plugin.json"
sub sync_codex_cache_package_surface
assert_eq "unparseable plugin.json: cache sync is a no-op" 0 "$TL_STATUS"
assert_file_absent "nothing cached for an unparseable plugin.json" "$CACHE"
reset_home
make_pkg "$MP/plugins/silver-bullet" ""
sub sync_codex_cache_package_surface
assert_eq "fat package without a version: no-op" 0 "$TL_STATUS"
assert_file_absent "nothing cached without a version" "$CACHE"
reset_home
make_pkg "$MP/plugins/silver-bullet" 2.10.0
printf "pin\n" >"$MP/plugins/silver-bullet/hooks/core-rules.sha256"
make_pkg "$CACHE/1.0.0" 1.0.0
mkdir -p "$CACHE/current"
printf 'stray' >"$CACHE/not-a-dir"
sub sync_codex_cache_package_surface
assert_eq "fat package cache sync exits 0" 0 "$TL_STATUS"
assert_file_exists "new version cached" "$CACHE/2.10.0/.codex-plugin/plugin.json"
assert_file_exists "pin present in the new version" "$CACHE/2.10.0/hooks/core-rules.sha256"
assert_eq "older versions are refreshed from the marketplace package" 2.10.0 "$(jq -r .version "$CACHE/1.0.0/.codex-plugin/plugin.json")"
assert_eq "stray files in the cache root left alone" stray "$(<"$CACHE/not-a-dir")"
assert_file_absent "'current' directory not overwritten" "$CACHE/current/.codex-plugin"

# ------------------------------------------------------- cache.sh: pruning helpers
reset_home
make_pkg "$CACHE/1.0.0" 1.0.0; make_pkg "$CACHE/1.10.0" 1.10.0; make_pkg "$CACHE/1.9.0" 1.9.0
sub prune_stale_silver_bullet_cache_versions
assert_eq "only the newest version survives pruning" "1.10.0 current" "$(cd "$CACHE" && ls | sort -V | tr '\n' ' ' | sed 's/ $//')"
assert_eq "current points at the newest version" "$CACHE/1.10.0" "$(readlink "$CACHE/current")"
sub refresh_silver_bullet_current_alias
assert_eq "alias refresh validates the installed package" 0 "$TL_STATUS"
rm -rf "$CACHE/1.10.0/skill-source/sb-feature"
sub refresh_silver_bullet_current_alias
assert_eq "alias refresh rejects a package without required skills" 1 "$TL_STATUS"

# ------------------------------------------------------- marketplace.sh
reset_home
set_marketplace_source "$FAKE_REPO"
sub refresh_marketplace alo-labs-codex
assert_eq "marketplace that is the checkout needs no refresh" 0 "$TL_STATUS"
sub cleanup_legacy_marketplace_picker_surfaces
assert_eq "checkout marketplace is never cleaned" 0 "$TL_STATUS"

reset_home
sub cleanup_legacy_marketplace_picker_surfaces
assert_eq "missing marketplace dir: nothing to clean" 0 "$TL_STATUS"
mkdir -p "$MP/skills/x" "$MP/agents/y" "$MP/skill-source/z" "$MP/commands"
sub cleanup_legacy_marketplace_picker_surfaces
assert_file_absent "legacy picker skills removed" "$MP/skills"
assert_file_absent "legacy picker agents removed" "$MP/agents"
assert_file_absent "legacy picker skill-source removed" "$MP/skill-source"
assert_file_exists "other marketplace content kept" "$MP/commands"
mkdir -p "$MP/skills/x" "$MP/plugins/silver-bullet" "$TL_TMP/ss-target"
ln -s "$TL_TMP/ss-target" "$MP/plugins/silver-bullet/skill-source"
sub cleanup_legacy_marketplace_picker_surfaces
assert_file_exists "fat layout (skill-source symlink) keeps picker dirs" "$MP/skills/x"

# refresh_marketplace against a real git marketplace clone
reset_home
git init -q --bare "$TL_TMP/upstream.git"
git clone -q "$TL_TMP/upstream.git" "$TL_TMP/seed" 2>/dev/null
git -C "$TL_TMP/seed" config user.email t@example.invalid; git -C "$TL_TMP/seed" config user.name t
git -C "$TL_TMP/seed" config gc.auto 0
mkdir -p "$TL_TMP/seed/hooks"; echo v1 >"$TL_TMP/seed/hooks/h"; git -C "$TL_TMP/seed" add -A
git -C "$TL_TMP/seed" -c commit.gpgsign=false commit -q -m one
git -C "$TL_TMP/seed" push -q origin HEAD 2>/dev/null
mkdir -p "$(dirname "$MP")"
git clone -q "$TL_TMP/upstream.git" "$MP" 2>/dev/null
echo v2 >"$TL_TMP/seed/hooks/h"; git -C "$TL_TMP/seed" -c commit.gpgsign=false commit -q -am two; git -C "$TL_TMP/seed" push -q origin HEAD 2>/dev/null
mkdir -p "$MP/hooks/untracked-dir"; : >"$MP/hooks/untracked-dir/x"
sub refresh_marketplace alo-labs-codex
assert_eq "git marketplace refresh exits 0" 0 "$TL_STATUS"
assert_eq "marketplace fast-forwarded to upstream" v2 "$(<"$MP/hooks/h")"
assert_file_absent "untracked package files cleaned" "$MP/hooks/untracked-dir"
# no upstream configured: pull fallback; every git failure is tolerated
git -C "$MP" branch --unset-upstream
sub refresh_marketplace alo-labs-codex
assert_eq "marketplace without upstream tolerated" 0 "$TL_STATUS"
REAL_GIT="$(command -v git)"
tl_stub git 'case " $* " in *" fetch "*|*" reset "*|*" pull "*|*" clean "*|*" rev-parse "*) exit 1 ;; esac; exec '"$REAL_GIT"' "$@"'
sub refresh_marketplace alo-labs-codex
assert_eq "failing git commands tolerated" 0 "$TL_STATUS"
git -C "$MP" branch --set-upstream-to=origin/HEAD >/dev/null 2>&1 || git -C "$MP" branch --set-upstream-to="origin/$(git -C "$MP" rev-parse --abbrev-ref HEAD)" >/dev/null 2>&1 || true
tl_stub git 'case " $* " in *" fetch "*|*" reset "*|*" clean "*) exit 1 ;; esac; exec '"$REAL_GIT"' "$@"'
sub refresh_marketplace alo-labs-codex
assert_eq "failing reset tolerated when an upstream exists" 0 "$TL_STATUS"
rm -f "$TL_BIN/git"

# cache version resolution
reset_home
sub silver_bullet_cache_version_dir
assert_eq "no manifest, no plugin.json: no version" 1 "$TL_STATUS"
mkdir -p "$MP/.agents/plugins"
printf '{"plugins":[{"name":"silver-bullet","version":"3.1.4"}]}\n' >"$MP/.agents/plugins/marketplace.json"
sub silver_bullet_cache_version_dir
assert_eq "version taken from the manifest" "$CACHE/3.1.4" "$TL_OUT"
printf 'not json' >"$MP/.agents/plugins/marketplace.json"
sub silver_bullet_cache_version_dir
assert_eq "unparseable manifest: no version" 1 "$TL_STATUS"
make_pkg "$MP/plugins/silver-bullet" 4.0.0
sub silver_bullet_cache_version_dir
assert_eq "version taken from the plugin.json" "$CACHE/4.0.0" "$TL_OUT"
printf 'not json' >"$MP/plugins/silver-bullet/.codex-plugin/plugin.json"
sub silver_bullet_cache_version_dir
assert_eq "unparseable plugin.json: no version" 1 "$TL_STATUS"

# thin-manifest hydration
reset_home
sub hydrate_silver_bullet_from_thin_manifest
assert_eq "no manifest: hydration refused" 1 "$TL_STATUS"
mkdir -p "$MP/.agents/plugins"
printf '{"plugins":[{"name":"silver-bullet","version":"5.0.0","source":{"source":"local","path":"./pkg"}}]}\n' >"$MP/.agents/plugins/marketplace.json"
make_pkg "$MP/plugins/silver-bullet" 5.0.0
sub hydrate_silver_bullet_from_thin_manifest
assert_eq "fat package: nothing to hydrate" 0 "$TL_STATUS"
rm -rf "$MP/plugins"
printf '{"plugins":[{"name":"silver-bullet","source":{"source":"local","path":"./pkg"}}]}\n' >"$MP/.agents/plugins/marketplace.json"
sub hydrate_silver_bullet_from_thin_manifest
assert_eq "manifest without a version: hydration refused" 1 "$TL_STATUS"
printf '{"plugins":[{"name":"silver-bullet","version":"5.0.0","source":{"source":"local","path":"./pkg"}}]}\n' >"$MP/.agents/plugins/marketplace.json"
make_pkg "$MP/pkg" 5.0.0
sub hydrate_silver_bullet_from_thin_manifest
assert_eq "local thin source hydrated" 0 "$TL_STATUS"
assert_file_exists "package copied into the cache" "$CACHE/5.0.0/.codex-plugin/plugin.json"

# legacy snapshot seeding
reset_home
mkdir -p "$FAKE_REPO/marker-dir"; echo seed >"$FAKE_REPO/seed-file"
tl_run env SB_CODEX_LEGACY_MARKETPLACE_SNAPSHOT=0 LIBDIR="$LIBDIR" RR="$FAKE_REPO" CH="$CH" bash -c "$HARNESS" _ seed_marketplace_snapshot_if_missing
assert_file_absent "snapshot seeding is off by default" "$MP"
tl_run env SB_CODEX_LEGACY_MARKETPLACE_SNAPSHOT=1 LIBDIR="$LIBDIR" RR="$FAKE_REPO" CH="$CH" bash -c "$HARNESS" _ seed_marketplace_snapshot_if_missing
assert_file_exists "snapshot seeded from the checkout" "$MP/seed-file"
make_pkg "$MP/plugins/silver-bullet" 6.0.0
echo changed >"$FAKE_REPO/seed-file"
tl_run env SB_CODEX_LEGACY_MARKETPLACE_SNAPSHOT=1 LIBDIR="$LIBDIR" RR="$FAKE_REPO" CH="$CH" bash -c "$HARNESS" _ seed_marketplace_snapshot_if_missing
assert_eq "existing package: snapshot left alone" seed "$(<"$MP/seed-file")"

# surface sync from the checkout into the marketplace
reset_home
rm -rf "$FAKE_REPO"; mkdir -p "$FAKE_REPO"/{hooks,templates,docs,commands,scripts,skills,agents,plugins/silver-bullet}
echo h >"$FAKE_REPO/hooks/h"; echo t >"$FAKE_REPO/templates/t"; echo README >"$FAKE_REPO/README.md"; echo '{}' >"$FAKE_REPO/.silver-bullet.json"
make_pkg "$FAKE_REPO/plugins/silver-bullet" 7.0.0
mkdir -p "$MP/skills" "$MP/agents" "$TL_TMP/link-target"
ln -s "$TL_TMP/link-target" "$MP/hooks"
ln -s "$FAKE_REPO/README.md" "$MP/README.md"
sub sync_marketplace_package_surface
assert_eq "surface sync exits 0" 0 "$TL_STATUS"
assert_file_exists "hooks copied" "$MP/hooks/h"
assert_eq "symlinked destination replaced by a real directory" 0 "$([[ -L "$MP/hooks" ]] && echo 1 || echo 0)"
assert_file_absent "target of the old symlink untouched" "$TL_TMP/link-target/h"
assert_eq "symlinked README replaced by a copy" 0 "$([[ -L "$MP/README.md" ]] && echo 1 || echo 0)"
assert_file_absent "marketplace skills removed" "$MP/skills"
assert_file_absent "marketplace agents removed" "$MP/agents"
assert_file_exists "project config copied" "$MP/.silver-bullet.json"
# a marketplace that is the checkout: identical files are skipped
set_marketplace_source "$FAKE_REPO"
sub sync_marketplace_package_surface
assert_eq "checkout marketplace sync exits 0" 0 "$TL_STATUS"
assert_file_exists "checkout content untouched" "$FAKE_REPO/hooks/h"
reset_home
sub sync_marketplace_package_snapshot
assert_eq "snapshot sync copies the generated package" 0 "$TL_STATUS"
assert_file_exists "generated package snapshot present" "$MP/plugins/silver-bullet/.codex-plugin/plugin.json"
rm -rf "$FAKE_REPO/plugins"
sub sync_marketplace_package_snapshot
assert_eq "no generated package: snapshot sync is a no-op" 0 "$TL_STATUS"

# ------------------------------------------------------- package.sh
reset_home
make_pkg "$FAKE_REPO/plugins/silver-bullet" 7.0.0
sub codex_package_is_repo_checkout "$FAKE_REPO/plugins/silver-bullet"
assert_eq "repo package recognised" 0 "$TL_STATUS"
sub codex_package_is_repo_checkout "$TL_TMP/elsewhere"
assert_eq "other package not recognised" 1 "$TL_STATUS"

sub materialize_silver_bullet_package
assert_eq "no package: nothing to materialize" 0 "$TL_STATUS"
make_pkg "$MP/plugins/silver-bullet" 8.0.0
mkdir -p "$TL_TMP/real-templates"; echo tpl >"$TL_TMP/real-templates/t"
ln -s "$TL_TMP/real-templates" "$MP/plugins/silver-bullet/templates"
sub materialize_silver_bullet_package
assert_eq "symlinked package surface materialized" 0 "$([[ -L "$MP/plugins/silver-bullet/templates" ]] && echo 1 || echo 0)"
assert_file_exists "materialized content present" "$MP/plugins/silver-bullet/templates/t"
# thin marketplace: the cache version dir is the package
reset_home
mkdir -p "$MP/.agents/plugins"
printf '{"plugins":[{"name":"silver-bullet","version":"9.0.0"}]}\n' >"$MP/.agents/plugins/marketplace.json"
make_pkg "$CACHE/9.0.0" 9.0.0
ln -s "$TL_TMP/real-templates" "$CACHE/9.0.0/templates"
sub materialize_silver_bullet_package
assert_file_exists "cache package materialized" "$CACHE/9.0.0/templates/t"
assert_eq "cache symlink replaced" 0 "$([[ -L "$CACHE/9.0.0/templates" ]] && echo 1 || echo 0)"
# the repo's own generated package is never mutated
reset_home
set_marketplace_source "$FAKE_REPO"
make_pkg "$FAKE_REPO/plugins/silver-bullet" 7.0.0
ln -s "$TL_TMP/real-templates" "$FAKE_REPO/plugins/silver-bullet/templates"
printf '[marketplaces.alo-labs-codex]\nsource_type = "local"\nsource = "%s"\n' "$FAKE_REPO" >"$CFG"
sub materialize_silver_bullet_package
assert_eq "checkout package keeps its symlinks" 1 "$([[ -L "$FAKE_REPO/plugins/silver-bullet/templates" ]] && echo 1 || echo 0)"
rm -f "$FAKE_REPO/plugins/silver-bullet/templates"

reset_home
sub sync_materialized_package_surface
assert_eq "no package: nothing to sync" 0 "$TL_STATUS"
set_marketplace_source "$FAKE_REPO"
make_pkg "$FAKE_REPO/plugins/silver-bullet" 7.0.0
sub sync_materialized_package_surface
assert_eq "checkout package is never rewritten" 0 "$TL_STATUS"
reset_home
make_pkg "$MP/plugins/silver-bullet" 8.0.0
rm -rf "$MP/plugins/silver-bullet/skill-source"
mkdir -p "$MP/skills/sb-init" "$MP/hooks" "$MP/plugins/silver-bullet/skills"
printf -- '---\nname: sb-init\n---\n' >"$MP/skills/sb-init/SKILL.md"
echo newhook >"$MP/hooks/h2"; echo notes >"$MP/CHANGELOG.md"
sub sync_materialized_package_surface
assert_eq "materialized surface sync exits 0" 0 "$TL_STATUS"
assert_file_absent "top-level skills removed from the package" "$MP/plugins/silver-bullet/skills"
assert_file_exists "hooks synced into the package" "$MP/plugins/silver-bullet/hooks/h2"
assert_file_exists "skills mirrored as SILVER_SOURCE" "$MP/plugins/silver-bullet/skill-source/sb-init/SILVER_SOURCE"
assert_file_absent "SKILL.md renamed away" "$MP/plugins/silver-bullet/skill-source/sb-init/SKILL.md"
assert_file_exists "top-level docs copied" "$MP/plugins/silver-bullet/CHANGELOG.md"

# skill surface validation
mkdir -p "$TL_TMP/vs"; make_pkg "$TL_TMP/vs"
sub silver_bullet_internal_skill_file "$TL_TMP/vs/skill-source/sb"
assert_eq "SILVER_SOURCE preferred" "$TL_TMP/vs/skill-source/sb/SILVER_SOURCE" "$TL_OUT"
for alt in SILVER_SOURCE.md SILVER_SKILL.md SKILL.md; do
  rm -f "$TL_TMP/vs/skill-source/sb"/SILVER_* "$TL_TMP/vs/skill-source/sb"/SKILL.md
  : >"$TL_TMP/vs/skill-source/sb/$alt"
  sub silver_bullet_internal_skill_file "$TL_TMP/vs/skill-source/sb"
  assert_eq "$alt accepted" "$TL_TMP/vs/skill-source/sb/$alt" "$TL_OUT"
done
rm -f "$TL_TMP/vs/skill-source/sb/SKILL.md"
sub silver_bullet_internal_skill_file "$TL_TMP/vs/skill-source/sb"
assert_eq "no skill file found" 1 "$TL_STATUS"
sub validate_silver_bullet_skill_surface label "$TL_TMP/does-not-exist"
assert_eq "missing package: validation skipped" 0 "$TL_STATUS"
mkdir -p "$TL_TMP/vs/skills"
sub validate_silver_bullet_skill_surface label "$TL_TMP/vs"
assert_eq "top-level skills/ rejected" 1 "$TL_STATUS"
assert_contains "top-level skills/ explained" "$TL_ERR" "exposes top-level skills/"
rmdir "$TL_TMP/vs/skills"
mv "$TL_TMP/vs/skill-source" "$TL_TMP/vs/moved"
sub validate_silver_bullet_skill_surface label "$TL_TMP/vs"
assert_eq "missing skill-source rejected" 1 "$TL_STATUS"
assert_contains "missing skill-source explained" "$TL_ERR" "missing internal skill-source/"
mv "$TL_TMP/vs/moved" "$TL_TMP/vs/skill-source"

# ------------------------------------------------------- plugin.sh
reset_home
sub install_silver_bullet_codex_cli
assert_file_absent "no package: no CLI shim" "$CH/.codex/bin/silver-bullet"
make_pkg "$CACHE/1.0.0" 1.0.0; make_pkg "$CACHE/1.10.0" 1.10.0
sub install_silver_bullet_codex_cli
assert_contains "shim targets the newest version without a current alias" "$(<"$CH/.codex/bin/silver-bullet")" "$CACHE/1.10.0/scripts/silver-bullet"
assert_eq "shim is private and executable" 700 "$(stat -c %a "$CH/.codex/bin/silver-bullet" 2>/dev/null || stat -f %Lp "$CH/.codex/bin/silver-bullet")"
ln -s "$CACHE/1.0.0" "$CACHE/current"
sub install_silver_bullet_codex_cli
assert_contains "shim targets the current alias when present" "$(<"$CH/.codex/bin/silver-bullet")" "$CACHE/current/scripts/silver-bullet"
sub remove_plugin_enabled "silver-bullet@alo-labs-codex"
assert_eq "remove without a config file is a no-op" 0 "$TL_STATUS"

# ------------------------------------------------------- registry.sh
reset_home
sub sync_codex_installed_plugin_registry_paths
assert_eq "no registry: nothing to sync" 0 "$TL_STATUS"
REG="$CH/.codex/plugins/installed_plugins.json"
mkdir -p "$(dirname "$REG")"
printf '{"plugins":{"":[{"version":"0"}],"not-qualified":[{"version":"1"}],"ghost@mkt":[{"version":"1"}]}}\n' >"$REG"
sub sync_codex_installed_plugin_registry_paths
assert_eq "entries without a cache are skipped" 0 "$TL_STATUS"
assert_eq "registry unchanged" '{"plugins":{"":[{"version":"0"}],"not-qualified":[{"version":"1"}],"ghost@mkt":[{"version":"1"}]}}' "$(jq -c . "$REG")"
make_pkg "$CACHE/1.0.0" 1.0.0
printf '{"plugins":{"silver-bullet@alo-labs-codex":[{"version":"0.1","installPath":"/old"}],"other@x":[{"version":"9"}]}}\n' >"$REG"
sub sync_codex_installed_plugin_registry_paths
assert_eq "registry sync exits 0" 0 "$TL_STATUS"
assert_eq "SB entry points at the stable alias" "$CACHE/current" "$(jq -r '.plugins["silver-bullet@alo-labs-codex"][0].installPath' "$REG")"
assert_eq "SB entry version refreshed" 1.0.0 "$(jq -r '.plugins["silver-bullet@alo-labs-codex"][0].version' "$REG")"
assert_eq "foreign entries untouched" 9 "$(jq -r '.plugins["other@x"][0].version' "$REG")"

# ------------------------------------------------------- skill-mirror.sh
reset_home
sub sync_silver_bullet_native_codex_skill_mirror
assert_eq "no package: no skill mirror" 0 "$TL_STATUS"
mkdir -p "$CACHE/current/skills/sb-init"
printf -- '---\nname: sb-init\ndescription: d\n---\nbody\n' >"$CACHE/current/skills/sb-init/SKILL.md"
sub sync_silver_bullet_native_codex_skill_mirror
assert_eq "legacy top-level skills still mirrored" 0 "$TL_STATUS"
reset_home
sub sync_silver_bullet_skill_cache
assert_eq "no marketplace: skill cache sync is a no-op" 0 "$TL_STATUS"
mkdir -p "$MP"
sub sync_silver_bullet_skill_cache
assert_eq "marketplace without skill-source: no-op" 0 "$TL_STATUS"

# ------------------------------------------------------- legacy.sh
reset_home
mkdir -p "$MP"
sub scrub_legacy_silver_bullet_traces
assert_eq "no changelog: nothing to scrub" 0 "$TL_STATUS"
printf 'keep\nmentions using-silver-bullet here\nkeep2\n' >"$MP/CHANGELOG.md"
sub scrub_legacy_silver_bullet_traces
assert_eq "legacy skill mentions scrubbed" "keep
keep2" "$(<"$MP/CHANGELOG.md")"
reset_home
sub scrub_legacy_silver_bullet_traces
assert_eq "no marketplace: nothing to scrub" 0 "$TL_STATUS"

# ------------------------------------------------------- hooks.sh
reset_home
sub seed_silver_bullet_hook_trust_state
assert_eq "no package: no trust seeding" 0 "$TL_STATUS"
sub merge_silver_bullet_hooks_into_user_config
assert_eq "no package hooks: nothing to merge" 0 "$TL_STATUS"
make_pkg "$MP/plugins/silver-bullet" 1.0.0
cat >"$MP/plugins/silver-bullet/hooks/hooks.json" <<'JSON'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/a.sh"}]}]}}
JSON
mkdir -p "$CH/.codex"
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/usr/bin/user-hook"},{"type":"command","command":"/old/silver-bullet/1.0/hooks/a.sh"}]}]}}\n' >"$CH/.codex/hooks.json"
sub merge_silver_bullet_hooks_into_user_config
assert_eq "hook merge exits 0" 0 "$TL_STATUS"
MERGED="$(jq -r '[.hooks.PreToolUse[].hooks[].command] | sort | join(",")' "$CH/.codex/hooks.json")"
assert_contains "user hook preserved" "$MERGED" "/usr/bin/user-hook"
assert_contains "SB hook installed with the package path" "$MERGED" "$MP/plugins/silver-bullet/hooks/a.sh"
assert_not_contains "stale SB hook replaced" "$MERGED" "/old/silver-bullet"
FIRST="$(<"$CH/.codex/hooks.json")"
sub merge_silver_bullet_hooks_into_user_config
assert_eq "hook merge is idempotent" "$FIRST" "$(<"$CH/.codex/hooks.json")"
printf '{broken' >"$CH/.codex/hooks.json"
sub merge_silver_bullet_hooks_into_user_config
assert_eq "unparseable user hooks.json makes the merge fail" 1 "$([[ $TL_STATUS -ne 0 ]] && echo 1 || echo 0)"
assert_eq "unparseable user hooks.json left byte-identical" "{broken" "$(<"$CH/.codex/hooks.json")"

tl_results
