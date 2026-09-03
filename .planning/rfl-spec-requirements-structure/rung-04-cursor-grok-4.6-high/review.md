# Review — Rung 04 (Cursor Grok 4.6 High) — review-plan

**Reviewer:** Grok 4.6 High (`cursor-grok-4.6-high`), Cursor native.
**Rung:** 4 of 8 (Policy C, review-only).
**Artifact:** `.planning/spec_requirements_structure.plan.md` (PLAN doc).
**Skill:** `skills/review-plan/SKILL.md` + RFL Template A (plan-doc emphasis).
**Date:** 2026-08-29.

`review-plan` status: `ISSUES_FOUND` (maps to RFL **NOT CLEAN**). Finding IDs are `R4-Fnn` per this ladder, not `PLAN-Fnn`.

## Freeze integrity

- `shasum -a 256 .planning/spec_requirements_structure.plan.md` → `2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe` ✓ matches expected (post rung-02 APPLY; unchanged after Gemini CLEAN — no APPLY).
- Twin `.planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md` → same SHA ✓ (byte-identical pair, 454 lines).
- No branch switch, no commit, no freeze YAML execution performed.

## Method

- Graphify CLI first (`graphify query` on spec-requirements-structure / review-plan / compiler / QC; `graphify explain "SPEC.md REQUIREMENTS.md structure"`). MCP `user-graphify` failed live discovery this session; CLI used.
- agentmemory saved at start: `mem_mte3z17y_6844e515c00f`.
- Context Mode sandbox used to inspect templates, reviewer skills, compiler/clarify skills, hooks, and tests without dumping those files into this review.
- Full read of the freeze PLAN, `CONTEXT.md` / `SPEC.md` / `REQUIREMENTS.md` under `.planning/spec-requirements-structure/`, prior APPLY confirmation against freeze text, `skills/review-plan/SKILL.md`, Template A in `skills/silver-review-fix-ladder/SKILL.md`, and `skills/artifact-reviewer/rules/reviewer-interface.md` + `review-loop.md`.
- Spot-checked live surfaces: `templates/specs/*.template`, `skills/review-requirements/SKILL.md` QC-4, `skills/silver-spec/SKILL.md` Steps 2/7/8/8a, `hooks/spec-floor-check.sh`, `hooks/pr-traceability.sh`.

## Prior APPLY Confirmation (Rungs 01 & 02)

Do not re-open unless still wrong. All nine APPLYed items remain correctly integrated:

| Prior Finding | Status in Freeze | Verification |
|---------------|------------------|--------------|
| **R1-F01 (MED)** | APPLIED | Wave 6 steps 3–4 lock only when missing `spec-version` **and** missing `## User Stories` **and** missing `feature-slug`. Rollback residual: none expected. |
| **R1-F02 (LOW)** | APPLIED | Mapping `AC-09 / REQ-09` → `1, 2, 3, 4, 7`. |
| **R1-F03 (LOW)** | APPLIED | `If/Then` pinned to non-interactive AC; interactive AC require GWT; QC-9 ISSUE-new / INFO-legacy. |
| **R1-F04 (NIT)** | APPLIED | Evidence table: `SPEC.md.template` 52 lines / 1017 bytes (file is 1017 bytes). |
| **R1-F05 (NIT)** | APPLIED | Spec-floor is NFR-03 only; footnote on the mapping table. |
| **R2-F01 (LOW)** | APPLIED | Wave 6 step 4b covers `spec-version` present + no stories + no slug as augment. Tree is total. |
| **R2-F02 (LOW)** | APPLIED | ISSUE-new / INFO-legacy split covers QC-8, QC-9, QC-10, and QC-6 `feature-slug`. |
| **R2-F03 (LOW)** | APPLIED | Single test name `tests/scripts/test-review-spec-req-xart-qc-strings.sh` in Wave 2 and Wave 7. |
| **R2-F04 (NIT)** | APPLIED | Line 38 is a blockquote warning, not a second H1. |

