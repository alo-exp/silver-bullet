# Phase 71 — Claude-SB Lock Hooks (SUMMARY)

**Status:** Complete
**Plans:** 4/4 (071-01..04)
**Requirements:** HOOK-01, HOOK-02, HOOK-03, HOOK-04

## Files

**Created:**
- `hooks/lib/phase-path.sh` — path-resolver lib + `_phase_lock_peek_on_exit` EXIT-trap helper
- `hooks/phase-lock-claim.sh` — PreToolUse claim hook (Edit|Write|MultiEdit)
- `hooks/phase-lock-heartbeat.sh` — PostToolUse heartbeat hook (Edit|Write|MultiEdit|Bash) with 5-min throttle
- `hooks/phase-lock-release.sh` — Stop/SubagentStop release hook with manifest cleanup
- `tests/hooks/test-phase-lock-claim.sh` — 19 cases including conflict, sanitization, idempotency
- `tests/hooks/test-phase-lock-heartbeat.sh` — 10 cases including throttle behavior + non-owner
- `tests/hooks/test-phase-lock-release.sh` — 11 cases including non-owner cleanup safety

**Modified:**
- `hooks/hooks.json` — registered 4 new entries (PreToolUse, PostToolUse, Stop, SubagentStop)
- `hooks/completion-audit.sh` — sources phase-path.sh + registers EXIT trap for informational peek
- `hooks/stop-check.sh` — same informational peek wiring

## Commits

| Hash | Plan | Description |
|------|------|-------------|
| 402c2a8 | 071-01 | path resolver lib |
| 97deb64 | 071-02 | three hook scripts + hooks.json registration |
| 9125d97 | 071-03 | informational lock-owner peek in completion-audit + stop-check |
| (this) | 071-04 | three test files + phase summary |

## Requirements satisfied

- **HOOK-01** — PreToolUse hook on Edit/Write/MultiEdit claims via helper, exits 2 with stderr block-message on conflict naming current owner.
- **HOOK-02** — PostToolUse heartbeat hook iterates session manifest, throttled to once per 5 min per phase via mtime on `~/.claude/.silver-bullet/heartbeat-<NNN>`.
- **HOOK-03** — Stop/SubagentStop release hook walks session manifest, releases each phase via helper, deletes manifest. Continues clearing entries even when individual releases fail (non-owner).
- **HOOK-04** — `hooks/hooks.json` registers all three hooks; `completion-audit.sh` and `stop-check.sh` emit a non-blocking stderr WARN via EXIT-trap helper when the phase resolved from `$PWD` has no active lock or is owned by a non-claude runtime.

## Deviations

1. **Trap-suspend pattern around helper calls.** Plan 02 didn't anticipate that the parent shell's `trap 'exit 0' ERR` is inherited by `$(...)` subshells and fires on the helper's non-zero conflict exit. Implementation suspends the trap (`trap - ERR`) before each helper call and re-arms it after, so `helper_rc` is captured correctly. Caught and fixed during smoke test on the conflict path.

2. **Helper resolution walks up from `$PWD`.** Plan 03's spec used `$PWD/.planning/scripts/phase-lock.sh` directly, which only works at repo root. Implementation walks up the directory tree to locate the helper so the warning fires when developer has `cd`'d into a phase directory (the case where the multi-agent collision warning is most useful). Caught during smoke test.

3. **Function extracted into `phase-path.sh` (vs inlined).** Plan 03 made this optional. Implementation extracts the `_phase_lock_peek_on_exit` function into the shared lib so both `completion-audit.sh` and `stop-check.sh` source the same single source of truth.

## Test results

- `tests/hooks/test-phase-lock-claim.sh`: 19 passed, 0 failed
- `tests/hooks/test-phase-lock-heartbeat.sh`: 10 passed, 0 failed
- `tests/hooks/test-phase-lock-release.sh`: 11 passed, 0 failed
- `tests/hooks/test-completion-audit.sh`: 24/24 (no regressions from EXIT-trap addition)
- `tests/hooks/test-stop-check.sh`: 18/18 (same)
- `tests/hooks/test-dev-cycle-check.sh`: 45/45 (Pass 1 hotfix tests stable)

## Smoke test (manual)

`/tmp/sb-smoke` end-to-end verified:
- Claim under phase path → manifest+lock present
- Heartbeat fires once → throttle file created → second heartbeat throttled within 300 s
- Release deletes manifest, clears lock
- Conflict path: `forge` claims first → claude attempt blocked with rc=2 + stderr naming forge owner
- Informational peek from inside phase dir → WARN emitted on stderr, rc preserved

## How HOOK-01..HOOK-04 advance

Phase 72 (Forge-SB integration) will add custom Forge agents that call the same `phase-lock.sh` operations under `runtime=forge`. Phase 73 (`/forge-delegate`) sets `SB_PHASE_LOCK_INHERITED=true` when spawning a sibling runtime so the child doesn't double-claim under the parent's existing lock — the bypass path is already implemented and tested.
