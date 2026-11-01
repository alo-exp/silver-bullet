#!/usr/bin/env bash
# scripts/generate-plugin-commands.sh against a staged mini checkout: stub
# rendering from SKILL.md frontmatter, legacy-name migration and cleanup, the
# --check drift gate, and determinism against the real skills and the
# committed stubs (R10b-19).
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
skill silver-ui 'name: silver-ui' 'description: >' '  Build the UI: screens,' '' '  and states.' 'other: x'
skill silver-fast 'name: silver-fast' 'description: Quick fix "now"'
skill silver-devops 'name: silver-devops' 'description: >-' '  Infra work' 'argument-hint: |' '  <infra task>'
skill silver-orient 'description: no name line'

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
assert_contains "main route description" "$SB" 'description: "Main router"'
assert_contains "main route hint" "$SB" 'argument-hint: "<what>"'
assert_contains "main route body invokes sb" "$SB" 'Invoke the Silver Bullet `sb` workflow'
FEATURE="$(<"$OUT/sb-feature.md")"
assert_contains "feature name uses safe stem" "$FEATURE" 'name: "sb-feature"'
assert_contains "feature description" "$FEATURE" 'description: "Build a feature"'
assert_contains "feature hint" "$FEATURE" 'argument-hint: "<feature>"'
assert_contains "feature body keeps the colon route name" "$FEATURE" 'Silver Bullet `sb:feature` workflow'
assert_contains "feature body points at the Cursor skill source" "$FEATURE" '`cursor-skill-source/sb-feature/SILVER_SOURCE`'
assert_contains "feature body records markers through the Skill tool" "$FEATURE" "through the host Skill tool"
assert_not_contains "no Codex picker title (R8-02)" "$FEATURE" "title:"
assert_not_contains "no Codex wording (R8-02)" "$FEATURE" "runtime-native"
UI="$(<"$OUT/sb-ui.md")"
assert_contains "folded description is read, YAML-quoted (R10b-19)" "$UI" 'description: "Build the UI: screens, and states."'
assert_contains "missing hint falls back" "$UI" 'argument-hint: "<task description>"'
assert_contains "embedded quotes are escaped" "$(<"$OUT/sb-fast.md")" 'description: "Quick fix \"now\""'
DEVOPS="$(<"$OUT/sb-devops.md")"
assert_contains "strip-folded description read" "$DEVOPS" 'description: "Infra work"'
assert_contains "literal block hint read" "$DEVOPS" 'argument-hint: "<infra task>"'
ORIENT="$(<"$OUT/sb-orient.md")"
assert_contains "missing name falls back to the directory" "$ORIENT" 'name: "sb-orient"'
assert_contains "frontmatter parses as YAML" "$(python3 - "$OUT" <<'PY'
import json, re, sys
from pathlib import Path
bad = []
for p in sorted(Path(sys.argv[1]).glob("sb*.md")):
    lines = p.read_text().split("\n")
    if lines[0] != "---":
        continue
    for line in lines[1:lines.index("---", 1)]:
        key, _, value = line.partition(": ")
        try:
            json.loads(value)
        except ValueError:
            bad.append(f"{p.name}:{key}")
print("bad=" + ",".join(bad))
PY
)" "bad="

EXTRA="$(<"$OUT/extra.md")"
assert_contains "retained route gets frontmatter" "$EXTRA" 'name: "extra"'
assert_contains "retained route gets description" "$EXTRA" 'description: "Silver Bullet extra workflow"'
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

# --check: fresh stubs pass without writing anything
tl_run bash "$ROOT/scripts/generate-plugin-commands.sh" --check
assert_eq "--check passes on fresh stubs" 0 "$TL_STATUS"
assert_contains "--check reports fresh" "$TL_OUT" "Command stubs fresh"
assert_eq "--check writes nothing" "$BEFORE" "$(cd "$OUT" && sha256sum -- *.md)"

# --check: a stale stub, a stub the generator would delete, and a missing stub all drift
printf 'stale\n' >>"$OUT/sb-feature.md"
echo old >"$OUT/silver-feature.md"
rm -f "$OUT/sb-ui.md"
tl_run bash "$ROOT/scripts/generate-plugin-commands.sh" --check
assert_eq "--check fails on drift" 1 "$TL_STATUS"
assert_contains "stale stub named" "$TL_ERR" "DRIFT: plugins/silver-bullet/commands/sb-feature.md"
assert_contains "stub the generator removes named" "$TL_ERR" "DRIFT: plugins/silver-bullet/commands/silver-feature.md"
assert_contains "missing stub named" "$TL_ERR" "DRIFT: plugins/silver-bullet/commands/sb-ui.md"
assert_contains "--check tells how to fix" "$TL_ERR" "run: bash scripts/generate-plugin-commands.sh"
assert_file_exists "--check never repairs" "$OUT/silver-feature.md"
assert_file_absent "--check never regenerates" "$OUT/sb-ui.md"

tl_run bash "$ROOT/scripts/generate-plugin-commands.sh" --bogus
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "usage printed" "$TL_ERR" "Usage: generate-plugin-commands.sh [--check]"

# R10b-19: against the real skills/ and the committed stubs the generator is
# a no-op (byte-identical), so the committed stubs are its exact output.
REAL="$TL_TMP/real"
mkdir -p "$REAL/scripts" "$REAL/plugins/silver-bullet"
cp "$TL_REPO_ROOT/scripts/generate-plugin-commands.sh" "$REAL/scripts/"
cp -R "$TL_REPO_ROOT/skills" "$REAL/skills"
cp -R "$TL_REPO_ROOT/plugins/silver-bullet/commands" "$REAL/plugins/silver-bullet/commands"
tl_run bash "$REAL/scripts/generate-plugin-commands.sh"
assert_eq "real generator run exits 0" 0 "$TL_STATUS"
tl_run diff -r "$TL_REPO_ROOT/plugins/silver-bullet/commands" "$REAL/plugins/silver-bullet/commands"
assert_eq "committed stubs are byte-identical to a fresh generation" 0 "$TL_STATUS"
tl_run bash "$TL_REPO_ROOT/scripts/generate-plugin-commands.sh" --check
assert_eq "--check passes on the committed stubs" 0 "$TL_STATUS"

tl_results
