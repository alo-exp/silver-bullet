# Brief — Rung 05 review pass 1 (Pi Codex GPT-5.6 Sol High)

**Rung:** 5 of 8 — **first review pass** on this freeze (Policy F: GPT-5.6 Sol High streak starts at **0**)
**Model:** GPT-5.6 Sol High — CHARTER slug `gpt-5.6-sol-high` via Pi Codex (`PI_PROVIDER=omniroute`). You **are** this named GPT. Never remap GPT onto Grok. Never substitute Cursor models. Claude via Pi is later rungs (07–08).
**Host:** Pi Codex (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not launch verify. Do not advance to GPT-5.6 Sol XHigh or Claude.

This is the **first Pi pass** on this ladder. There is no prior `review.md` for rung 05. Write **`review-rerun-1.md`** only (do not invent a live `review.md`).

## Why this pass exists

Cursor rungs 01–04 finished Policy F on this SHA (Grok 4.6 High two consecutive CLEAN). Per Policy F, this Pi model’s consecutive-CLEAN streak starts at **0**. This is **pass 1 of 2** consecutive CLEAN reviews required before the next Pi model (`gpt-5.6-sol-xhigh`). REJECT does not break the streak; any ACCEPT resets it after APPLY.

Policy E: review the **world-class SPEC template + software-kind packs**. Not plan-hygiene unless hygiene breaks the template contract.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twins must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Do **not** mutate either twin. Do **not** patch live `templates/` or `skills/` as a substitute for freeze findings.

## KEEP REJECT (do not reopen as goals)

- Two files only: SPEC.md + REQUIREMENTS.md
- Clarify does **not** write SPEC.md
- Ingest stays
- Do not merge kinds into a third canonical kind doc
- REQUIREMENTS.md stays the ID index (kinds may add NFR packs as **rows**, not a third file)

## Already APPLYed — do not re-open unless residual

R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03 are already in this freeze. Do **not** re-file those IDs unless a **residual defect remains in this freeze text**.

New finding IDs: **R5-F01+** (first Pi pass on this ladder).

## Review this as plan + SPEC template + kind packs

Same as Policy E / CHARTER. Not plan-hygiene unless it breaks the template.

1. Template contract (required vs optional headings; IDs; GWT; invariants; change history; examples; decision log; NFR; security; telemetry; API; UX; data; errors).
2. Kind catalog + Clarify skip-turns.
3. Implementation waves (compiler, QC, tests, v0.35 lock).
4. Plan-hygiene last.

Findings that improve the template contract are in scope even when the wave text is tidy.

Confirm prior APPLY still landed: kind-aware QC-7 / `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); XART-F02 Step 4 Functional-only (`NFR-nn` exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`; Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Tools (mandatory)

1. `graphify query "agent-pi invoke review-fix-ladder PI_MODEL gpt-5.6-sol spec_template_world_class"` (or a scoped template/kind-pack query) before exploring. Retrieve prior notes via Graphify, not raw agentmemory dumps.
2. Save session notes via agentmemory MCP `memory_save` when available.
3. After any code/doc writes in this work dir only: `graphify update .`

## Finding format

For each: ID (`R5-F01+`), severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested freeze-text fix. Then: **CLEAN** or **NOT CLEAN**.

If CLEAN with no new gaps, say so explicitly.

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/review-rerun-1.md` only.
- Do **not** write live `templates/` or `skills/` patches. Freeze-text suggestions belong in `review-rerun-1.md`.
- Do not create `review.md`. Do not launch verify. Do not APPLY. Do not `--record-rung-review-outcome`.
- Do not use Fast. Do not remap this GPT review onto Grok.

## FORBIDDEN

- Do NOT triage ACCEPT/REJECT, file issues, or apply fixes.
- Do NOT `git checkout` / `git switch` / change branches / commit.
- Do NOT claim ladder PASS or recommend advancing — parent verifies with Grok 4.5 High native Cursor (`verify_1` / `verify_2`) later.
- Do NOT launch subagents for Cursor-family models through Pi.
