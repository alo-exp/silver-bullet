# Plan clarify-answers delta — 2026-08-25

Planning-only. No product code. Git stayed on `main`. Both plan copies stayed byte-identical. YAML: 23 original todos remain `pending`; added 3 pending todos. KEEP REJECT stayed closed except the locked FAST short-order amendment in KR-fast-overlay.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `cd7db06bc17f72df16a95800dbff90c9d9f22e084a377f3f6d2c96c703889f87` | 592212 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Start pair (confirmed before edits): `eb9c7bb0d9f584c199cd4a2e157129c21cb7b609d28ecd5d63eec8647944caba` / 583052 bytes.

## YAML todos

| Metric | Before | After |
|--------|--------|-------|
| Todo count | 23 | **26** |
| Status | all `pending` | all `pending` (none completed) |
| Added ids | — | `fast-short-quality-order`, `deep-research-reimplement`, `legacy-dr-deprecate` |

Frontmatter stayed compact (one-line `content:`).

## Locked decisions encoded

### Q1 — FAST / trivial / `/sb:improve`

FAST = classified-trivial (one concept). FAST is **required**; `/sb:fast` is the user-facing command. FAST is **not** a Job and **not** subject to Evolution or `/sb:improve`. FAST **does** run **Executor → Verifier → Validator** (not six-role Job order; not skip-all-quality). `/sb:improve` is **always a Job** (never FAST). Empty-tag no-op may fail-closed as a Job.

KR-fast-overlay amended: FAST still skips Job GST, Advisor-first plan, Board, composition-Val, Process-final-as-Job, evolution/improve; FAST **does** run the short order.

### Q2 — workstream owner — **A**

WS1 emit only (catalog/generator public routes). WS4 Job runtime for `/sb:improve` and `/sb:contribute`, plus FAST short-order runtime. WS7 docs/Doctor/site only (documents contribute; does not own the Job).

### Q3 — deep research

`WF-SILVER-DEEP-RESEARCH-MULTI-AI` → **`WF-DEEP-RESEARCH`**, fresh Job re-implementation with full Job quality order. Public **`/sb:deep-research`**. Current impl deprecated until retired as **`/sb:legacy-dr`**. `/silver:multi-ai-task` / `/sb:multi-ai-task` stay retired with **no alias**. Target architecture is **not** `AF-MULTI-AI-TASK`.

## Completeness (whole file)

Present after rewrite: all 23 original todo ids plus 3 adds; `/sb:improve`; `/sb:contribute`; `/sb:ladder`; `/sb:parallel`; `/sb:new-workflow`; `/sb:fast`; `/sb:deep-research`; `/sb:legacy-dr`; `WF-DEEP-RESEARCH`; Executor → Verifier → Validator FAST order; `WS0`; `WS0b`; `WS8`; `PUB-01`; `KLW-01`; `VAL/TST-RFL-625`; `additionalProperties: false`; `row 40`; `sb:agent-wrap`; `wbs-projector.sh`; `nested_executor`; `prompt_hash`; `context_refs_hash`; `GST-01`; `HNEST-01`; `HINST-01`; `WFM-01`; `test-sb-improve.sh`; `test-pre-impl-repo-hygiene.sh`; `test-sb-fast.sh`; `test-sb-deep-research.sh`; `test-sb-legacy-dr.sh`; every pre-existing `VAL/TST-RFL-*` id (27: `001` + `601`–`626`).

Unchanged KEEP REJECT: dual `/silver` forbidden; no `sb:agent-wrap`; no `/sb:multi-ai-task` alias; evolution general not per-user; contribute fail-closed if opt-out; catalog generated.

## 8-line MUST summary

1. FAST = classified-trivial; `/sb:fast` is required and is **not** a Job.
2. FAST short quality order is **Executor → Verifier → Validator** (not skip-all-quality).
3. FAST skips Job GST, Advisor-first plan, Board, composition-Val, Process-final-as-Job, Evolution/`/sb:improve`.
4. `/sb:improve` is always a Job; empty-tag no-op may fail-closed as a Job.
5. WS1 emits routes; WS4 owns improve/contribute Jobs and FAST short-order runtime; WS7 is docs/Doctor/site.
6. Deep research target is `WF-DEEP-RESEARCH` / `/sb:deep-research` (full Job quality order).
7. Current deep-research is `/sb:legacy-dr` until retired; no `/sb:multi-ai-task` alias.
8. Named execute-time tests: `test-sb-fast.sh`, `test-sb-deep-research.sh`, `test-sb-legacy-dr.sh`.
