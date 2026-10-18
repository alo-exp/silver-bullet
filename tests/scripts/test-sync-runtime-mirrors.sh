#!/usr/bin/env bash
# sync-runtime-mirrors.sh: regenerate and --check modes, drift reporting for
# files and directory trees, and tolerance for a missing canonical source.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPTS=(reconcile-recommended-tools.sh sb-doctor.sh optimize-five-tool-stack.sh
  optimize-rtk-context-mode.sh install-leanctx-sb.sh install-cursor.sh
  install-global-toolstack.sh install-recommended-tools-cursor.sh)

# Minimal tree: the script locates its repo root from its own path.
new_tree() {
  local t="$1" f
  rm -rf "$t"
  mkdir -p "$t/scripts/lib/recommended-tools" "$t/scripts/lib/global-toolstack" \
    "$t/hooks/lib/sub" "$t/plugins/silver-bullet"
  cp "$TL_REPO_ROOT/scripts/sync-runtime-mirrors.sh" "$t/scripts/"
  for f in "${SCRIPTS[@]}"; do printf '#!/bin/sh\necho %s\n' "$f" >"$t/scripts/$f"; done
  printf 'rt\n' >"$t/scripts/lib/recommended-tools/a.sh"
  printf 'gt\n' >"$t/scripts/lib/global-toolstack/b.sh"
  printf '#!/bin/sh\n' >"$t/hooks/session-start"
  printf '{}\n' >"$t/hooks/hooks.json"
  printf 'lib\n' >"$t/hooks/lib/x.sh"
  printf 'deep\n' >"$t/hooks/lib/sub/y.sh"
}

T="$TL_TMP/tree"
M="$T/plugins/silver-bullet"
SYNC="$T/scripts/sync-runtime-mirrors.sh"

# --- regenerate ---------------------------------------------------------
new_tree "$T"
tl_run bash "$SYNC"
assert_eq "regenerate exits 0" 0 "$TL_STATUS"
assert_contains "regenerate counts every operation" "$TL_OUT" "Synced runtime mirrors (13 operations)"
assert_eq "script copied" "#!/bin/sh
echo sb-doctor.sh" "$(<"$M/scripts/sb-doctor.sh")"
assert_eq "lib tree copied" "rt" "$(<"$M/scripts/lib/recommended-tools/a.sh")"
assert_eq "nested hook lib copied" "deep" "$(<"$M/hooks/lib/sub/y.sh")"
assert_eq "hooks.json copied" "{}" "$(<"$M/hooks/hooks.json")"
if [[ -x "$M/scripts/reconcile-recommended-tools.sh" ]]; then
  tl_pass "reconcile script is executable in the mirror"
else
  tl_fail "reconcile script is executable in the mirror"
fi

# --- check: fresh -------------------------------------------------------
tl_run bash "$SYNC" --check
assert_eq "fresh mirror passes --check" 0 "$TL_STATUS"
assert_contains "check reports path count" "$TL_OUT" "Runtime mirrors fresh (13 paths checked)"

# --- check: drift -------------------------------------------------------
printf 'changed\n' >"$M/scripts/sb-doctor.sh"
rm -f "$M/hooks/hooks.json"
printf 'changed\n' >"$M/hooks/lib/sub/y.sh"
rm -f "$M/scripts/lib/global-toolstack/b.sh"
tl_run bash "$SYNC" --check
assert_eq "drift fails --check" 1 "$TL_STATUS"
assert_contains "changed file named" "$TL_OUT" "DRIFT: plugins/silver-bullet/scripts/sb-doctor.sh"
assert_contains "missing file named" "$TL_OUT" "DRIFT: plugins/silver-bullet/hooks/hooks.json"
assert_contains "changed nested file named" "$TL_OUT" "DRIFT: plugins/silver-bullet/hooks/lib/sub/y.sh"
assert_contains "missing tree file named" "$TL_OUT" "DRIFT: plugins/silver-bullet/scripts/lib/global-toolstack/b.sh"
assert_contains "drift summary counts files" "$TL_ERR" "Runtime mirror drift: 4 file(s)"
assert_eq "--check never repairs" "changed" "$(<"$M/scripts/sb-doctor.sh")"

# Regenerate repairs the drift.
tl_run bash "$SYNC"
tl_run bash "$SYNC" --check
assert_eq "regenerate repairs drift" 0 "$TL_STATUS"

# --- missing sources ----------------------------------------------------
# A missing canonical file warns (regenerate) or is skipped (check) without failing.
rm -f "$T/scripts/install-cursor.sh" "$M/scripts/install-cursor.sh"
tl_run bash "$SYNC"
assert_eq "missing source file does not fail regenerate" 0 "$TL_STATUS"
assert_contains "missing source warned" "$TL_ERR" "WARN: missing source $T/scripts/install-cursor.sh"
assert_contains "one operation fewer" "$TL_OUT" "Synced runtime mirrors (12 operations)"
tl_run bash "$SYNC" --check
assert_eq "missing source file does not fail --check" 0 "$TL_STATUS"

# Missing canonical directories are skipped silently.
rm -rf "$T/scripts/lib/recommended-tools" "$T/hooks/lib"
tl_run bash "$SYNC"
assert_eq "missing source dirs do not fail regenerate" 0 "$TL_STATUS"
assert_contains "dir operations skipped" "$TL_OUT" "Synced runtime mirrors (10 operations)"
tl_run bash "$SYNC" --check
assert_eq "missing source dirs do not fail --check" 0 "$TL_STATUS"

# Without reconcile-recommended-tools.sh the chmod fallback keeps the run green.
new_tree "$T"
rm -f "$T/scripts/reconcile-recommended-tools.sh"
tl_run bash "$SYNC"
assert_eq "no reconcile script: regenerate still exits 0" 0 "$TL_STATUS"
assert_file_absent "no reconcile script: nothing invented in mirror" "$M/scripts/reconcile-recommended-tools.sh"

tl_results
