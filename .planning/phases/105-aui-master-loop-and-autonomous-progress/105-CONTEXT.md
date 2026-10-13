# Phase 105: AUI, Master Loop, And Autonomous Progress - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Give Silver Bullet a natural AUI that hides GSD mechanics, keeps SB as the master agentic loop over the SE and coding agents, and maximizes autonomous progress by front-loading user input and only stopping for crucial decisions or hard safety boundaries.

</domain>

<decisions>
## Implementation Decisions

### Session start and AUI
- **A-01:** SB shows an autonomous-mode choice at session start before any SDLC orchestration begins.
- **A-02:** The autonomous prompt includes a reminder of what autonomous mode changes plus the crucial decision types SB will still escalate.
- **A-03:** The AUI shows a high-level journey map and a compact behind-the-scenes progress/status panel.

### Master loop behavior
- **A-04:** SB remains the master agentic loop and monitors both the SE agent and the coding agent.
- **A-05:** SB intervenes when necessary and keeps work moving when one agent returns but the next step is still unattended.

### Autonomous posture
- **A-06:** SB advances aggressively when it can, continuing through the workflow until a hard stop or user decision boundary is reached.
- **A-07:** SB only interrupts for crucial decisions or unsafe actions.
- **A-08:** SB front-loads user information capture so autonomous work can proceed with minimal later interruption.

### the agent's Discretion
- Exact visual style of the journey map and status panel.
- The internal prioritization policy for choosing which unattended next step to advance first when multiple are available.

</decisions>

<specifics>
## Specific Ideas

- The session-start autonomous prompt should be unavoidable at the beginning of SDLC orchestration.
- Autonomous mode is a per-session choice, not an invisible default.
- The user should see the high-level SDLC journey, but not GSD command plumbing.

</specifics>

<canonical_refs>
## Canonical References

### Planning artifacts
- `repo/.planning/PROJECT.md` — AUI, master-loop, and autonomy goals
- `repo/.planning/REQUIREMENTS.md` — ORCH-10, ORCH-11, ORCH-12
- `repo/.planning/ROADMAP.md` — Phase 105 goal and boundary
- `repo/.planning/STATE.md` — milestone status and current position

### Upstream context
- `repo/.planning/phases/104-completion-verification-and-redispatch/104-CONTEXT.md` — verification behavior that informs autonomous follow-through
- `repo/.planning/phases/103-long-running-context-and-intent-retention/103-CONTEXT.md` — intent ledger state that autonomy should preserve

</canonical_refs>

<deferred>
## Deferred Ideas

- Host-level interception mechanics.
- Helper-skill discoverability and plugin parity.

</deferred>

---

*Phase: 105-aui-master-loop-and-autonomous-progress*
*Context gathered: 2026-05-19*
