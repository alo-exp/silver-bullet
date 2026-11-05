#!/usr/bin/env bash
# scripts/validate-plugin-mirror.sh against a regenerated copy of the generator
# inputs and outputs (never the checkout): a fresh regeneration passes, and
# every seeded kind of drift fails with the drifting path named (R8-03).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

FX="$TL_TMP/fx"
PKG="$FX/plugins/silver-bullet"
mkdir -p "$FX/plugins"
rsync -a --exclude='__pycache__/' --exclude='*.render.lock' \
  "$TL_REPO_ROOT/skills" "$TL_REPO_ROOT/templates" "$TL_REPO_ROOT/scripts" "$TL_REPO_ROOT/hooks" \
  "$TL_REPO_ROOT/agents" "$TL_REPO_ROOT/host-bundles" "$TL_REPO_ROOT/package.json" \
  "$TL_REPO_ROOT/.cursor-plugin" "$FX/"
rsync -a "$TL_REPO_ROOT/plugins/silver-bullet" "$FX/plugins/"
for f in AGENTS.md CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md LICENSE README.md SECURITY.md .silver-bullet.json; do
  : >"$FX/$f"
done
mkdir -p "$FX/docs"
# Clean by construction, whatever state the checkout's mirrors are in.
bash "$FX/scripts/sync-codex-package.sh" >/dev/null 2>&1
run() { tl_run bash "$FX/scripts/validate-plugin-mirror.sh"; }

run
assert_eq "fresh regeneration passes" 0 "$TL_STATUS"
assert_contains "OK message" "$TL_OUT" "Plugin mirror OK"

# --- every drift class at once, each named ------------------------------------
REF="$FX/skills/silver-init/references/scaffold-steps.md"
cp "$REF" "$TL_TMP/ref.bak"
printf '\nseeded drift\n' >>"$REF"                               # source edited, mirrors not regenerated
mkdir -p "$FX/agents/claude/sb:stale-route"
printf -- '---\nname: sb:stale-route\n---\n' >"$FX/agents/claude/sb:stale-route/SKILL.md"   # stray skill
printf 'stale\n' >>"$PKG/commands/sb-feature.md"                # hand-edited stub
printf 'stale\n' >>"$PKG/templates/silver-bullet.md.base"       # hand-edited template mirror
printf ' ' >>"$FX/hooks/cursor-hooks.json"                       # hand-edited generated hooks
rm "$PKG/hooks" && cp -R "$FX/hooks" "$PKG/hooks"               # link replaced by a stale copy
mkdir -p "$PKG/skills/x"                                          # entry the sync would prune
touch "$FX/skills/silver-feature/bad:name.md"                    # Windows-unsafe generated path
ln -s /etc/hostname "$FX/agents/claude/sb:init/evil-link"        # symlink smuggled into a generated tree
printf -- '---\nname: "sb-bogus"\n---\n\nx\n' >"$PKG/commands/sb-bogus.md"   # orphan stub: no composer produces it
run
assert_eq "drift fails" 1 "$TL_STATUS"
for drifted in \
  "agents/claude/sb:init/references/scaffold-steps.md" \
  "host-bundles/codex/sb-init/references/scaffold-steps.md" \
  "plugins/silver-bullet/skill-source/sb-init/references/scaffold-steps.md" \
  "plugins/silver-bullet/cursor-skill-source/sb-init/references/scaffold-steps.md" \
  "agents/claude/sb:stale-route/SKILL.md" \
  "plugins/silver-bullet/commands/sb-feature.md" \
  "plugins/silver-bullet/templates/silver-bullet.md.base" \
  "hooks/cursor-hooks.json" \
  "plugins/silver-bullet/hooks must be a symlink to ../../hooks" \
  "plugins/silver-bullet/skills (the sync would remove or create it)" \
  "agents/claude/sb:init/evil-link" \
  "plugins/silver-bullet/commands/sb-bogus.md" \
  "host-bundles/codex/sb-feature/bad:name.md"; do
  assert_contains "drift named: $drifted" "$TL_OUT" "DRIFT: $drifted"
done
assert_contains "Windows-unsafe path flagged" "$TL_OUT" "plugins/silver-bullet/skill-source/sb-feature/bad:name.md (Windows-unsafe path)"
assert_not_contains "colon route directories are the documented exception" "$TL_OUT" "agents/claude/sb:init/SKILL.md (Windows-unsafe"
assert_contains "error annotation names the fix" "$TL_OUT" "::error::Plugin mirror drift detected"
assert_contains "error annotation tells how to fix" "$TL_OUT" "run: bash scripts/sync-codex-package.sh"

# restore
cp "$TL_TMP/ref.bak" "$REF"
rm -rf "$FX/agents/claude/sb:stale-route" "$PKG/skills" "$PKG/hooks" "$FX/skills/silver-feature/bad:name.md" "$FX/agents/claude/sb:init/evil-link" "$PKG/commands/sb-bogus.md"
ln -s ../../hooks "$PKG/hooks"
bash "$FX/scripts/sync-codex-package.sh" >/dev/null 2>&1
run
assert_eq "restored fixture passes again" 0 "$TL_STATUS"

# --- a large drift is capped in the report ------------------------------------
mv "$FX/host-bundles/codex" "$TL_TMP/codex.bak"
run
assert_eq "missing bundle fails" 1 "$TL_STATUS"
assert_match "long reports are capped" '\.\.\. and [0-9]+ more' "$TL_OUT"
mv "$TL_TMP/codex.bak" "$FX/host-bundles/codex"

# --- a regeneration that fails is reported, not passed --------------------------
mkdir -p "$FX/skills/sb-feature"
printf -- '---\nname: sb-feature\n---\n' >"$FX/skills/sb-feature/SKILL.md"
run
assert_eq "failed regeneration fails the check" 1 "$TL_STATUS"
assert_contains "renderer error shown" "$TL_OUT" "skill rename collision: silver-feature -> sb-feature"
assert_contains "regeneration failure annotated" "$TL_OUT" "could not regenerate the package"
rm -rf "$FX/skills/sb-feature"

tl_results
