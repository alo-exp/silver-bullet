# Rung 07 — Pi Claude Opus 5 High pass 8 — TRIAGE

**Triage worker:** Composer 2.5 High (RFL Triage, Policy A)  
**Review artifact:** [review-rerun-8.md](./review-rerun-8.md)  
**verify_1:** [verify_1-rerun-8.md](./verify_1-rerun-8.md) — **11 CONFIRMED / 0 NOT REPRODUCED / 0 NEEDS TRIAGE**  
**Verdict:** **NOT CLEAN** — 11/11 residuals **ACCEPT**, 0 **REJECT**  
**Pin:** `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085`

## Authenticity & pin

| Check | Result |
|-------|--------|
| Freeze SHA | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` matches pin |
| Twin [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md) | SHA match; 725 lines |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | SHA match; byte-identical |
| Review scope | Residual-only R7h-F01–F11; R7g-F01–F10 claimed landed — not re-filed; R7b-F17 REJECT — not re-filed |
| KEEP REJECT | Two files; Clarify never writes SPEC.md; ingest stays; no third canonical doc — intact |
| Freeze mutation this hop | **none** (triage-only; no APPLY) |

## Triage table

| ID | Sev | Disposition | One-line |
|----|-----|-------------|----------|
| R7h-F01 | MED | **ACCEPT** | L73/L457/L458 ordinal stability scoped to "ID-less section"; L73 R7g-F07 mixed Assumptions is ID-bearing yet `bNN`-citable — exempt from no-silent-repoint / re-anchor. |
| R7h-F02 | MED | **ACCEPT** | L457 Step 7 assigns re-anchor rewrite to staged SPEC only; ordinals live in REQUIREMENTS Source (Step 8); L458 fail-only — no owner for Source-cell rewrite; R6d fixed-point unstated. |
| R7h-F03 | MED | **ACCEPT** | L131 malformed-prior seed deletes cited version rows; L73 clause (c) has no stability/re-anchor terminal; L458 omits `v<integer>` unre-anchorable; L601 pins PASS path can dead-end `REQ-F71`. |
| R7h-F04 | MED | **ACCEPT** | L198 "sole" ID-less NF SCAN anchor contradicted by same-sentence "(or … ID-less heading slug + ordinal)"; L73 universal ID-less MUST (b) without counting grammar for non-Invariants/non-Assumptions sections. |
| R7h-F05 | MED | **ACCEPT** | L73 clause (b) counts "top-level bullet"; Assumptions exception counts "entries"; L175 bracketed shape not defined as bullet; L437 `#b02` PASS rests on undefined unit. |
| R7h-F06 | MED | **ACCEPT** | L73 per-entry MUST (a) for `ASM-nn` vs R7f-F10 stable-base rationale when cited entry later gains prefix; no FAIL/migrate/rewrite terminal — formerly valid `bNN` ⇒ `REQ-F71`. |
| R7h-F07 | LOW | **ACCEPT** | L217/L457/L491/L601 catalog-side `EX-00` present-or-tombstoned fixture vs R7g-F09 REQUIREMENTS `-00`-absent primary; compiler never mints `EX-00` so absent branch has no SPEC-side fixture. |
| R7h-F08 | LOW | **ACCEPT** | L427/L428 clause (c) `v<integer>` present; L434 Wave 2 `rg` alternation and L466–500 Wave 3 `- contains` omit `version-cell`/`v<integer>` — R7g-F04 test-surface lag class. |
| R7h-F09 | LOW | **ACCEPT** | L437 Assumptions PASS fixtures (`#ASM-01`, `#b02`) only; no negative asserting `SCAN:assumptions#b01` on `ASM-01` entry FAIL `REQ-F71`. |
| R7h-F10 | nit | **ACCEPT** | L197 `decision-log` Default class cell carries enum + scope + inline predicate vs L209 R7c-F15 five-class enum-only rule (R7d-F10 pattern on `nfr`). |
| R7h-F11 | nit | **ACCEPT** | L182 no-structural-change template uses unbound `N` and open `<reason>`; can emit placeholder-like text QC-10 must reject. |

## Freeze cites (accepted MED + order-dependent)

| ID | Primary cites |
|----|---------------|
| R7h-F01 | L73 (ordinal stability "ID-less section"; R7g-F07 per-entry Assumptions exception), L457 Step 7 re-anchor, L458 Step 8 fail-only precondition |
| R7h-F02 | L457 Step 7 (re-anchor + staged SPEC only), L458 Step 8 (fail precondition, no rewrite), L475 Wave 3 `- contains`, L601 `b03`⇒`b04` fixture |
| R7h-F03 | L73 clause (c) `v<integer>`, L131 malformed-prior seed, L427/L428 reviewer surfaces, L458 preconditions, L599–601 malformed-`spec-version` fixture |
| R7h-F04 | L198 `nfr` Notes ("sole" + escape hatch), L73 ID-less MUST (b), L172 Overview prose contract, R7g-F05 Invariants sole anchor |
| R7h-F05 | L73 "bullet" vs Assumptions "entries", L175 entry shape, L437 `#b02` PASS fixture |
| R7h-F06 | L73 per-entry MUST (a)/(b) adjacency to R7f-F10 stable-base, L175 optional `ASM-nn`, L437 mixed-section PASS only |

## ACCEPT pack (APPLY order)

`R7h-F01`, `R7h-F02`, `R7h-F03`, `R7h-F04`, `R7h-F05`, `R7h-F06`, `R7h-F07`, `R7h-F08`, `R7h-F09`, `R7h-F10`, `R7h-F11`

Order-dependent note: **F01 / F05 / F06** together (Assumptions mixed-section classification, entry counting unit, and post-prefix citation migration); **F02 / F03** together (Step 7/8 re-anchor ownership + clause-(c) version-cell stability across malformed-prior seed); **F04 / F05** next (ID-less SCAN grammar / Overview addressing); verify-surface **F07–F09** and pack-table/QC-10 nit **F10–F11** may follow when touching shared L73/L182/L197/L217/L427/L428/L437 surfaces. **F08** after **F03** if clause-(c) stability rules added. **F07** aligns with R7g-F09 REQUIREMENTS-side `-00`-absent primary when fixing catalog-side `EX-00` fixture.

## REJECT list

**none**

No KEEP REJECT collisions. `R7b-F17` (nine-turn interview numeric vs label) not re-filed. No ledger duplicate — R7h IDs are new residuals at pin `ba563660…` (post-R7g APPLY); ledger rows R7g-F01–F10 are prior-hop resolved, not re-ACCEPTed here. Review did not propose a third canonical doc, Clarify SPEC.md writes, or ingest removal. R7h-F03 proposed direction keeps migration record non-canonical; R7h-F04/F05 are grammar/addressing fixes, not new artifacts.

## Summary

- **Accepted:** 11 (5 MED, 4 LOW, 2 nit)  
- **Rejected:** 0  
- **Invalid / KEEP REJECT reopeners:** 0  
- **verify_2:** skipped (verify_1 PASS; triage complete)  
- **Next:** parent launches **Grok 4.6 High pack APPLY** on ACCEPT list above — **not** verify_2, **not** another Pi review
