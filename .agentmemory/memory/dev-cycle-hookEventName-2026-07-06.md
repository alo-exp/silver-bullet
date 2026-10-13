# dev-cycle-check hookEventName fix — 2026-07-06

**Commit:** 864e242bcd753fa655ed8e090934ae4ba3693f56  
**Branch:** main (pushed origin)

## Decision / fix

Claude PreToolUse requires `hookSpecificOutput.hookEventName` in advisory JSON. `hooks/dev-cycle-check.sh` now centralizes advisories in `emit_advisory()` using `jq` with `$hook_event`, and jq-missing / error fallbacks set explicit event names.

## Verification

- `bash tests/hooks/test-dev-cycle-check.sh` — 118 passed, 0 failed
- `bash tests/scripts/test-agent-claude-skill.sh` — 52 passed, 0 failed
- `bash -n hooks/dev-cycle-check.sh` (and hooks/scripts sweep) — OK

## Files

- hooks/dev-cycle-check.sh
