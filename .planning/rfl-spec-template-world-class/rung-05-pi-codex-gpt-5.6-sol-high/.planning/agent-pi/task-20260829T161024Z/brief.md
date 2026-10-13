# Brief — Rung 05 review pass 2 (Pi Codex GPT-5.6 Sol High)

**Rung:** 5 of 8 — **second review pass** on this freeze (Policy F: GPT-5.6 Sol High streak is **0** after ACCEPT-apply)
**Model:** GPT-5.6 Sol High — CHARTER slug `gpt-5.6-sol-high` via Pi Codex (`PI_PROVIDER=omniroute`). You **are** this named GPT. Never remap GPT onto Grok. Never substitute Cursor models. Never Extra High (`gpt-5.6-sol-xhigh` is rung 06 only, after streak == 2). Claude via Pi is later rungs (07–08).
**Host:** Pi Codex (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not launch verify. Do not advance to GPT-5.6 Sol XHigh or Claude.

Pass 1 history is **`review-rerun-1.md`**. Do **not** overwrite it. Do **not** create or clobber live `review.md`. Write **`review-rerun-2.md`** only.

## Why this pass exists

Pass 1 (`review-rerun-1.md`) was **NOT CLEAN**: R5-F01 HIGH + R5-F02 MED + R5-F03 MED were ACCEPT-applied. verify_1-rerun-1 and verify_2-rerun-1 CONFIRMED. Policy F: ACCEPT → APPLY → streak **resets to 0**. This is **pass 2 of 2** consecutive CLEAN reviews required on the **same** model before Extra High. REJECT does not break the streak; any new ACCEPT resets it after APPLY.

Policy E: review the **world-class SPEC template + software-kind packs**. Not plan-hygiene unless hygiene breaks the template contract.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twins must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Do **not** mutate either twin. Do **not** patch live `templates/` or `skills/` as a substitute for freeze findings.

This SHA is **post R5 APPLY** (pre-APPLY was `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`).

## KEEP REJECT (do not reopen as goals)

- Two files only: SPEC.md + REQUIREMENTS.md
- Clarify does **not** write SPEC.md
- Ingest stays
- Do not merge kinds into a third canonical kind doc
- REQUIREMENTS.md stays the ID index (kinds may add NFR packs as **rows**, not a third file)

## Already APPLYed — do not re-open unless residual in THIS freeze

R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03, and **R5-F01–F03** (just APPLYed on this SHA) are already in this freeze. Do **not** re-file those IDs unless a **residual defect remains in this freeze text**.

New finding IDs: **R5b-F01+** (pass 2 on this Pi model).

### Confirm R5 APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5-F01 HIGH | Wave 3 Step 7 and every Wave 6 augment branch (2, 3, 4b) run kind-reconciliation before write: preserve-body cannot keep forbidden/unlisted headings (e.g. `## UX Flows` after minting `cli`); migrate or ASK; fail-before-write if unresolved so the compiler cannot emit a SPEC that must fail `SPEC-F08`. Behavioral fixtures: generic-old-spec-with-UX → `cli`, plus a kind-change case. |
| R5-F02 MED | QC-6 required set is only `feature-slug` (kebab-case) + `software-kind` (catalog enum or `multi`), plus QC-6b `software-kinds` iff `multi`. `clarify-brief` optional/allowed-empty; `derived-requirements` stays a template default key (Wave 1 string assert) but is **not** QC-6 required. Step 7 writes the QC-6 keys. |
| R5-F03 MED | REQUIREMENTS NFR table has a `Source` column joining each `NFR-nn` to pack-local `QA-nn` / `SLO-nn` / `CTRL-nn` (or `SCAN:<section>#<line-or-id>`). Functional AC join stays Functional-only (R3-F02). Step 8 + review-requirements + XART encode the join. |

Also still true from earlier APPLY: kind-aware QC-7 / `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); XART-F02 Step 4 Functional-only (`NFR-nn` exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`; Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Review this as plan + SPEC template + kind packs

Same as Policy E / CHARTER. Not plan-hygiene unless it breaks the template.

1. Template contract (required vs optional headings; IDs; GWT; invariants; change history; examples; decision log; NFR; security; telemetry; API; UX; data; errors).
2. Kind catalog + Clarify skip-turns.
3. Implementation waves (compiler, QC, tests, v0.35 lock).
4. Plan-hygiene last.

Findings that improve the template contract are in scope even when the wave text is tidy.

## Tools (mandatory)

1. `graphify query "agent-pi invoke gpt-5.6-sol-high spec_template_world_class R5-F01 SPEC-F08 QC-6 NFR Source"` (or a scoped template/kind-pack query) before exploring. Retrieve prior notes via Graphify, not raw agentmemory dumps.
2. Save session notes via agentmemory MCP `memory_save` when available.
3. After any code/doc writes in this work dir only: `graphify update .`

## Finding format

For each: ID (`R5b-F01+`), severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested freeze-text fix. Then: **CLEAN** or **NOT CLEAN**.

If CLEAN with no new gaps, say so explicitly.

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/review-rerun-2.md` only.
- Do **not** overwrite `review-rerun-1.md`.
- Do **not** write live `templates/` or `skills/` patches. Freeze-text suggestions belong in `review-rerun-2.md`.
- Do not create `review.md`. Do not launch verify. Do not APPLY. Do not `--record-rung-review-outcome`.
- Do not use Fast. Do not remap this GPT review onto Grok. Do not Extra High.

## FORBIDDEN

- Do NOT triage ACCEPT/REJECT, file issues, or apply fixes.
- Do NOT `git checkout` / `git switch` / change branches / commit.
- Do NOT claim ladder PASS or recommend advancing — parent verifies with Grok 4.5 High native Cursor (`verify_1` / `verify_2`) later.
- Do NOT launch subagents for Cursor-family models through Pi.
- EXIT 124 / timeout: stop. Do not `--continue`.