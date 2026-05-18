# Phase 101: Clarify Composition Stack - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn `silver:clarify` into the stand-alone clarification front-end that merges Product Management brainstorming and Superpowers brainstorming into one non-redundant workflow, so SB can resolve all gray areas before handing a decision-ready brief to `gsd:discuss-phase`.

</domain>

<decisions>
## Implementation Decisions

### Clarify composition
- **C-01:** `silver:clarify` becomes the merged, stand-alone version of Product Management brainstorming and Superpowers brainstorming rather than exposing those skills as separate user-facing steps.
- **C-02:** Product Management-style framing runs first inside the merged clarify flow, followed by Superpowers-style brainstorming/pressure-testing behavior.
- **C-03:** The merged clarify flow absorbs both skill sets non-redundantly, so overlapping questions and prompts are not repeated.

### Gray-area resolution
- **C-04:** `silver:clarify` resolves all gray areas, major and minor, before handing off, so little or no uncertainty remains for `gsd:discuss-phase`.
- **C-05:** One question is asked at a time, sequentially, rather than batching multiple unrelated clarifications.
- **C-06:** The goal of clarify is to eliminate as much later-stage clarification as possible, especially anything that would otherwise be deferred to GSD discussion.

### Autonomous mode
- **C-07:** Autonomous mode is a per-session opt-in set at session start by asking the user.
- **C-08:** In autonomous mode, SB makes the best decision on the user's behalf whenever it is safe to do so.
- **C-09:** SB must ask the user when the decision is crucial or unsafe, including scope changes, cost changes, timeline changes, external commitments, security-sensitive actions, and irreversible actions.

### External artifacts
- **C-10:** `silver:ingest` runs first only when multiple complex remote artifacts need to be ingested; otherwise `silver:clarify` handles the intake path itself.

### Output shape
- **C-11:** `silver:clarify` writes a single consolidated brief rather than separate PM and Superpowers outputs.
- **C-12:** PM framing appears as a section only when the input has product/user-value implications.
- **C-13:** Section order may vary per input type, but PM framing must remain visible when applicable.
- **C-14:** Unresolved questions appear after the recommendation as follow-up notes, not before it.

### the agent's Discretion
- Exact wording of the merged clarify prompts and the final brief template.
- The internal mechanism for tracking how PM framing and Superpowers-style pressure testing are merged without redundancy.

</decisions>

<specifics>
## Specific Ideas

- `silver:clarify` should absorb both `product-management:product-brainstorming` and `superpowers:brainstorming` 100%.
- Product Management framing comes first in logical order, but it is not exposed as a separate skill.
- If remote artifacts need complex intake, `silver:ingest` precedes clarify.
- The merged clarify flow should leave very little gray area for `gsd:discuss-phase`.

</specifics>

<canonical_refs>
## Canonical References

### Clarify behavior
- `repo/skills/silver-clarify/SKILL.md` — current clarify front-end behavior and GSD handoff
- `repo/.planning/CLARIFY.md` — v0.37.0 handoff brief and orchestration vision

### Composition model
- `repo/skills/silver/SKILL.md` — router complexity triage and clarify routing
- `repo/docs/composable-flows-contracts.md` — CLARIFY and DECIDE flow contracts

### Milestone framing
- `repo/.planning/PROJECT.md` — active milestone scope and orchestration vision
- `repo/.planning/REQUIREMENTS.md` — ORCH-03, ORCH-04, ORCH-05, ORCH-12
- `repo/.planning/ROADMAP.md` — Phase 101 goal and boundaries
- `repo/.planning/phases/100-sdlc-interception-boundary/100-CONTEXT.md` — upstream interception assumptions that feed clarify

</canonical_refs>

<deferred>
## Deferred Ideas

- `gsd:discuss-phase` implementation details for how it consumes the brief.
- Host-level interception hook mechanics.
- Helper-skill discoverability and payload parity for Codex.
- Long-running context retention and completion verification.
- AUI/master-loop behavior and session-level autonomy UX.

</deferred>

---

*Phase: 101-clarify-composition-stack*
*Context gathered: 2026-05-19*
