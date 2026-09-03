# Brief — Rung 04 re-review pass 1 (Cursor Grok 4.6 High)

**Rung:** 4 of 8 — **re-run pass 1** (Policy F: Grok streak starts at 0 on this SHA)
**Model:** Grok 4.6 High (`cursor-grok-4.6-high` / `sb-grok-4-6-high`)
**Host:** Cursor (native; never Pi; never Fast; never Extra High / XHigh)
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not launch verify. Do not advance to Pi GPT.

No original Grok `review.md` exists (rung 04 was **paused** during the Policy F retro from GLM). Do **not** invent pass-1 history. This file pair (`brief-review-rerun-1.md` / `review-rerun-1.md`) is the first Grok review on the **current** freeze.

## Why this pass exists

Gemini just completed **two consecutive CLEAN** reviews on this freeze. Per Policy F, Grok’s consecutive-CLEAN streak starts at **0**. Earlier Grok 04 was paused (never reviewed this SHA). This worker reviews the **current** freeze — not plan-hygiene.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twins must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Already APPLYed: R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03. Do **not** re-open those IDs unless a **residual defect remains in this freeze text**. New IDs: **R4b-F01+**.

KEEP REJECT: two files; Clarify ≠ SPEC writer; ingest stays; no third kind doc.

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

- Official review: `.planning/rfl-spec-template-world-class/rung-04-cursor-grok-4.6-high/review-rerun-1.md` only.
- Do not create or overwrite a Grok `review.md` (none exists; do not invent paused pass-1 history).
- Do not launch verify. Do not advance to Pi GPT.
