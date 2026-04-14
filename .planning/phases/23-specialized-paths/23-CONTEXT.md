# Phase 23: Specialized Paths - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Auto-mode (decisions from design spec + Phase 21-22 prior context)

<domain>
## Phase Boundary

Implement the 6 context-triggered specialized paths: PATH 2 (EXPLORE), PATH 3 (IDEATE), PATH 4 (SPECIFY), PATH 6 (DESIGN CONTRACT), PATH 8 (UI QUALITY), PATH 15 (DESIGN HANDOFF). Each path activates only when its trigger condition is met. These paths are implemented by updating silver-* skill files that already have placeholder comments from Phase 22.

</domain>

<decisions>
## Implementation Decisions

### PATH 2: EXPLORE — Implementation Strategy
- **D-01:** PATH 2 replaces the existing `Step 1b: Fuzzy Scope Clarification` placeholder in silver-feature/SKILL.md. Converts from a flat step to a full path section with prerequisite check (PATH 1 completed), trigger condition (fuzzy intent OR complex work), steps, and exit condition.
- **D-02:** PATH 2 steps: gsd-explore (always), product-management:product-brainstorming (always), design:user-research (as-needed), product-management:synthesize-research (as-needed), product-management:competitive-brief (as-needed). All invoked via Skill tool.
- **D-03:** PATH 2 trigger detection: complexity triage already classifies "fuzzy" and "complex" — those classifications route to PATH 2. "Simple" skips it.

### PATH 3: IDEATE — Implementation Strategy
- **D-04:** PATH 3 replaces the existing `Step 1c: Brainstorm` and `Step 1d: MultAI Pre-Spec Review` placeholders. Becomes a full path section following PATH 2.
- **D-05:** PATH 3 steps: superpowers:brainstorming (always), engineering:architecture (as-needed — new service/cross-cutting/ADR-worthy), engineering:system-design (as-needed — new service boundary), design:design-system (as-needed — UI phase, new component type). MultAI pre-spec review remains as conditional sub-step within PATH 3.
- **D-06:** PATH 3 skip condition: skipped for simple/clear-scope work (same as current behavior).

### PATH 4: SPECIFY — Implementation Strategy
- **D-07:** PATH 4 replaces the existing `Step 2: Testing Strategy`, `Step 2.5: Writing Plans`, and `Step 2.7: Pre-Build Validation` placeholders. These are reordered per the path contract: silver-ingest → write-spec → silver-spec → silver-validate.
- **D-08:** PATH 4 skip condition: may be skipped ONLY when REQUIREMENTS.md already exists (from PATH 0). This aligns with the existing `silver-feature` behavior where milestone setup creates REQUIREMENTS.md.
- **D-09:** PATH 4 includes review cycles for SPEC.md, REQUIREMENTS.md, DESIGN.md (if exists), and INGESTION_MANIFEST.md (if ingest). Each uses artifact-reviewer → artifact-review-assessor → 2-pass pattern from Phase 21.
- **D-10:** Testing strategy (engineering:testing-strategy) and writing-plans (superpowers:writing-plans) move INTO PATH 5 (PLAN), not PATH 4. The design spec §5 places them in PATH 5. Phase 22's PATH 5 already includes them.

### PATH 6: DESIGN CONTRACT — Implementation Strategy
- **D-11:** PATH 6 is a NEW path section added to silver-feature/SKILL.md between PATH 5 (PLAN) and PATH 7 (EXECUTE). It only activates for UI phases.
- **D-12:** PATH 6 trigger detection: phase involves UI — detected by keywords in phase name/goal, UI file types in existing code, or DESIGN.md existence.
- **D-13:** PATH 6 steps: design:design-system (always in this path), design:ux-copy (as-needed), gsd-ui-phase (always in this path), design:accessibility-review (as-needed — WCAG 2.1 AA). Iterative — user can loop steps 1-4.
- **D-14:** PATH 6 also added to silver-ui/SKILL.md as a core step (always active there since silver-ui is inherently UI work).
- **D-15:** PATH 6 exit condition: UI-SPEC.md exists, user accepts design contract. Claude suggests when solid; user decides exit.

### PATH 8: UI QUALITY — Implementation Strategy
- **D-16:** PATH 8 is a NEW path section added to silver-feature/SKILL.md between PATH 7 (EXECUTE) and the review steps (future PATH 9). It only activates when PATH 6 was in the composition OR SUMMARY.md contains UI file types.
- **D-17:** PATH 8 steps: design:design-critique (always in this path), gsd-ui-review (always — 6-pillar audit), design:accessibility-review (always in this path).
- **D-18:** PATH 8 produces UI-REVIEW.md. Fixes route through gsd-execute-phase --gaps-only.
- **D-19:** PATH 8 also added to silver-ui/SKILL.md as a core step (always active there).

