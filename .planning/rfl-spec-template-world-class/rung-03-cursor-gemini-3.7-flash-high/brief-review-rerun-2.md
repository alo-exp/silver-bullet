# Brief — Rung 03 re-review pass 2 (Cursor Gemini 3.7 Flash High)

**Rung:** 3 of 8 — **re-run pass 2** (second consecutive Gemini CLEAN attempt; pass 1 was CLEAN + verify_1-rerun-1 / verify_2-rerun-1 PASS; Policy F Gemini streak is 1 after parent records pass 1)
**Model:** Gemini 3.7 Flash High (`gemini-3.7-flash-high` / `sb-gemini-3-7-flash-high`)
**Host:** Cursor (native; never Pi for Cursor-family)
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not overwrite original `review.md` or `review-rerun-1.md`. Do not launch verify. Do not `--record-rung-review-outcome`.

## Why this pass exists

Pass 1 was CLEAN. Parent records clean → streak 1. This pass is the second consecutive CLEAN attempt. If CLEAN (zero ACCEPT-worthy), parent records clean → Gemini streak 2 → then Grok. If NOT CLEAN, APPLY then streak resets. Do **not** advance to Grok from this worker.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twin must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Already APPLYed: R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03. Do **not** re-open those IDs unless a **residual defect remains in this freeze text**. New IDs: **R3c-F01+**. KEEP REJECT unchanged.

KEEP REJECT: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third kind doc; do not drop REQUIREMENTS OOS/Open Items headings.

## Review this as plan + SPEC template + kind packs

Same as Policy E / CHARTER. Not plan-hygiene unless it breaks the template.

1. Template contract (required vs optional headings; IDs; GWT; invariants; change history; examples; decision log; NFR; security; telemetry; API; UX; data; errors).
2. Kind catalog + Clarify skip-turns.
3. Implementation waves (compiler, QC, tests, v0.35 lock).
4. Plan-hygiene last.

Confirm prior APPLY still landed: kind-aware QC-7 / `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); XART-F02 Step 4 Functional-only (`NFR-nn` exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`; Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Finding format

For each: ID, severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested fix. Then: CLEAN or NOT CLEAN.

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-03-cursor-gemini-3.7-flash-high/review-rerun-2.md` only.
- Do not overwrite `review-rerun-1.md`.
- Do not launch verify.
