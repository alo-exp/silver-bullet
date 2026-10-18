#!/usr/bin/env bash
# scripts/generate-plugin-commands.sh against a staged mini checkout: stub
# rendering from SKILL.md frontmatter, legacy-name migration and cleanup.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

ROOT="$TL_TMP/repo"
OUT="$ROOT/plugins/silver-bullet/commands"
mkdir -p "$ROOT/scripts" "$OUT"
cp "$TL_REPO_ROOT/scripts/generate-plugin-commands.sh" "$ROOT/scripts/"

skill() { # skill <dir> <frontmatter lines...>
  local dir="$1"; shift
  mkdir -p "$ROOT/skills/$dir"
  { echo '---'; printf '%s\n' "$@"; echo '---'; echo 'body'; } >"$ROOT/skills/$dir/SKILL.md"
}
skill silver 'name: silver' 'description: "Main router"' 'argument-hint: "<what>"'
skill silver-feature 'name: "silver-feature"' 'description: Build a feature' 'argument-hint: <feature>'
skill silver-ui 'name: silver-ui' 'description: >' 'other: x'
skill silver-fast 'name: silver-fast' 'description: Quick fix'

# Pre-existing stubs from older generators / hosts
echo old >"$OUT/source-command-feature.md"
echo old >"$OUT/feature.md"
echo old >"$OUT/silver-feature.md"
echo old >"$OUT/sb:feature.md"          # colon-named, safe name sb-feature.md will be regenerated
echo legacy >"$OUT/sb:custom.md"        # colon-named, no safe twin: migrated
echo twin >"$OUT/sb-twin.md"
echo dup >"$OUT/sb:twin.md"             # colon-named with an existing safe twin: dropped
printf 'Retained body\n' >"$OUT/extra.md"
printf -- '---\nname: "kept"\n---\n\nKept body\n' >"$OUT/kept.md"
echo silver >"$OUT/silver.md"
echo custom >"$OUT/silver-custom.md"   # not a composer route: removed by the sweep

tl_run bash "$ROOT/scripts/generate-plugin-commands.sh"
assert_eq "generator exits 0" 0 "$TL_STATUS"
assert_contains "summary line" "$TL_OUT" "Generated 17 composer command stubs in $OUT"
assert_contains "missing skill warned" "$TL_ERR" "WARN: missing $ROOT/skills/silver-init/SKILL.md"
assert_contains "wrote the main route" "$TL_OUT" "Wrote $OUT/sb.md"

assert_file_absent "source-command stubs removed" "$OUT/source-command-feature.md"
assert_file_absent "bare route stub removed" "$OUT/feature.md"
assert_file_absent "silver-prefixed stub removed" "$OUT/silver-feature.md"
assert_file_absent "colon-named stub removed" "$OUT/sb:feature.md"
assert_file_absent "colon twin removed" "$OUT/sb:twin.md"
assert_file_absent "legacy silver.md removed" "$OUT/silver.md"
assert_file_absent "unlisted silver-* stub swept" "$OUT/silver-custom.md"
assert_contains "colon-named stub migrated to safe name" "$(<"$OUT/sb-custom.md")" "legacy"
assert_contains "existing safe twin kept" "$(<"$OUT/sb-twin.md")" "twin"
assert_not_contains "colon twin content not merged" "$(<"$OUT/sb-twin.md")" "dup"

SB="$(<"$OUT/sb.md")"
assert_contains "main route name" "$SB" 'name: "sb"'
assert_contains "main route description unquoted" "$SB" "description: Main router"
assert_contains "main route hint" "$SB" "argument-hint: <what>"
assert_contains "main route body invokes sb" "$SB" 'Invoke the Silver Bullet `sb` workflow'
FEATURE="$(<"$OUT/sb-feature.md")"
assert_contains "feature name uses safe stem" "$FEATURE" 'name: "sb-feature"'
assert_contains "feature description" "$FEATURE" "description: Build a feature"
assert_contains "feature hint" "$FEATURE" "argument-hint: <feature>"
assert_contains "feature body keeps the colon route name" "$FEATURE" 'Silver Bullet `sb:feature` workflow'
assert_contains "feature body points at skill source" "$FEATURE" 'skill-source/sb-feature/SILVER_SOURCE'
UI="$(<"$OUT/sb-ui.md")"
assert_contains "folded description falls back" "$UI" "description: Silver Bullet sb-ui workflow"
assert_contains "missing hint falls back" "$UI" "argument-hint: <task description>"
assert_contains "fast route generated" "$(<"$OUT/sb-fast.md")" "description: Quick fix"

EXTRA="$(<"$OUT/extra.md")"
assert_contains "retained route gets frontmatter" "$EXTRA" 'name: "extra"'
assert_contains "retained route gets description" "$EXTRA" "description: Silver Bullet extra workflow"
assert_contains "retained route keeps its body" "$EXTRA" "Retained body"
assert_eq "route with frontmatter is not rewritten" '---
name: "kept"
---

Kept body' "$(<"$OUT/kept.md")"

# Idempotent: a second run reproduces identical files
BEFORE="$(cd "$OUT" && sha256sum -- *.md)"
tl_run bash "$ROOT/scripts/generate-plugin-commands.sh"
assert_eq "second run exits 0" 0 "$TL_STATUS"
assert_eq "second run leaves outputs identical" "$BEFORE" "$(cd "$OUT" && sha256sum -- *.md)"

tl_results
