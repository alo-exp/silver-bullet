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

tl_results
