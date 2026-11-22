#!/usr/bin/env bash
# /sb:init must ignore the per-checkout phase-lock runtime state itself (user decision):
# the exact line sb-migrate-project.sh uses, added once, never through a symlink.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

STEPS="$TL_REPO_ROOT/skills/silver-init/references/scaffold-steps.md"
SKILL="$TL_REPO_ROOT/skills/silver-init/SKILL.md"
LINE='.planning/.phase-locks.json*'

# The migrate script is the source of the line: they must stay identical.
assert_contains "migrate script uses the same line" "$(cat "$TL_REPO_ROOT/scripts/sb-migrate-project.sh")" "LOCKS_MARKER='$LINE'"

# Extract the fenced bash block under the 3.2.6 heading.
SNIP="$TL_TMP/snippet.sh"
awk '/^### 3\.2\.6 /{h=1;next} h&&/^```bash/{b=1;next} h&&b&&/^```/{exit} h&&b{print}' "$STEPS" >"$SNIP"
assert_eq "snippet extracted" "yes" "$([[ -s "$SNIP" ]] && echo yes || echo no)"
assert_contains "SKILL.md lists step 3.2.6" "$(cat "$SKILL")" "3.2.6"
assert_contains "update mode runs 3.2.6" "$(cat "$STEPS")" "Run step 3.2.6"

run_in() { (cd "$1" && bash "$SNIP"); }

# No .gitignore: created with the line.
P1="$TL_TMP/p1"; mkdir -p "$P1"; run_in "$P1" >/dev/null
assert_contains "created .gitignore has the line" "$(cat "$P1/.gitignore")" "$LINE"
# Idempotent.
run_in "$P1" >/dev/null; run_in "$P1" >/dev/null
assert_eq "line appears once" "1" "$(grep -cF "$LINE" "$P1/.gitignore")"

# Existing file without trailing newline: contents kept, line on its own line.
P2="$TL_TMP/p2"; mkdir -p "$P2"; printf 'node_modules/' >"$P2/.gitignore"
run_in "$P2" >/dev/null
assert_contains "existing entry kept" "$(cat "$P2/.gitignore")" "node_modules/"
assert_eq "line is its own line" "1" "$(grep -cxF "$LINE" "$P2/.gitignore")"

# Existing file that already has the line: untouched.
P3="$TL_TMP/p3"; mkdir -p "$P3"; printf '%s\n' "$LINE" >"$P3/.gitignore"; cp "$P3/.gitignore" "$P3/before"
run_in "$P3" >/dev/null
assert_eq "already-ignored file untouched" "" "$(diff "$P3/before" "$P3/.gitignore" || true)"

# A commented or negated line is not the ignore (whole-line match); a CRLF whole line is.
for decoy in '# .planning/.phase-locks.json*' '!.planning/.phase-locks.json*'; do
  P5="$TL_TMP/p5"; rm -rf "$P5"; mkdir -p "$P5"; printf '%s\n' "$decoy" >"$P5/.gitignore"
  run_in "$P5" >/dev/null
  assert_eq "'$decoy' does not count: the line is added" "1" "$(grep -cxF "$LINE" "$P5/.gitignore")"
  run_in "$P5" >/dev/null
  assert_eq "'$decoy': and not added twice" "1" "$(grep -cxF "$LINE" "$P5/.gitignore")"
done
P6="$TL_TMP/p6"; mkdir -p "$P6"; printf '%s\r\n' "$LINE" >"$P6/.gitignore"; cp "$P6/.gitignore" "$P6/before"
run_in "$P6" >/dev/null
assert_eq "a CRLF whole-line entry counts as present" "" "$(cmp "$P6/before" "$P6/.gitignore" || true)"

# Symlink: never written through.
P4="$TL_TMP/p4"; mkdir -p "$P4"; : >"$TL_TMP/target"; ln -s "$TL_TMP/target" "$P4/.gitignore"
OUT="$(run_in "$P4")"
assert_contains "symlink skipped with a message" "$OUT" "symlink"
assert_eq "symlink target untouched" "0" "$(wc -c <"$TL_TMP/target" | tr -d ' ')"

tl_results
