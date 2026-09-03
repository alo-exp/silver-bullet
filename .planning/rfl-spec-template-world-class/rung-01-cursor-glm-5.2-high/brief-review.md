# Brief — Rung 01 (Cursor GLM 5.2 High) — review plan + SPEC template + kind packs

**Rung:** 1 of 8
**Model:** GLM 5.2 High (`glm-5.2-high`)
**Host:** Cursor (native; never Pi for Cursor-family)
**Role:** review-only (Policy C). Do not implement. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `8f17a38571e9d0c94598dcd2a2095f7eb65b9b2f202be50ce9d81390709f810f`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Also read: `.planning/spec-template-world-class/CONTEXT.md` and `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` (must be byte-identical to the freeze).

This ladder **supersedes** `.planning/rfl-spec-requirements-structure/` (discontinued 2026-08-29 after rung 04). Do not review that old freeze. Inherited R1–R4 APPLY pins are already in this plan; do not unwind them without a template-contract reason.

## Review this as plan + SPEC template + kind packs

You are **not** limited to plan-hygiene (wave mapping, GFM slugs, “path TBD”). Those are **secondary**.

Review **all three**:

1. **The implementation plan** — waves, compiler, clarify `--spec`, ingest, QCs, tests, v0.35 lock.
2. **The SPEC.md template itself as the primary product** — world-class for humans and AI: frontmatter, IDs, GWT, invariants, change history, examples, decision log, NFR/quality attributes, security, telemetry, API, UX, data, errors — what must exist vs optional.
3. **Software-kind tailoring** — `software-kind` frontmatter + section packs that compile in/out (web/UI, HTTP API, CLI, library/SDK, mobile, data/ML, infra/DevOps, plugin/extension, headless service, `multi`). Required / optional / forbidden headings per kind. How Clarify `--spec` asks only relevant turns. REQUIREMENTS.md stays the ID index; kinds may add NFR packs. No third canonical doc.

**Findings that improve the template contract are in scope** even if the wave text is already tidy. Plan-hygiene is secondary.

Skills: `skills/review-plan/SKILL.md` (PLAN-F IDs) **and** treat the “Target structure — SPEC.md” / kind catalog tables as the product under review, not as decoration. `skills/silver-review-fix-ladder/SKILL.md` Template A.

KEEP REJECT (do not violate): two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; do not merge kinds into a third canonical doc; do not drop REQUIREMENTS OOS/Open Items headings.

## Finding format

For each: ID, severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested fix. Then: CLEAN or NOT CLEAN. Do not reject as "documentation nit" when it is a contract hole. Do not spend the review on hygiene if the catalog or required/optional ontology is wrong.

## Tools

- Graphify first (`graphify query`); agentmemory save; Context Mode for large analysis; PathJail for `skills/`.
- Nested Tasks if any: `cursor-grok-4.6-high` except this review is `glm-5.2-high`. No Fast. No Grok 4.6 Extra High as unspecified default.

## Output

Write the official review to `.planning/rfl-spec-template-world-class/rung-01-cursor-glm-5.2-high/review.md` only.
