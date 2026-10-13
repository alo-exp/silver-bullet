# APPLY — rung 07 Pi Claude Opus 5 High pass 5 (rerun-5)

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer. Not Claude Extra High.  
**Disposition:** ACCEPT-apply — ordered pack **R7e-F01–R7e-F10** (1 HIGH, 2 MED, 4 LOW, 3 nit). **0 REJECT in this pass.** **R7b-F17 not encoded** (prior REJECT; KEEP REJECT / 9-turn left intact).  
**Pre-APPLY SHA-256:** `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33`  
**Post-APPLY SHA-256:** `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; no third canonical doc; **one 9-turn interview for every kind** wording left intact — F17 not encoded; interview not reopened). **R7d-F01–F12**, **R7c-F01–F16**, **R7b-F01–F16**, **R7-F01–F13**, and **R6\*** encodings retained. Spec-floor not tightened.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not launch pass 6 or Claude Extra High.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7e-F01 | HIGH | APPLIED | L427, L428, L458 | Reverse-coverage surfaces now **resolve `SCAN:` atoms before the eligible-set join** (same parser as Wave 1). Eligible `QA-nn` / `SLO-nn` / `CTRL-nn` targets count as in ≥1 NFR Source; non-eligible SCAN remains carve-out-only. Fixture: `SCAN:quality-attributes#QA-01` sole Source ⇒ `QA-01` reverse-covered, PASS. Do not weaken R5k. |
| R7e-F02 | MED | APPLIED | L73, L143, L198, L293 | `<line-or-id>` is live ID **or** section-anchored ordinal `b[0-9]{2}` for ID-less sections (`SCAN:invariants#b03` = third R7c-F03 counted bullet). Bare line numbers still FAIL `REQ-F71`. Do not mint `INV-nn`. Omitted-`nfr` kinds scan Invariants via ordinal, not a fabricated pack ID. |
| R7e-F03 | MED | APPLIED | L182, L426, L457, L516 | Change History summary provenance: (1) operator-supplied brief `change-summary` (not a turn — KEEP: interview not reopened); else (2) deterministic structural-delta sentence; else (3) ASK / fail-before-write. Fabricate never. Brief-less augment 2/3/4b MUST take (2) or (3). |
| R7e-F04 | LOW | APPLIED | L217, L284, L457, L458, L489 | Retired all five "`-00` is allocatable" sites. Parseable domain stays `00–99`; `-00` counts toward exhaustion but is **never minted**. Exhaustion FAIL when `01–99` are live or tombstoned **and** `-00` is live, tombstoned, **or absent** (never mint it). R6f fail-closed kept. |
| R7e-F05 | LOW | APPLIED | L437, L474, L599 | QC-string tests: count-mismatch FAIL (`decision-count: 2` / three live `DEC-nn` ⇒ `SPEC-F74`) + union-emission positive. Wave 3 verify names union emission (retain / append by identity / next-free). Wave 6: 2 preserved + 3 distinct brief + live Invariants ⇒ 5 live, `decision-count: 5`. |
| R7e-F06 | LOW | APPLIED | L599 | Wave 6 invariants-supersede fixture: path 2 with prior bullets B1, B2 and brief carrying only B1 PASSes only if B2 appends to retained `.planning/.spec-kind-migration.md` (R7c-F07); unresolved ⇒ fail before write; `invariant-count` = resulting live count. KEEP REJECT: not a third canonical doc. |
| R7e-F07 | LOW | APPLIED | L359 | Wave 1 SPEC core-template YAML assert list adds `spec-version` (R7-F07 grammar: integer ≥ 1; not `v1`, not `1.0`). |
| R7e-F08 | nit | APPLIED | L142 | Named `decision-row-identity`: trim; collapse whitespace runs; case-fold; strip surrounding emphasis and trailing punctuation; apply identically to brief and live rows. Fixture: same brief twice ⇒ `decision-count` unchanged. |
| R7e-F09 | nit | APPLIED | L195–L207 | Catalog-derived kind lists in pack-table Notes (`ux`, `examples`, `security`, `telemetry`, `api`, `data`, `errors`, `cli`, `mobile`, `pipeline`, `ops`) carry the same *derived from the current catalog, non-normative* tag as `nfr` (R7d-F10). `decision-log` Notes left as enforcement prose. L209 global "Notes MUST NOT derive YAML sets" unchanged. |
| R7e-F10 | nit | APPLIED | L359 | Core template example `invariant-count` MUST equal counted example `### Invariants` MUST/MUST NOT bullets (R7c-F03) and MUST be ≥ 1; example `decision-count` vs `## Decision Log` present iff ≥ 1 (R7c-F02). Assert in `test-spec-requirements-templates.sh`. |

**REJECT encoded:** none. **KEEP REJECT reopeners:** none. **F17:** confirmation — **not encoded**. **R7d-F01–F12 / R7c-F01–F16 / R7b-F01–F16 / R7-F01–F13 / R6\*:** not regressed.

**Skipped:** none of R7e-F01–F10 (all 10/10 ACCEPT residual at pin `74b9acf2…`; prior-hop R7d rows not re-encoded).

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` | `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` | `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` |
