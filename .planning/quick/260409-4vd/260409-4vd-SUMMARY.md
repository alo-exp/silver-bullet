# Summary: 260409-4vd — First-install hooks hardening

**Status:** Complete
**Date:** 2026-04-09
**Commits:** 826c949, e6bac01, d9570d4

## What was done

1. Added `trap 'exit 0' ERR` to 8 hooks that used `set -euo pipefail` without an error
   trap, preventing first-install failures from causing Claude to reject the plugin.
2. Restored `"hooks": "./hooks/hooks.json"` to `.claude-plugin/plugin.json` for automatic
   marketplace hook registration.
3. Enhanced `silver:init` step 3.7.5 to merge SB hook entries into `~/.claude/settings.json`
   with idempotent path substitution.
4. Bumped version to v0.13.2 with CHANGELOG entry.

## Files modified

- `hooks/session-start`, `hooks/compliance-status.sh`, `hooks/session-log-init.sh`,
  `hooks/ensure-model-routing.sh`, `hooks/semantic-compress.sh`, `hooks/record-skill.sh`,
  `hooks/ci-status-check.sh`, `hooks/dev-cycle-check.sh` — ERR trap added
- `.claude-plugin/plugin.json` — hooks field restored, version bumped
- `skills/silver-init/SKILL.md` — step 3.7.5 added
- `CHANGELOG.md` — v0.13.2 entry
