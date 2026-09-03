# Brief — Rung 01 re-review pass 1 (Cursor GLM 5.2 High)

**Rung:** 1 of 8 — **re-run pass 1** (consecutive GLM CLEAN streak was 0)
**Model:** GLM 5.2 High (`glm-5.2-high` / `sb-glm-5-2-high`)
**Host:** Cursor (native; never Pi for Cursor-family)
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not overwrite `review.md`.

## Why this pass exists

The ladder skipped “re-run each rung until 2 consecutive reviews have zero valid (ACCEPT-worthy) findings.” Original GLM review was NOT CLEAN and was APPLYed, then the ladder moved to Kimi. This pass reviews the **current** freeze (post Gemini APPLY).

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twin must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Already APPLYed: R1-F01–F10, R2-F01–F06, R3-F01–F05. Do **not** re-open those IDs unless a **residual defect remains in this freeze text**. New IDs: **R1b-F01**, R1b-F02, …

KEEP REJECT: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third kind doc; do not drop REQUIREMENTS OOS/Open Items headings.

## Review this as plan + SPEC template + kind packs

Same as Policy E / CHARTER. Not plan-hygiene unless it breaks the template.

1. Template contract (required vs optional headings; IDs; GWT; invariants; change history; examples; decision log; NFR; security; telemetry; API; UX; data; errors).
2. Kind catalog + Clarify skip-turns.
3. Implementation waves (compiler, QC, tests, v0.35 lock).
4. Plan-hygiene last.

## Finding format

For each: ID, severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested fix. Then: CLEAN or NOT CLEAN.

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-01-cursor-glm-5.2-high/review-rerun-1.md` only.
- Do not launch verify.
