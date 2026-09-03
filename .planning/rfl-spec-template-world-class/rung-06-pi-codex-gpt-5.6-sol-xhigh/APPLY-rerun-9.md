# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 9

**Disposition:** ACCEPT-apply (R6i-F01 MED + R6i-F02 MED; review verify_1-rerun-9 + verify_2-rerun-9 CONFIRMED).  
**Freeze SHA-256 after apply:** `f20dd7b1f1c0ff3e33a782a94d0de45979df2ce9badbb65e78b6a6961313b6b3`  
**Pre-APPLY SHA-256:** `4d0d3684ccd0a73ecd15698a19c1498b7919e65eb89b4ca20a2f74cfc96cccba`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol Extra High pass 10** (same model). Do not launch pass 10 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6i-F01 MED | APPLIED | Closed the open “many-to-one via explicit AC column lists?” directive. R6h exact `AC-[0-9]{2}` **wins**: one Functional `AC` cell = **exactly one** `AC-nn`. No lists (`AC-01, AC-02` FAIL). Many-to-one REQ↔AC if needed is via **multiple Functional rows**, not a comma list in one cell. Fixture: `AC-01` PASS; `AC-01, AC-02` FAIL. Wave 1 parse + Wave 2 QC-4/`REQ-F30` consume that cardinality. |
| R6i-F02 MED | APPLIED | Named **NFR Source cell list grammar** `nfr-source-cell-list`: one or more source IDs separated by `, ` (U+002C COMMA + exactly one U+0020 SPACE); no other whitespace. Each atom exact `QA-[0-9]{2}` / `SLO-[0-9]{2}` / `CTRL-[0-9]{2}` / `SCAN:<section>#<line-or-id>` (`<section>` and `<line-or-id>` non-empty, no comma, no space). Same parser for reverse-coverage / exclusivity / overlap FAIL. Live Source example required (not header-only empty). Fixture PASS: `QA-01, SLO-01` parses as two IDs. Fixture FAIL: malformed list (e.g. `QA-01,SLO-01` missing space). Do not weaken R5k exclusive Source vs Dispositions. R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R6b/R6c/R6d pair-install/fixed-point, R6f exhaustion FAIL closed, and R6h AC-nn cells unchanged. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi Extra High pass 10.
