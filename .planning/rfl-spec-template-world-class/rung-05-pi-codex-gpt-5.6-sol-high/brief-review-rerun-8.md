# Brief — Rung 05 review pass 8 (Pi Codex GPT-5.6 Sol High)

**Rung:** 5 of 8 — **eighth review pass** on this freeze (Policy F: GPT-5.6 Sol High streak is **1** after pass 7 CLEAN was recorded; this is consecutive CLEAN attempt **2**)
**Model:** GPT-5.6 Sol High — CHARTER slug `gpt-5.6-sol-high` via Pi Codex (`PI_PROVIDER=omniroute`). You **are** this named GPT. Never remap GPT onto Grok. Never substitute Cursor models. Never Extra High (`gpt-5.6-sol-xhigh` is rung 06 only, after streak == 2). Claude via Pi is later rungs (07–08).
**Host:** Pi Codex (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast. Not Cursor via Pi.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not launch verify. Do not advance to GPT-5.6 Sol XHigh or Claude.

Pass 1 history is **`review-rerun-1.md`**. Pass 2 history is **`review-rerun-2.md`**. Pass 3 history is **`review-rerun-3.md`**. Pass 4 history is **`review-rerun-4.md`**. Pass 5 history is **`review-rerun-5.md`**. Pass 6 history is **`review-rerun-6.md`**. Pass 7 history is **`review-rerun-7.md`**. Do **not** overwrite any of those. Do **not** create or clobber live `review.md`. Write **`review-rerun-8.md`** only.

## Why this pass exists

Pass 7 (`review-rerun-7.md`) was **CLEAN** (zero `R5g-F*`). `verify_1-rerun-7.md` PASS and `verify_2-rerun-7.md` PASS independently confirmed that CLEAN. Launcher recorded `--record-rung-review-outcome clean` → `consecutive_clean_reviews: 1`. Policy F still requires **two consecutive** CLEAN reviews on the **same** model before Extra High. This is **pass 8** — consecutive CLEAN attempt **2** on the same post-R5f freeze (SHA unchanged; no APPLY after pass 7). REJECT does not break the streak; any new ACCEPT resets it after APPLY.

**Independent re-hunt is mandatory.** Do **not** rubber-stamp pass 7. Do **not** copy `review-rerun-7.md`. Re-read the pinned freeze from scratch. Pass 7 is history, not authority. Residual only: do not re-file APPLYed IDs unless a residual defect remains in **this** freeze text. If you find a residual template-contract gap, file it as `R5h-F01+`. If you find none, say **CLEAN** with evidence from **this** pass’s freeze read.

Pass 1 (`review-rerun-1.md`) was NOT CLEAN (R5-F01–F03 ACCEPT-applied). Pass 2 (`review-rerun-2.md`) was NOT CLEAN (R5b-F01–F03 ACCEPT-applied). Pass 3 (`review-rerun-3.md`) was NOT CLEAN (R5c-F01–F03 ACCEPT-applied). Pass 4 (`review-rerun-4.md`) was CLEAN (zero `R5d-F*`) then broken by pass 5 ACCEPT. Pass 5 (`review-rerun-5.md`) was NOT CLEAN (R5e-F01 ACCEPT-applied). Pass 6 (`review-rerun-6.md`) was NOT CLEAN (R5f-F01 ACCEPT-applied). Pass 7 (`review-rerun-7.md`) was CLEAN (zero `R5g-F*`; streak now 1). Those APPLYs (through R5f) are already in this freeze.

Policy E: review the **world-class SPEC template + software-kind packs**. Not plan-hygiene unless hygiene breaks the template contract. Residual only — do not re-open APPLYed IDs unless a residual defect remains in **this** freeze text.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `e056076257a4ec1e7b6f85da3500d948feb1cf0551c58c6852aacaabff26cd10`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twins must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Do **not** mutate either twin. Do **not** patch live `templates/` or `skills/` as a substitute for freeze findings.

This SHA is **unchanged since R5f APPLY** (same pin as pass 7). Twins are byte-identical at this pin. No APPLY landed after pass 7.

## KEEP REJECT (do not reopen as goals)

- Two files only: SPEC.md + REQUIREMENTS.md
- Clarify does **not** write SPEC.md
- Ingest stays
- Do not merge kinds into a third canonical kind doc
- REQUIREMENTS.md stays the ID index (kinds may add NFR packs as **rows**, not a third file)

## Already APPLYed — do not re-open unless residual in THIS freeze

R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03, **R5-F01–F03**, **R5b-F01–F03**, **R5c-F01–F03**, **R5e-F01**, and **R5f-F01** are already in this freeze. Do **not** re-file those IDs unless a **residual defect remains in this freeze text**.

New finding IDs: **R5h-F01+** (pass 8 on this Pi model). Do **not** reuse `R5g-F*` or `R5f-F*` or `R5e-F*` or `R5d-F*`.

### Confirm R5 APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5-F01 HIGH | Wave 3 Step 7 and every Wave 6 augment branch (2, 3, 4b) run kind-reconciliation before write: preserve-body cannot keep forbidden/unlisted headings (e.g. `## UX Flows` after minting `cli`); migrate or ASK; fail-before-write if unresolved so the compiler cannot emit a SPEC that must fail `SPEC-F08`. Behavioral fixtures: generic-old-spec-with-UX → `cli`, plus a kind-change case. |
| R5-F02 MED | QC-6 required set is only `feature-slug` (kebab-case) + `software-kind` (catalog enum or `multi`), plus QC-6b `software-kinds` iff `multi`. `clarify-brief` optional/allowed-empty; `derived-requirements` stays a template default key (Wave 1 string assert) but is **not** QC-6 required. Step 7 writes the QC-6 keys. |
| R5-F03 MED | REQUIREMENTS NFR table has a `Source` column joining each `NFR-nn` to pack-local `QA-nn` / `SLO-nn` / `CTRL-nn` (or `SCAN:<section>#<line-or-id>`). Functional AC join stays Functional-only (R3-F02). Step 8 + review-requirements + XART encode the join. |

### Confirm R5b APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5b-F01 HIGH | Kind-aware QC-1 + new QC-12 (`SPEC-F74`) require required-pack **bodies** and catalog pack-local IDs (`EP-nn` / `CTRL-nn` / `SLO-nn` / `EX-nn` / etc.), not headings-only. `_TBD — Clarify skipped illegally_` is an audit ISSUE marker and **does not** satisfy QC-1. Heading-only / empty stub required packs FAIL. |
| R5b-F02 MED | QC-6b: `software-kinds` must be two+ **distinct atomic** catalog kinds (not `[cli]`, not `[multi, web-ui]`, not `[cli, cli]`, not unknown members). Validate before pack union; Turn 0 / Wave 1b negatives encode the same shape. |
| R5b-F03 MED | NFR Source (R5-F03) stays. Added **reverse coverage**: dropped SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` FAIL even when remaining NFR rows have valid Source. One-to-many / many-to-one allowed. Empty `None identified` only when no eligible SPEC sources exist. |

### Confirm R5c APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5c-F01 HIGH | Named **QC-13 / `SPEC-F75`** global ID-integrity: file-unique + exact two-digit shape for `US-nn` / `AC-nn` / `OQ-nn` / `OOS-nn` and present pack-local IDs (`ASM-nn` still optional). Duplicate `AC-01` FAIL Coverage Matrix / AC→REQ before coverage. Unlabeled US/OQ/OOS FAIL. Fixtures: dup `AC-01`, malformed IDs, unlabeled US/OQ/OOS. |
| R5c-F02 MED | QC-10 / `SPEC-F72` requires Change History **table** (columns spec-version, date, summary), a current YAML `spec-version` row, unique/ordered versions, and a non-placeholder summary. Heading-only / placeholder-only / stale-latest-row FAIL. Still not QC-1. |
| R5c-F03 MED | Reverse-NFR “recorded non-requirement disposition” is now `### Source Dispositions` (`| Source | Disposition | Rationale | Owner |`) with closed enum `not-requirement` \| `deferred` \| `duplicate` \| `out-of-scope`. Free prose is not a disposition. Dropped `QA-nn` / `SLO-nn` / `CTRL-nn` without NFR Source **or** exactly one valid dispositions row FAIL. `None identified.` forbidden while any eligible source is unresolved. |

### Confirm R5e APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5e-F01 MED | Wave 2 `review-requirements` **QC-2 / `REQ-F10`** requires exact `REQ-[0-9]{2}` and `NFR-[0-9]{2}` (two digits; **not** one-or-more digits). QC-3 uniqueness unchanged (not width). Step 8 mints sequential two-digit `REQ-nn` / `NFR-nn` and preserves existing valid two-digit IDs during augment. Coverage Matrix / ROADMAP parsers consume the same exact grammar. Fixtures: positive `REQ-01` / `NFR-01`; malformed-width negatives `REQ-1`, `REQ-001`, `NFR-2`, `NFR-0003` (also `tests/scripts/test-spec-req-id-parse.sh`). Phrase “one or more digits” must be **absent**. Aligns with template `REQ-nn`/`NFR-nn` and SPEC QC-13. |

### Confirm R5f APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5f-F01 MED | Catalog pack-local ID for required `examples` pack is exact two-digit `EX-nn`. Pack table, ID scheme, and QC-12/QC-13 prefix lists include `EX-nn`. Step 7 mints sequential `EX-[0-9]{2}` for present `## Examples` and preserves valid IDs. Wave 1b fixtures: `EX-01` on examples-required kinds (`library-sdk`, `http-api`, `cli`). QC fixtures: missing `EX-nn`, unlabeled Examples, malformed-width `EX-1`/`EX-001`, duplicate `EX-01`. Clarify brief `examples` may stay unnumbered; compiler mints at write time. |

Also still true from earlier APPLY: kind-aware QC-7 / `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); XART-F02 Step 4 Functional-only (`NFR-nn` exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`; Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Independent re-hunt (do not skip because pass 7 was CLEAN)

Re-scan the pinned freeze for **new** residual gaps that pass 7 could have missed. Hunt these classes even if you expect none; file only if evidence is in **this** freeze text:

1. Template contract: required vs optional headings; ID uniqueness/shape beyond QC-13 **and** QC-2 two-digit REQ/NFR **and** the `EX-nn` grammar (parser holes, Coverage Matrix / ROADMAP vs compiler mint, `P1–P3` vs ID width, other required packs still missing prefixes); GWT; invariants; Change History beyond QC-10; decision log; NFR reverse+forward; Source Dispositions vs `SCAN:` sources; security/telemetry/API/UX/data/errors packs.
2. Kind catalog + Clarify skip-turns: required-pack bodies (QC-12) including `EX-nn` vs **optional**-present Examples; `multi` union completeness; QC-6b vs catalog membership; `_TBD` vs QC-1; Step 7 mint/preserve vs unlabeled/malformed/duplicate `EX-*`.
3. Compiler/QC/tests/v0.35 lock: Wave 3 Step 7 vs Wave 6 branches 2/3/4b fail-before-write holes; named fault codes vs string-only asserts; Coverage Matrix vs unlabeled/dup AC; QC-2 exact-width vs any remaining “one or more digits” baseline leak; QC-12/QC-13 prefix lists vs pack table (any other required pack still without an ID).
4. Plan-hygiene last — only if it breaks the template contract.

Findings that improve the template contract are in scope even when the wave text is tidy. Do **not** invent findings to avoid a second CLEAN. Do **not** invent findings to force Extra High either.

## Tools (mandatory)

1. `graphify query "agent-pi invoke gpt-5.6-sol-high EX-nn examples QC-12"` (or a scoped template/kind-pack query) before exploring. Retrieve prior notes via Graphify, not raw agentmemory dumps.
2. Save session notes via agentmemory MCP `memory_save` when available.
3. After any code/doc writes in this work dir only: `graphify update .`

## Finding format

For each: ID (`R5h-F01+`), severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested freeze-text fix. Then: **CLEAN** or **NOT CLEAN**.

If CLEAN with no new gaps, say so explicitly with freeze SHA + twin check + residual-hunt notes. Do not claim ladder PASS or recommend Extra High. Do not `--record-rung-review-outcome` (parent records after verify).

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/review-rerun-8.md` only.
- Do **not** overwrite `review-rerun-1.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, `review-rerun-6.md`, or `review-rerun-7.md`.
- Do **not** write live `templates/` or `skills/` patches. Freeze-text suggestions belong in `review-rerun-8.md`.
- Do not create `review.md`. Do not launch verify. Do not APPLY. Do not `--record-rung-review-outcome`.
- Do not use Fast. Do not remap this GPT review onto Grok. Do not Extra High.

## FORBIDDEN

- Do NOT triage ACCEPT/REJECT, file issues, or apply fixes.
- Do NOT `git checkout` / `git switch` / change branches / commit.
- Do NOT claim ladder PASS or recommend advancing — parent verifies with Grok 4.5 High native Cursor (`verify_1` / `verify_2`) later.
- Do NOT launch subagents for Cursor-family models through Pi.
- EXIT 124 / timeout: stop. Do not `--continue`.
