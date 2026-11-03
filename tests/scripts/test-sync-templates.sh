#!/usr/bin/env bash
# sync-templates.sh: mirrors templates/ into plugins/silver-bullet/templates/
# byte for byte (host-neutral: the package root is shared by Codex and Cursor,
# R8-02) and fails loudly when a prerequisite is missing (before it touches the
# mirror).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# The script derives its repo root from its own location, so a minimal tree
# keeps the real checkout out of reach.
new_tree() {
  local tree="$1"
  rm -rf "$tree"
  mkdir -p "$tree/scripts" "$tree/templates/sub" "$tree/plugins/silver-bullet/templates/stale-dir"
  cp "$TL_REPO_ROOT/scripts/sync-templates.sh" "$tree/scripts/"
  printf 'one\n' >"$tree/templates/a.md"
  printf 'two\n' >"$tree/templates/sub/b.md"
  printf 'old\n' >"$tree/plugins/silver-bullet/templates/stale-dir/old.md"
  printf 'old\n' >"$tree/plugins/silver-bullet/templates/stale.md"
  # A runtime placeholder and a Cursor path the Codex sanitizer used to rewrite.
  printf '%s\n' 'state: ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state' 'mcp: ~/.cursor/mcp.json' >"$tree/templates/c.md"
}

T="$TL_TMP/tree"
new_tree "$T"
tl_run bash "$T/scripts/sync-templates.sh"
assert_eq "sync exits 0" 0 "$TL_STATUS"
assert_eq "template copied" "one" "$(<"$T/plugins/silver-bullet/templates/a.md")"
assert_eq "nested template copied" "two" "$(<"$T/plugins/silver-bullet/templates/sub/b.md")"
assert_file_absent "stale mirror file deleted" "$T/plugins/silver-bullet/templates/stale.md"
assert_file_absent "stale mirror dir deleted" "$T/plugins/silver-bullet/templates/stale-dir"
assert_eq "mirror is byte-identical and keeps placeholders" "$(<"$T/templates/c.md")" "$(<"$T/plugins/silver-bullet/templates/c.md")"
tl_run diff -r "$T/templates" "$T/plugins/silver-bullet/templates"
assert_eq "whole mirror equals the source" 0 "$TL_STATUS"
SYNC_OUT="$(bash "$T/scripts/sync-templates.sh")"
assert_contains "reports file count" "$SYNC_OUT" "(3 files)"
assert_contains "reports source and destination" "$SYNC_OUT" "Synced $T/templates -> $T/plugins/silver-bullet/templates"

# Missing destination parent is created.
rm -rf "$T/plugins"
tl_run bash "$T/scripts/sync-templates.sh"
assert_eq "destination created from scratch" 0 "$TL_STATUS"
assert_file_exists "template present in fresh destination" "$T/plugins/silver-bullet/templates/a.md"

# Missing source: error, mirror untouched.
new_tree "$T"
rm -rf "$T/templates"
tl_run bash "$T/scripts/sync-templates.sh"
assert_eq "missing templates dir exits 1" 1 "$TL_STATUS"
assert_contains "missing templates dir named" "$TL_ERR" "missing source templates at $T/templates"
assert_file_exists "mirror untouched when source missing" "$T/plugins/silver-bullet/templates/stale.md"

# rsync absent: error before the mirror is touched.
new_tree "$T"
tl_run env PATH="$(tl_path_without rsync)" bash "$T/scripts/sync-templates.sh"
assert_eq "missing rsync exits 1" 1 "$TL_STATUS"
assert_contains "missing rsync reported" "$TL_ERR" "rsync is required"
assert_file_exists "mirror untouched when rsync missing" "$T/plugins/silver-bullet/templates/stale.md"

tl_results
