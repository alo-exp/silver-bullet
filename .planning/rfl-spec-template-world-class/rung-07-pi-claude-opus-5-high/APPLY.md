# APPLY — rung 07 Pi Claude Opus 5 High pass 1

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer.  
**Disposition:** ACCEPT-apply — full pack **R7-F01–R7-F13** (2 HIGH, 6 MED, 3 LOW, 2 NIT) as one ordered freeze edit.  
**Pre-APPLY SHA-256:** `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69`  
**Post-APPLY SHA-256:** `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; R7-F08 is a named **non-canonical** staging file, not a third canonical doc). **R6b–R6n** encodings retained (lineage, namespace, edge-set, grammars, staging/snapshot/fixed-point, exhaustion, 1b preserve-or-fail-closed). Spec-floor not tightened.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not launch pass 2 or Claude Extra High.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7-F01 | HIGH | APPLIED | L170, L308, L420, L448, L451, L452, L466, L507, L509 | Always-on Clarify Invariants turn + brief `invariants`; Step 1 maps to `### Invariants`; Step 7 writes sourced MUST/MUST NOT (no fabricate); empty/scaffold FAIL QC-11 / `SPEC-F73` before install. |
| R7-F02 | HIGH | APPLIED | L172, L286, L421, L422, L452, L590 | ≥1 live `AC-nn` and ≥1 Functional row on any installing pair; empty set is **not** vacuous QC-8 / R6l / R6k / XART-F02 PASS. True greenfield (both files absent) may still create a first pair; that pair must satisfy the floor. R5j 1b unchanged. Spec-floor KEEP intact. |
| R7-F03 | MED | APPLIED | L213, L258, L287, L421, L452 | Named **eligible NFR source**: live, non-tombstoned `QA-nn` / `SLO-nn` / `CTRL-nn` on required **and** optional-present packs. Tombstones excluded. `SCAN:` not in this set. |
| R7-F04 | MED | APPLIED | L258, L287, L421, L452 | `SCAN:<section>#<line-or-id>` resolution: live staged-SPEC heading + live line/id. Lexical grammar (R6i) necessary but not sufficient. Unresolvable `SCAN:` FAIL before install. |
| R7-F05 | MED | APPLIED | L288, L289, L421, L452 | REQUIREMENTS OOS / Open Items snapshots MUST equal live non-tombstoned SPEC `OOS-nn` / `OQ-nn` (unknown/tombstoned/invented/missing FAIL). Bound to QC-8 / XART / Step 8. |
| R7-F06 | MED | APPLIED | L142, L195, L420, L451, L507, L660 | YAML `decision-count` (not QC-6 required) is the QC-visible iff: `## Decision Log` present iff count ≥ 1. Reviewers read SPEC YAML, not the brief. |
| R7-F07 | MED | APPLIED | L131, L180, L279, L282, L451 | `spec-version` = positive integer ≥ 1; `1`/`"1"` coerce equal; YAML `v1`/`1.0` FAIL. Table cell = decimal string; human line = `v`+decimal. Ordered = strictly ascending; bump = +1; QC-10/R6n use integer comparator. |
| R7-F08 | MED | APPLIED | L254, L307, L451, L468, L581, L590 | Named **non-canonical** `.planning/.spec-kind-migration.md` (dotfile; not SPEC/REQUIREMENTS/KIND). Staging sibling; deleted after install or snapshot-restore FAIL. **KEEP REJECT:** not a third canonical doc. |
| R7-F09 | LOW | APPLIED | L428 | Wave 2 `rg` includes `nfr-source-cell-list\|id-tombstones\|QC-6b\|QC-4\|REQ-F30`. |
| R7-F10 | LOW | APPLIED | L353 | Wave 1 SPEC core-template asserts include `id-tombstones` (with REQUIREMENTS). |
| R7-F11 | LOW | APPLIED | L346, L355 | `world-class-min` is `software-kind: cli` **core-only exempt** from kind-required packs; Wave 1b `kind-*` owns pack obligations. |
| R7-F12 | NIT | APPLIED | L452 | Fail-before-replace parenthetical closed after lineage inequality (+ R7 floors); emit duties are a new sentence. Paren balance 60/60. |
| R7-F13 | NIT | APPLIED | L193, L196 | Pack-table Notes use catalog enum: `plugin-extension`, `infra-devops`, `headless-service`. |

**REJECT:** none. **KEEP REJECT reopeners:** none.

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69` | `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69` | `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` |
