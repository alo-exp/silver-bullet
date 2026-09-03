# Requirements: Standardized RFL plan-review prompt

**Derived from:** [.planning/rfl-plan-review-prompt/SPEC.md](SPEC.md) v1
**Generated:** 2026-08-29

## Functional Requirements

| ID | Requirement | Acceptance Criterion | Priority |
|----|-------------|----------------------|----------|
| REQ-01 | The RFL skill publishes a named Template A-PLAN distinct from Template A and Template B | `skills/silver-review-fix-ladder/SKILL.md` (or a file it includes) contains a heading or include named `Template A-PLAN` (or equivalent `rung_N_review_plan`) that is not Template A or Template B | P1 |
| REQ-02 | A-PLAN requires the plan-review checklist | The prompt text mandates coverage of: scope/non-goals, contract vs implementation, KEEP REJECT drift, GFM/slug vs TOC, test citations (path or “no test exists”), contradictions, missing owners, and review-plan QCs | P1 |
| REQ-03 | A-PLAN forbids launcher-owned and out-of-scope behaviors | The prompt forbids triage, Policy C writes, APPLY/edits, verify-phase work, git checkout/switch, freeze YAML execution, nested subagents, and claiming ladder PASS | P1 |
| REQ-04 | Launchers select A-PLAN only for plan-review charters | Detection rule is documented in the skill: plan-review charter → A-PLAN; execute/code review → Template A; verify → Template B | P1 |
| REQ-05 | Standalone `review-plan` remains the QC source of truth for structural plan review | Any new structural plan QC added for RFL is also present in `skills/review-plan/SKILL.md`; the two checklists do not contradict | P1 |
| REQ-06 | Generated `brief-review.md` for plan-scoped rungs uses A-PLAN as the body | Skill instructions (and any script/template that writes `brief-review.md`) emit A-PLAN; freeze-specific SHA/KEEP REJECT lists are an appendix, not a replacement body | P1 |
| REQ-07 | Automated tests lock the prompt contract | Tests assert A-PLAN marker/strings, plan-document detection examples, and that Template B / verify model-policy strings are unchanged by this work | P1 |
| REQ-08 | Plan body is treated as untrusted data in the prompt | A-PLAN delimits system instructions from the plan document (and any pasted freeze text) so the plan cannot override FORBIDDEN / Policy rules | P1 |
| REQ-09 | Inherited model locks are restated for plan-review rungs | A-PLAN or host notes state: Verify = Grok 4.5 High native Cursor Task; unspecified Grok = 4.6 High not Extra High; Fast forbidden; Cursor via Pi forbidden until Omni tool-call translation is fixed | P2 |

## Non-Functional Requirements

| ID | Requirement | Metric | Priority |
|----|-------------|--------|----------|
| NFR-01 | A-PLAN stays loadable in a rung context window | Canonical A-PLAN body (excluding optional freeze appendix) is ≤ 400 lines / ≤ 24 KB | P2 |
| NFR-02 | Prompt injection resistance | Untrusted plan/freeze text is fenced or otherwise delimited; tests include at least one fixture where plan text containing “ignore FORBIDDEN” does not remove FORBIDDEN from the skill source | P1 |
| NFR-03 | No live freeze execution | Implementation and tests MUST NOT run router_subagent_surfaces freeze YAML; freeze paths are read-only evidence | P1 |
| NFR-04 | Reliability of detection | Given a fixture set of ≥ 6 paths (3 in / 3 out per D1), detection classification matches SPEC D1 with 100% agreement | P1 |
| NFR-05 | Extensibility | Adding a future `A-SPEC` / `A-CODE` template must not require rewriting A-PLAN; detection remains a documented fork | P2 |

## Out of Scope

- Verify rungs (`verify_1` / `verify_2`), Template B, and verify model routing.
- Execute / code-review RFL except documenting the detection fork.
- Rewriting live prompts during the document-authoring pass.
- Executing `.planning/router_subagent_surfaces_85bf9f09.plan.md` or any freeze YAML.
- Creating `Architecture.md`, `DESIGN.md`, or UI-SPEC.
- Changing Policy A/B/C/D state machines, quota retry, or OpenCode skip policy.
- Public site / Help Center copy unless a later docs wave explicitly adds it.

## Open Items

- [ ] Optional `scripts/` brief emitter vs skill-only paste — Owner: implementation | Status: Follow-up-required (default: skill canonical; script if tests need a fixture)
- [ ] CHARTER.md / ISSUE-LEDGER.md are **out** of D1 (resolved in SPEC); do not expand silently