### PATH 15: DESIGN HANDOFF — Implementation Strategy
- **D-20:** PATH 15 is added to silver-release/SKILL.md (NOT silver-feature). Per design spec, it runs inside PATH 17 (RELEASE) only — between milestone audit and gap closure.
- **D-21:** PATH 15 trigger: milestone has UI phases AND in release flow. Detection: scan phase directories for UI-SPEC.md or UI-REVIEW.md existence.
- **D-22:** PATH 15 steps: design:design-handoff (always in this path), design:design-system (as-needed — final component inventory).

### Files Modified
- **D-23:** Primary files: `skills/silver-feature/SKILL.md` (PATHs 2, 3, 4, 6, 8), `skills/silver-ui/SKILL.md` (PATHs 6, 8), `skills/silver-release/SKILL.md` (PATH 15).
- **D-24:** Forward-compatible building: all paths work under current hook enforcement. No hook changes until Phase 26 (per D-02 from Phase 22).

### Claude's Discretion
- Exact trigger detection logic for UI phase classification (keywords, file type patterns)
- Internal helper logic for prerequisite checking
- Error messages when prerequisites are not met
- Ordering of as-needed sub-steps within each path

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Path Contracts
- `docs/composable-paths-contracts.md` — Quick-lookup reference for all 18 path contracts (7 fields each)
- `docs/superpowers/specs/2026-04-14-composable-paths-design.md` §5 — Source of truth for path definitions

### Skill Files (to be updated)
- `skills/silver-feature/SKILL.md` — Primary workflow; has placeholder comments for PATHs 2, 3, 4, 6, 8 from Phase 22
- `skills/silver-ui/SKILL.md` — UI workflow; needs PATHs 6 and 8
- `skills/silver-release/SKILL.md` — Release workflow; needs PATH 15

### Phase 21-22 Artifacts
- `skills/artifact-review-assessor/SKILL.md` — Assessor for review cycles (used in PATH 4 review cycles)
- `templates/workflow.md.base` — WORKFLOW.md template (paths reference this format)

### Requirements
- `.planning/REQUIREMENTS.md` — SPEC-01 through SPEC-06

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/silver-feature/SKILL.md` — Already has placeholder comments (from Phase 22) marking where PATHs 2, 3, 4, 6, 8 belong. The `[future]` markers indicate exact insertion points.
- `skills/silver-ui/SKILL.md` — Existing UI workflow that needs PATH 6 and PATH 8 sections added.
- `skills/silver-release/SKILL.md` — Existing release workflow that needs PATH 15 section added.
- `skills/artifact-review-assessor/SKILL.md` — New from Phase 21, used in PATH 4 review cycles.

### Established Patterns
- Phase 22 established the pattern for path sections: `## PATH N: NAME`, prerequisite check block, numbered steps, exit condition block
- Skills invoke other skills via `Skill(skill="skill-name", args="...")` tool
- Non-skippable gates use explicit STOP + error message pattern
- Conditional steps use "Only if [condition]:" prefix

### Integration Points
- PATH 2/3 connect to complexity triage in Step 0 (already routes fuzzy → exploration)
- PATH 4 connects to PATH 5 (PLAN) — PATH 5 expects REQUIREMENTS.md from PATH 4 or PATH 0
- PATH 6 sits between PATH 5 and PATH 7 — PLAN.md must exist, produces UI-SPEC.md for execution
- PATH 8 sits between PATH 7 and review steps — SUMMARY.md with UI deliverables triggers it

</code_context>

<specifics>
## Specific Ideas

- PATH 2 and 3 are primarily about upgrading existing placeholder steps to full path contract sections — the skill invocations already exist in silver-feature
- PATH 4 requires reordering existing steps (ingest → spec → validate) and adding review cycles
- PATH 6 is entirely new — no existing equivalent in silver-feature. silver-ui has some overlap but no path structure
- PATH 8 is entirely new — gsd-ui-review exists as a skill but isn't wired into silver-feature
- PATH 15 is the only path that goes in silver-release instead of silver-feature
- The key transformation is: flat steps with `[future]` comments → full path sections with prerequisite/trigger/exit structure

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 23-specialized-paths*
*Context gathered: 2026-04-15 via auto mode*
