# Phase 72: Forge-SB Lock Awareness — Context

**Gathered:** 2026-04-28
**Source:** REQUIREMENTS.md (AGENT-01..AGENT-04) + Phase 70 helper + Phase 71 hook patterns

## Phase Boundary

Mirror Phase 71's Claude-side hook integration on the Forge runtime. Forge has no `PreToolUse`/`PostToolUse`/`Stop` hook surface — instead, the main Forge agent invokes custom agents at deterministic phase boundaries within the silver-* parent skills.

Out of scope:
- Claude-SB integration (Phase 71 ✅)
- `/forge-delegate` skill (Phase 73)
- Multi-agent integration tests (Phase 74)

## Implementation Decisions

### New Forge agents (3)
- `forge/agents/forge-claim-phase.md` — calls `phase-lock.sh claim <NNN> forge "<intent>"`. Honors `SB_PHASE_LOCK_INHERITED=true` (no-op + ALLOW) so a delegated subagent doesn't double-claim.
- `forge/agents/forge-heartbeat-phase.md` — calls `phase-lock.sh heartbeat <NNN> forge`. No throttle inside the agent (Forge-side caller decides cadence, typically once per task tick of the parent skill). Agent honors `SB_PHASE_LOCK_INHERITED=true`.
- `forge/agents/forge-release-phase.md` — calls `phase-lock.sh release <NNN> forge`. Honors `SB_PHASE_LOCK_INHERITED=true`.

Each agent has `tool_supported: true`, `temperature: 0.1`, `max_turns: 3`, restricted `tools: [shell]`. Output is structured: `CLAIMED|HEARTBEAT-OK|RELEASED|ALLOW (inherited)|BLOCKED: <owner-info>`.

### Updated Forge agent (1)
- `forge/agents/forge-session-init.md` — peek every active phase lock at session start (read `.planning/.phase-locks.json`); for any lock owned by a non-`forge` runtime, emit a warning line in the session-summary output. Non-blocking, hint to run `/phase-status` (or the helper's peek subcommand).

### Updated Forge silver-* skills (7)
Each parent skill that owns a phase scope invokes:
- `forge-claim-phase` at phase entry (immediately after `gsd-discuss-phase` or `gsd-plan-phase` resolves the phase).
- `forge-heartbeat-phase` at the start of any long-running step (gsd-execute-phase, gsd-verify-work).
- `forge-release-phase` at phase exit (after gsd-ship for the phase, or before handoff to the next phase).

Skills to update:
1. `forge/skills/silver-feature/SKILL.md`
2. `forge/skills/silver-bugfix/SKILL.md`
3. `forge/skills/silver-ui/SKILL.md`
4. `forge/skills/silver-devops/SKILL.md`
5. `forge/skills/silver-release/SKILL.md`
6. `forge/skills/silver-spec/SKILL.md`
7. `forge/skills/silver-fast/SKILL.md` (only if the fast path touches a phase dir; otherwise skip — confirm in implementation)

### `SB_PHASE_LOCK_INHERITED` semantics
All three new agents check this env var first. When set to `"true"`, the agent emits `ALLOW (inherited from parent runtime)` and exits without invoking the helper. This matches Phase 71 hook behavior and is what `/forge-delegate` (Phase 73) sets when spawning a sibling runtime.

### Helper invocation contract
Each agent calls `.planning/scripts/phase-lock.sh <op> <phase> forge [<intent>]` and surfaces:
- exit 0 → success
- exit 2 → conflict (claim path) or non-owner (heartbeat/release path) — agent emits `BLOCKED: ...` for claim, `WARN: ...` for heartbeat/release (non-blocking — Stop must never block)
- exit 1/3/4 → internal/unknown-runtime/usage error — agent emits `WARN: ...` and ALLOWs (fail-open per project invariant)

## Canonical References

- `.planning/scripts/phase-lock.sh` — Phase 70 helper
- `hooks/phase-lock-claim.sh` / `hooks/phase-lock-heartbeat.sh` / `hooks/phase-lock-release.sh` — Phase 71 Claude-side equivalents (semantic reference)
- `forge/agents/forge-pre-commit-audit.md` — existing agent template
- `forge/agents/forge-session-init.md` — existing init agent (will be extended with peek logic)
- `forge/skills/silver-feature/SKILL.md` etc. — parent skills to extend

## Specifics

- Forge agents are invoked by the main agent via the agent registry, not by hooks — the parent skill must include explicit `Skill(agent="forge-claim-phase", args="<phase>|<intent>")` calls at phase boundaries.
- No session-claim manifest is needed on the Forge side — the parent skill's instructions explicitly drive claim+release as a pair, so manifest-based release-on-stop isn't necessary. (Forge has no Stop event analogous to Claude's; the parent skill's `phase exit` step IS the release point.)
- Output format for the agents must be machine-parseable so the parent skill can branch on conflict.

## Deferred

- Per-skill granular cooperation (vs phase-grain) — superseded.
- `/phase-status` slash command — Phase 74 may add it.
- Forge equivalent of the informational completion-audit peek — out of scope (the existing forge-pre-commit-audit and forge-task-complete-check could optionally peek, but that is Phase 74 polish, not Phase 72 core).
