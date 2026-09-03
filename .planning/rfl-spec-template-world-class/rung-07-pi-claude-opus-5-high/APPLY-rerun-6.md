# APPLY — rung 07 Pi Claude Opus 5 High pass 6 (rerun-6)

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer. Not Claude Extra High.  
**Disposition:** ACCEPT-apply — ordered pack **R7f-F01–R7f-F14** (1 HIGH, 4 MED, 5 LOW, 4 nit). **0 REJECT in this pass.** **R7b-F17 not encoded** (prior REJECT; KEEP REJECT / 9-turn left intact).  
**Pre-APPLY SHA-256:** `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d`  
**Post-APPLY SHA-256:** `e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; no third canonical doc; **one 9-turn interview for every kind** wording left intact — F17 not encoded; interview not reopened). **R7e-F01–F10**, **R7d-F01–F12**, **R7c-F01–F16**, **R7b-F01–F16**, **R7-F01–F13**, and **R6\*** encodings retained. Spec-floor not tightened.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not `--write-review-brief`. Did not launch Pi. Did not launch verify_2.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7f-F01 | HIGH | APPLIED | L182, L457, L599 | Branch (2) delta list now includes `spec-version` **seed**, Invariants add/remove/migrate, and `DEC-nn` append. Empty delta ⇒ named no-structural-change sentence (`version seeded to 1 (prior spec-version malformed); no structural changes`) so brief-less augment 2/3/4b never drops to ASK solely for ∅ delta. L599 malformed-prior PASS uses (2) including seed. Fabricate never. |
| R7f-F02 | MED | APPLIED | L427, L428 | `review-requirements` SCAN resolution mirrors L73/L293: `<line-or-id>` is (a) live ID **or** (b) section-anchored ordinal `b[0-9]{2}` for ID-less sections; ID-bearing MUST use (a); ID-less MUST use (b). `review-cross-artifact` same two-clause rule. Bare line numbers still FAIL `REQ-F71`. |
| R7f-F03 | MED | APPLIED | L217, L422, L427, L482, L484, L573, L582, L583, L584, L590, L647 | All `00–99`-live-or-tombstoned shorthand sites now use the single L217/L457 predicate: every `01–99` live or tombstoned **and** (`-00` live, tombstoned, or absent — never mint it). Parseable domain stays `00–99` at L217. Do not weaken R6f fail-closed, R7d-F09, or R7e-F04. |
| R7f-F04 | MED | APPLIED | L73, L293, L599 | Ordinal stability: mutate an ID-less section cited by live `SCAN:…#bNN` ⇒ re-anchor by `decision-row-identity`-style bullet-text match **or** fail-before-write / ASK. Wave 6 fixture: prior `SCAN:invariants#b03` + insert at position 1 ⇒ `b04` or fail; silent repoint FAIL. |
| R7f-F05 | MED | APPLIED | L131, L584, L587, L599 | Malformed-prior seed still writes exactly one canonical SPEC Change History row for version `1`, but prior human-authored rows MUST append to retained `.planning/.spec-kind-migration.md` **or** ASK; fail before write if unresolved. L599 PASS requires the `0.35` row in the migration record. KEEP REJECT: not a third canonical doc. |
| R7f-F06 | LOW | APPLIED | L142 | `decision-row-identity` is the **`decision` cell only** (not `date` / `why`). Live `DEC-nn` match with non-identical normalized `decision` text ⇒ fail before write (or ASK). Same-brief-twice idempotence kept; divergent-text fixture FAIL. |
| R7f-F07 | LOW | APPLIED | L314, L535 | `change-summary` added to Clarify blast-radius capture parenthetical and to the Wave 4 brief-field string-assert list. Not a turn (KEEP: interview not reopened). |
| R7f-F08 | LOW | APPLIED | L434 | Wave 2 `rg` alternation extended with `change-summary` and `section-anchored ordinal` (after F02/F07 landed). |
| R7f-F09 | LOW | APPLIED | L437, L497 | QC-string SCAN: `SCAN:invariants#b03` PASS (≥ 3 counted bullets); ordinal on ID-bearing section FAIL. Wave 3 `- contains` QC-10 now names summary provenance (brief `change-summary`; else structural-delta sentence; else ASK fail-before-write). |
| R7f-F10 | LOW | APPLIED | L73 | Ordinal enumeration: Overview top-level bullets excluding nested subsections; Change History is a table (cite `spec-version` cell, not `bNN`); Assumptions with `ASM-nn` = clause (a), without = counted bullets. |
| R7f-F11 | nit | APPLIED | L198 | `nfr` pack Notes re-delimited: `R7d-F10:*` → `R7d-F10:` so the derived/non-normative tag and kind list render. |
| R7f-F12 | nit | APPLIED | L143 | `invariant-count` is the **resulting live** post-compile MUST/MUST NOT count: (1) brief supersede; else (2) preserved live; else (3) ASK / fail-before-write. Not a brief-only or preserved-only source count. |
| R7f-F13 | nit | APPLIED | L73, L293 | Ordinals are **1-based**: `b00` parses but FAILs `REQ-F71`; index > 99 FAILs (no `b100`, no wrap). |
| R7f-F14 | nit | APPLIED | L361 | `world-class-min` asserts R7e-F10 equalities: `invariant-count` = counted R7c-F03 bullets and ≥ 1; `decision-count` = live `DEC-nn` and Decision Log present iff ≥ 1 (`cli` with no decisions ⇒ `decision-count: 0`, heading absent). |

**REJECT encoded:** none. **KEEP REJECT reopeners:** none. **F17:** confirmation — **not encoded**. **R7e-F01–F10 / R7d-F01–F12 / R7c-F01–F16 / R7b-F01–F16 / R7-F01–F13 / R6\*:** not regressed.

**Skipped:** none of R7f-F01–F14 (all 14/14 ACCEPT residual at pin `f5fda2ae…`; prior-hop R7e rows not re-encoded).

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` | `e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` | `e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1` |
