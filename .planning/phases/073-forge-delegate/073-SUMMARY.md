# Phase 73 — `/forge-delegate` Skill (SUMMARY)

**Status:** Complete
**Requirements:** DELEG-01, DELEG-02, DELEG-03, DELEG-04

## Files

**Created:**
- `skills/forge-delegate/SKILL.md` (DELEG-01) — Claude-SB side skill. Verifies the parent owns the phase lock, builds a JSON envelope, spawns `forge -p <prompt>` with `SB_PHASE_LOCK_INHERITED=true` in env, timeout-bounded, parses `## FILES_CHANGED`/`## ASSUMPTIONS`/`## REQ-IDS` sections from the result, integrates into the parent phase's working SUMMARY.md.
- `forge/skills/forge-delegate/SKILL.md` (DELEG-02) — Forge side mirror. Same envelope shape, same `SB_PHASE_LOCK_INHERITED` contract, supports `--target=claude|codex|opencode|forge` for cross-runtime delegation.

**Modified:**
- `templates/silver-bullet.config.json.default` — added `multi_agent.delegation_timeout_seconds: 1200` (DELEG-04 default).

## Requirements satisfied

- **DELEG-01** — `skills/forge-delegate/SKILL.md` ships with envelope-building, `SB_PHASE_LOCK_INHERITED=true` spawning, structured-result parsing, and integration logic.
- **DELEG-02** — `forge/skills/forge-delegate/SKILL.md` mirrors DELEG-01, supports four target runtimes (claude, codex, opencode, forge).
- **DELEG-03** — both skills document the result contract (top-level markdown `## FILES_CHANGED`, `## ASSUMPTIONS`, `## REQ-IDS` sections) and parse it on return. Malformed result → display raw output for manual integration.
- **DELEG-04** — both skills wrap the spawn in `timeout ${TIMEOUT_SEC}`, default `1200` seconds (configurable via `multi_agent.delegation_timeout_seconds` in `.silver-bullet.json`). On `rc=124` (timeout): preserve partial output, parent lock untouched, user prompted for manual continuation.

## Key design decisions

1. **Envelope is runtime-agnostic.** Same JSON shape for Claude→Forge, Forge→Claude, Forge→Codex, etc. The receiving runtime's session-init logic detects `SB_PHASE_LOCK_INHERITED=true` and short-circuits its own claim machinery.

2. **Lock stays with the parent.** Even on timeout or child failure, the parent never releases its lock during delegation — the user can recover manually.

3. **Structured result contract is markdown, not JSON.** Easier for LLMs to produce reliably than JSON. The three required sections are top-level `##` headings; parser uses `awk` ranges.

4. **Pre-flight refuses to delegate without an owned lock.** `peek` confirms the parent holds the phase before spawning the child. If the parent doesn't own the lock, the skill exits with a clear error pointing the user at `phase-lock.sh claim`.

## Smoke test (manual)

The skill files are skill instructions, not directly executable. Integration test in Phase 74 (DELEG-03 round-trip) will:
1. Have Claude `/forge-delegate` with a fake-but-real envelope
2. Verify the spawned child runs with `SB_PHASE_LOCK_INHERITED=true` (no double-claim — checked via `peek` on the lock file)
3. Verify the structured result is parsed back and merged into the parent SUMMARY.md

## How DELEG-01..04 advance

Phase 74 will write the integration test. Phase 75 ships v0.29.0.

The full multi-agent coordination story is now in place:
- Phase 70: lock primitive + helper
- Phase 71: Claude-SB hook integration
- Phase 72: Forge-SB agent integration
- **Phase 73 (here): cross-runtime delegation as the controlled exception**
- Phase 74: integration tests + user docs
- Phase 75: release
