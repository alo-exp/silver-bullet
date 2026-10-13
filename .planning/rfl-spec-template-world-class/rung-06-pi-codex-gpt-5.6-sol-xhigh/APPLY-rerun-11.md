# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 11

**Disposition:** ACCEPT-apply (**R6k-F01 MED**; review [review-rerun-11.md](review-rerun-11.md) + [verify_1-rerun-11.md](verify_1-rerun-11.md) PASS; parent triage ACCEPT).  
**Pre-APPLY SHA-256 (both twins):** `1b681ea74e5b606c52481e10d81377fbedffb5206074c860d0989c9e4cbe1fe3`  
**Post-APPLY SHA-256 (both twins):** `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94`  
**Twins byte-identical after APPLY:** **yes**  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md).

**KEEP REJECT:** unchanged (L687 still two files; Clarify does not write SPEC; ingest stays).

Did **not** run `--record-rung-review-outcome`. Did **not** launch Claude or Extra High pass 12. Did not switch branches. Did not commit. Did not implement templates/skills.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6k-F01 MED | APPLIED | Named **`coverage-matrix-req-cell-list`** (`, ` = U+002C + U+0020; atoms exact `REQ-[0-9]{2}`). Matrix `AC` cell **exactly one** exact `AC-[0-9]{2}`. Normative **matrix ↔ Functional edge-set equality** (fail closed). Bound to QC-8 (`REQ-F70` mismatch FAIL, not advisory), Wave 3 Step 8 serialize+parse, `review-cross-artifact`, compiler/migration tests. Fixture PASS: Functional `REQ-01`/`AC-01` plus `REQ-02`/`AC-01` with matrix `AC-01 \| REQ-01, REQ-02`. Fixture FAIL: `REQ-01,REQ-02`; semicolon/slash/pipe/whitespace aliases; exact-ID-but-wrong-pair. Malformed staged matrix cannot install. R6j-F01/F02 and `nfr-source-cell-list` left intact. |

**REJECT:** none.

## Freeze line cites (post-APPLY)

| Surface | Line | Content |
|---------|------|---------|
| Locked-contract grammar | **L76** | Named `coverage-matrix-req-cell-list` + matrix AC-cell exact-one + matrix↔Functional edge-set equality |
| Locked-contract Step 8/XART/QC-8 bind | **L77** | Bind same parser/equality to Step 8, QC-8, `review-cross-artifact`; malformed staged matrix cannot install |
| ID scheme | **L206** | Coverage Matrix named grammar + edge-set FAIL closed |
| Target `## Coverage Matrix` | **L282** | Column-level AC/REQ grammar + edge-set equality + fixtures |
| Wave 1 template assert | **L345** | Matrix `AC-01` + `REQ-01, REQ-02` example; `REQ-01,REQ-02` FAIL |
| Wave 1 parser fixture | **L346** | Parse `coverage-matrix-req-cell-list`; edge-set equality with Functional rows |
| Wave 2 inherited pins | **L401** | `R6k-F01` |
| QC-8 (`review-requirements`) | **L412** | Grammar + edge-set; mismatch FAIL not advisory |
| XART (`review-cross-artifact`) | **L413** | Same parser; edge-set before orphan/coverage; malformed matrix cannot install |
| Wave 2 string test | **L419**, **L422** | `coverage-matrix-req-cell-list` in `rg` + QC-string Name |
| Wave 3 inherited pins | **L433** | `R6k-F01` Step 8 / XART / QC-8 |
| Step 8 work | **L443** | Serialize+parse + edge-set FAIL before install |
| Compiler verify | **L451**, **L473** | Contains named grammar; mint/serialize/XART fixtures |
| Wave 6 inherited pins | **L550** | `R6k-F01` |
| Wave 6 behavioral | **L576** | Multi-REQ PASS; delimiter aliases FAIL; wrong-pair FAIL; no-install |
| Risks | **L627** | Coverage Matrix REQ list / edge-set underspecified |

R6j-F01 remains **L74**; R6j-F02 remains **L75**.
