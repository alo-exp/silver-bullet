# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 14

**Disposition:** ACCEPT-apply (**R6n-F01 MED**; review [review-rerun-14.md](review-rerun-14.md) + [TRIAGE-rerun-14.md](TRIAGE-rerun-14.md) ACCEPT + [verify_1-rerun-14.md](verify_1-rerun-14.md) PASS).  
**Pre-APPLY SHA-256 (both twins):** `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458`  
**Post-APPLY SHA-256 (both twins):** `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69`  
**Twins byte-identical after APPLY:** **yes**  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md).

**KEEP REJECT:** unchanged (L701 still two files; Clarify does not write SPEC; ingest stays — Wave 4).

Did **not** run `--record-rung-review-outcome`. Did **not** launch Claude or Extra High pass 15. Did not switch branches. Did not commit. Did not implement templates/skills.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6n-F01 MED | APPLIED | Named **staged-pair lineage equality:** fail-closed parse-and-compare of staged REQUIREMENTS YAML (`derived-from`, `spec-version`, `feature-slug`, `software-kind`) and human `**Derived from:**` against the exact staged SPEC before install. QC-6 is no longer presence-only (`derived-from` **or** human line). Human/YAML agreement required. `multi` keeps staged SPEC QC-6b `software-kinds` authoritative (exact list equality if REQUIREMENTS mirrors). Bound to Wave 2 QC-6 / XART (before orphan/coverage), Step 8 serialize+parse, 7a/8a fixed-point, compiler asserts, and Wave 6 paths 1/1b/2/3/4b. Matching pair PASS; independently stale `spec-version` / wrong `feature-slug` / wrong `software-kind` / wrong `derived-from` / contradictory human-line/YAML FAIL, no install. R6m-F01 QC-7 exact-ID + NFR Metric, R6l-F01 namespace/set equality, R6k-F01 `coverage-matrix-req-cell-list` + edge-set, and R6j-F01/F02 left intact. |

**REJECT:** none.

## Freeze line cites (post-APPLY)

| Surface | Line | Content |
|---------|------|---------|
| Locked-contract named contract | **L82** | **staged-pair lineage equality** (R6n-F01): parse both exact staged artifacts; YAML `derived-from` identifies staged SPEC; human/YAML agree; exact `spec-version` / `feature-slug` / `software-kind`; fail closed |
| Locked-contract Step 8/XART/QC-6 bind | **L83** | Bind to Wave 2 QC-6 parse-and-compare, XART before orphan/coverage, Step 8, 7a/8a fixed-point, Wave 6 1/1b/2/3/4b |
| ID scheme | **L212** | Staged-pair lineage equality; QC-6 parse-and-compare, not presence-only; do not weaken R6m |
| Target frontmatter + human line | **L280** | Dual-emit YAML + `**Derived from:**`; equality vs staged SPEC before install |
| Wave 1 template | **L351** | Emit both YAML and human line; Wave 2/3/6 own equality fixtures |
| Wave 2 inherited pins | **L407** | `R6n-F01` |
| QC-6 (`review-requirements`) | **L418** | Parse-and-compare, not `derived-from` **or** human line; mismatch fixtures |
| XART (`review-cross-artifact`) | **L419** | Lineage check **before** orphan/coverage |
| Wave 2 string test | **L425**, **L428** | `staged-pair lineage equality` / `derived-from` in `rg` + Name fixtures |
| Wave 2 risks | **L430** | QC-6 MUST parse-and-compare; do not leave presence-only |
| Wave 3 inherited pins | **L439** | `R6n-F01` Step 8 / XART / QC-6 |
| Step 8 work | **L449**, **L450** | Serialize+parse lineage; fail-before-replace on inequality; 7a/8a two-clean-passes |
| Compiler verify | **L484** | Contains QC-6 staged-pair lineage equality fixtures |
| Wave 6 inherited pins | **L561** | `R6n-F01` |
| Wave 6 paths 1/1b/2/3/4b | **L570**–**L575**, **L578** | Named equality on all install paths; 1b no longer advisory reconcile |
| Wave 6 behavioral | **L587** | Matching PASS; independently stale/wrong/contradictory FAIL, no install |
| Risks | **L641** | New presence-only QC-6 risk row |

R6m-F01 remains **L80**–**L81**. R6l-F01 remains **L78**–**L79**. R6k-F01 remains **L76**–**L77**. R6j-F01 remains **L74**; R6j-F02 remains **L75**.
