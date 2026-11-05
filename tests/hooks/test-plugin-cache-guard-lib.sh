#!/usr/bin/env bash
# hooks/lib/plugin-cache-guard.sh: uninstall-cleanup detection for the plugin cache.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/hooks/lib/plugin-cache-guard.sh"
CACHE="$SB_RUNTIME_PLUGIN_CACHE_ROOT"
REGISTRY="$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
mkdir -p "$CACHE/mkt/gone/1.0" "$CACHE/mkt/kept/1.0" "$CACHE/mkt/kept/0.9"

# call <function> [args...]: run a lib function in a clean bash and capture status/output.
call() {
  tl_run bash -c 'source "$1"; shift; "$@"' _ "$LIB" "$@"
}
write_registry() { printf '%s\n' "$1" >"$REGISTRY"; }

# --- registry file / installed paths -------------------------------------
call sb_plugin_cache_registry_file
assert_eq "registry file path" "$REGISTRY" "$TL_OUT"

rm -f "$REGISTRY"
call sb_plugin_cache_installed_paths
assert_eq "no registry: installed paths succeed" 0 "$TL_STATUS"
assert_eq "no registry: nothing listed" "" "$TL_OUT"

write_registry "{\"plugins\":{\"a@m\":[{\"installPath\":\"$CACHE/mkt/kept/1.0\"},{\"other\":1}],\"b@m\":[{\"installPath\":\"$CACHE/mkt/kept/0.9\"}]}}"
call sb_plugin_cache_installed_paths
assert_eq "installed paths succeed" 0 "$TL_STATUS"
assert_eq "installed paths listed" "$CACHE/mkt/kept/1.0
$CACHE/mkt/kept/0.9" "$TL_OUT"

TL_NOJQ="$(tl_path_without jq)"
tl_run env PATH="$TL_NOJQ" bash -c 'source "$1"; sb_plugin_cache_installed_paths' _ "$LIB"
assert_eq "jq missing: installed paths fail" 1 "$TL_STATUS"

write_registry "{\"plugins\":{\"a@m\":[{\"installPath\":\"$CACHE/mkt/kept/1.0\"}]}}"
tl_run env PATH="$TL_NOJQ" bash -c 'source "$1"; sb_plugin_cache_path_is_uninstalled "$2/mkt/gone/1.0" "$2"' _ "$LIB" "$CACHE"
assert_eq "jq missing: unreadable registry is treated as no installs" 0 "$TL_STATUS"

# --- sb_plugin_cache_path_is_uninstalled ----------------------------------
call sb_plugin_cache_path_is_uninstalled "" "$CACHE"
assert_eq "empty target is not uninstalled" 1 "$TL_STATUS"
tl_run env SB_RUNTIME_PLUGIN_CACHE_ROOT= bash -c 'source "$1"; sb_plugin_cache_path_is_uninstalled "$2"' _ "$LIB" "$CACHE/mkt/gone/1.0"
assert_eq "empty cache root is not uninstalled" 1 "$TL_STATUS"

rm -f "$REGISTRY"
call sb_plugin_cache_path_is_uninstalled "$CACHE/mkt/gone/1.0"
assert_eq "missing registry: not uninstalled" 1 "$TL_STATUS"

write_registry "{\"plugins\":{\"a@m\":[{\"installPath\":\"$CACHE/mkt/kept/1.0\"}]}}"
call sb_plugin_cache_path_is_uninstalled "$CACHE/mkt/gone/1.0"
assert_eq "unreferenced cache path is uninstalled (default cache root)" 0 "$TL_STATUS"
call sb_plugin_cache_path_is_uninstalled "$CACHE/mkt/gone/1.0" "$CACHE/"
assert_eq "trailing slash on cache root is tolerated" 0 "$TL_STATUS"
call sb_plugin_cache_path_is_uninstalled "$TL_TMP/elsewhere" "$CACHE"
assert_eq "path outside the cache is not uninstalled" 1 "$TL_STATUS"
call sb_plugin_cache_path_is_uninstalled "$CACHE/mkt/kept/1.0" "$CACHE"
assert_eq "installed path is not uninstalled" 1 "$TL_STATUS"
call sb_plugin_cache_path_is_uninstalled "$CACHE/mkt/kept" "$CACHE"
assert_eq "parent of an installed path is not uninstalled" 1 "$TL_STATUS"
call sb_plugin_cache_path_is_uninstalled "$CACHE/mkt/kept/1.0/sub" "$CACHE"
assert_eq "child of an installed path is not uninstalled" 1 "$TL_STATUS"

write_registry "{\"plugins\":{\"a@m\":[{\"installPath\":\"\"},{\"installPath\":\"~/tilde//dir\"},{\"installPath\":\"$TL_TMP/outside/other\"},{\"installPath\":\"$CACHE/mkt/kept/1.0\"}]}}"
call sb_plugin_cache_path_is_uninstalled "$CACHE/mkt/gone/1.0" "$CACHE"
assert_eq "blank, tilde and out-of-cache install paths are skipped" 0 "$TL_STATUS"

