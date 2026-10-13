---
spec-version: 1
status: Draft
jira-id: ""
figma-url: ""
source-artifacts: []
created: 2026-08-29
last-updated: 2026-08-29
feature-slug: rfl-plan-review-prompt
planning-root: .planning/rfl-plan-review-prompt
---

# Standardized RFL plan-review prompt — Spec

## Overview

RFL launchers and plan-review rungs lack a single standardized prompt for reviewing **plan documents**. Today [`skills/silver-review-fix-ladder/SKILL.md`](../../skills/silver-review-fix-ladder/SKILL.md) Template A is a generic code/scope audit, while live ladders paste large one-off `brief-review.md` files (evidence: [`.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/`](../rfl-router-subagent-surfaces-85bf9f09-final-review-2/)). Operators cannot rely on consistent coverage of contract vs implementation, KEEP REJECT, GFM/slug integrity, test citations, contradictions, or missing owners.

This spec defines **Template A-PLAN**: one plan-review RFL prompt, owned by the RFL skill, aligned with [`skills/review-plan/SKILL.md`](../../skills/review-plan/SKILL.md), emitted into rung `brief-review.md` (and any future generator). It does not change verify rungs, execute/code review, or Policy C/D machinery.

## User Stories

- As an **RFL launcher**, I want a single named plan-review prompt so that every plan-review rung is briefed the same way.
- As a **plan-review rung**, I want an explicit checklist (contract vs implementation, KEEP REJECT, GFM/slug, test citations, contradictions, owners) so that my `review.md` is comparable across models.
- As an **operator**, I want KEEP REJECT and GFM locks honored as “do not reopen / do not false-fix” so that rungs do not churn closed decisions or “fix” GFM with `--`.
- As a **standalone plan reviewer**, I want `review-plan` quality criteria to stay the source of truth so that `/review-plan` and RFL A-PLAN do not contradict.

## UX Flows

This is a prompt/docs change, not a UI. Operator flow:

1. User (or flow skill) starts `/silver:review-fix-ladder` with scope that is a **plan document** (D1).
2. Launcher detects plan-review charter (not execute/code review, not verify).
3. Launcher pastes **Template A-PLAN** into the rung Task prompt and writes `brief-review.md` in the rung folder.
4. Optional appendix: freeze identity (SHA-256 of copies), named KEEP REJECT list, HOLD items — **after** the standard checklist, not instead of it.
5. Rung reviews read-only, writes `review.md` with HIGH/MED/LOW/NIT (or explicit **none**) and CLEAN/NOT CLEAN.
6. Launcher triages (Policy A/C); rungs do not triage or write Policy C.
7. Verify rungs still use Template B (unchanged).

## Acceptance Criteria

- [ ] A named **Template A-PLAN** exists in `skills/silver-review-fix-ladder/SKILL.md` (or a file it explicitly includes) and is distinguishable from Template A and Template B.
- [ ] A-PLAN instructs rungs to cover all of: scope/non-goals, contract vs implementation (plan vs live code/docs), KEEP REJECT drift, GFM/slug vs TOC, test citations (path or “no test exists”), contradictions, missing owners, review-plan QCs (scope, dependencies, sequencing, testable AC, verification evidence, risks, no deferred blockers).
- [ ] A-PLAN forbids: triage, Policy C writes, APPLY/edits, verify-phase work, git checkout/switch, executing freeze YAML, launching nested subagents, claiming ladder PASS.
- [ ] Detection rule is documented: when RFL scope/charter is plan review, use A-PLAN; execute/code review stays Template A; verify stays Template B.
- [ ] `skills/review-plan` QCs remain compatible; any new plan-review checklist item that belongs in the standalone reviewer is added there too (single source of truth for structural plan QCs).
- [ ] Any script or template that generates `brief-review.md` for a plan-scoped rung emits A-PLAN (or a tested fixture of it), not a one-off freeze-only prompt as the sole body.
- [ ] Tests prove: (1) A-PLAN marker/strings present in the skill (or generator output); (2) plan-document detection examples; (3) Template B / verify model policy strings unchanged by this work.
- [ ] Untrusted plan body is delimited from system instructions in the prompt (AI/LLM safety).
- [ ] Inherited model locks remain stated in A-PLAN appendix or host notes: Verify = Grok 4.5 High native Cursor Task; unspecified Grok = 4.6 High not Extra High; Fast forbidden; Cursor via Pi forbidden until Omni tool-call translation is fixed.

## Assumptions

- [ASSUMPTION: Root `.planning/SPEC.md` (v0.35.0 SB/GSD alignment) stays untouched; this feature’s spec lives under `.planning/rfl-plan-review-prompt/` | Status: Accepted | Owner: planning]
- [ASSUMPTION: “Plan document” is D1 in the clarify brief | Status: Accepted | Owner: planning]
- [ASSUMPTION: Policy C/D and verify prompts are out of scope | Status: Accepted | Owner: planning]
- [ASSUMPTION: This authoring pass does not rewrite the live RFL prompt | Status: Accepted | Owner: planning]
- [ASSUMPTION: Freeze YAML in router_subagent_surfaces must not be executed as part of this work | Status: Accepted | Owner: planning]
- [ASSUMPTION: No Figma/JIRA/Google Doc source artifacts exist for this feature | Status: Accepted | Owner: planning]
- [ASSUMPTION: A future brief-emitter script is optional; the skill text is the canonical prompt | Status: Accepted | Owner: implementation]

## Open Questions

- [ ] Optional `scripts/` brief emitter vs skill-only paste — Owner: implementation | Status: Follow-up-required (default: skill canonical; script if tests need a fixture)
- [ ] Whether CHARTER.md / ISSUE-LEDGER.md in an RFL run dir count as plan documents — Owner: planning | Status: Resolved as **out** (D1); listed here so implementers do not expand silently

## Out of Scope

- Verify rungs (`verify_1` / `verify_2`), Template B, and verify model routing (Grok 4.5 High native Cursor).
- Execute / code-review RFL (Template A generic) except documenting the detection fork.
- Rewriting live prompts in the document-authoring pass.
- Executing `.planning/router_subagent_surfaces_85bf9f09.plan.md` or any freeze YAML.
- Creating `Architecture.md`, `DESIGN.md`, or UI-SPEC.
- Changing Policy A/B/C/D state machines, quota retry, or OpenCode skip policy.
- Public site / Help Center copy unless a later docs wave explicitly adds it.
- Child-sex / unrelated product work.

## Implementations

<!-- Populated automatically by pr-traceability.sh hook post-merge. -->
