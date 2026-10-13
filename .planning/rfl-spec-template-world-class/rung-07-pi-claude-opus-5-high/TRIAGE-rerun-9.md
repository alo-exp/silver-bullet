# Rung 07 — Pi Claude Opus 5 High pass 9 — TRIAGE

**Triage worker:** Composer 2.5 High (RFL Triage, Policy A)  
**Review artifact:** [review-rerun-9.md](./review-rerun-9.md)  
**verify_1:** [verify_1-rerun-9.md](./verify_1-rerun-9.md) — **11 CONFIRMED / 0 NOT REPRODUCED / 0 NEEDS TRIAGE**  
**Verdict:** **NOT CLEAN** — 11/11 residuals **ACCEPT**, 0 **REJECT**  
**Pin:** `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4`

## Authenticity & pin

| Check | Result |
|-------|--------|
| Freeze SHA | `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4` matches pin |
| Twin [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md) | SHA match; 726 lines |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | SHA match; byte-identical |
| Review scope | Residual-only R7i-F01–F11; R7h-F01–F11 claimed landed — not re-filed; R7b-F17 REJECT — not re-filed |
| KEEP REJECT | Two files; Clarify never writes SPEC.md; ingest stays; no third canonical doc — intact |
| Freeze mutation this hop | **none** (triage-only; no APPLY) |

## Triage table

| ID | Sev | Disposition | One-line |
|----|-----|-------------|----------|
| R7i-F01 | HIGH | **ACCEPT** | L73 offers migration-record re-anchor while KEEP REJECT marks it non-canonical / not QC-parsed; L131 deletes cited rows on malformed-prior seed; L602 pins PASS on unreachable clause-(c) re-anchor. |
| R7i-F02 | MED | **ACCEPT** | L73/L437 mandate clause-(a) `ASM-nn` citation; L217 keeps `ASM-nn` optional outside QC-13 shape/uniqueness; no tombstone rule or producer for R7h-F06 prefix-migration trigger. |
| R7i-F03 | MED | **ACCEPT** | L182/L602 mandate named no-structural-change sentence; L426 QC-10 placeholder-only FAIL has no admissibility whitelist; string absent from L437 reviewer asserts. |
| R7i-F04 | MED | **ACCEPT** | L426 QC-10 states brief `change-summary` provenance as reviewer obligation; adjacent QC-11 on same row is compiler-obligation with "Reviewers read SPEC YAML, not the brief." |
| R7i-F05 | LOW | **ACCEPT** | L428 XART eligible-ID join requires full SCAN resolve; `scan-section-slug` normalization at L73/L293/L427, absent at L428. |
| R7i-F06 | LOW | **ACCEPT** | L427 opens clause (b) as "ID-less sections" then narrows to Invariants/Assumptions only; contradicts L73 closed domain (Overview too broad; mixed Assumptions per-entry exception). |
| R7i-F07 | LOW | **ACCEPT** | L437 pins `decision-row-identity` and Assumptions per-entry fixtures; L434 Wave 2 `rg` alternation omits both — same test-surface-lag class as R7h-F08/R7d-F06 ACCEPTs. |
| R7i-F08 | LOW | **ACCEPT** | L500 Wave 3 QC-10 `- contains` cites generic structural-delta only; L182 named empty-delta clause, closed `<reason>` enum, and `N` binding unpinned in compiler skill. |
| R7i-F09 | nit | **ACCEPT** | L197 `decision-log` Default class cell is `**conditionally-required** (R7c-F15/R7h-F10)` vs L209 five-class enum-only rule — R7h-F10 APPLY residual, not already encoded. |
| R7i-F10 | nit | **ACCEPT** | L73 pins `b00` dead-value + fixed-width for clause (b); clause (c) `v<integer>` lacks canonical decimal form (`v01` vs `v1`) and no `v0`/non-positive dead-value rule. |
| R7i-F11 | nit | **ACCEPT** | L73/L175 exclude continuation/nested/non-conforming Assumptions lines from ordinal base; L437 has PASS + per-entry MUST negative only — exclusion half untested. |

## Freeze cites (accepted MED + order-dependent)

| ID | Primary cites |
|----|---------------|
| R7i-F01 | L73 (version-cell stability + migration-record parenthetical vs KEEP REJECT), L131 (malformed-prior seed deletes cited rows), L293/L427/L428 (clause (c) staged-SPEC resolution), L602 (pinned PASS re-anchor fixture) |
| R7i-F02 | L73/L175/L437 (`ASM-nn` clause-(a) MUST; mixed-section fixtures), L217 (QC-13 scope omits `ASM-nn` from enumerated prefixes), L457 (prefix migration trigger) |
| R7i-F03 | L182 (named no-structural-change sentence + closed `<reason>`), L426 (QC-10 placeholder-only), L437 (reviewer assert list), L602 (PASS install fixture) |
| R7i-F04 | L426 (QC-10 provenance chain vs QC-11 compiler-obligation caveat), L197 (`change-summary` has no SPEC YAML projection) |
| R7i-F05 | L428 (XART SCAN resolution import), L73/L293/L427 (`scan-section-slug`), L434 (Wave 2 `rg` cross-skill alternation) |
| R7i-F06 | L427 ("ID-less sections" vs closed Invariants/Assumptions-only), L73 (Overview not SCAN-addressable; per-entry Assumptions exception), L293/L428 (closed formulation already present elsewhere) |

## ACCEPT pack (APPLY order)

`R7i-F01`, `R7i-F02`, `R7i-F03`, `R7i-F04`, `R7i-F05`, `R7i-F06`, `R7i-F07`, `R7i-F08`, `R7i-F09`, `R7i-F10`, `R7i-F11`

Order-dependent note: **F01 / F10** together (clause-(c) `v<integer>` stability, canonical decimal, dead-value rules, and reachable re-anchor without non-canonical migration-record target); **F02 / F06** together (`ASM-nn` QC-13 shape/uniqueness/tombstone + prefix-migration producer); **F03 / F04 / F08** together (QC-10 admissibility, compiler-obligation provenance caveat, Wave 3 `- contains` binding for empty-delta branch); **F05 / F06 / F07** next (reviewer-surface SCAN grammar parity across `review-requirements` / `review-cross-artifact` / Wave 2 `rg`); nits **F09 / F11** when touching L197 pack table and L437 Assumptions fixtures. **F01** fix must preserve KEEP REJECT: migration record stays non-canonical — resolve via surviving canonical Change History row identity or fail-before-write / ASK, not a third parsed doc.

## REJECT list

**none**

No KEEP REJECT collisions. `R7b-F17` (nine-turn interview numeric vs label) not re-filed. No ledger duplicate — R7i IDs are new residuals at pin `892b263d…` (post-R7h APPLY); ledger rows R7h-F01–F11 are prior-hop resolved, not re-ACCEPTed here. Review did not propose a third canonical doc, Clarify SPEC.md writes, or ingest removal. R7i-F01 proposed direction keeps migration record non-canonical per L73 KEEP REJECT; R7i-F02–F11 are grammar/test-surface fixes within two-file scope.

## Summary

- **Accepted:** 11 (1 HIGH, 3 MED, 4 LOW, 3 nit)  
- **Rejected:** 0  
- **Invalid / KEEP REJECT reopeners:** 0  
- **verify_2:** skipped (verify_1 PASS; triage complete)  
- **Next:** parent launches **Grok 4.6 High pack APPLY** on ACCEPT list above — **not** verify_2, **not** another Pi review
