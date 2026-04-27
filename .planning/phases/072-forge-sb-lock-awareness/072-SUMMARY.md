# Phase 72 — Forge-SB Lock Awareness (SUMMARY)

**Status:** Complete
**Requirements:** AGENT-01, AGENT-02, AGENT-03, AGENT-04

## Files

**Created (3 new Forge agents):**
- `forge/agents/forge-claim-phase.md` — calls `phase-lock.sh claim <NNN> forge "<intent>"`. Honors `SB_PHASE_LOCK_INHERITED=true` (no-op + ALLOW). On conflict (rc=2), surfaces helper stderr verbatim and returns `BLOCKED:` so the parent skill stops.
- `forge/agents/forge-heartbeat-phase.md` — calls `phase-lock.sh heartbeat <NNN> forge`. Returns `HEARTBEAT-OK:` or `WARN:`. Cadence is driven by parent skill (no internal throttle — the helper itself is idempotent).
- `forge/agents/forge-release-phase.md` — calls `phase-lock.sh release <NNN> forge`. Returns `RELEASED:` or `WARN:` (release-on-non-owner is informational, never blocking).

All three: `tools: [shell]`, `tool_supported: true`, `temperature: 0.1`, `max_turns: 3`. Output is structured (single line, grep-able) so the parent skill can branch on conflict.

**Updated (1 existing agent):**
- `forge/agents/forge-session-init.md` — new step 3a peeks `.planning/.phase-locks.json` at session start and emits `OTHER-RUNTIME-LOCK:` lines for any non-`forge` lock. Surfaced in the session summary under `## Active phase locks (other runtimes)`. Non-blocking.

**Updated (6 silver-* parent skills):**
- `forge/skills/silver-feature/SKILL.md`
- `forge/skills/silver-bugfix/SKILL.md`
- `forge/skills/silver-ui/SKILL.md`
- `forge/skills/silver-devops/SKILL.md`
- `forge/skills/silver-release/SKILL.md`
- `forge/skills/silver-spec/SKILL.md`

Each gets a uniform `## Multi-Agent Phase Coordination` section that documents: invoke `forge-claim-phase` at phase entry, `forge-heartbeat-phase` during long-running steps (>5 min, every wave/pass), `forge-release-phase` at phase exit. Includes the `SB_PHASE_LOCK_INHERITED` delegation contract.

## Skipped

- `forge/skills/silver-fast/SKILL.md` — silver-fast is the trivial-task path that bypasses the workflow. Per CONTEXT.md, it doesn't usually touch phase directories. Skipping per the explicit guidance ("only if the fast path touches a phase dir; otherwise skip").

## Requirements satisfied

- **AGENT-01** — `forge-session-init.md` peeks active phase locks at session start and warns (non-blocking) when other-runtime locks are detected.
- **AGENT-02** — three new agents `forge-claim-phase`, `forge-heartbeat-phase`, `forge-release-phase` created with correct frontmatter (`tool_supported: true`, `tools: [shell]`, `max_turns: 3`).
- **AGENT-03** — six Forge silver-* parent skills updated with the Multi-Agent Phase Coordination section directing claim/heartbeat/release at phase boundaries.
- **AGENT-04** — all three new agents short-circuit on `SB_PHASE_LOCK_INHERITED=true`, returning `ALLOW (inherited)` without calling the helper. Same semantics as Phase 71 hooks. Parent skills' Multi-Agent section explicitly documents the delegation contract.

## Deviations

1. **silver-fast not updated.** CONTEXT.md explicitly authorized skipping if the fast path doesn't touch phase dirs. Verified silver-fast is the trivial-task router with no phase-scoped work.

2. **No internal heartbeat throttle.** Plan suggested optional internal throttling. Implementation defers cadence entirely to the parent skill (matches helper's idempotent nature; simpler agent body).

3. **Uniform "## Multi-Agent Phase Coordination" section vs per-flow surgical insertion.** The plan allowed either approach. Implementation chose the uniform documentation section — each parent skill now contains a single canonical block describing when to invoke the three agents. This is easier to maintain (one canonical text) and lets the agent reason about phase boundaries naturally rather than threading explicit calls into every flow node.

## Smoke test (manual)

In `/tmp/sb-smoke`:
```bash
SB_PHASE_LOCK_INHERITED=true bash forge/agents/forge-claim-phase.md  # not directly executable — agents are markdown; smoke verified via the agent's procedure block applied to the helper
bash .planning/scripts/phase-lock.sh peek 099  # confirms forge-equivalent runtime tag accepted by helper
```

The actual integration test is in Phase 74 (test-multi-agent-coexistence.sh) which simulates two-agent race for the same phase.

## How AGENT-01..04 advance

Phase 73 (`/forge-delegate`) builds on these agents — when the Claude-side `/forge-delegate` skill spawns a Forge subprocess, it sets `SB_PHASE_LOCK_INHERITED=true` in the child's environment. Forge's own silver-* skills, on next phase boundary, invoke `forge-claim-phase` which detects the env var and short-circuits to `ALLOW (inherited)` — preventing double-claim under the parent's existing lock.
