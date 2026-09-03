# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 10

**Disposition:** ACCEPT-apply (R6j-F01 MED + R6j-F02 MED; review verify_1-rerun-10 + verify_2-rerun-10 CONFIRMED).  
**Freeze SHA-256 after apply:** `1b681ea74e5b606c52481e10d81377fbedffb5206074c860d0989c9e4cbe1fe3`  
**Pre-APPLY SHA-256:** `f20dd7b1f1c0ff3e33a782a94d0de45979df2ce9badbb65e78b6a6961313b6b3`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol Extra High pass 11** (same model). Do not launch pass 11 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6j-F01 MED | APPLIED | Bound R6i one-`AC-nn`-per-cell to Wave 3 **Step 8**, **`review-cross-artifact`**, and compiler/migration tests. Emitted Functional cell is **exactly one** exact `AC-[0-9]{2}`. Prohibit list aliases (comma, semicolon, slash, pipe, or whitespace-separated lists). Many-to-one REQ↔AC via **multiple Functional rows**. Fixture: `AC-01` PASS; `AC-01, AC-02` FAIL at mint/serialize/XART (not Wave 1 template tests only); malformed cell cannot install. Wave 3 / Wave 6 inherited pins now include `R6h-F01` / `R6i-F01` / `R6j-F01`. Do not weaken R6i Wave 1 grammar. |
| R6j-F02 MED | APPLIED | Bound named **`nfr-source-cell-list`** (`, ` = U+002C + U+0020) to Step 8 serialize+parse and `review-cross-artifact` reverse-coverage / exclusivity / overlap (same parser as Wave 1). Fixture: `QA-01, SLO-01` parses as two IDs; `QA-01,SLO-01` (no space) FAIL. Overlap second-atom detectable only through correct list parsing. Malformed staged Source cannot install. Wave 3 / Wave 6 inherited pins now include `R6i-F02` / `R6j-F02`. Do not weaken R5k exclusivity. R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R6b/R6c/R6d pair-install/fixed-point, R6f exhaustion FAIL closed, and R6h AC-nn cells unchanged. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi Extra High pass 11.