# --- sb_plugin_cache_writes_are_uninstall_cleanup -------------------------
write_registry "{\"plugins\":{\"a@m\":[{\"installPath\":\"$CACHE/mkt/kept/1.0\"}]}}"
call sb_plugin_cache_writes_are_uninstall_cleanup "$CACHE/mkt/gone/1.0"
assert_eq "all cache targets uninstalled: cleanup" 0 "$TL_STATUS"
call sb_plugin_cache_writes_are_uninstall_cleanup "" "$TL_TMP/other" "$CACHE/mkt/gone/1.0"
assert_eq "blank and non-cache targets are ignored" 0 "$TL_STATUS"
call sb_plugin_cache_writes_are_uninstall_cleanup "$CACHE/mkt/gone/1.0" "$CACHE/mkt/kept/1.0"
assert_eq "one installed target blocks cleanup" 1 "$TL_STATUS"
call sb_plugin_cache_writes_are_uninstall_cleanup "$TL_TMP/other"
assert_eq "no cache target at all is not cleanup" 1 "$TL_STATUS"
call sb_plugin_cache_writes_are_uninstall_cleanup
assert_eq "no targets is not cleanup" 1 "$TL_STATUS"
tl_run env SB_RUNTIME_PLUGIN_CACHE_ROOT= bash -c 'source "$1"; sb_plugin_cache_writes_are_uninstall_cleanup "$2"' _ "$LIB" "$CACHE/mkt/gone/1.0"
assert_eq "empty cache root: not cleanup" 1 "$TL_STATUS"
rm -f "$REGISTRY"
call sb_plugin_cache_writes_are_uninstall_cleanup "$CACHE/mkt/gone/1.0"
assert_eq "missing registry: not cleanup" 1 "$TL_STATUS"

# --- sb_plugin_cache_command_is_uninstall_cleanup -------------------------
write_registry "{\"plugins\":{\"a@m\":[{\"installPath\":\"$CACHE/mkt/kept/1.0\"}]}}"
call sb_plugin_cache_command_is_uninstall_cleanup "rm -rf $CACHE/mkt/gone/1.0" "$CACHE/mkt/gone/1.0"
assert_eq "rm of an uninstalled cache dir is cleanup" 0 "$TL_STATUS"
call sb_plugin_cache_command_is_uninstall_cleanup "rmdir $CACHE/mkt/gone/1.0" "$CACHE/mkt/gone/1.0"
assert_eq "rmdir of an uninstalled cache dir is cleanup" 0 "$TL_STATUS"
call sb_plugin_cache_command_is_uninstall_cleanup "rm -rf $CACHE/mkt/kept/1.0" "$CACHE/mkt/kept/1.0"
assert_eq "rm of an installed cache dir is not cleanup" 1 "$TL_STATUS"
call sb_plugin_cache_command_is_uninstall_cleanup "cp x $CACHE/mkt/gone/1.0" "$CACHE/mkt/gone/1.0"
assert_eq "non-deletion write is not cleanup" 1 "$TL_STATUS"
call sb_plugin_cache_command_is_uninstall_cleanup "rm -rf /tmp/unrelated" "/tmp/unrelated"
assert_eq "command not mentioning the cache is not cleanup" 1 "$TL_STATUS"
call sb_plugin_cache_command_is_uninstall_cleanup "" "$CACHE/mkt/gone/1.0"
assert_eq "empty command is not cleanup" 1 "$TL_STATUS"
tl_run env SB_RUNTIME_PLUGIN_CACHE_ROOT= bash -c 'source "$1"; sb_plugin_cache_command_is_uninstall_cleanup "rm x"' _ "$LIB"
assert_eq "empty cache root: command is not cleanup" 1 "$TL_STATUS"

# The canonical (symlink-resolved) cache path also counts as a mention of the cache.
ln -s "$CACHE" "$TL_TMP/cache-link"
tl_run env SB_RUNTIME_PLUGIN_CACHE_ROOT="$TL_TMP/cache-link" bash -c \
  'source "$1"; sb_plugin_cache_command_is_uninstall_cleanup "rm -rf $2/mkt/gone/1.0" "$2/mkt/gone/1.0"' _ "$LIB" "$CACHE"
assert_eq "command naming the canonical cache path is cleanup" 0 "$TL_STATUS"

tl_run bash -c 'source "$1"; unset -f sb_plugin_cache_writes_are_uninstall_cleanup; sb_plugin_cache_command_is_uninstall_cleanup "rm -rf $2/mkt/gone/1.0" "$2/mkt/gone/1.0"' _ "$LIB" "$CACHE"
assert_eq "missing writes helper fails closed" 1 "$TL_STATUS"

# --- library directory detection ------------------------------------------
tl_run bash -c 'pwd() { return 1; }; source "$1"; sb_plugin_cache_registry_file' _ "$LIB"
assert_eq "unresolvable lib dir still loads" "$REGISTRY" "$TL_OUT"

tl_results
