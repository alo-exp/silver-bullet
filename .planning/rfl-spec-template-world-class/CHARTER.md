# RFL — world-class SPEC template + software-kind packs

## Charter

- **Rungs:** 8 (no OpenCode).
- **Cursor rungs:** `glm-5.2-high`, `kimi-k3-high`, `gemini-3.7-flash-high`, `cursor-grok-4.6-high`.
- **Pi rungs:** `gpt-5.6-sol-high`, `gpt-5.6-sol-xhigh`, `claude-opus-5-high`, `claude-opus-5-xhigh`.
- **Verify:** Grok 4.5 High native Cursor Task only (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), **per rung** (`verify_1` then `verify_2`). Cursor-family models are never routed via Pi until Omni tool-call translation is fixed.
- **Claude:** Pi (`/silver:agent-claude` / `scripts/agent-claude/invoke.sh`). **GPT:** Pi Codex path. Never remap Claude/GPT onto Grok High.
- **Mode:** review-only for Policy C rungs. Rung workers do not implement; the launcher/parent applies ACCEPT fixes.
- **Policy F (HARD):** per rung (same model/effort) do **not** advance to the next ladder model until **two consecutive** reviews have **zero valid (ACCEPT) findings**. REJECT does not break the streak. ACCEPT → APPLY (after verify_1/verify_2) → streak resets to 0 → re-review the **same** model. Encoder: `--record-rung-review-outcome clean|accept-apply`; `--assert-rfl-advance --next-action next_rung_review` and `--assert-consecutive-clean` fail while `consecutive_clean_reviews` < 2.
- **Fast:** forbidden. No Grok 4.6 Extra High/XHigh as unspecified default.
- **Last completed rung:** none under Policy F. Rungs 01–03 original `review.md` files are **pass-1 history** only (each had ACCEPT-apply; streak never reached 2).
- **Current phase:** Rung 05 Pi Codex GPT-5.6 Sol High re-run pass 6 ACCEPT-apply on freeze SHA `e056076257a4ec1e7b6f85da3500d948feb1cf0551c58c6852aacaabff26cd10` (streak 0). Parent next step is **Pi GPT-5.6 Sol High pass 7** (same model — not Extra High). Do not clobber `rung-NN-*/review.md` pass-1 files; keep them as history.
- **Policy C:** after every rung, encoder-first (`--write-policy-c` then `--assert-policy-c`); paste encoder stdout. Canonical files: `rung-NN-*/POLICY-C.json` + `POLICY-C.md` (+ `policy-c-payload.json`).
- **Supersedes:** [`.planning/rfl-spec-requirements-structure/`](../rfl-spec-requirements-structure/) (discontinued 2026-08-29 after rung 04 APPLY). Do not continue that ladder.
- **Retro:** [RETRO-2-CONSECUTIVE-CLEAN.md](RETRO-2-CONSECUTIVE-CLEAN.md)

## Freeze

- **File:** `.planning/spec_template_world_class.plan.md`
- **SHA-256:** `e056076257a4ec1e7b6f85da3500d948feb1cf0551c58c6852aacaabff26cd10`
- **Byte-identical to:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- **Also read:** `.planning/spec-template-world-class/CONTEXT.md`

## Product

Make the **SPEC.md template** world-class for humans and AI, with **software-kind** frontmatter and section packs that compile in/out. REQUIREMENTS.md stays the ID index (kinds may add NFR packs as rows, not a third file).

KEEP REJECT: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; do not merge kinds into a third canonical doc.

## Review priority (every rung)

1. Template contract (required vs optional headings; IDs; GWT; invariants; change history; examples; decision log; NFR; security; telemetry; API; UX; data; errors).
2. Kind catalog + Clarify skip-turns.
3. Implementation waves (compiler, QC, tests, v0.35 lock).
4. Plan-hygiene last.

Findings that improve the template contract are in scope even when the wave text is tidy.
