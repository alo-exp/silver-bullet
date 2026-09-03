# CONTEXT — Clarify/Spec compiler factoring

Locked 2026-08-29. Do not reopen product decisions.

## Locked Ds

| ID | Decision |
|----|----------|
| D1 | Document-authoring pipeline is **Ingest → Clarify → Spec**. Do not fold ingest into spec. |
| D2 | **Clarify `next=spec`** owns **all interviewing** (today’s Spec Step 1 + Turns 1–9 + assumption protocol). Writes only `.planning/{plan-basename}-CLARIFY-*.md`. **Does not** write `SPEC.md` / `REQUIREMENTS.md`. |
| D3 | Clarify **default** (research, content, new-workflow, decide/compare) stays **light FLOW 3**. Do **not** attach the 9 spec turns. Need-profile interview stays on **AF-DECIDE** paths only. |
| D4 | **Spec is a compiler**: read newest clarify brief + ingest SPEC draft (if any). Write `.planning/SPEC.md`, then derive `.planning/REQUIREMENTS.md` from **SPEC AC** (not from the brief). |
| D5 | Spec **zero Socratic** unless a **required SPEC section is still empty** after compile (gap-fill only — not a second 9-turn tour). |
| D6 | Spec **must consume** the newest `*-CLARIFY-*.md`. Min-4 live turn-counter **dies**; replace with brief-domain completeness for `next=spec` (problem, scope, stories, AC) counted as covered. |
| D7 | **Ingest** stays MCP dump (SPEC ± DESIGN + `INGESTION_MANIFEST`). Next-step copy: run `/silver:clarify` (`next=spec`) then `/silver:spec`. Do not write `REQUIREMENTS.md` from ingest. |
| D8 | Version bump / augment detection unchanged. Conditional `DESIGN.md` unchanged. Run review-spec / review-requirements / review-design. |
| D9 | Invoke `next=spec` via `--spec` or `--next spec`, **and** auto-detect when `.planning/INGESTION_MANIFEST.md` exists and/or user/composition is heading to AF-SPECIFY. |
| D10 | Router `/silver` fuzzy-idea-with-no-SPEC stays on **light** clarify first. When the user then wants a spec, `next=spec` fills remaining spec domains (do not double Frame if already converged). |
| D11 | Feature plan lives at `.planning/clarify-spec-compiler/`. Do **not** clobber `.planning/rfl-plan-review-prompt/` or root v0.35 SPEC. |
| D12 | No freeze YAML. No git branch switch. No push/tag/release. No commit unless the user asked (they did not). |

## Capture schema (`next=spec` brief)

The timestamped clarify brief must be compilable into a review-spec-passing SPEC:

- Overview: who + problem
- ≥1 user story `As a… I want to… so that…`
- ≥1 testable acceptance criterion
- Assumptions with `Status:` (`Resolved` / `Accepted` / `Follow-up-required`)
- Out of scope
- Edges, errors, data
- Open questions

## Out of scope

- Inventing `/sb:fusion` or a new skill
- Changing chain-guard’s “feature without SPEC.md requires silver-spec marker” (spec still produces SPEC.md)
- Rewriting review-spec QC predicates
