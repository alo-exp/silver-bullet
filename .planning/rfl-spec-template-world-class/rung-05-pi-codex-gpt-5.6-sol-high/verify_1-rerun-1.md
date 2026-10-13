# verify_1 — Rung 05 re-run pass 1 (Pi Codex GPT-5.6 Sol High)

**Verifier:** Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), native Cursor Task only.  
**Role:** RFL verify_1 (falsify/confirm reviewer findings). Not Reviewer. No APPLY. No branch switch. No commit.  
**Date:** 2026-08-30.  
**Review under test:** [`.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/review-rerun-1.md`](review-rerun-1.md)  
**Brief:** [`brief-review-rerun-1.md`](brief-review-rerun-1.md)  
**Claim:** **NOT CLEAN** (1 HIGH / 2 MED; R5-F01–F03). Parent triage: ACCEPT if confirmed.

## Freeze integrity

```
bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8  .planning/spec_template_world_class.plan.md
bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

| Check | Result |
|-------|--------|
| Expected SHA-256 | `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8` |
| Live freeze | **MATCH** |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | **MATCH** same SHA; `cmp` byte-identical (55746 bytes, 653 lines) |
| Reviewer freeze SHA claim | Correct (not invented) |

**STOP condition:** not triggered. Branch unchanged (no switch). Did not APPLY. Did not mutate freeze / twins. Did not `--record-rung-review-outcome`. Did not launch verify_2. Did not invent or overwrite a live `review.md`.

## Method

- Graphify CLI first: `graphify query "spec_template_world_class R5-F01 augment SPEC-F08 forbidden headings frontmatter QC-6 NFR source ID QA-nn SLO-nn"`.
- agentmemory `memory_save` at start + on verdict; `graphify update .` after this write.
- Independent freeze re-read of ontology / Wave 2 QC-6 / Wave 3 Steps 7–8 / Wave 6 augment / REQUIREMENTS NFR table / KEEP REJECT.
- Re-checked against freeze SHA `bb06eb8…` only.
- Did not rewrite freeze. Did not APPLY. Did not launch verify_2 or Pi. Did not `--record-rung-review-outcome`.

## Per-finding verdicts

### R5-F01 — HIGH — Augment preservation can keep forbidden pack headings so compiler emits SPEC that must fail SPEC-F08 — **CONFIRMED**

| Claim | Freeze evidence |
|-------|-----------------|
| Forbidden present = ISSUE (`SPEC-F08`) on new compiles | **L145**, **L241**, **L398** |
| Default compile: **omit** forbidden headings | **L147**: “Default compile rule: **omit forbidden headings** (no N/A stubs).” |
| Compiler omits forbidden + unlisted packs on concat | **L239**: “Omit forbidden packs **and unlisted packs** (R2-F03 closed-world).” |
| Step 7 concatenates required/optional packs; no kind-reconciliation | **L429**: “set frontmatter including `software-kind` … preserve `created` in augment … **concatenate kind-required packs** (and optional packs with brief content).” No strip/migrate of existing forbidden headings. |
| Wave 6 augment preserves body / extra sections when minting kind | **L528**: “preserve `created` and extra sections … If `software-kind` missing, mint from brief or ASK”; **L529** / **L531**: “mint frontmatter, **preserve body**” / “**preserve body**, mint missing structure” |
| `cli` forbids `ux` (`## UX Flows`) | Catalog **L226**: forbidden column includes `ux`; pack note **L180**: ux required only for web-ui/mobile (plugin optional); others omit |

**Sharp path (reviewer):** old template-shaped SPEC with `## UX Flows` + stories, no/`missing` `software-kind` → Wave 6 augment mints `software-kind: cli` and preserves body → output contains forbidden `## UX Flows` while QC requires `SPEC-F08` on new compiles. No freeze step reconciles existing pack headings against the newly resolved catalog before write.

**Not a re-open of R2-F05 / R3-F05:** those pins correctly define present-forbidden → `SPEC-F08`. Residual is the **interaction** with augment preservation — compiler is instructed to create the forbidden condition without a migration rule. HIGH severity stands. Not invented.

**Suggested fix scope (agree):** kind-reconciliation on Wave 3 Step 7 + Wave 6 augment branches; do not silently keep or silent-delete; fail-before-write if unresolved. Honors KEEP REJECT (still two files).

### R5-F02 — MED — Frontmatter lists more required keys than QC-6 / compiler / tests enforce — **CONFIRMED**

| Claim | Freeze evidence |
|-------|-----------------|
| Core template marks keys required | **L122–L130**: “Add (**required non-empty except as noted**)”; `feature-slug` kebab-case required; `software-kind` required closed enum; `clarify-brief` path or `""`; `derived-requirements` relative path with default |
| Wave 2 QC-6 only requires two keys | **L398**: “Extend QC-6: `feature-slug` **and** `software-kind` required.” No QC shape for kebab-case / enum membership / `clarify-brief` / `derived-requirements` presence |
| Wave 3 Step 7 write set narrower | **L429**: “set frontmatter including `software-kind` (and `software-kinds` iff `multi`)” — does not require writing `feature-slug`, `clarify-brief`, or `derived-requirements` |
| Wave 1 tests are presence greps only | **L333**: assert YAML keys `feature-slug`, `software-kind`, `derived-requirements` appear in template — not QC shape / not compiler write of all declared required keys |

