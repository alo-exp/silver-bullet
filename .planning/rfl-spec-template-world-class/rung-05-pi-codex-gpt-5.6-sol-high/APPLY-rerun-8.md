# APPLY — rung 5 Pi Codex GPT-5.6 Sol High — re-run pass 8

**Disposition:** ACCEPT-apply (R5h-F01 MED; review verify_1-rerun-8 + verify_2-rerun-8 CONFIRMED).  
**Freeze SHA-256 after apply:** `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`  
**Pre-APPLY SHA-256:** `e056076257a4ec1e7b6f85da3500d948feb1cf0551c58c6852aacaabff26cd10`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance to GPT Extra High). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol High pass 9** (same model — not Extra High). Do not launch pass 9 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R5h-F01 MED | APPLIED | Named mechanism: tombstone list (`id-tombstones`). YAML list of retired full IDs persists across augment versions in SPEC.md (`[]` if none; never drop). Pack table, ID scheme, QC-12/QC-13, Step 7, and Wave 6 augment honor it. QC-13 FAIL if a live ID is tombstoned (retired `AC-03` reissued). QC-12 and QC-13 FAIL on retired `EX-nn` reissued. Step 7 sequential next-free skips tombstones, not only live current-file IDs (mint after retire skips the hole → `AC-04`). Happy path: preserve-still-present. Current-file uniqueness and exact two-digit `AC-nn` / `EX-nn` schemes stay intact. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi GPT pass 9.
