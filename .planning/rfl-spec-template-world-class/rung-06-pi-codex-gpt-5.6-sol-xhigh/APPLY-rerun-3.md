# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 3

**Disposition:** ACCEPT-apply (R6c-F01 HIGH; review verify_1-rerun-3 + verify_2-rerun-3 CONFIRMED).  
**Freeze SHA-256 after apply:** `7a6bfc5d66e9acdbf782f15bbe724c51b586e39d1c9cac95e8c547017e6bdc91`  
**Pre-APPLY SHA-256:** `878301866ecbc51c2ee144d566fdfaa36fcb34b37d8fd88166723b32d92879f5`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol Extra High pass 4** (same model). Do not launch pass 4 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6c-F01 HIGH | APPLIED | Extends **staged pair commit (R6b-F01)** with named **recoverable pair-install (snapshot-restore)**. Wave 3 7a/8a and intervening review/QC gates operate on **staged** SPEC/REQUIREMENTS candidates (`source_inputs` = staged SPEC path), not only on-disk canonical paths. Snapshot prior bytes of both canonicals before mutating either; if the second replace fails after the first, restore prior bytes of both. Fixtures: (1) 7a/8a FAIL on staged candidate MUST NOT install; (2) commit-boundary (second write fails after first) leaves both canonical files at prior bytes. R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR Source vs dispositions, and R6b staged-until-Step-8-succeeds unchanged. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi Extra High pass 4.
