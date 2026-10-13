# verify_1 — Rung 05 re-run pass 2 (Pi Codex GPT-5.6 Sol High)

**Verifier:** Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), native Cursor Task only.  
**Role:** RFL verify_1 (falsify/confirm reviewer findings). Not Reviewer. No APPLY. No branch switch. No commit.  
**Date:** 2026-08-30.  
**Review under test:** [`review-rerun-2.md`](review-rerun-2.md)  
**Brief:** [`brief-review-rerun-2.md`](brief-review-rerun-2.md)  
**Claim:** **NOT CLEAN** (1 HIGH / 2 MED; R5b-F01–F03). Parent triage: ACCEPT if confirmed.

## Freeze integrity

```
acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b  .planning/spec_template_world_class.plan.md
acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

| Check | Result |
|-------|--------|
| Expected SHA-256 | `acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b` |
| Live freeze | **MATCH** |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | **MATCH** same SHA; `cmp` byte-identical (59452 bytes, 659 lines) |
| Reviewer freeze SHA claim | Correct (not invented) |

**STOP condition:** not triggered. Branch unchanged (no switch). Did not APPLY. Did not mutate freeze / twins. Did not `--record-rung-review-outcome`. Did not launch verify_2. Did not invent or overwrite a live `review.md`.

## Method

- Graphify CLI first: `graphify query "spec_template_world_class R5b-F01 QC-1 pack body IDs QC-6b software-kinds NFR Source one-way"`.
- agentmemory `memory_save` at start + on verdict; `graphify update .` after this write.
- Independent freeze re-read of ontology / ID scheme / catalog `multi` / Wave 2 QC-1+QC-6b+NFR Source / Wave 3 Steps 7–8 / Wave 4 required-empty / KEEP REJECT.
- Re-checked against freeze SHA `acaae5f7…` only (post R5 APPLY).
- Did not rewrite freeze. Did not APPLY. Did not launch verify_2 or Pi. Did not `--record-rung-review-outcome`.
- Did **not** re-open R5-F01–F03; confirmed APPLY pins still present (residuals only where claimed).

## Per-finding verdicts

### R5b-F01 — HIGH — Kind-aware QC checks required pack headings, but not required pack bodies or pack-local IDs — **CONFIRMED**

| Claim | Freeze evidence |
|-------|-----------------|
| Kind-required QC is **heading presence** only | **L143**: “**kind-required** \| … \| Missing = ISSUE for that kind” |
| Compiler may emit `_TBD` for required+empty | **L147**: “Kind-required headings: compiler writes a real section from the brief, or a `_TBD — Clarify skipped illegally_` ISSUE rather than a fake happy path.” **L463**: “required + empty → `_TBD — Clarify skipped illegally_` ISSUE.” |
| Pack-local IDs are contractually required for structured packs | **L198**: “plus pack-local IDs (`ERR-nn` … `EP-nn` … `SLO-nn` … `CTRL-nn` … `QA-nn` …) — zero-padded two digits, unique in the file. … Every structured pack is ID-addressable” |
| Wave 2 QC-1 only unions **required `##` set** | **L398**: “**QC-1 is kind-aware:** required `##` set = **7 QC-1 core headings** … ∪ kind-required packs” |
| Named ID QC covers AC only | **L398**: “Add **QC-8:** every AC has `AC-nn` (`SPEC-F70`).” No pack-body / EP/CTRL/SLO shape QC |
| Optional-class placeholder rule is **not** applied to kind-required | **L144**: “**optional** \| … \| Absent = PASS; placeholder-only = ISSUE” — ontology does **not** attach the same executable placeholder-body ISSUE to kind-required; Wave 2 does not turn even the optional rule into a named pack-body `SPEC-F*` |

**Sharp path (reviewer):** `http-api` (or any kind with required packs) can have every kind-required `##` heading present with body `_TBD — Clarify skipped illegally_` and/or structured rows lacking `EP-nn` / `CTRL-nn` / `SLO-nn`. Heading-only QC-1 PASSes; QC-8 does not touch pack rows. Supported compiler path (**L147**, **L463**), not hand-edit only.

**Severity:** HIGH stands — required pack can “pass review” with no usable contract body. Not invented.

**Not a re-open of R5-F01:** that pin (kind-reconciliation / fail-before-write) is present (**L239**, **L429**, **L536**). This residual is pack **body/ID shape** after heading presence is satisfied.

**KEEP REJECT:** honored — suggested fix is reviewer/`SPEC-F*` + fixtures, not a third file.

---

### R5b-F02 — MED — `software-kinds` QC accepts lists that violate the catalog’s “Two+ of the above” contract — **CONFIRMED**

| Claim | Freeze evidence |
|-------|-----------------|
| Catalog `multi` means two+ atomic kinds | **L233**: “`multi` \| Two+ of the above \| union of listed `software-kinds` required packs …” |
| QC-6b only presence + non-empty | **L128**: “if `software-kind: multi` then `software-kinds` MUST be a **non-empty list**”; **L398**: “**QC-6b (R1-F10):** `software-kinds` present and non-empty iff `software-kind: multi`; absent otherwise” |
| No cardinality ≥2 / distinct / atomic / no-nested-`multi` rule in QC | Freeze text for QC-6b stops at non-empty; no “≥2 distinct atomic catalog kinds; reject `multi` member / unknown / duplicates” |

**Sharp path (reviewer):** `[cli]`, `[multi, web-ui]`, `[cli, cli]`, `[spaceship, cli]` all satisfy stated QC-6b non-empty while failing “Two+ of the above” / atomic-catalog membership. Pack union / forbid / Clarify skip / QC-1/QC-7 then become undefined or silently wrong while frontmatter review PASSes.

