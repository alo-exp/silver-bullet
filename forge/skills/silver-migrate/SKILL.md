---
name: silver-migrate
description: Migrate a Silver Bullet project from older SB conventions or from Claude Desktop SB to Forge SB — reconciles paths, removes hook-only artifacts, and generates Forge-equivalent setup.
---

# Silver Migrate — Forge Edition

Migrates a project that was using Silver Bullet on Claude Desktop (with hooks + plugins) to the Forge equivalent setup.

## When to Use

- The user moved a project from Claude Desktop to Forge and wants to update the SB scaffolding
- An older Forge project needs to be brought up to current SB conventions

## Procedure

### Step 1 — Detect Migration Source

Look for indicators of Claude Desktop SB:

```bash
test -f silver-bullet.md && echo "Claude Desktop SB detected (silver-bullet.md present)"
test -f .silver-bullet.json && echo "SB config detected"
test -d .planning && echo ".planning/ scaffold exists"
```

Look for indicators of an older Forge SB:

```bash
test -f AGENTS.md && grep -q "Silver Bullet" AGENTS.md && echo "Older Forge SB detected"
```

If neither, ask the user what they're migrating from.

### Step 2 — Inventory Existing Artifacts

Capture the project state:

- `.planning/STATE.md` — current phase, milestone, version
- `.planning/PROJECT.md` — project context
- `.planning/ROADMAP.md` — phases
- `silver-bullet.md` (Claude Desktop only) — enforcement instructions
- `.silver-bullet.json` (Claude Desktop only) — config
- `.claude/skills/` (Claude Desktop only) — project skills
- `.claude/settings.json` (Claude Desktop only) — hook registration

### Step 3 — Move Content That Translates

For each artifact:

| Claude Desktop SB | Forge SB equivalent |
|---|---|
| `silver-bullet.md` | Migrate enforcement guidance into `AGENTS.md` |
| `.silver-bullet.json` (required-skill lists, paths) | Inline equivalent into `AGENTS.md` as prose |
| `.claude/skills/*/SKILL.md` (project skills) | Move to `.forge/skills/*/SKILL.md` |
| `.claude/settings.json` hook registration | Replaced by hook-equivalent custom agents at `~/forge/agents/`; AGENTS.md drives invocation |
| `.planning/*` | Unchanged — moves over as-is |

### Step 4 — Remove Claude-Only Artifacts

After translating, remove artifacts that have no Forge equivalent:

```bash
# After confirming with the user:
rm -rf .claude/settings.json   # hook registration not used in Forge
# Optionally keep .claude/ if user dual-runs Claude Desktop and Forge
```

If the user dual-runs both, leave `.claude/` intact and just add the Forge-side files.

### Step 5 — Generate AGENTS.md

If `AGENTS.md` does not exist (or only has minimal content), use the global template at `~/forge/silver-bullet/templates/AGENTS.md.template` (or fetch from `https://raw.githubusercontent.com/alo-exp/silver-bullet/main/templates/AGENTS.md.template`).

Customize for the migrated project — fold in any project-specific conventions captured from `silver-bullet.md` or CLAUDE.md.

### Step 6 — Verify Global Skill+Agent Set

Confirm the Forge global skill+agent set is installed:

```bash
test -d "$HOME/forge/skills" && find "$HOME/forge/skills" -name SKILL.md | wc -l
test -d "$HOME/forge/agents" && find "$HOME/forge/agents" -name "*.md" | wc -l
```

If absent or stale, instruct the user to install:

```bash
curl -fsSL https://raw.githubusercontent.com/alo-exp/silver-bullet/main/forge-sb-install.sh | bash
```

### Step 7 — Confirm

Report what was migrated, what was removed, and what manual edits the user should make to `AGENTS.md` (typically: project conventions, language/framework specifics, project-specific routing).

## Notes

- Forge has no hooks — automatic enforcement is replaced by hook-equivalent custom agents the main agent invokes at gating moments. The migration removes hook registration but the gating logic is preserved (and improved) via these agents.
- Forge custom agents replace Claude Code subagents — same delegation semantics, configured per `forgecode.dev/docs/creating-agents/`.
- `.planning/` artifacts (PROJECT.md, ROADMAP.md, STATE.md, etc.) carry over without modification — they are runtime-agnostic.
