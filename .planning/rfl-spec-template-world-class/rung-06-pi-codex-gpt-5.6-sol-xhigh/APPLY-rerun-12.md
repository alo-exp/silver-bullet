# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 12

**Disposition:** ACCEPT-apply (**R6l-F01 MED**; review [review-rerun-12.md](review-rerun-12.md) + [TRIAGE-rerun-12.md](TRIAGE-rerun-12.md) ACCEPT + [verify_1-rerun-12.md](verify_1-rerun-12.md) PASS).  
**Pre-APPLY SHA-256 (both twins):** `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94`  
**Post-APPLY SHA-256 (both twins):** `91652845956169f878a53bb184ccd6e4d4403f03a3e3c9cd803bdf360bf8b5e0`  
**Twins byte-identical after APPLY:** **yes**  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md).

**KEEP REJECT:** unchanged (L692 still two files; Clarify does not write SPEC; ingest stays — Wave 4 L490).

Did **not** run `--record-rung-review-outcome`. Did **not** launch Claude or Extra High pass 13. Did not switch branches. Did not commit. Did not implement templates/skills.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6l-F01 MED | APPLIED | Fail-closed **live staged-SPEC AC namespace closure**: every Functional and Coverage Matrix `AC-nn` MUST resolve to a unique **live** staged-SPEC `AC-nn` (not tombstoned, not invented). **Coverage AC set equality:** `distinct(Functional.AC) = distinct(Matrix.AC) = live staged-SPEC AC set`. QC-8 bidirectional (`REQ-F70` also FAIL on unknown/tombstoned/invented AC). Bound to QC-8, `review-cross-artifact` (before orphan/coverage), Step 8 serialize+parse, fixed-point, compiler/migration fixtures. Negative fixture: SPEC only `AC-01` plus mutually consistent Functional `REQ-99`/`AC-99` and matrix `AC-99 \| REQ-99` FAIL; no canonical pair install. R6k-F01 `coverage-matrix-req-cell-list` and matrix↔Functional edge-set equality left intact. |

**REJECT:** none.

## Freeze line cites (post-APPLY)

| Surface | Line | Content |
|---------|------|---------|
| Locked-contract grammar | **L78** | Live staged-SPEC AC namespace closure + coverage AC set equality + phantom `AC-99` FAIL |
| Locked-contract Step 8/XART/QC-8 bind | **L79** | Bind closure to QC-8 (`REQ-F70`), XART, Step 8; QC-8 bidirectional |
| ID scheme | **L208** | Functional/matrix AC resolve to unique live staged-SPEC AC; set equality |
| Target `## Functional Requirements` | **L280** | Functional AC cell live staged-SPEC resolution |
| Target `## Coverage Matrix` | **L284** | Set equality + phantom fixture; R6k edge-set retained |
| Wave 1 parser fixture | **L348** | Parse against live staged-SPEC AC; exact-but-unknown `AC-99` FAIL |
| Wave 2 inherited pins | **L403** | `R6l-F01` |
| QC-8 (`review-requirements`) | **L414** | Bidirectional QC-8; `REQ-F70` on phantom AC |
| XART (`review-cross-artifact`) | **L415** | Namespace closure before orphan/coverage; phantom cannot install |
| Wave 2 string test | **L421**, **L424** | `live staged-SPEC` in `rg` + QC-string Name |
| Wave 3 inherited pins | **L435** | `R6l-F01` Step 8 / XART / QC-8 |
| Step 8 work | **L445** | Serialize+parse + set equality FAIL before install; phantom no-install |
| Compiler verify | **L454**, **L477** | Contains `live staged-SPEC`; mint/serialize/XART phantom fixture |
| Wave 6 inherited pins | **L554** | `R6l-F01` |
| Wave 6 behavioral | **L580** | Phantom `AC-99`/`REQ-99` FAIL at QC-8 / XART / Step 8; no install |
| Risks | **L632** | Phantom Functional/matrix AC not in live staged SPEC |

R6k-F01 remains **L76**–**L77**. R6j-F01 remains **L74**; R6j-F02 remains **L75**.
