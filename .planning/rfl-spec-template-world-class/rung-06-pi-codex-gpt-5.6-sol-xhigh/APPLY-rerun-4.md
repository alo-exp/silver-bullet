# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 4

**Disposition:** ACCEPT-apply (R6d-F01 HIGH; review verify_1-rerun-4 + verify_2-rerun-4 CONFIRMED).  
**Freeze SHA-256 after apply:** `1f11eacc50529cb8bab062a37bc80b4b6c988d855b17833332159b32a46d53fa`  
**Pre-APPLY SHA-256:** `7a6bfc5d66e9acdbf782f15bbe724c51b586e39d1c9cac95e8c547017e6bdc91`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol Extra High pass 5** (same model). Do not launch pass 5 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6d-F01 HIGH | APPLIED | Extends **staged pair commit (R6b-F01)** and **recoverable pair-install (snapshot-restore) (R6c-F01)** with named **fixed-point**. After any successful 7a or 8a mutation of staged bytes, re-run Step 8 / 7a/8a / `review-cross-artifact` (as applicable) on the **exact** staged pair that will be installed. Install is allowed only when the last review/QC PASS was on those bytes with no further mutation. If 8a (or 7a) mutates after a PASS, that prior PASS is stale; fail-before-install until the pair is revalidated. Fixture: 8a mutates REQUIREMENTS after a pair PASS → install FAIL unless a subsequent full PASS on the new bytes. Distinct from R6c snapshot-restore. R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR Source vs dispositions, R6b staged-until-Step-8-succeeds, and R6c snapshot-restore unchanged. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi Extra High pass 5.
