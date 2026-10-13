# Phase 102: SB-Owned Milestone Bootstrap - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Silver Bullet itself perform the handoff from clarification into `gsd:new-milestone` when milestone creation is the right next step, using the clarified brief as the source input so the user does not need to restart the process manually.

</domain>

<decisions>
## Implementation Decisions

### Milestone bootstrap handoff
- **M-01:** When `silver:clarify` determines that milestone creation is the next step, SB should hand off into `gsd:new-milestone` automatically instead of asking the user to re-enter the same intent.
- **M-02:** The handoff payload should be a full clarify brief translated into GSD-ready milestone input, not just a terse summary.
- **M-03:** The handoff should also include an SB-generated rough phase breakdown so GSD starts from a stronger scaffold.
- **M-04:** Any ideas that are clearly out of scope for the current milestone should be called out explicitly as deferred ideas during the handoff.

### Handoff content
- **M-05:** The handoff should preserve the key decisions and open questions from clarify so GSD can seed milestone requirements from the actual conversation.
- **M-06:** The handoff should carry forward the merged clarify framing, including any PM framing that was visible in the clarify output when applicable.

### the agent's Discretion
- Exact markdown or structured format used for the GSD-ready milestone bootstrap note.
- How the clarify-to-milestone translation maps open questions into requirement prompts versus deferred ideas.

</decisions>

<specifics>
## Specific Ideas

- The handoff should be "full brief plus SB-translated milestone bootstrap note."
- The bootstrap note should help GSD start requirements work immediately.
- Deferred ideas should not silently disappear during milestone creation.

</specifics>

<canonical_refs>
## Canonical References

### Milestone start workflow
- `repo/.agents/skills/gsd-new-milestone/SKILL.md` — milestone-start contract and required outputs
- `repo/.Codex/get-shit-done/workflows/new-milestone.md` — workflow steps, confirmation gate, and artifact updates

### Clarify source
- `repo/skills/silver-clarify/SKILL.md` — clarify brief production and GSD handoff
- `repo/.planning/phases/101-clarify-composition-stack/101-CONTEXT.md` — merged clarify behavior and output shape

### Milestone framing
- `repo/.planning/PROJECT.md` — current milestone goals and orchestration scope
- `repo/.planning/REQUIREMENTS.md` — ORCH-06, ORCH-12
- `repo/.planning/ROADMAP.md` — Phase 102 goal and boundaries

</canonical_refs>

<deferred>
## Deferred Ideas

- Host-level interception mechanics.
- Long-running context retention and completion verification.
- AUI and master-loop autonomy mechanics.

</deferred>

---

*Phase: 102-sb-owned-milestone-bootstrap*
*Context gathered: 2026-05-19*