Declared contract rejects malformed slug / unknown kind / missing provenance keys; planned QC and Step 7 do not enforce that shape. MED severity correct (contract inconsistency, not a silent greenfield crash alone). Not invented. Suggested fix (align Step 7 write set + QC-6/6b shape + tests) stays inside freeze text / two-file KEEP.

### R5-F03 — MED — REQUIREMENTS NFR rows have no source-ID join to pack-local QA-nn / SLO-nn / CTRL-nn — **CONFIRMED**

| Claim | Freeze evidence |
|-------|-----------------|
| Pack IDs are ID-addressable; QA maps to NFR | **L198**: “Every structured pack is ID-addressable … `QA-nn` maps to REQUIREMENTS `NFR-nn`.” Pack table lists `QA-nn`, `CTRL-nn`, `SLO-nn` (**L183–L192**) |
| NFR table columns have no Source | **L268**: ``## Non-Functional Requirements` — `| ID | Requirement | Metric | Priority |` — from Quality Attributes / kind NFR packs / scanned NF concerns.” |
| Narrative derivation only | **L400** (XART): “`NFR-nn` derive from SPEC `## Quality Attributes` (`QA-nn`), kind NFR packs (`SLO-nn`, `CTRL-nn`), or scanned NF concerns.” **L430** Step 8: “NFR from Quality Attributes / kind NFR packs / scan” |
| Functional AC join exists; NFR exempt with no replacement join | **L400**: XART-F02 Step 4 Functional-only; “Do **not** apply Step 4 to `NFR-nn`”; Coverage Matrix is AC↔REQ only |

No QC / column requires `NFR-03` → `QA-02` / `SLO-01` / `CTRL-04` (or a SCAN sentinel). Pack-local IDs stop at the SPEC boundary. MED stands — traceability hole under the stated ID-addressable contract, not a third-file proposal. Reviewer’s Source-column suggestion keeps REQUIREMENTS as the single ID index (KEEP intact). Not invented.

## KEEP REJECT

Intact. Reviewer did not reopen as goals:

| KEEP | Still in this SHA? | Reviewer honor? |
|------|-------------------|-----------------|
| Two files (SPEC + REQUIREMENTS); no third canonical kind doc | Yes (**L45**, **L245**) | Yes — F03 adds a column/rows, not a third file |
| Clarify does not write SPEC.md | Yes (**L47**, **L454**, **L480**) | Yes — no Clarify-writes-SPEC finding |
| Ingest stays | Yes (**L48**, **L454**) | Yes |
| REQUIREMENTS stays ID index; kinds add NFR **rows** | Yes (**L51**, **L243**) | Yes |

## Prior APPLY residual (pins still present)

| Pin | Live |
|-----|------|
| QC-7 / `SPEC-F61` catalog-derived `ux` forbidden (incl. multi / optional-omitted plugin) | **L241**, **L398**, **L409** |
| XART-F02 Functional `REQ-nn` only; `NFR-nn` exempt | **L400** |
| Wave 3 Step 1 kind-aware domain mapping | **L426** |
| Wave 2 `rg` includes QC-9/10 + SPEC-F71/F72/REQ-F70 + SPEC-F08 | **L406** |
| Present forbidden → `SPEC-F08` | **L145**, **L241**, **L398** |
| Wave 4 names kind-gated fields + `decisions` | **L239**, **L461**, **L480** |
| Blast-radius Clarify row is real `nfr` turn | **L288**, **L467** (per prior verify; not re-broken) |

No prior finding ID re-filed. R5-F01 is a residual interaction, not a duplicate of R2-F05/R3-F05.

## Reviewer meta-checks

| Check | Result |
|-------|--------|
| Freeze SHA | Correct (`bb06eb8…cbfaf8`) |
| Twin PLAN byte-identical | Correct (55746 bytes) |
| Invented findings | **None** — all three grounded in freeze quotes |
| Severity dump | No — 1 HIGH / 2 MED fit evidence |
| NOT CLEAN verdict | **Sustained** — R5-F01 alone blocks CLEAN |
| KEEP REJECT | Honored |
| Review-only | No implement / branch / commit / freeze mutation in `review-rerun-1.md` |
| Did not invent live `review.md` | Correct (`review-rerun-1.md` only) |

## Overall verdict

**verify_1 PASS** (findings confirmed; reviewer’s **NOT CLEAN** stands)

| ID | Sev | Verdict |
|----|-----|---------|
| R5-F01 | HIGH | **CONFIRMED** |
| R5-F02 | MED | **CONFIRMED** |
| R5-F03 | MED | **CONFIRMED** |

Parent triage ACCEPT set matches freeze evidence. No FALSE findings. No REJECT of KEEP items. Ready for parent ACCEPT → APPLY (not performed here).

## Appendix — SHA

```
bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8  .planning/spec_template_world_class.plan.md
bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```
