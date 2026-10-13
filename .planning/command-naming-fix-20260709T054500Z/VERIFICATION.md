# SB command naming fix — verification evidence (2026-07-09)

## Root causes

- **Cursor:** Plugin command stubs used bare filenames (`init.md`) while cursor-agent TUI derives slash routes from the **filename stem**, producing `/silver-init` instead of `/silver:init`.
- **Codex:** Native `~/.codex/skills/` mirror used hyphen directory names (`silver-feature/`) while Codex TUI derives picker routes from **directory names**, showing bare `feature` without the `silver:` prefix (frontmatter `name:` alone is insufficient).

## Fix summary

1. Renamed all `plugins/silver-bullet/commands/*.md` stubs to match `name:` (`silver:init.md`, etc.).
2. Updated `generate-plugin-commands.sh` to emit colon-route filenames.
3. Updated `skill-mirror.sh` to mirror native Codex skills into `silver:<route>/` directories.
4. Extended `validate-host-skill-surface.sh` + `tests/scripts/test-host-command-naming.sh`.

## Installed surface checks (post `install-cursor.sh` + `install-codex.sh`)

| Check | Path | Result |
|-------|------|--------|
| Cursor command stub | `~/.cursor/plugins/cache/alo-labs/silver-bullet/current/commands/silver:init.md` | OK |
| Cursor picker dedupe | `bash scripts/diagnose-cursor-picker-duplicates.sh` | OK |
| Codex native mirror | `~/.codex/skills/silver:feature/SKILL.md` (`name: "silver:feature"`) | OK |
| Codex plugin commands | `~/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/commands/silver:init.md` | OK |

## Tests

- `bash tests/scripts/test-host-command-naming.sh` — PASS
- `bash tests/scripts/test-validate-host-skill-surface.sh` — PASS
- `bash tests/scripts/test-install-cursor.sh` — PASS (39)
- `bash tests/scripts/test-sync-codex-package.sh` — PASS (98)
- `bash tests/scripts/test-render-agent-bundle-freshness.sh` — PASS (330)

## User steps

Optional: restart cursor-agent / codex TUI session to pick up refreshed plugin caches. No Cursor desktop reload required.
