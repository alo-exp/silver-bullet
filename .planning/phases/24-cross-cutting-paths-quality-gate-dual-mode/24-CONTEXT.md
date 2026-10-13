# Phase 24: Cross-Cutting Paths + Quality Gate Dual-Mode - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Source:** Auto-mode (decisions from design spec + Phase 21-23 prior context)

<domain>
## Phase Boundary

Implement the 6 cross-cutting paths (PATH 9 REVIEW, PATH 10 SECURE, PATH 12 QUALITY GATE, PATH 14 DEBUG, PATH 16 DOCUMENT, PATH 17 RELEASE) and upgrade all 9 quality dimension skills to dual-mode operation (design-time checklist + adversarial audit). Cross-cutting paths can insert at any point in a composition. PATH 11 (VERIFY) and PATH 13 (SHIP) were already implemented in Phase 22.

</domain>

<decisions>
## Implementation Decisions

### PATH 9: REVIEW — Three-layer parallel review
- **D-01:** PATH 9 is a NEW path section added to silver-feature/SKILL.md. It replaces the existing flat review steps (9a-9d) with a structured path section.
- **D-02:** Three parallel review layers: Layer A (gsd-code-review → receiving-code-review → gsd-code-review-fix), Layer B (requesting-code-review → receiving-code-review → gsd-code-review-fix), Layer C (engineering:code-review → receiving-code-review → gsd-code-review-fix). Layer D (gsd-review --multi-ai) is as-needed/conditional.
- **D-03:** Each layer runs independently. After all layers complete, the entire cycle iterates until 2 consecutive clean passes across all layers.
- **D-04:** PATH 9 prerequisite: PATH 7 completed. Trigger: always for any composition with PATH 7.

### PATH 10: SECURE — Security verification
- **D-05:** PATH 10 is a NEW path section replacing the existing flat security steps (10, 11, 12) in silver-feature/SKILL.md.
- **D-06:** Steps: security/SENTINEL (as-needed — AI plugins/skills), gsd-secure-phase (always), gsd-validate-phase (always), ai-llm-safety (as-needed — LLM agents/prompts).
- **D-07:** PATH 10 prerequisite: PATH 9 completed. Produces SECURITY.md with 2 consecutive clean passes.

### PATH 12: QUALITY GATE — Dual-mode operation
- **D-08:** PATH 12 replaces the existing flat quality gate steps (3 and 13) in silver-feature/SKILL.md. It appears TWICE in compositions: pre-plan (design-time checklist) and pre-ship (adversarial audit).
- **D-09:** Dual-mode detection: if PLAN.md does NOT exist → design-time checklist mode (pre-plan). If PATH 11 completed → adversarial audit mode (pre-ship). This is the 4-state disambiguation table from the design spec.
- **D-10:** Steps: quality-gates (9 dimensions) for standard projects OR devops-quality-gates (7 dimensions) for IaC/infra. Individual dimension deep-dive as-needed for specific failures.
- **D-11:** All dimensions must pass. Gate itself is the review — no separate review cycle.

### PATH 14: DEBUG — Dynamic insertion on failure
- **D-12:** PATH 14 is a NEW path section added to silver-feature/SKILL.md. It does NOT replace any existing step — it is inserted dynamically when execution fails.
- **D-13:** Steps: systematic-debugging (always), gsd-debug (always), engineering:debug (as-needed), forensics (as-needed — unknown root cause), gsd-forensics (as-needed — failed GSD workflow), engineering:incident-response (as-needed — production incident).
- **D-14:** Resume semantics: after PATH 14 completes, execution resumes from the interrupted path. Fix plan validated before re-entering the interrupted path. Fixes route through gsd-execute-phase --gaps-only.
- **D-15:** PATH 14 has no prerequisites — it is inserted on failure at any point.

### PATH 16: DOCUMENT — Post-ship documentation
- **D-16:** PATH 16 is a NEW path section added to silver-feature/SKILL.md replacing the existing episodic memory step (16).
- **D-17:** Steps: gsd-docs-update (always), engineering:documentation (always), engineering:tech-debt (always), gsd-milestone-summary (as-needed), episodic-memory:remembering-conversations (always), gsd-session-report (as-needed).
- **D-18:** PATH 16 prerequisite: PATH 13 completed. Trigger: always post-ship.

