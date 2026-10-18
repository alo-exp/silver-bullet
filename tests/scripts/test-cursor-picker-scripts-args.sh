#!/usr/bin/env bash
# Argument handling of the Cursor picker diagnostics and the Codex package
# sanitizer wrapper (help text, unknown flags, flags missing their value).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

for script in diagnose-cursor-picker-duplicates enumerate-cursor-slash-picker; do
  S="$TL_REPO_ROOT/scripts/$script.sh"
  tl_run bash "$S" --help
  assert_eq "$script --help exits 0" 0 "$TL_STATUS"
  assert_contains "$script --help prints the usage header" "$TL_OUT" "Usage:"
  tl_run bash "$S" --bogus
  assert_eq "$script unknown argument exits 2" 2 "$TL_STATUS"
  assert_contains "$script unknown argument named" "$TL_ERR" "$script: unknown argument: --bogus"
  # A flag that needs a value but is last on the command line: clear usage error, not a silent exit.
  for flag in --cursor-home --surface --workspace; do
    [[ "$script" == diagnose-cursor-picker-duplicates && "$flag" != --cursor-home ]] && continue
    tl_run bash "$S" "$flag"
    assert_eq "$script $flag without value exits 2" 2 "$TL_STATUS"
    assert_contains "$script $flag without value explains" "$TL_ERR" "$script: $flag requires a value"
  done
done

# ---- flags with values reach the report
EMPTY_HOME="$TL_TMP/empty-cursor-home"
mkdir -p "$EMPTY_HOME"
tl_run bash "$TL_REPO_ROOT/scripts/diagnose-cursor-picker-duplicates.sh" --cursor-home "$EMPTY_HOME" --all-gitpaths
assert_eq "diagnose with an explicit empty cursor home exits 0" 0 "$TL_STATUS"
assert_contains "diagnose reports the given cursor home" "$TL_OUT" "cursor_home=$EMPTY_HOME"
assert_contains "diagnose concludes with a result line" "$TL_OUT" "RESULT:"
tl_run bash "$TL_REPO_ROOT/scripts/enumerate-cursor-slash-picker.sh" --cursor-home "$EMPTY_HOME" --surface "$EMPTY_HOME/none" --workspace "$EMPTY_HOME/ws"
assert_eq "enumerate without any plugin surface exits 1" 1 "$TL_STATUS"
assert_contains "enumerate explains the missing surface" "$TL_OUT$TL_ERR" "no Cursor Silver Bullet plugin surface found"

# ---- global custom agents: only genuinely installer-generated files are exempt
SURF="$TL_TMP/surface"; mkdir -p "$SURF"
AGH="$TL_TMP/agents-home"; AG="$AGH/agents"; mkdir -p "$AG/sub"
MARK='<!-- sb-managed: cursor-sb-agents -->'
genuine() { printf -- '---\nname: %s\ndescription: SB reusable ladder agent — x effort=high.\nmodel: m\nreadonly: false\n---\nYou are a Silver Bullet reusable review/verify agent.\n%s\n' "$1" "$MARK"; }
genuine sb-ok-high >"$AG/sb-ok-high.md"
genuine sb:evil >"$AG/sb-evil.md"                              # marker + sb: name
genuine silver-fake >"$AG/silver-fake.md"                      # marker + non-sb filename
printf -- '---\nname: sb-mid-high\ndescription: SB reusable ladder agent — x.\n---\n%s\nSilver Bullet trailing body\n' "$MARK" >"$AG/sb-mid-high.md"   # marker mid-file
genuine sb-nested-high >"$AG/sub/sb-nested-high.md"            # subdirectory
printf -- '---\nname: sb-other-high\ndescription: something else Silver Bullet.\n---\nbody\n%s\n' "$MARK" >"$AG/sb-other-high.md"   # wrong description
printf -- '---\nname: sb-mismatch\ndescription: SB reusable ladder agent — x.\n---\nSilver Bullet\n%s\n' "$MARK" >"$AG/sb-differs-high.md"   # name != filename stem
tl_run bash "$TL_REPO_ROOT/scripts/enumerate-cursor-slash-picker.sh" --cursor-home "$AGH" --surface "$SURF"
for f in sb-evil sb-mid-high sb-other-high sb-differs-high sb-nested-high silver-fake; do
  assert_contains "$f is flagged" "$TL_OUT" "$f"
done
assert_not_contains "genuine generated agent is not flagged" "$TL_OUT" "sb-ok-high"

# ---- codex-sanitize-package.sh
SAN="$TL_REPO_ROOT/scripts/codex-sanitize-package.sh"
tl_run bash "$SAN"
assert_eq "sanitizer without roots exits 2" 2 "$TL_STATUS"
assert_contains "sanitizer usage names the script" "$TL_ERR" "Usage: codex-sanitize-package.sh <package-root>"
mkdir -p "$TL_TMP/pkg1" "$TL_TMP/pkg2"
printf 'Use the Agent tool here\n' >"$TL_TMP/pkg1/a.md"
printf 'Use the Agent tool here\n' >"$TL_TMP/pkg2/b.md"
tl_run bash "$SAN" "$TL_TMP/pkg1" "$TL_TMP/pkg2"
assert_eq "sanitizer exits 0" 0 "$TL_STATUS"
assert_contains "first root rewritten for Codex" "$(<"$TL_TMP/pkg1/a.md")" "active runtime delegation mechanism"
assert_contains "second root rewritten for Codex" "$(<"$TL_TMP/pkg2/b.md")" "active runtime delegation mechanism"
tl_run bash "$SAN" "$TL_TMP/missing-root"
assert_eq "sanitizer tolerates a missing root" 0 "$TL_STATUS"

tl_results