Rung 03 CLEAN (zero findings) is not treated as proof the freeze is complete; this rung re-audited live QC vs the new table shape.

## Quality Criteria Evaluation (`skills/review-plan/SKILL.md`)

1. **Scope is explicit:** Goal, seven non-goals, KEEP REJECT table, blast-radius table, and out-of-blast-radius list are present.
2. **Dependencies are explicit:** Compiler split, `test-clarify-spec-compiler.sh`, parity tests, site freshness tests, inter-wave order.
3. **Work is sequenced:** Waves 1–7 with owners, expected files, and handoffs.
4. **Acceptance criteria are testable and traced:** Mapping table covers AC-01..AC-10, REQ-01..REQ-10, NFR-01..NFR-04. **Gap:** REQ-04 / Wave 2 omit Functional QC-4 retarget (R4-F01).
5. **Verification plan is concrete:** Named scripts and fixtures; no “path TBD.” Wave 3 negative assert is incomplete (R4-F02).
6. **Risk handling is present:** Five-row rollback table; per-wave risks.
7. **No unspecified deferred blockers:** OQ-01 / OQ-02 remain non-blocking with defaults. R4-F01 is a Wave 2 hole, not an open question.

## Template A Checklist Evaluation (Plan-Doc Emphasis)

- **KEEP REJECT:** Intact. Two files stay; compiler derives REQ from SPEC AC; Clarify does not write SPEC; ingest stays; REQUIREMENTS keeps OOS / Open Items as ID snapshots; spec-floor stays Overview + AC; Implementations HTML comment stays; plugin mirror via `sync-templates.sh`. Not re-opened.
- **ID scheme:** `US-nn` / `FLOW-nn` / `AC-nn` / `OQ-nn` / `OOS-nn` / `REQ-nn` / `NFR-nn`; new QC IDs `SPEC-F70`–`SPEC-F72`, `REQ-F70` do not collide with current `SPEC-F01`…`SPEC-F61` / `REQ-F01`…`REQ-F60`.
- **Test citations:** Named. Wave 1 fixtures and Wave 6 `legacy-v035` still do not exist on disk (expected pre-implement).
- **OQ-01 / OQ-02:** Defaults (optional Quality Attributes; refuse-overwrite only) are acceptable; this rung does not flip them.
- **Compiler 1:1 AC→REQ:** Default 1:1 with comma-separated AC column for many-to-one is enough; no new finding.

## Findings

### R4-F01 — MED — Wave 2 does not retarget review-requirements QC-4 for the new Functional `AC` column

- **Location:** Target structure Functional table (freeze L137–L141); Wave 2 `review-requirements` row (L247); Wave 3 Step 8 / 8a (L275–L276). Live skill: `skills/review-requirements/SKILL.md` QC-4 (L70–L78) and QC-7 step 3 (L101).
- **Evidence:**
  - New REQUIREMENTS shape: `| ID | Requirement | AC | Priority |` where **`AC` column is `AC-nn`**, and the Requirement column is a one-line normative statement — **GWT stays in SPEC** (L139–L141). Wave 1 tests lock column header `AC` (L217).
  - Live QC-4: every Functional row **MUST** have an **Acceptance Criterion** column value that is **measurable** (thresholds, named states, pass/fail). `AC-01` is an ID join key, not a measurable criterion. Live QC-7 still tells reviewers the AC column should “capture the same observable outcome.”
  - Wave 2 rewrites QC-6, QC-7 (ID join), and adds QC-8. It mentions QC-4 **only** for empty NFR + `None identified` (vacuous PASS). It does **not** say: rename the column, move measurability to SPEC QC-9 / the Requirement one-liner, or treat `AC-nn` as out of QC-4’s measurable-text rule.
  - Wave 3 Step 8a remains a non-skippable 2-pass `review-requirements` gate (`silver-spec` L257–L263) and only adds `source_inputs` for QC-7/QC-8 (plan L276). QC-4 still runs.
