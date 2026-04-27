---
name: silver-update
description: Update the installed Silver Bullet for Forge skill+agent set to the latest release. Re-runs the installer and verifies skill/agent files are refreshed.
---

# Silver Update — Forge Edition

Updates the locally installed Silver Bullet skills and custom agents to the latest version published in the `alo-exp/silver-bullet` repo.

## When to Use

Use this skill when:

- A new SB version was released (check `https://github.com/alo-exp/silver-bullet/releases/latest`)
- Skills or custom agents in `~/forge/skills/` or `~/forge/agents/` are out of date
- The user runs `silver:update` or asks "update silver bullet"

## Procedure

### Step 1 — Detect Current Version

Read the bundled `VERSION` file under the global skill set if present:

```bash
cat "$HOME/forge/silver-bullet/VERSION" 2>/dev/null || echo "unknown"
```

Compare to the latest GitHub release:

```bash
curl -s https://api.github.com/repos/alo-exp/silver-bullet/releases/latest \
  | grep '"tag_name"' \
  | sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/'
```

If installed ≥ latest: report "Already up to date" and exit.

### Step 2 — Confirm With User

Report the version delta and ask the user: "Silver Bullet for Forge {installed} is outdated (latest: {latest}). Update now? (y/n)"

If `n`: exit silently.

### Step 3 — Run the Installer

Execute the install script — it is idempotent and overwrites existing skill/agent files with the latest content:

```bash
curl -fsSL https://raw.githubusercontent.com/alo-exp/silver-bullet/main/forge-sb-install.sh | bash
```

Or, if the user has the repo checked out locally:

```bash
bash <repo-root>/forge-sb-install.sh
```

### Step 4 — Verify Refresh

Confirm files were updated by checking counts:

```bash
test -d "$HOME/forge/skills" && find "$HOME/forge/skills" -name SKILL.md | wc -l
test -d "$HOME/forge/agents" && find "$HOME/forge/agents" -name "*.md" | wc -l
```

Expected: ≥100 skills, ≥30 custom agents.

### Step 5 — Reload

Tell the user that Forge will pick up the updated skills/agents at the start of the next session — no restart required mid-session if they want to use the new versions, but a fresh `:new` conversation guarantees a clean reload.

### Step 6 — Confirm

Report: "✓ Silver Bullet for Forge updated to v{latest}. Run `:skill` to verify the skill list."

## Notes

- Forge has no plugin registry — `forge-sb-install.sh` is the canonical install/update mechanism.
- The installer copies SB skills, ported Superpowers skills, Anthropic knowledge-work skills, hook-equivalent custom agents, and GSD subagent custom agents in one pass.
- If the user is on a custom branch or fork, point them at the appropriate `forge-sb-install.sh`.
