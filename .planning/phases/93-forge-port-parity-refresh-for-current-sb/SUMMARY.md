# Phase 93 Summary — Forge Port Parity Refresh for Current SB

**Status:** Completed  
**Date:** 2026-05-13  
**Plan:** 93-01

## Goal

Update the Forge port of Silver Bullet skills, hook-equivalent agents, installer surfaces, templates, parity docs, and Forge tests so Forge reflects the current SB source version after the Codex-native and dynamic-flow updates.

## Completed

- Refreshed Forge SB-owned skills from the current source skill surface, adding `silver-ensure-docs`, `silver-handoff`, and the current `artifact-reviewer/rules/` content.
- Preserved and updated Forge-specific `silver-init` and `silver-update` behavior so they remain Forge-native.
- Added three hook-equivalent Forge agents:
  - `forge-dependency-skill-check`
  - `forge-instruction-file-guard`
  - `forge-workflow-chain-guard`
- Updated `~/forge/AGENTS.md` and project AGENTS templates for 16 hook-equivalent agents and the current SB/GSD routing model.
- Synced Forge templates with the source `templates/` tree, including governed-doc JSON, task checklist, archive, specs, and workflow templates.
- Expanded `forge-sb-install.sh` remote template fetching so remote installs receive the current template surface.
- Updated Forge parity docs, README counts, smoke tests, and todo-app Forge scenario coverage.
- Removed Forge skill references to Claude-only tool names (`AskUserQuestion`, `TodoWrite`, `NotebookEdit`) from the installed Forge skill surface.
- Regenerated the Codex package surface and confirmed package sync checks still pass.

## Inventory

- Forge skills: 109
- Forge agents: 50 total
- Hook-equivalent Forge agents: 16
- Forge commands: 50
- Forge template files: 18

## Verification

- `bash tests/smoke-test.sh` — 649 passed, 0 failed
- `bash tests/forge-test-app/run-forge-sb-tests.sh` — 62 passed, 0 failed
- Temp install + `bash forge/scripts/smoke-test.sh` — 47 passed, 0 failed
- `bash tests/integration/test-skill-integrity.sh` — 372 passed, 0 failed
- `bash tests/integration/test-skill-refs.sh` — 130 passed, 0 failed
- `bash tests/scripts/test-silver-router-flow-contracts.sh` — 76 passed, 0 failed
- `bash tests/scripts/test-sync-codex-package.sh` — 33 passed, 0 failed
- `bash tests/scripts/test-install-codex.sh` — 136 passed, 0 failed, 0 skipped
- `bash tests/run-all-tests.sh` — 2002 passed, 0 failed

## Notes

- Historical v0.31.0 inventory notes remain unchanged in milestone archives.
- The active v0.33.1 milestone cursor is ready to resume Phase 86.