- **Why it matters:** As written, a greenfield compile that follows the target table will systematically fail QC-4 (`REQ-F30`) on every REQ row (ID is not a threshold) **or** fail to find an “Acceptance Criterion” column after the header rename. That makes Step 8a unsatisfiable and fights AC-02 / REQ-02 (AC column = ID) plus AC-04 / REQ-04 (Wave 2 QC updates). Empty-NFR QC-4 was thought through; Functional QC-4 was not. Not a KEEP REJECT reopen and not an APPLYed item.
- **Suggested fix:** In the Wave 2 `review-requirements` cell, add an explicit QC-4 retarget, for example:
  1. Functional: `AC` column is an ID list (`AC-nn`); **do not** require that cell to be measurable prose. Measurability of the outcome lives in SPEC GWT / QC-9; the Requirement column stays a one-line normative statement (fail QC-4 only if that statement is the vague-adjective class).
  2. Keep NFR Metric measurable; empty NFR + `None identified` remains PASS.
  3. Align QC-7 leftover “same observable outcome” language with the ID-join rule already specified.
  4. Name `REQ-F30` in `test-review-spec-req-xart-qc-strings.sh` so the retarget is asserted.

### R4-F02 — LOW — Wave 3 verify omits the “Requirements” negative assert the work item itself requires

- **Location:** Wave 3 work step 1 (L273) vs Verify bullets (L280–L288), especially L284.
- **Evidence:** Work: Step 2 fallback scaffold = template headings **(drop “Users and goals” / “Requirements”)**. Verify asserts **does not** list “Users and goals” as a write section, plus positives (`Coverage Matrix`, `feature-slug`, `None identified`, lock phrase). There is no matching **does not** list “Requirements” as a write section (the exact REJECT the critique table at L61 calls out).
- **Why it matters:** The compiler-split KEEP is “no SPEC `## Requirements` section.” A string harness that only bans “Users and goals” can still ship a fallback that invents `## Requirements` and fail review-spec QC-1 / REJECT. The work sentence is clear; the verify list is not the contract join.
- **Suggested fix:** Add a Wave 3 verify bullet: does **not** list “Requirements” as a write / fallback section (same strength as the “Users and goals” assert). Optional: also assert fallback headings match the eight QC-1 names (so “Source artifacts” does not linger as an H2).

### R4-F03 — NIT — `## Invariants` is not a subsection of Overview

- **Location:** L102–L105; rollback “Cut Invariants subsection” (L401).
- **Evidence:** The heading says “a short `## Invariants` subsection of Overview — prefer subsection to avoid a ninth QC-1 heading.” In GFM, `## Invariants` is a sibling H2 of `## Overview`, not a subsection. A subsection is `### Invariants`. QC-1 today is an existence check (extra H2 does not fail), and Change History is already a non-QC-1 ninth H2 via QC-10 — so this is not a QC-1 lock break. It is the plan arguing against a ninth QC-1 heading while showing the markup that would add one.
- **Why it matters:** Implementers copying the backticks will emit `## Invariants`. Harmless under current QC-1; confusing next to “avoid a ninth QC-1 heading.”
- **Suggested fix:** Pin `### Invariants` under Overview (default), or state that Invariants MUST NOT be an H2 unless Wave 2 adds it to QC-1.

## Verdict

**NOT CLEAN.**

No HIGH. One MED (R4-F01) is a Wave 2 contract hole: the new Functional `AC` ID column is incompatible with live review-requirements QC-4, which Step 8a still runs. Two smaller items (R4-F02 LOW, R4-F03 NIT) should APPLY with it.

KEEP REJECT is not re-opened. R1/R2 APPLY remains correct. OQ-01 stays optional Quality Attributes; OQ-02 stays refuse-overwrite.

Parent: APPLY R4-F01–F03 (including LOW/NIT), then Grok 4.5 High verify — this worker does not triage, patch, or advance.

## Appendix — Freeze SHA

```
2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe  .planning/spec_requirements_structure.plan.md
2b2f7d7672534c8895ac821fe49d34b634833cc1eb16770d6f2f5d9d3f2d1ffe  .planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md
```
