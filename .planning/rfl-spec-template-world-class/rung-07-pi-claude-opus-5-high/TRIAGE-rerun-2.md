# Rung 07 — Pi Claude Opus 5 High pass 2 — TRIAGE

**Triage worker:** Composer 2.5 High (RFL Triage)  
**Review artifact:** [review-rerun-2.md](./review-rerun-2.md)  
**Verdict:** **NOT CLEAN** — 16/17 residuals **ACCEPT**, 1 **REJECT**  
**Pin:** `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc`

## Authenticity & pin

| Check | Result |
|-------|--------|
| Freeze SHA | `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` matches pin |
| Twin [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md) | SHA match; 714 lines |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | SHA match; byte-identical |
| Review scope | Residual-only R7b-F01–F17; R7-F01–F13 claimed landed — not re-filed |
| KEEP REJECT | Two files; Clarify never writes SPEC.md; ingest stays; no third canonical doc — intact |

## Triage table

| ID | Sev | Disposition | One-line |
|----|-----|-------------|----------|
| R7b-F01 | HIGH | **ACCEPT** | L451 migration-record lifecycle deletes `.planning/.spec-kind-migration.md` on both install success and snapshot-restore FAIL, voiding L590 “user prose preserved” migrate-path claim. |
| R7b-F02 | HIGH | **ACCEPT** | L73/L287 `SCAN:<section>` forbids spaces but R7-F04 requires `<section>` equal a live heading — multi-word sections unreachable with no normalization rule. |
| R7b-F03 | HIGH | **ACCEPT** | L170/L451/L452 require brief-sourced Invariants with no brief-absent, preserve-on-augment, or legacy-preserve branch while L140 allows empty brief and Wave 6 paths 2/3/4b are brief-less. |
| R7b-F04 | MED | **ACCEPT** | L420 QC-11 “sourced from brief `invariants`” has no SPEC YAML projection unlike L195 `decision-count` precedent — reviewers cannot verify provenance. |
| R7b-F05 | MED | **ACCEPT** | L142/L195 QC-12 iff depends on `decision-count` but missing/malformed YAML key has no defined reviewer or fail-before-install behavior. |
| R7b-F06 | MED | **ACCEPT** | L142 derives `decision-count` only from brief `decisions`; brief-less augment yields 0 and forces legacy `## Decision Log` delete or QC-12 FAIL with no preserve rule. |
| R7b-F07 | MED | **ACCEPT** | L190–205 pack-table Notes omit optional/forbidden classes present in L237–248 catalog (e.g. `ops` on `http-api`), contradicting L389 “Notes must match the catalog”. |
| R7b-F08 | MED | **ACCEPT** | L258 R7-F03 `eligible` includes required-pack `CTRL-nn`; L198–250 make `security` required for 9/10 kinds while L354 still asserts unconditional empty-NFR `None identified` PASS. |
| R7b-F09 | LOW | **ACCEPT** | L157 ontology `optional` = “Absent = PASS” contradicts L195/L420 QC-12 iff requiring `## Decision Log` when `decision-count` ≥ 1 — no conditionally-required class. |
| R7b-F10 | LOW | **ACCEPT** | L172 R7-F02 ≥1-live-AC floor binds L286/L421/XART but L420 `review-spec` QC-8 (`SPEC-F70`) stays ID-shape-only with no ≥1 AC namespace check. |
| R7b-F11 | LOW | **ACCEPT** | L428 Wave 2 `rg` alternation omits landed tokens `decision-count`, `SCAN`, `eligible`, and `spec-version` while asserting other R7 encodings. |
| R7b-F12 | LOW | **ACCEPT** | L131 defines grammar/comparator/bump but no normative seed (`1`) for true greenfield path 1 or path-3 frontmatter mint (L272 example is non-normative). |
| R7b-F13 | LOW | **ACCEPT** | L353 Wave 1 core-template YAML asserts include `id-tombstones` but omit `decision-count` though L142 Step 7 always writes it and QC-12 depends on it. |
| R7b-F14 | LOW | **ACCEPT** | L346 `world-class-min` is `cli`; L354 `QA-01, SLO-01` example requires `SLO-nn` from forbidden `ops` pack on `cli` — only dedicated fixture branch is legal. |
| R7b-F15 | LOW | **ACCEPT** | L284 “Headings (QC-1 lock)” lists five headings including Coverage Matrix while L421 pins QC-1 at four — unfixed R1-F01 parallel on REQUIREMENTS side. |
| R7b-F16 | nit | **ACCEPT** | L452 fail-before-install gates (unresolvable `SCAN:`, OOS/OQ snapshot inequality, empty AC/Functional floor, Step 8 unsourced Invariants) lack `SPEC-F*`/`REQ-F*`/`XART-F*` codes per L256/L420. |
| R7b-F17 | nit | **REJECT** | L509 nine always-on turns vs L47 “9-turn interview” is numeric-only; L526/L703 already reject a kind-blind universal blob — no product-lock reopen, not a blocking defect. |

## Freeze cites (accepted HIGH)

| ID | Primary cites |
|----|---------------|
| R7b-F01 | L307, L451 (Kind-reconciliation migration record lifecycle), L590 (preserve-via-migration fixture) |
| R7b-F02 | L73, L287 (no-space atom + heading-equals resolution), L452 (`unresolvable SCAN:` fail-before-install) |
| R7b-F03 | L140 (brief optional), L170/L451/L452 (brief-only Invariants sourcing), L575–576 (brief-less augment paths) |

## Summary

- **Accepted:** 16 (3 HIGH, 6 MED, 6 LOW, 1 nit)  
- **Rejected:** 1 (R7b-F17 — cosmetic count collision already disambiguated at L526)  
- **Invalid / KEEP REJECT reopeners:** 0  
- **Next:** APPLY may address accepted findings; verify not launched from this hop.
