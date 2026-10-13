# Rung 07 — Pi Claude Opus 5 High pass 3 — TRIAGE

**Triage worker:** Composer 2.5 High (RFL Triage)  
**Review artifact:** [review-rerun-3.md](./review-rerun-3.md)  
**Verdict:** **NOT CLEAN** — 16/16 residuals **ACCEPT**, 0 **REJECT**  
**Pin:** `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7`

## Authenticity & pin

| Check | Result |
|-------|--------|
| Freeze SHA | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` matches pin |
| Twin [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md) | SHA match; 720 lines |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | SHA match; byte-identical |
| Review scope | Residual-only R7c-F01–F16; R7b-F01–F16 claimed landed — not re-filed; R7b-F17 REJECT — not re-filed |
| KEEP REJECT | Two files; Clarify never writes SPEC.md; ingest stays; no third canonical doc — intact |

## Triage table

| ID | Sev | Disposition | One-line |
|----|-----|-------------|----------|
| R7c-F01 | HIGH | **ACCEPT** | Invariants precedence branch (3) `ASK` has no non-interactive terminal (`fail-before-write` unlike kind-reconciliation ASK), blocking two pinned brief-less Wave 6 fixtures that assert PASS install. |
| R7c-F02 | MED | **ACCEPT** | `decision-count` is QC-visible count language but QC-12 only gates heading presence iff ≥ 1 — no live-`DEC-nn` equality unlike `invariant-count`. |
| R7c-F03 | MED | **ACCEPT** | `invariant-count` exact equality (`SPEC-F73`) gates on undefined MUST/MUST NOT bullet grammar — no per-line rule or `INV-nn` anchor. |
| R7c-F04 | MED | **ACCEPT** | R7b-F14 `QA-01, SLO-01` parser fixture on `infra-devops`/`headless-service` necessarily carries required-pack `CTRL-nn`, making the pinned positive fixture fail its own neither-branch rule. |
| R7c-F05 | MED | **ACCEPT** | R7b-F12 seeds absent `spec-version` only; present-but-malformed prior values on augment paths 2/4b have no seed, bump, or fail-before-write branch. |
| R7c-F06 | MED | **ACCEPT** | Fifth ontology class `conditionally-required` (`decision-log` predicate) cannot be expressed in `software-kinds.yaml`, the sole machine source declared at L212. |
| R7c-F07 | MED | **ACCEPT** | Retained `.planning/.spec-kind-migration.md` is a fixed path with default overwrite semantics — second migration destroys first preserved prose; no append/rotate rule. |
| R7c-F08 | MED | **ACCEPT** | `SCAN:` normalization ("collapse non-alphanumerics to `-`") is ambiguous on runs, edges, and trim — legitimate citations can hit fail-closed `REQ-F71`. |
| R7c-F09 | LOW | **ACCEPT** | `SCAN:<line-or-id>` bare line half has no base, stability, or revalidation rule — contradicts stable-ID contract at L217. |
| R7c-F10 | LOW | **ACCEPT** | L437 named QC-string test assert list omits `SPEC-F70`, `REQ-F71`, `REQ-F72`, `XART-F03`, and conditionally-required/`decision-count: 0` direction though L435 `rg` alternation includes them. |
| R7c-F11 | LOW | **ACCEPT** | L361 `world-class-min` fixture assert list not updated with `decision-count` / `invariant-count` keys added to L359 template asserts by R7b-F13. |
| R7c-F12 | LOW | **ACCEPT** | Wave 4 verify asserts mandatory `nfr` turn for nfr-required kinds but has no equivalent always-on assert for the Invariants turn (L515). |
| R7c-F13 | LOW | **ACCEPT** | L360 requires the REQUIREMENTS template to contain both a live measurable `Metric` row and `None identified` empty-NFR example — mutually exclusive states on one artifact. |
| R7c-F14 | nit | **ACCEPT** | L159 `conditionally-required` ontology row emits bare "ISSUE" with no `SPEC-F*` code, violating L260/L426 bare-ISSUE rule. |
| R7c-F15 | nit | **ACCEPT** | Pack table Default class column uses non-enum vocabulary (`kind-gated`, `always required`) while R7b-F07 de-normativized only Notes. |
| R7c-F16 | nit | **ACCEPT** | R7b-F08 catalog-derived "in practice only `cli`" conclusion restated as normative prose in six places — second-source-of-truth hazard R7b-F07 removed from Notes. |

## Freeze cites (accepted HIGH + order-dependent MED)

| ID | Primary cites |
|----|---------------|
| R7c-F01 | L172 (Invariants precedence ASK), L258/L457 (kind-reconciliation `fail before write`), L596 (generic-old-spec + R7b-F06 brief-less augment fixtures assert PASS) |
| R7c-F04 | L360–L361 (dedicated parser fixture), L246/L249 (catalog `security` required), L293/L427 (eligible + neither-branch), L596 (`web-ui`/`CTRL-01` FAIL fixture) |
| R7c-F05 | L131 (grammar + seed for absent only), L579–L586 (Wave 6 tree paths 2/4b bump) |

## Summary

- **Accepted:** 16 (1 HIGH, 7 MED, 5 LOW, 3 nit)  
- **Rejected:** 0  
- **Invalid / KEEP REJECT reopeners:** 0  
- **Next:** APPLY may address accepted findings as an order-dependent pack (F01/F04/F05/F11/F13 first); verify not launched from this hop.
