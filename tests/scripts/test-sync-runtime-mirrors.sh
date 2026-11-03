#!/usr/bin/env bash
# sync-runtime-mirrors.sh: the plugin package's runtime scripts/ and hooks/ are
# relative symlinks to the canonical trees (the committed layout, R8-01).
# Regenerate repairs the links; --check fails on any other layout.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# Minimal tree in the committed layout: the script locates its repo root from its own path.
new_tree() {
  local t="$1"
  rm -rf "$t"
  mkdir -p "$t/scripts/lib" "$t/hooks/lib" "$t/plugins/silver-bullet"
  cp "$TL_REPO_ROOT/scripts/sync-runtime-mirrors.sh" "$t/scripts/"
  printf '#!/bin/sh\necho doctor\n' >"$t/scripts/sb-doctor.sh"
  printf 'lib\n' >"$t/hooks/lib/x.sh"
  printf '{}\n' >"$t/hooks/hooks.json"
  ln -s ../../scripts "$t/plugins/silver-bullet/scripts"
  ln -s ../../hooks "$t/plugins/silver-bullet/hooks"
}

T="$TL_TMP/tree"
M="$T/plugins/silver-bullet"
SYNC="$T/scripts/sync-runtime-mirrors.sh"

# --- committed layout: regenerate is a no-op, --check passes ---------------
new_tree "$T"
tl_run bash "$SYNC"
assert_eq "regenerate on the symlink layout exits 0 (no cp onto itself)" 0 "$TL_STATUS"
assert_contains "regenerate reports links in place" "$TL_OUT" "Runtime mirrors linked (2 links)"
assert_eq "scripts link kept" "../../scripts" "$(readlink "$M/scripts")"
tl_run bash "$SYNC" --check
assert_eq "fresh links pass --check" 0 "$TL_STATUS"
assert_contains "check reports fresh" "$TL_OUT" "Runtime mirrors fresh (2 links)"
assert_eq "mirror resolves to the canonical file" "lib" "$(<"$M/hooks/lib/x.sh")"

# --- a link to a stale copy is drift ----------------------------------------
mkdir -p "$T/stale/scripts"
printf 'old\n' >"$T/stale/scripts/sb-doctor.sh"
rm "$M/scripts"
ln -s ../../stale/scripts "$M/scripts"
tl_run bash "$SYNC" --check
assert_eq "link to a stale directory fails --check" 1 "$TL_STATUS"
assert_contains "wrong link named" "$TL_OUT" "DRIFT: plugins/silver-bullet/scripts -> ../../stale/scripts (expected ../../scripts)"
assert_contains "drift summary" "$TL_ERR" "Runtime mirror drift: 1 path(s) — run: bash scripts/sync-runtime-mirrors.sh"
assert_eq "--check never repairs" "../../stale/scripts" "$(readlink "$M/scripts")"
tl_run bash "$SYNC"
assert_eq "regenerate repairs a wrong link" 0 "$TL_STATUS"
assert_eq "link repointed" "../../scripts" "$(readlink "$M/scripts")"
assert_eq "stale tree left alone" "old" "$(<"$T/stale/scripts/sb-doctor.sh")"

# --- a physical directory (legacy mirror) and a missing link are drift ------
rm "$M/hooks"
mkdir -p "$M/hooks/lib"
printf 'lib\n' >"$M/hooks/lib/x.sh"
rm "$M/scripts"
tl_run bash "$SYNC" --check
assert_eq "physical copy and missing link fail --check" 1 "$TL_STATUS"
assert_contains "physical copy named" "$TL_OUT" "DRIFT: plugins/silver-bullet/hooks is a directory, not a link to ../../hooks"
assert_contains "missing link named" "$TL_OUT" "DRIFT: plugins/silver-bullet/scripts is missing"
assert_contains "two paths drift" "$TL_ERR" "Runtime mirror drift: 2 path(s)"
tl_run bash "$SYNC"
assert_eq "regenerate replaces the copy and restores the link" 0 "$TL_STATUS"
assert_eq "hooks relinked" "../../hooks" "$(readlink "$M/hooks")"
assert_eq "scripts relinked" "../../scripts" "$(readlink "$M/scripts")"
tl_run bash "$SYNC" --check
assert_eq "repaired layout passes --check" 0 "$TL_STATUS"

# --- a missing canonical tree cannot be linked -------------------------------
new_tree "$T"
rm -rf "$T/hooks"
tl_run bash "$SYNC"
assert_eq "missing canonical tree fails regenerate" 1 "$TL_STATUS"
assert_contains "missing source named" "$TL_ERR" "ERROR: missing canonical tree $T/hooks"

tl_run bash "$SYNC" --nope
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "usage printed" "$TL_ERR" "Usage: sync-runtime-mirrors.sh [--check]"

# --- the repository's own package passes --check -----------------------------
tl_run bash "$TL_REPO_ROOT/scripts/sync-runtime-mirrors.sh" --check
assert_eq "repository runtime mirrors are fresh" 0 "$TL_STATUS"

tl_results