**Severity:** MED stands — metadata-shape residual beyond applied presence-iff (R5-F02). Not a re-open of dropping optional QC-6 keys; R5-F02 pin still present (**L126–L132**, **L398**).

**KEEP REJECT:** honored — keeps `multi`; tightens list shape only.

---

### R5b-F03 — MED — The applied NFR `Source` join validates NFR→SPEC provenance but not SPEC→NFR coverage — **CONFIRMED**

| Claim | Freeze evidence |
|-------|-----------------|
| Source column joins each NFR row → SPEC IDs | **L268**: “**Source (R5-F03):** each `NFR-nn` cites one or more pack-local IDs (`QA-nn`, `SLO-nn`, `CTRL-nn`) or `SCAN:…`” |
| Reviewer QC is forward-only | **L399**: “**NFR Source QC (R5-F03):** every `NFR-nn` row has a resolvable Source (`QA-nn` / `SLO-nn` / `CTRL-nn` / `SCAN:…`)” |
| Cross-artifact likewise cites Source on emitted rows | **L400**: “each row must cite that source in the Source column (R5-F03)” |
| Step 8 writes Source join on derived NFRs | **L430**: “NFR from Quality Attributes / kind NFR packs / scan with **Source** join to `QA-nn` / `SLO-nn` / `CTRL-nn` or `SCAN:…`” |
| No reverse “every eligible QA/SLO/CTRL appears in ≥1 NFR Source” | Absent in freeze (no bidirectional / dropped-source coverage clause) |

**Sharp path (reviewer):** compiler may omit `QA-02` or `SLO-01` from REQUIREMENTS while every remaining `NFR-nn` has a valid Source → all planned checks PASS; dropped SPEC NF obligations invisible.

**Severity:** MED stands — residual **directionality** gap in applied R5-F03, not a third file or Functional AC join on NFR. R5-F03 forward pin still present (**L198**, **L243**, **L268**, **L399–L400**, **L430**).

**KEEP REJECT:** honored — bidirectional coverage still one REQUIREMENTS NFR table / rows only.

---

## KEEP REJECT

Intact. Reviewer did not reopen as goals:

| KEEP | Still in this SHA? | Reviewer honor? |
|------|-------------------|-----------------|
| Two files (SPEC + REQUIREMENTS); no third canonical kind doc | Yes (**L41–L45**, **L245**, **L648**) | Yes — no third-file / merge-kinds finding |
| Clarify does not write SPEC.md | Yes (**L456**, **L480**, **L648**) | Yes |
| Ingest stays | Yes (**L456**, **L648**) | Yes |
| REQUIREMENTS stays ID index; kinds add NFR **rows** | Yes (**L243**, **L268**) | Yes — F03 extends Source coverage, not a new file |
| UX Flows not universal QC-1 | Yes (**L153**, **L398**) | Yes |

## Prior APPLY residual (pins still present; not re-filed)

| Pin | Live |
|-----|------|
| R5-F01 kind-reconciliation Wave 3 Step 7 + Wave 6 branches 2/3/4b; migrate/ASK; fail-before-write | **L239**, **L429**, **L536** |
| R5-F02 QC-6 only `feature-slug` + `software-kind`; QC-6b iff `multi`; optional `clarify-brief` / non-QC-6 `derived-requirements` | **L126–L132**, **L398** |
| R5-F03 NFR `Source` column + forward join Step 8 / reviewers | **L243**, **L268**, **L399–L400**, **L430** |
| Catalog-derived QC-7 / `SPEC-F61` (incl. multi / optional-omitted plugin) | **L241**, **L398**, **L409** |
| `XART-F02` Functional-only; NFR exempt from AC join | **L400** |
| Wave 3 Step 1 kind-aware mapping; Wave 2 named-code grep; present forbidden = `SPEC-F08` | **L426**, **L406**, **L145**/**L241**/**L398** |
| Wave 4 pack fields + `decisions`; real `nfr` turn | **L463**, **L469** |

No R5-F01–F03 IDs re-filed. R5b-* are residuals beyond those pins.

## Reviewer meta-checks

| Check | Result |
|-------|--------|
| Freeze SHA | Correct (`acaae5f7…9f79a5b`) |
| Twin PLAN byte-identical | Correct (59452 bytes) |
| Invented findings | **None** — all three grounded in freeze quotes |
| Severity dump | No — 1 HIGH / 2 MED fit evidence |
| NOT CLEAN verdict | **Sustained** — R5b-F01 alone blocks CLEAN |
| KEEP REJECT | Honored |
| Review-only | No implement / branch / commit / freeze mutation in `review-rerun-2.md` |
| Did not invent live `review.md` | Correct (`review-rerun-2.md` only) |
| Did not reopen R5-F01–F03 as goals | Correct — residuals only |

## Overall verdict

**verify_1 PASS** (findings confirmed; reviewer’s **NOT CLEAN** stands)

| ID | Sev | Verdict |
|----|-----|---------|
| R5b-F01 | HIGH | **CONFIRMED** |
| R5b-F02 | MED | **CONFIRMED** |
| R5b-F03 | MED | **CONFIRMED** |

Parent triage ACCEPT set matches freeze evidence. No FALSE findings. No REJECT of KEEP items. Ready for parent ACCEPT → APPLY (not performed here). Did not launch verify_2.

## Appendix — SHA

```
acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b  .planning/spec_template_world_class.plan.md
acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```
