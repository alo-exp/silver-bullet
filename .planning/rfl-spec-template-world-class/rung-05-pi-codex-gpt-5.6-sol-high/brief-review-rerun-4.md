# Brief — Rung 05 review pass 4 (Pi Codex GPT-5.6 Sol High)

**Rung:** 5 of 8 — **fourth review pass** on this freeze (Policy F: GPT-5.6 Sol High streak is **0** after ACCEPT-apply)
**Model:** GPT-5.6 Sol High — CHARTER slug `gpt-5.6-sol-high` via Pi Codex (`PI_PROVIDER=omniroute`). You **are** this named GPT. Never remap GPT onto Grok. Never substitute Cursor models. Never Extra High (`gpt-5.6-sol-xhigh` is rung 06 only, after streak == 2). Claude via Pi is later rungs (07–08).
**Host:** Pi Codex (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast. Not Cursor via Pi.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not launch verify. Do not advance to GPT-5.6 Sol XHigh or Claude.

Pass 1 history is **`review-rerun-1.md`**. Pass 2 history is **`review-rerun-2.md`**. Pass 3 history is **`review-rerun-3.md`**. Do **not** overwrite any of those. Do **not** create or clobber live `review.md`. Write **`review-rerun-4.md`** only.

## Why this pass exists

Pass 3 (`review-rerun-3.md`) was **NOT CLEAN**: R5c-F01 HIGH + R5c-F02 MED + R5c-F03 MED were ACCEPT-applied. verify_1-rerun-3 and verify_2-rerun-3 CONFIRMED. Policy F: ACCEPT → APPLY → streak **resets to 0**. This is **pass 4** toward **2 consecutive CLEAN** reviews required on the **same** model before Extra High. REJECT does not break the streak; any new ACCEPT resets it after APPLY.

Pass 1 (`review-rerun-1.md`) was NOT CLEAN (R5-F01–F03 ACCEPT-applied). Pass 2 (`review-rerun-2.md`) was NOT CLEAN (R5b-F01–F03 ACCEPT-applied). Those plus R5c are already in this freeze.

Policy E: review the **world-class SPEC template + software-kind packs**. Not plan-hygiene unless hygiene breaks the template contract. Residual only — do not re-open APPLYed IDs unless a residual defect remains in **this** freeze text.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `506eca57afb3ea2dad0c8c69b486a2c0f7c632ad33bbff40b1f0e82665272d1a`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twins must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Do **not** mutate either twin. Do **not** patch live `templates/` or `skills/` as a substitute for freeze findings.

This SHA is **post R5c APPLY** (pre-APPLY was `4a99ea1e75bfb3a0d364d365f61d2286ce1f82df1bd8070e12f599c1f1aa5374`; R5b APPLY SHA was that same `4a99ea1e…` blob).

## KEEP REJECT (do not reopen as goals)

- Two files only: SPEC.md + REQUIREMENTS.md
- Clarify does **not** write SPEC.md
- Ingest stays
- Do not merge kinds into a third canonical kind doc
- REQUIREMENTS.md stays the ID index (kinds may add NFR packs as **rows**, not a third file)

## Already APPLYed — do not re-open unless residual in THIS freeze

R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03, **R5-F01–F03**, **R5b-F01–F03**, and **R5c-F01–F03** (just APPLYed on this SHA) are already in this freeze. Do **not** re-file those IDs unless a **residual defect remains in this freeze text**.

New finding IDs: **R5d-F01+** (pass 4 on this Pi model).

### Confirm R5 APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5-F01 HIGH | Wave 3 Step 7 and every Wave 6 augment branch (2, 3, 4b) run kind-reconciliation before write: preserve-body cannot keep forbidden/unlisted headings (e.g. `## UX Flows` after minting `cli`); migrate or ASK; fail-before-write if unresolved so the compiler cannot emit a SPEC that must fail `SPEC-F08`. Behavioral fixtures: generic-old-spec-with-UX → `cli`, plus a kind-change case. |
| R5-F02 MED | QC-6 required set is only `feature-slug` (kebab-case) + `software-kind` (catalog enum or `multi`), plus QC-6b `software-kinds` iff `multi`. `clarify-brief` optional/allowed-empty; `derived-requirements` stays a template default key (Wave 1 string assert) but is **not** QC-6 required. Step 7 writes the QC-6 keys. |
| R5-F03 MED | REQUIREMENTS NFR table has a `Source` column joining each `NFR-nn` to pack-local `QA-nn` / `SLO-nn` / `CTRL-nn` (or `SCAN:<section>#<line-or-id>`). Functional AC join stays Functional-only (R3-F02). Step 8 + review-requirements + XART encode the join. |

### Confirm R5b APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5b-F01 HIGH | Kind-aware QC-1 + new QC-12 (`SPEC-F74`) require required-pack **bodies** and catalog pack-local IDs (`EP-nn` / `CTRL-nn` / `SLO-nn` / etc.), not headings-only. `_TBD — Clarify skipped illegally_` is an audit ISSUE marker and **does not** satisfy QC-1. Heading-only / empty stub required packs FAIL. |
| R5b-F02 MED | QC-6b: `software-kinds` must be two+ **distinct atomic** catalog kinds (not `[cli]`, not `[multi, web-ui]`, not `[cli, cli]`, not unknown members). Validate before pack union; Turn 0 / Wave 1b negatives encode the same shape. |
| R5b-F03 MED | NFR Source (R5-F03) stays. Added **reverse coverage**: dropped SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` FAIL even when remaining NFR rows have valid Source. One-to-many / many-to-one allowed. Empty `None identified` only when no eligible SPEC sources exist. |

### Confirm R5c APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5c-F01 HIGH | Named **QC-13 / `SPEC-F75`** global ID-integrity: file-unique + exact two-digit shape for `US-nn` / `AC-nn` / `OQ-nn` / `OOS-nn` and present pack-local IDs (`ASM-nn` still optional). Duplicate `AC-01` FAIL Coverage Matrix / AC→REQ before coverage. Unlabeled US/OQ/OOS FAIL. Fixtures: dup `AC-01`, malformed IDs, unlabeled US/OQ/OOS. |
| R5c-F02 MED | QC-10 / `SPEC-F72` requires Change History **table** (columns spec-version, date, summary), a current YAML `spec-version` row, unique/ordered versions, and a non-placeholder summary. Heading-only / placeholder-only / stale-latest-row FAIL. Still not QC-1. |
| R5c-F03 MED | Reverse-NFR “recorded non-requirement disposition” is now `### Source Dispositions` (`| Source | Disposition | Rationale | Owner |`) with closed enum `not-requirement` \| `deferred` \| `duplicate` \| `out-of-scope`. Free prose is not a disposition. Dropped `QA-nn` / `SLO-nn` / `CTRL-nn` without NFR Source **or** exactly one valid dispositions row FAIL. `None identified.` forbidden while any eligible source is unresolved. |

Also still true from earlier APPLY: kind-aware QC-7 / `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); XART-F02 Step 4 Functional-only (`NFR-nn` exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`; Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Review this as plan + SPEC template + kind packs

Same as Policy E / CHARTER. Not plan-hygiene unless it breaks the template.

1. Template contract (required vs optional headings; IDs; GWT; invariants; change history; examples; decision log; NFR; security; telemetry; API; UX; data; errors).
2. Kind catalog + Clarify skip-turns.
3. Implementation waves (compiler, QC, tests, v0.35 lock).
4. Plan-hygiene last.

Findings that improve the template contract are in scope even when the wave text is tidy.

## Tools (mandatory)

1. `graphify query "agent-pi invoke gpt-5.6-sol-high QC-13 SPEC-F75 QC-10 Change History Source Dispositions"` (or a scoped template/kind-pack query) before exploring. Retrieve prior notes via Graphify, not raw agentmemory dumps.
2. Save session notes via agentmemory MCP `memory_save` when available.
3. After any code/doc writes in this work dir only: `graphify update .`

## Finding format

For each: ID (`R5d-F01+`), severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested freeze-text fix. Then: **CLEAN** or **NOT CLEAN**.

If CLEAN with no new gaps, say so explicitly.

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/review-rerun-4.md` only.
- Do **not** overwrite `review-rerun-1.md`, `review-rerun-2.md`, or `review-rerun-3.md`.
- Do **not** write live `templates/` or `skills/` patches. Freeze-text suggestions belong in `review-rerun-4.md`.
- Do not create `review.md`. Do not launch verify. Do not APPLY. Do not `--record-rung-review-outcome`.
- Do not use Fast. Do not remap this GPT review onto Grok. Do not Extra High.

## FORBIDDEN

- Do NOT triage ACCEPT/REJECT, file issues, or apply fixes.
- Do NOT `git checkout` / `git switch` / change branches / commit.
- Do NOT claim ladder PASS or recommend advancing — parent verifies with Grok 4.5 High native Cursor (`verify_1` / `verify_2`) later.
- Do NOT launch subagents for Cursor-family models through Pi.
- EXIT 124 / timeout: stop. Do not `--continue`.
