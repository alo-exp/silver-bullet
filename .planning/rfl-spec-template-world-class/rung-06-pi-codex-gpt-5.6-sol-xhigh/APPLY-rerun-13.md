# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 13

**Disposition:** ACCEPT-apply (**R6m-F01 MED**; review [review-rerun-13.md](review-rerun-13.md) + [TRIAGE-rerun-13.md](TRIAGE-rerun-13.md) ACCEPT + [verify_1-rerun-13.md](verify_1-rerun-13.md) PASS).  
**Pre-APPLY SHA-256 (both twins):** `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0`  
**Post-APPLY SHA-256 (both twins):** `364594469c19a7127b93f5d39a01b539a62f407e0a10940b2edab0faa2d05458`  
**Twins byte-identical after APPLY:** **yes**  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md).

**KEEP REJECT:** unchanged (L697 still two files; Clarify does not write SPEC; ingest stays — Wave 4 L494).

Did **not** run `--record-rung-review-outcome`. Did **not** launch Claude or Extra High pass 14. Did not switch branches. Did not commit. Did not implement templates/skills.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6m-F01 MED | APPLIED | **QC-7 two-mode exact-ID:** ID-bearing staged pairs map Source Consistency by exact Functional `AC` ↔ live staged-SPEC `AC-nn` (same join as QC-8/R6l). Do **not** fuzzy-match “same observable outcome” on a removed `Acceptance Criterion` column. Fail closed. Prose fallback **legacy-only**. **NFR Metric measurability** kept on Wave 2 QC-4 test surface: `fast` FAIL / `p95 <= 200 ms` PASS; Functional `REQ-F30` no-fire on valid `AC-nn` unchanged. Bound to Wave 2 `review-requirements` / XART, Step 8 serialize+parse, compiler/migration fixtures. R6l-F01 namespace/set equality, R6k-F01 `coverage-matrix-req-cell-list` + edge-set, and R6j-F01/F02 left intact. |

**REJECT:** none.

## Freeze line cites (post-APPLY)

| Surface | Line | Content |
|---------|------|---------|
| Locked-contract QC-4 NFR Metric | **L72** | NFR `Metric` measurability retained; `fast` FAIL / `p95 <= 200 ms` PASS |
| Locked-contract QC-7 two-mode | **L80** | Exact-ID Source Consistency for ID-bearing pairs; prose fallback legacy-only; fail closed |
| Locked-contract Step 8/XART bind | **L81** | Bind QC-7 exact-ID + NFR Metric to Wave 2 / Step 8 / XART / compiler tests |
| ID scheme | **L210** | QC-7 exact-ID + NFR Metric; do not weaken R6l |
| Target `## Functional Requirements` | **L282** | QC-7 exact-ID join (not GWT paraphrase of `AC-01`) |
| Target `## Non-Functional Requirements` | **L283** | Live `Metric` cells measurable under QC-4 |
| Wave 1 template | **L349** | NFR `Metric` header + measurable example; Wave 2 owns `fast`/`p95` fixtures |
| Wave 2 inherited pins | **L405** | `R6m-F01` |
| QC-7 (`review-requirements`) | **L416** | Two-mode exact-ID + NFR Metric fixtures |
| XART (`review-cross-artifact`) | **L417** | Exact-ID before leftover fuzzy text |
| Wave 2 string test | **L423**, **L426** | `exact-ID` / `legacy-only` / `NFR Metric` / `p95` in `rg` + QC-string Name |
| Wave 2 risks | **L428** | review-requirements QC-7 exact-ID; do not drop NFR Metric |
| Wave 3 inherited pins | **L437** | `R6m-F01` Step 8 / XART / QC-7 |
| Step 8 work | **L447**, **L448** | Serialize+parse exact-ID; non-measurable Metric cannot install; 7a/8a two-clean-passes |
| Compiler verify | **L480**, **L481** | Contains QC-7 two-mode + NFR Metric fixtures |
| Wave 6 inherited pins | **L558** | `R6m-F01` |
| Wave 6 behavioral | **L584** | Exact-ID PASS without GWT paraphrase; fuzzy FAIL; `fast`/`p95` fixtures |
| Risks | **L621**, **L637** | QC-7 prose fallback **legacy-only**; new QC-7/NFR Metric risk row |

R6l-F01 remains **L78**–**L79**. R6k-F01 remains **L76**–**L77**. R6j-F01 remains **L74**; R6j-F02 remains **L75**.
