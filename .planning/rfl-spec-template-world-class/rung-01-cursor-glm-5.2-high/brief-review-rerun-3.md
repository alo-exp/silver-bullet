# Brief — Rung 01 re-review pass 3 (Cursor GLM 5.2 High)

**Rung:** 1 of 8 — **re-run pass 3** (second consecutive GLM CLEAN attempt; pass 2 was CLEAN + verify_1-rerun-2 / verify_2-rerun-2 PASS; Policy F streak will be 1 after parent records pass 2)
**Model:** GLM 5.2 High (`glm-5.2-high` / `sb-glm-5-2-high`)
**Host:** Cursor (native; never Pi for Cursor-family)
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not overwrite `review.md`, `review-rerun-1.md`, or `review-rerun-2.md`. Do not launch verify. Do not `--record-rung-review-outcome`.

## Why this pass exists

Pass 2 was CLEAN. Parent records clean → streak 1. This pass is the second consecutive CLEAN attempt. If CLEAN (zero ACCEPT-worthy), parent records clean → streak 2 → then Kimi. If NOT CLEAN, APPLY then streak resets. Do **not** advance to Kimi from this worker.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twin must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Already APPLYed: R1-F01–F10, R2-F01–F06, R3-F01–F05, **R1b-F01–F03**. Do **not** re-open those IDs unless a **residual defect remains in this freeze text**. New IDs: **R1d-F01**, R1d-F02, …

KEEP REJECT: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third kind doc; do not drop REQUIREMENTS OOS/Open Items headings.

## Review this as plan + SPEC template + kind packs

Same as Policy E / CHARTER. Not plan-hygiene unless it breaks the template.

1. Template contract (required vs optional headings; IDs; GWT; invariants; change history; examples; decision log; NFR; security; telemetry; API; UX; data; errors).
2. Kind catalog + Clarify skip-turns.
3. Implementation waves (compiler, QC, tests, v0.35 lock).
4. Plan-hygiene last.

Confirm R1b APPLY still landed: QC-7 `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Finding format

For each: ID, severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested fix. Then: CLEAN or NOT CLEAN.

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-01-cursor-glm-5.2-high/review-rerun-3.md` only.
- Do not launch verify.
