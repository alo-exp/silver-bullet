#!/usr/bin/env bash
# sync-cursor-package.sh in a disposable repository snapshot: manifest
# derivation (with and without a commands dir), pruning of agents/, hook file
# generation, preflight and missing-manifest errors, idempotence.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=tests/lib/repo-snapshot.sh
source "$TL_REPO_ROOT/tests/lib/repo-snapshot.sh"
SNAP="$(sb_repo_snapshot --git "$TL_REPO_ROOT" "$TL_TMP/repo")"
SCRIPT="$SNAP/scripts/sync-cursor-package.sh"
PKG="$SNAP/plugins/silver-bullet"
cd "$TL_TMP"

snap_dirty() { git -C "$SNAP" status --porcelain --untracked-files=all; }
sync_pkg() { tl_run timeout 60 bash "$SCRIPT"; }

# --- with a commands dir ------------------------------------------------------
mkdir -p "$PKG/agents/cursor/x" "$PKG/commands"
printf 'stale\n' >"$PKG/commands/zz-stale-command.md"
jq '.version = "0.0.0-stale" | .skills = "./skills" | .commands = "./nope"' "$PKG/.cursor-plugin/plugin.json" >"$TL_TMP/m.json"
cp "$TL_TMP/m.json" "$PKG/.cursor-plugin/plugin.json"
chmod 600 "$PKG/.cursor-plugin/plugin.json"
sync_pkg
assert_eq "sync exits 0" 0 "$TL_STATUS"
assert_contains "completion logged" "$TL_OUT" "[cursor-sync] Cursor package manifest synchronized to $PKG"
ROOT_V="$(jq -r .version "$SNAP/.cursor-plugin/plugin.json")"
assert_eq "package version follows the root manifest" "$ROOT_V" "$(jq -r .version "$PKG/.cursor-plugin/plugin.json")"
assert_eq "hooks point at the generated file" '"./cursor-hooks.json"' "$(jq -c .hooks "$PKG/.cursor-plugin/plugin.json")"
assert_eq "commands dir referenced" '"./commands"' "$(jq -c .commands "$PKG/.cursor-plugin/plugin.json")"
assert_eq "skills field removed" 'null' "$(jq -c .skills "$PKG/.cursor-plugin/plugin.json")"
assert_eq "root fields carried over" "$(jq -c .keywords "$SNAP/.cursor-plugin/plugin.json")" "$(jq -c .keywords "$PKG/.cursor-plugin/plugin.json")"
assert_eq "manifest is world-readable" "644" "$(stat -c %a "$PKG/.cursor-plugin/plugin.json" 2>/dev/null || stat -f %Lp "$PKG/.cursor-plugin/plugin.json")"
assert_eq "hooks file is world-readable" "644" "$(stat -c %a "$PKG/cursor-hooks.json" 2>/dev/null || stat -f %Lp "$PKG/cursor-hooks.json")"
assert_eq "hooks file matches the generated source" "" "$(cmp "$SNAP/hooks/cursor-hooks.json" "$PKG/cursor-hooks.json" && echo)"
assert_file_absent "agents dir pruned from the package" "$PKG/agents"
# The commands dir is owned by the package itself: the sync keeps it as is.
assert_file_exists "existing commands are kept" "$PKG/commands/sb-bugfix.md"
assert_eq "extra command file kept as is" "stale" "$(<"$PKG/commands/zz-stale-command.md")"
rm -f "$PKG/commands/zz-stale-command.md"
assert_eq "tree restored to the generated state" "" "$(snap_dirty)"

# Idempotent.
sync_pkg
assert_eq "second sync exits 0" 0 "$TL_STATUS"
assert_eq "second sync changes nothing" "" "$(snap_dirty)"

# --- without a commands dir ---------------------------------------------------
rm -rf "$PKG/commands"
sync_pkg
assert_eq "sync without commands exits 0" 0 "$TL_STATUS"
assert_eq "no commands field without a commands dir" 'null' "$(jq -c .commands "$PKG/.cursor-plugin/plugin.json")"
assert_eq "hooks still set without commands" '"./cursor-hooks.json"' "$(jq -c .hooks "$PKG/.cursor-plugin/plugin.json")"
assert_file_absent "commands dir not invented" "$PKG/commands"
git -C "$SNAP" checkout -q -- plugins/silver-bullet/commands plugins/silver-bullet/.cursor-plugin/plugin.json

# --- preflight ------------------------------------------------------------------
for tool in rsync python3; do
  if [[ "$tool" == rsync ]]; then keep=python3; else keep=rsync; fi
  dir="$TL_TMP/preflight-no-$tool"
  mkdir -p "$dir"
  ln -sf "$(command -v dirname)" "$dir/dirname"
  ln -sf "$(command -v "$keep")" "$dir/$keep"
  tl_run env PATH="$dir" "$(command -v timeout)" 60 "$(command -v bash)" "$SCRIPT"
  assert_eq "missing $tool exits 1" 1 "$TL_STATUS"
  assert_contains "missing $tool named" "$TL_ERR" "ERROR: $tool is required by sync-cursor-package.sh"
  assert_eq "missing $tool: nothing touched" "" "$(snap_dirty)"
done

# --- missing root manifest --------------------------------------------------------
rm -f "$SNAP/.cursor-plugin/plugin.json"
sync_pkg
assert_eq "missing root manifest exits 1" 1 "$TL_STATUS"
assert_contains "missing root manifest named" "$TL_ERR" "missing Cursor plugin manifest at $SNAP/.cursor-plugin/plugin.json"
git -C "$SNAP" checkout -q -- .cursor-plugin/plugin.json

# --- generator failure --------------------------------------------------------------
printf 'import sys\nsys.exit(4)\n' >"$SNAP/scripts/generate-cursor-hooks.py"
cp "$PKG/cursor-hooks.json" "$TL_TMP/hooks.before"
sync_pkg
assert_eq "generator failure status propagates" 4 "$TL_STATUS"
assert_eq "previous hooks file untouched after generator failure" "$(<"$TL_TMP/hooks.before")" "$(<"$PKG/cursor-hooks.json")"
git -C "$SNAP" checkout -q -- scripts/generate-cursor-hooks.py

tl_results
