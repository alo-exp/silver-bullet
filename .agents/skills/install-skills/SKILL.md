---
name: install-skills
description: >
  Sub-skill of TopGun. Installs a secured skill via /plugin install with
  local-copy fallback. Not normally invoked directly. The topgun orchestrator
  dispatches this via the topgun-installer agent.
---

# InstallSkills

InstallSkills is the installation sub-skill of TopGun. It is dispatched by the TopGun orchestrator via the `topgun-installer` agent after the user has approved installation in the approval gate (Step 6 of the orchestrator).

It is not normally invoked directly by the user.

## What It Does

1. Reads the secured skill path and metadata from TopGun state.
2. Attempts `/plugin install` as the primary installation method.
3. Runs post-install verification (installed_plugins.json check + test invocation).
4. Falls back to local-copy install (`~/.codex/skills/{skill_name}/`) if the plugin install fails or verification fails.
5. Updates `~/.topgun/installed.json` with the install record.
6. Returns a completion or error marker.

## Completion Markers

### `## INSTALL COMPLETE`

Returned when the skill was successfully installed (via either plugin or local-copy) and the registry was updated. The orchestrator reads this marker to proceed to Step 8 (audit trail header).

### `## INSTALL FAILED — FALLBACK NEEDED`

Returned by the installer when the primary `/plugin install` path fails and the local-copy fallback has not yet been attempted. This is an internal signal — the agent immediately proceeds to the local-copy fallback step rather than stopping.

If both the plugin install and the local-copy fallback fail, the agent outputs a clear error with the secured path for manual recovery and does NOT output `## INSTALL COMPLETE`.
