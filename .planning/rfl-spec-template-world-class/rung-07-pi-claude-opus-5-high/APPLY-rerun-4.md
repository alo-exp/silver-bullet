# APPLY — rung 07 Pi Claude Opus 5 High pass 4 (rerun-4)

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer. Not Claude Extra High.  
**Disposition:** ACCEPT-apply — ordered pack **R7d-F01–R7d-F12** (2 HIGH, 3 MED, 4 LOW, 3 nit). **0 REJECT in this pass.** **R7b-F17 not encoded** (prior REJECT; KEEP REJECT / 9-turn left intact).  
**Pre-APPLY SHA-256:** `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e`  
**Post-APPLY SHA-256:** `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; no third canonical doc; **one 9-turn interview for every kind** wording left intact — F17 not encoded; interview not reopened). **R7c-F01–F16**, **R7b-F01–F16**, **R7-F01–F13**, and **R6\*** encodings retained. Spec-floor not tightened.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not launch pass 5 or Claude Extra High.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7d-F01 | HIGH | APPLIED | L142, L197, L457, L669 | Augment Decision Log is named **union emission** (preserved `DEC-nn` retained; new brief rows appended by ID-or-text identity with next-free `DEC-nn`). YAML `decision-count` = resulting live count, **not** `max`. Keep R7b-F06 non-deletion (≥ preserved). Fixture: 2 preserved + 3 distinct brief ⇒ 5 live, `decision-count: 5`, QC-12 PASS. |
| R7d-F02 | HIGH | APPLIED | L172, L599 | Generalized: **every** Wave 6 PASS-install fixture must supply Invariants via branch (1) brief or branch (2) live prior `### Invariants` (no ASK). Explicitly includes R7c-F05 malformed-`spec-version`, R6n lineage PASS-on-augment, and R6c commit-boundary augment — not only the two R7c-F01 fixtures. |
| R7d-F03 | MED | APPLIED | L516, L518 | Named non-turn provenance: `decisions` is operator-supplied brief field only, never interview-sourced. L515 “all 13 packs” corrected to **12 kind-gated packs** (+ `decision-log` via brief field). **Did not** add a Decision Log turn (KEEP: interview not reopened). |
| R7d-F04 | MED | APPLIED | L172, L457 | Branch (1) is a **superseding** write with no-silent-delete: prior live Invariants not carried forward append to retained `.planning/.spec-kind-migration.md` (R7c-F07) **or** ASK; fail before write if unresolved. KEEP REJECT: not a third canonical doc. |
| R7d-F05 | MED | APPLIED | L262, L293 | `SCAN:` whose `<line-or-id>` resolves to eligible `QA-nn` / `SLO-nn` / `CTRL-nn` **counts as forward coverage** of that ID (resolve atoms before eligible-set join). Carve-out reserved for non-eligible SCAN targets. Fixture: `SCAN:quality-attributes#QA-01` sole Source ⇒ `QA-01` reverse-covered, no dispositions row. Do not weaken R5k. |
| R7d-F06 | LOW | APPLIED | L434 | Wave 2 `rg` alternation adds `scan-section-slug\|conditionally-required`. |
| R7d-F07 | LOW | APPLIED | L473–L477 | Wave 3 `test-clarify-spec-compiler.sh` `- contains` bullets for Step 7 source-precedence + ASK fail-before-write, `invariant-count`/`decision-count` writes, `spec-version` seed + malformed-prior seed; migrate bullet now asserts **append** (R7c-F07). |
| R7d-F08 | LOW | APPLIED | L159, L209, L395 | `software-kinds.yaml` = **nine atomic** kinds only; `multi` is compile-time union / required-wins, excluded from Wave 1b set diff. `conditionally-required` predicate applies to the resolved kind (no `multi` YAML row). |
| R7d-F09 | LOW | APPLIED | L217, L457, L489, L599 | Sequential next-free **starts at `-01`**; `-00` is legal/parseable (legacy/hand-authored) and counts toward exhaustion but is **never minted**. Exhaustion fixtures restated as `EX-01`–`EX-99` plus `EX-00` present-or-tombstoned. R6f fail-closed kept. |
| R7d-F10 | nit | APPLIED | L198 | Pack-table `nfr` **Default class** cell is enum-only `**optional**`; catalog kind list moved to Notes as *derived from the current catalog, non-normative* (R7c-F15 / R7c-F16 pattern). |
| R7d-F11 | nit | APPLIED | L143 | `invariant-count` grammar: ≥ 1 on any installed SPEC; `0` parses but FAILs QC-11 / `SPEC-F73` (dead install state). No QC change. |
| R7d-F12 | nit | APPLIED | L73, L293, L427, L428, L437 | `SCAN:` atom: `<section>` / `<line-or-id>` contain no `#`; exactly one U+0023 `#` separates them; zero or ≥2 `#` FAIL `REQ-F71`. Fixture FAIL: `SCAN:a#b#c`. |

**REJECT encoded:** none. **KEEP REJECT reopeners:** none. **F17:** confirmation — **not encoded**. **R7c-F01–F16 / R7b-F01–F16 / R7-F01–F13 / R6\*:** not regressed.

**Skipped:** none of R7d-F01–F12 (all 12/12 ACCEPT residual at pin `fce83948…`; prior-hop R7c rows not re-encoded).

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` | `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` | `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` |
