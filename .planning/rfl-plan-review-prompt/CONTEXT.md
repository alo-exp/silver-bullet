---
phase: 01-standardize-plan-review-prompt
created: 2026-08-29
last-updated: 2026-08-29
status: ready-to-plan
clarify: .planning/rfl-plan-review-prompt-CLARIFY-260828-20260828T155216Z.md
spec: .planning/rfl-plan-review-prompt/SPEC.md
---

# CONTEXT — Standardized RFL plan-review prompt

## Why this file is scoped

Canonical `/silver:context` writes `.planning/CONTEXT.md`. That file is the **v0.35.0 SB/GSD alignment** project context (last updated 2026-08-25) and must not be overwritten. Same for root [`SPEC.md`](../SPEC.md) / [`REQUIREMENTS.md`](../REQUIREMENTS.md).

This feature’s context lives at [`.planning/rfl-plan-review-prompt/CONTEXT.md`](CONTEXT.md).

**Deviation (skill):** silver-spec Step 7/8 default paths were not used. Reason: clobber risk. silver-plan phase folder is [`.planning/rfl-plan-review-prompt/phases/01-standardize-plan-review-prompt/`](phases/01-standardize-plan-review-prompt/) rather than `.planning/phases/` so this work does not collide with other active phases.

## Scope

Standardize the prompt RFL **review** rungs receive when the artifact is a **plan document**. Implementation of the prompt rewrite is a later phase.

## Locked decisions

Recorded in [clarify brief](../rfl-plan-review-prompt-CLARIFY-260828-20260828T155216Z.md) (D1–D8). Summary:

1. **D1 Plan documents:** `.cursor/plans/*.plan.md`, `.planning/**/*.plan.md`, `.planning/**/PLAN.md`, `.planning/phases/**/PLAN.md`, and the RFL scope target when the charter is plan review. Not SPEC/REQUIREMENTS/CONTEXT/DESIGN, not review.md/POLICY-C, not CHARTER/ISSUE-LEDGER, not code/tests, not verify briefs.
2. **D2 Dual surface:** Template **A-PLAN** in `silver-review-fix-ladder` is the RFL prompt. `review-plan` remains the standalone reviewer and the QC source of truth for structural plan review. Do not create a third competing prompt.
3. **D3 Policy C/D unchanged.** Rungs review-only. KEEP REJECT is a finding surface. Launcher still writes Policy C.
4. **D4 Verify out of scope.** Grok 4.5 High native Cursor Task; Template B unchanged.
5. **D5 Detection:** plan-review charter → A-PLAN; execute/code → Template A; verify → Template B.
6. **D6 This pass is docs only.**
7. **D7 Scoped planning dir** (this folder).
8. **D8 Model policy inherited:** unspecified Grok = 4.6 High not Extra High; Fast forbidden; Cursor via Pi forbidden until Omni tool-call translation is fixed.

## Constraints

- Do not `git checkout` / `git switch` / SetActiveBranch.
- Do not push, tag, or release.
- Do not execute frozen router_subagent_surfaces YAML.
- Do not commit unless the user asks (user did not; spec Step 10 skipped).
- Graphify first; agentmemory save; Context Mode for large analysis.

## Risks

| Risk | Mitigation |
|------|------------|
| Freeze-specific briefs remain necessary (SHA, HOLD, named KR) | A-PLAN body + optional appendix; appendix cannot replace checklist |
| `brief-review.md` naming collision (some rungs wrote summaries into that filename) | Implementation must distinguish input brief vs output `review.md`; do not use `brief-review.md` as the official review |
| Prompt injection from plan/freeze text | NFR-02 delimiters + fixture test |
| Scope creep into verify or Policy C | SPEC out of scope + tests that Template B strings are unchanged |
| Skill file size (RFL SKILL.md already ~510 lines / 42 KB) | Prefer include file for A-PLAN if adding it would exceed modularity soft limits |

## Non-goals

- Architecture.md / DESIGN.md / UI-SPEC
- Rewriting Template A (code review) or Template B (verify) in this feature
- Running the freeze ladder

## Dependencies

- [`skills/silver-review-fix-ladder/SKILL.md`](../../skills/silver-review-fix-ladder/SKILL.md)
- [`skills/review-plan/SKILL.md`](../../skills/review-plan/SKILL.md)
- Evidence (read-only): [`.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/`](../rfl-router-subagent-surfaces-85bf9f09-final-review-2/)
- Tests to extend later: `tests/skill-scenarios/review-plan.md`, `tests/skill-scenarios/silver-review-fix-ladder.md`, `tests/live/lib/review-fix-ladder-common.sh`

## Assumptions (planner-visible)

| Assumption | Owner | Status |
|------------|-------|--------|
| No scripts/ generator currently writes brief-review.md | implementation | Accepted |
| Skill text is canonical; script optional for fixtures | implementation | Accepted |
| Root planning files stay for unrelated v0.35.0 work | planning | Accepted |

## Unresolved blockers

None blocking plan authoring. Follow-up-required: optional brief-emitter script (not blocking).

## Planning handoff

- **Scope:** Author A-PLAN + detection + review-plan alignment + tests; freeze appendix pattern; no verify/Policy C changes.
- **Out of scope:** See SPEC.
- **Acceptance:** REQ-01–REQ-09, NFR-01–NFR-05.
- **Verification:** skill-string tests + detection fixtures; do not run freeze YAML.
- **Blockers:** none.
