#!/usr/bin/env bash
# sync-templates.sh: mirrors templates/ into plugins/silver-bullet/templates/,
# runs the Codex sanitizer on the mirror and fails loudly when a prerequisite
# is missing (before it touches the mirror).
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
  cat >"$tree/scripts/codex-sanitize-package.sh" <<SAN
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$tree/sanitizer.log"
SAN
  chmod +x "$tree/scripts/codex-sanitize-package.sh"
}

T="$TL_TMP/tree"
new_tree "$T"
tl_run bash "$T/scripts/sync-templates.sh"
assert_eq "sync exits 0" 0 "$TL_STATUS"
assert_eq "template copied" "one" "$(<"$T/plugins/silver-bullet/templates/a.md")"
assert_eq "nested template copied" "two" "$(<"$T/plugins/silver-bullet/templates/sub/b.md")"
assert_file_absent "stale mirror file deleted" "$T/plugins/silver-bullet/templates/stale.md"
assert_file_absent "stale mirror dir deleted" "$T/plugins/silver-bullet/templates/stale-dir"
assert_eq "sanitizer ran once on the mirror" "$T/plugins/silver-bullet/templates" "$(<"$T/sanitizer.log")"
assert_contains "reports file count" "$TL_OUT" "(2 files)"
assert_contains "reports source and destination" "$TL_OUT" "Synced $T/templates -> $T/plugins/silver-bullet/templates"

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

# Sanitizer missing or not executable.
new_tree "$T"
rm -f "$T/scripts/codex-sanitize-package.sh"
tl_run bash "$T/scripts/sync-templates.sh"
assert_eq "missing sanitizer exits 1" 1 "$TL_STATUS"
assert_contains "missing sanitizer named" "$TL_ERR" "missing Codex sanitizer at $T/scripts/codex-sanitize-package.sh"
new_tree "$T"
chmod -x "$T/scripts/codex-sanitize-package.sh"
if [[ -x "$T/scripts/codex-sanitize-package.sh" ]]; then
  echo "SKIP: cannot drop the exec bit here"
else
  tl_run bash "$T/scripts/sync-templates.sh"
  assert_eq "non-executable sanitizer exits 1" 1 "$TL_STATUS"
fi

# A failing sanitizer fails the sync.
new_tree "$T"
printf '#!/usr/bin/env bash\nexit 5\n' >"$T/scripts/codex-sanitize-package.sh"
tl_run bash "$T/scripts/sync-templates.sh"
assert_eq "sanitizer failure propagates" 5 "$TL_STATUS"
assert_not_contains "no success line after sanitizer failure" "$TL_OUT" "Synced"

tl_results
