---
verdict: PASS
overturns: n
sha: 22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc
role: apply_verify
pass: 1
model: composer-2.5
pre_apply_sha: 397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69
twins_identical: y
---

# verify_1-apply — Rung 07 Pi Claude Opus 5 High — pass 1

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY:** [`APPLY.md`](./APPLY.md) — full pack R7-F01–R13  
**Pre-APPLY SHA:** `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69`  
**Claimed post-APPLY SHA:** `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc`

## SHA and twin verification (independent)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` |
| Twin B SHA-256 | `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` |
| Claimed post-APPLY match | **MATCH** |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q`; single-hash uniqueness) |
| Freeze line count | 714 |

Twins:

- [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md)
- [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## R6 / KEEP REJECT regression check

| Check | Result |
|-------|--------|
| KEEP REJECT block (L41) | Present — two files; Clarify does not write SPEC; ingest stays |
| Wave 4 KEEP (L500, L524) | `Do not write SPEC.md`; **Ingest stays**; KEEP ingest clarify read-only |
| Wave 6 KEEP (L592) | Do not rewrite live root SPEC/REQUIREMENTS |
| Summary KEEP (L704) | Two files; no third canonical doc |
| R6n-F01 encoding refs | 23 occurrences — staged-pair lineage equality retained |
| R6b–R6f pair-install / exhaustion | Present in ID scheme, Step 7/8, Wave 2, Wave 6 |
| Spec-floor not tightened | R7-F02 explicitly KEEP: Overview + AC headings only |

No R6 or KEEP REJECT regression observed.

## Per-ID landed (independent native read)

Independent verification on post-APPLY twins at SHA `22187ebf…` against APPLY cites and review defects.

| ID | Sev | Landed | Independent check |
|----|-----|--------|-------------------|
| R7-F01 | HIGH | **y** | L170 sourced Invariants (Clarify `invariants` → Step 1/7; no fabricate; empty/scaffold FAIL QC-11/`SPEC-F73`); L308 Clarify always-on Invariants turn; L420 QC-11 sourced; L448/451 Step 1/7 duties; L507 Wave 4 capture + turn sequence |
| R7-F02 | HIGH | **y** | L172 ≥1 live `AC-nn` floor; L286 Functional floor; L421/L422 QC-8 empty-set FAIL; L452 Step 8 empty AC/Functional FAIL; L590 Wave 6 zero-AC fixture; spec-floor KEEP intact |
| R7-F03 | MED | **y** | L213/L257/L287 eligible = live non-tombstoned QA/SLO/CTRL on required + optional-present packs; tombstones excluded; SCAN not in set; L421/L452 reverse-coverage branches cite R7-F03 |
| R7-F04 | MED | **y** | L258/L287 SCAN resolution: live staged-SPEC heading + line/id; unresolvable FAIL before install; L421/L452 XART/review bindings |
| R7-F05 | MED | **y** | L288/L289 OOS/OQ snapshot closure = live non-tombstoned SPEC sets; L421/L452 Step 8 emit + fail-before-replace; QC-8/XART bound |
| R7-F06 | MED | **y** | L142/L195 `decision-count` YAML; L420 QC-12 iff `decision-count` ≥ 1; L451 Step 7 write; L507/L660 Wave 4 + OQ-04 pin; reviewers read SPEC YAML not brief |
| R7-F07 | MED | **y** | L131 spec-version grammar (int ≥1, coerce `1`/`"1"`, `v1`/`1.0` FAIL); L180 Change History comparator; L279/L282 REQUIREMENTS examples; L451 bump +1; R6n integer equality |
| R7-F08 | MED | **y** | L254/L307 named non-canonical `.planning/.spec-kind-migration.md`; L451/468 Step 7 migrate lifecycle; L581 Wave 6; L590 behavioral fixture; not third canonical doc |
| R7-F09 | LOW | **y** | L428 Wave 2 verify `rg` includes `nfr-source-cell-list\|id-tombstones\|QC-6b\|QC-4\|REQ-F30` |
| R7-F10 | LOW | **y** | L353 Wave 1 SPEC core-template asserts include `id-tombstones` (with REQUIREMENTS L354) |
| R7-F11 | LOW | **y** | L346/L355 `world-class-min` core-only exempt from kind-required packs; Wave 1b `kind-*` owns pack obligations |
| R7-F12 | NIT | **y** | L452 Step 8 fail-before-replace parenthetical closes before `Emit:`; file-wide parens balanced (1072/1072) |
| R7-F13 | NIT | **y** | Pack/kind tables use catalog enums `plugin-extension`, `infra-devops`, `headless-service`; no Notes shorthand (`plugin`, `infra`, `headless`) |

**Landed:** 13/13  
**Missing:** 0/13  
**Overturned:** 0/13

## Verdict

**PASS** — Post-APPLY SHA `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` matches claimed; twins byte-identical; all 13 R7 encodings independently confirmed; R6/KEEP REJECT encodings retained; no overturns.
