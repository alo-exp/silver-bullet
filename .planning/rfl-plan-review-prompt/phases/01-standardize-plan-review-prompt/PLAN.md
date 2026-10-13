# PLAN — 01-standardize-plan-review-prompt

**Phase:** `01-standardize-plan-review-prompt`  
**Created:** 2026-08-29  
**Mode:** Standard (docs/prompt; not MVP UI slice)  
**Spec:** [SPEC.md](../../SPEC.md) v1  
**Requirements:** [REQUIREMENTS.md](../../REQUIREMENTS.md)  
**Context:** [CONTEXT.md](../../CONTEXT.md)  
**Quality gates:** [QUALITY-GATES.md](../../QUALITY-GATES.md) design-time PASS  
**Clarify:** [rfl-plan-review-prompt-CLARIFY-260828-20260828T155216Z.md](../../../rfl-plan-review-prompt-CLARIFY-260828-20260828T155216Z.md)

## Goal

Ship **Template A-PLAN**: one standardized RFL review prompt for **plan documents**, aligned with `review-plan` QCs, emitted as the body of plan-scoped `brief-review.md`. Do not change verify (Template B / Grok 4.5 High native Cursor), Policy C/D, or execute/code-review Template A beyond documenting the detection fork.

## Non-goals

- Execute freeze YAML (`router_subagent_surfaces_85bf9f09` or any freeze).
- Rewrite live prompts in the authoring pass (already done). This PLAN is for the **implementation** phase after docs exist.
- Architecture.md, DESIGN.md, UI-SPEC, public site (unless a later explicit docs wave).
- Changing Policy A/B/C/D, quota retry, or OpenCode skip.

## Blast radius / files

Expected implementation surfaces (≤5 source files plus tests/docs):