### PATH 17: RELEASE — Milestone completion
- **D-19:** PATH 17 is a NEW path section added to silver-feature/SKILL.md replacing the existing milestone completion step (17).
- **D-20:** Steps: gsd-audit-uat (always), gsd-audit-milestone (always), PATH 15 DESIGN HANDOFF (as-needed — inserted between steps 2 and 4 if milestone has UI phases), gsd-plan-milestone-gaps (as-needed), create-release (always), gsd-complete-milestone (always).
- **D-21:** PATH 17 prerequisite: all phases shipped. Trigger: user signals milestone complete or last phase shipped.
- **D-22:** Cross-artifact review → artifact-review-assessor → fix → pass runs before create-release. Gap closure is Claude-suggested, user-decided depth.
- **D-23:** PATH 17 also exists in silver-release/SKILL.md (the primary location). The silver-feature version is for the milestone completion step at end of feature workflow.

### CROSS-07: Quality Gate Dual-Mode
- **D-24:** All 9 quality dimension skills (modularity, reusability, scalability, security, reliability, usability, testability, extensibility, ai-llm-safety) must detect their mode from artifact state. The quality-gates/SKILL.md orchestrator already runs all 9 — the dual-mode detection logic goes in the quality-gates skill itself, not in individual dimension skills.
- **D-25:** Mode detection: check for PLAN.md existence and PATH 11 completion to determine pre-plan (design-time) vs pre-ship (adversarial). Pre-plan: lighter checklist, focus on design decisions. Pre-ship: full adversarial audit, focus on implementation quality.
- **D-26:** The quality-gates/SKILL.md file needs a new section at the top that detects mode and adjusts the checklist depth for each dimension accordingly.

### Files Modified
- **D-27:** Primary files: `skills/silver-feature/SKILL.md` (PATHs 9, 10, 12, 14, 16, 17), `skills/quality-gates/SKILL.md` (dual-mode detection).
- **D-28:** Forward-compatible building: all paths work under current hook enforcement. No hook changes until Phase 26.

### Claude's Discretion
- Exact dual-mode detection logic in quality-gates/SKILL.md
- Resume semantics implementation details for PATH 14
- Error messages when prerequisites are not met
- Layer parallelism implementation in PATH 9 (sequential invocation is acceptable — true parallelism is a future optimization)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Path Contracts
- `docs/composable-paths-contracts.md` — Quick-lookup reference for all 18 path contracts
- `docs/superpowers/specs/2026-04-14-composable-paths-design.md` §5 — Source of truth for path definitions

### Skill Files (to be updated)
- `skills/silver-feature/SKILL.md` — Primary workflow; needs PATHs 9, 10, 12, 14, 16, 17
- `skills/quality-gates/SKILL.md` — Quality gate orchestrator; needs dual-mode detection

### Phase 21-23 Artifacts
- `skills/artifact-review-assessor/SKILL.md` — Assessor for review cycles
- `templates/workflow.md.base` — WORKFLOW.md template

### Requirements
- `.planning/REQUIREMENTS.md` — CROSS-01 through CROSS-07

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/silver-feature/SKILL.md` — Has flat steps for review (9a-9d), security (10-12), quality gates (3, 13), episodic memory (16), and milestone completion (17). These become full path sections.
- `skills/quality-gates/SKILL.md` — Existing orchestrator that runs all 9 dimensions. Needs dual-mode wrapper.
- `skills/silver-bugfix/SKILL.md` — Has simplified PATH 5/7/11/13 from Phase 22. May need PATH 14 (DEBUG) wiring.

### Established Patterns
- Phase 22-23 established the pattern: `## PATH N: NAME`, prerequisite check, numbered steps, exit condition
- Skills invoke other skills via `Skill(skill="skill-name", args="...")` tool
- Non-skippable gates use explicit STOP + error message pattern

### Integration Points
- PATH 9 replaces Steps 9a-9d (review section between PATH 7/8 and PATH 10)
- PATH 10 replaces Steps 10-12 (security section)
- PATH 12 replaces Steps 3 and 13 (quality gates — appears twice)
- PATH 14 is dynamically inserted on failure (referenced in PATH 7's error path)
- PATH 16 replaces Step 16 (episodic memory, expanded)
- PATH 17 replaces Step 17 (milestone completion, expanded)

</code_context>

<specifics>
## Specific Ideas

- PATH 9's three parallel review layers are the most complex new structure — each layer has its own triage + fix cycle, and the overall path iterates until 2 consecutive clean passes
- PATH 12 dual-mode is the key architectural change — same skill, different behavior based on context
- PATH 14 is unique in that it has no fixed position — it's dynamically inserted on failure
- PATH 16 and 17 are primarily expansions of existing steps with more skill invocations
- The quality-gates dual-mode change is in the quality-gates/SKILL.md orchestrator, not in individual dimension skills

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 24-cross-cutting-paths-quality-gate-dual-mode*
*Context gathered: 2026-04-15 via auto mode*
