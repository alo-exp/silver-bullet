# Brief — Rung 01 (Cursor GLM 5.2 High) — review-plan

**Rung:** 1 of 8
**Model:** GLM 5.2 High (`glm-5.2-high`)
**Host:** Cursor (native; never Pi for Cursor-family)
**Role:** review-only (Policy C). Do not implement. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML.

## Freeze (pin this SHA)

- **File:** `.planning/spec_requirements_structure.plan.md`
- **Expected SHA-256:** `8f8a0d58aa11cc9cf23419ecc8eae73b9ae64cf25ff7c7365e7fc7c89d4beb74`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Also read: `.planning/spec-requirements-structure/CONTEXT.md`, `SPEC.md`, `REQUIREMENTS.md`, `phases/01-world-class-artifacts/PLAN.md` (should be byte-identical to the freeze).

## Review this as a PLAN

- `skills/review-plan/SKILL.md` (PLAN-F IDs, structured PASS/ISSUES_FOUND).
- `skills/silver-review-fix-ladder/SKILL.md` Template A (plan-doc emphasis: contract vs waves, KEEP REJECT, GFM slugs, test citations, contradictions, missing owners).
- `.planning/rfl-plan-review-prompt/` SPEC is **not live** — apply its intent: freeze SHA in appendix; KEEP REJECT as finding surface; Policy C rungs are review-only.

## Product

Make `SPEC.md` + `REQUIREMENTS.md` world-class for humans and AI. KEEP REJECT: two files stay; Clarify does not write SPEC; ingest stays; do not drop OOS/Open Items headings.

## Finding format

For each: ID, severity HIGH|MED|LOW|NIT, location (heading/wave), evidence quote, why it matters, suggested fix. Then: CLEAN or NOT CLEAN. Do not reject as "documentation nit" when it is a contract hole.

## Tools

- Graphify first (`graphify query`); agentmemory save; Context Mode for large analysis; PathJail for `skills/`.
- Nested Tasks if any: `cursor-grok-4.6-high` except this review is `glm-5.2-high`. No Fast.

## Output

Write the official review to `.planning/rfl-spec-requirements-structure/rung-01-cursor-glm-5.2-high/review.md` only.