| Area | Files |
|------|--------|
| Canonical prompt | `skills/silver-review-fix-ladder/SKILL.md` and/or `skills/silver-review-fix-ladder/templates/A-PLAN.md` (include if SKILL.md would grow) |
| Standalone QCs | `skills/review-plan/SKILL.md` (additive QCs only if missing vs A-PLAN) |
| Optional emitter | `scripts/` only if tests need a fixture generator (skill remains canonical) |
| Tests | `tests/skill-scenarios/silver-review-fix-ladder.md`, `tests/skill-scenarios/review-plan.md`, new unit/script test for detection + string contracts |
| Bundles | `scripts/sync-codex-package.sh` after skill edit (derived agents/*) |

Read-only evidence: `.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/` (do not execute).

## Dependencies

- Prerequisite: this folder’s SPEC / REQUIREMENTS / CONTEXT / design-time quality gates (done).
- Prerequisite: Graphify + agentmemory on implementation session.
- Ordering: detection fixtures (TDD) → A-PLAN text → review-plan alignment → brief-emission instructions → string tests → bundle sync.
- Rollback: revert skill/test commits; no data migration.
- Compatibility: Template A and Template B strings must remain greppable after the change (REQ-07).

## TDD policy

- **Detection + string contracts:** write tests first (`tdd` before production skill/script edits).
- **Docs/skill prose:** no application TDD; verification = scenario tests + grep/fixtures listed per wave.
- **Forbidden:** running freeze YAML as a test harness.

---

## Wave 1 — Detection contract (TDD)

**Goal:** Freeze D1 in tests before prompt prose.

**Tasks:**

1. Add a fixture table of ≥6 paths: 3 in (`.cursor/plans/foo.plan.md`, `.planning/phases/x/PLAN.md`, `.planning/foo.plan.md`) and 3 out (`SPEC.md`, `review.md`, `brief-verify-1.md`).
2. Document the detection function/rule in a test (bash or python) that the implementation must satisfy.
3. Charter rule: plan-review charter + plan-class scope → A-PLAN; else not.

**Expected files:** `tests/scripts/test-rfl-plan-document-detection.sh` (create; do not invent a second detection test path).

**Acceptance:** REQ-04, NFR-04.

**Verify:** `bash tests/scripts/test-rfl-plan-document-detection.sh` exits 0; 100% fixture agreement (including CHARTER.md as **out**).

**Risks:** over-matching CHARTER.md — SPEC resolved CHARTER as **out**; fixture must include it as out.

---

## Wave 2 — Template A-PLAN text + delimiters

**Goal:** Canonical prompt exists and is distinguishable.

**Tasks:**

1. Add Template A-PLAN to the RFL skill (or include file). Keep Template A and B intact.
2. Checklist body: scope/non-goals, contract vs implementation, KEEP REJECT drift, GFM/slug vs TOC, test citations, contradictions, missing owners, review-plan QCs.
3. FORBIDDEN block: triage, Policy C, APPLY, verify work, git checkout/switch, freeze YAML, nested subagents, ladder PASS claim.
4. Delimit untrusted plan/freeze body (REQ-08 / NFR-02).
5. Optional appendix slot for freeze SHA copies + named KEEP REJECT / HOLD (must not replace body).
6. Restate model locks (REQ-09) in host notes or appendix.
7. If SKILL.md would grow past maintainability, put A-PLAN in `skills/silver-review-fix-ladder/templates/A-PLAN.md` and include it.

**Expected files:** `skills/silver-review-fix-ladder/SKILL.md` ± `templates/A-PLAN.md`.

**Acceptance:** REQ-01, REQ-02, REQ-03, REQ-08, REQ-09, NFR-01.

**Verify:** grep Template A-PLAN heading; line/byte count vs NFR-01; Template B still present.

**Risks:** prompt injection via plan text — fixture in Wave 4. Modularity: split include if needed.

---

## Wave 3 — Align `review-plan`

**Goal:** No contradicting checklists.

**Tasks:**

1. Diff A-PLAN checklist vs `skills/review-plan` QCs 1–7.
2. Add only missing structural QCs to `review-plan` (e.g. GFM/slug, KEEP REJECT as INFO/ISSUE if appropriate). Do not turn `review-plan` into an RFL Policy C tutor.
3. Keep `PLAN-F` output contract.

**Expected files:** `skills/review-plan/SKILL.md`.

**Acceptance:** REQ-05.

**Verify:** both files mention GFM/slug and KEEP REJECT (or an explicit “RFL-only” note on KEEP REJECT if standalone review-plan should not assume an RFL ledger).

**Risks:** KEEP REJECT is RFL-specific — if adding to review-plan is wrong, document “RFL-only” in A-PLAN and do not force it into standalone review-plan. Default: add GFM/slug + missing-owners + test-citation QCs to review-plan; keep KEEP REJECT in A-PLAN with a pointer.

---

## Wave 4 — Emission + tests

**Goal:** Launchers emit A-PLAN; tests lock the contract.

**Tasks:**

1. Skill “Per-Rung Workflow” must say: plan-review charter → write `brief-review.md` from A-PLAN (+ optional appendix).
2. Optional script emitter only if a fixture cannot be asserted from the skill file alone.
3. Tests: A-PLAN marker present; Template B / verify model-policy strings unchanged; injection fixture (plan containing “ignore FORBIDDEN” does not strip FORBIDDEN from skill source); NFR-03 (no freeze YAML in test commands).
4. Update `tests/skill-scenarios/silver-review-fix-ladder.md` and `tests/skill-scenarios/review-plan.md` for the new path.
5. `bash scripts/sync-codex-package.sh` after skill edits.

**Expected files:** skill text, tests, maybe `scripts/` helper, generated agent bundles.

**Acceptance:** REQ-06, REQ-07, NFR-02, NFR-03, NFR-05.

**Verify:** targeted tests (not full freeze). `bash tests/run-all-tests.sh` only if a skill-sync or hook test requires it; prefer targeted first.

**Risks:** `brief-review.md` used as output summary (freeze rung-07 collision) — skill must say input brief vs `review.md` output.

---

## Wave 5 — Close-out verification

**Goal:** `silver:verify` can run without inventing criteria.

**Tasks:**

1. Re-run detection + string-contract tests.
2. Confirm Template A (code) and Template B (verify) still exist; Grok 4.5 High verify policy files untouched unless an accidental edit occurred (must not).
3. Design-time quality-gates leftovers: if SKILL.md grew, confirm include split or document waiver.
4. `graphify update .` after code/skill edits; agentmemory save.

**Acceptance:** all REQ/NFR mapped to a wave above.

**Verify commands (copy-paste for `/silver:verify`):**

```bash
bash tests/scripts/test-rfl-plan-document-detection.sh
rg -n "Template A-PLAN|Template A — Review-Only|Template B — Verify-Only" skills/silver-review-fix-ladder/
rg -n "cursor-grok-4.5-high" .cursor/rules/rfl-verify-grok-4.5-high.mdc
# Do NOT execute freeze YAML; do not git checkout / switch.
```

## Risk / rollback

| Risk | Handling |
|------|----------|
| Freeze appendix swallows standard checklist | Skill: appendix after body; tests assert checklist headings exist in skill/include |
| KEEP REJECT in standalone review-plan is nonsense | Wave 3 default: RFL-only in A-PLAN |
| Skill file size | Include file |
| Accidental Template B edit | REQ-07 grep in Wave 4–5 |

Rollback: revert the skill/test commit. No schema/data rollback.

## Assumptions surfaced from context

- Skill is canonical; script optional.
- CHARTER.md is not a plan document.
- This PLAN is implementation-ready; authoring pass must not apply Wave 2–4 yet.

## Unresolved questions

- Optional script emitter — not blocking; Wave 4 chooses.

## Mapping: acceptance criteria → waves

| Criterion | Wave |
|-----------|------|
| REQ-01 named A-PLAN | 2 |
| REQ-02 checklist | 2 |
| REQ-03 forbids | 2 |
| REQ-04 detection | 1 |
| REQ-05 review-plan align | 3 |
| REQ-06 brief emission | 4 |
| REQ-07 tests | 1, 4, 5 |
| REQ-08 delimiters | 2, 4 |
| REQ-09 model locks | 2 |
| NFR-01 size | 2 |
| NFR-02 injection | 4 |
| NFR-03 no freeze exec | 4, 5 |
| NFR-04 detection fixtures | 1 |
| NFR-05 extensibility | 2, 4 |
