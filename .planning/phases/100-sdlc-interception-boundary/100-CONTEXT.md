# Phase 100: SDLC Interception Boundary - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Define when Silver Bullet must intercept user input as SDLC intent and route it into SB/GSD orchestration instead of allowing ad hoc or direct handling. This phase locks the user-intent boundary, host-boundary cues, and direct-answer exceptions that determine whether SB intervenes.

</domain>

<decisions>
## Implementation Decisions

### What gets intercepted
- **B-01:** Broadly intercept any message that is SDLC-relevant by intent or context, including code, docs, workflows, hooks, planning, milestones, release state, and other owned SDLC artifacts.
- **B-02:** Intercept context-sensitive messages tied to an active SDLC thread even if they do not explicitly name the work.
- **B-03:** Treat pasted or attached artifacts as interception signals when they imply SDLC work.
- **B-04:** Use host-boundary signals such as selection context, pasted snippets, screenshots, and other available input cues when they clearly imply SDLC work.

### What stays direct
- **B-05:** Keep pure Q&A, trivial acknowledgements, and explicitly non-SDLC requests direct.
- **B-06:** Fuzzy SDLC intent stays direct until the user makes the action explicit enough to route.
- **B-07:** Status-only questions about active SDLC work are answered from SB's orchestrated source of truth instead of bypassing orchestration.

### Mixed intent handling
- **B-08:** When a message contains both action intent and a question, SB handles the action branch while the question branch is passed through to the relevant skill or agent.
- **B-09:** When a message introduces new action intent during an active workflow, SB asks the user how to route it at the next natural pause rather than silently choosing nest/defer/switch.
- **B-10:** The user preference prompt uses A/B/C options and does not interrupt mid-step unless delay would risk losing intent.

### Routing behavior
- **B-11:** SB should preserve the SDLC chain by nesting related work or deferring side work instead of letting the session drift into ad hoc execution.
- **B-12:** SB should keep track of multi-intent requests so user intent is not dropped, even when some branches are deferred.

### the agent's Discretion
- Exact wording of the interception banner and the host-specific hook implementation details.
- The specific internal bookkeeping structure used to track nested and deferred branches.

</decisions>

<specifics>
## Specific Ideas

- "The action part will always be handled by SB while question part passed through to the coding agent or any other skill it is directed to."
- "SB will manage the work in a way so that the SDLC doesn't get compromised and SB doesn't lose track either. Nesting where necessary, deferring where necessary."
- "SB will ask user for preference" when a new routing decision is needed.
- Broad interception should include selection context and pasted/artifact signals, not just typed text.

</specifics>

<canonical_refs>
## Canonical References

### Routing and interception
- `repo/silver-bullet.md` §2g-2h — current bare instruction interception and workflow composition rules
- `repo/skills/silver/SKILL.md` — router intent classification, direct-answer exceptions, and workflow routing behavior
- `repo/docs/composable-flows-contracts.md` — atomic flow contract and composition rules

### Clarify handoff
- `repo/skills/silver-clarify/SKILL.md` — clarify front-end behavior and GSD handoff
- `repo/.planning/CLARIFY.md` — v0.37.0 brief and orchestration vision for the milestone

### Milestone framing
- `repo/.planning/PROJECT.md` — active milestone scope and vision
- `repo/.planning/REQUIREMENTS.md` — ORCH-01 and ORCH-02 requirements
- `repo/.planning/ROADMAP.md` — Phase 100 goal and boundary
- `repo/.planning/STATE.md` — current milestone planning state

</canonical_refs>

<deferred>
## Deferred Ideas

- Host-specific interception hook implementation details for Claude and Codex.
- Codex helper-skill payload parity and plugin discoverability for Product Management and Engineering.
- Long-running context retention and intent-tracking machinery.
- Completion verification and redispatch behavior.
- AUI presentation and master-loop autonomy mechanics.

</deferred>

---

*Phase: 100-sdlc-interception-boundary*
*Context gathered: 2026-05-19*
