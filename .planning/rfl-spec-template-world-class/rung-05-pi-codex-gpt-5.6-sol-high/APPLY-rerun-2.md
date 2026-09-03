# APPLY — rung 5 Pi Codex GPT-5.6 Sol High — re-run pass 2

**Disposition:** ACCEPT-apply (all 3 findings; review verify_1-rerun-2 + verify_2-rerun-2 CONFIRMED).  
**Freeze SHA-256 after apply:** `4a99ea1e75bfb3a0d364d365f61d2286ce1f82df1bd8070e12f599c1f1aa5374`  
**Pre-APPLY SHA-256:** `acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance to GPT Extra High). Policy F: `--record-rung-review-outcome accept-apply` (streak → 0). **Next parent action: Pi GPT-5.6 Sol High pass 3** (same model — not Extra High).

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R5b-F01 HIGH | APPLIED | Kind-aware QC-1 + new QC-12 (`SPEC-F74`) require required-pack **bodies** and catalog pack-local IDs (`EP-nn` / `CTRL-nn` / `SLO-nn` / etc.), not headings-only. `_TBD — Clarify skipped illegally_` is an audit ISSUE marker and **does not** satisfy QC-1. Heading-only / empty stub required packs FAIL. |
| R5b-F02 MED | APPLIED | QC-6b: `software-kinds` must be two+ **distinct atomic** catalog kinds (not `[cli]`, not `[multi, web-ui]`, not `[cli, cli]`, not unknown members). Validate before pack union; Turn 0 / Wave 1b negatives encode the same shape. |
| R5b-F03 MED | APPLIED | NFR Source (R5-F03) stays. Added **reverse coverage**: dropped SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` FAIL even when remaining NFR rows have valid Source. One-to-many / many-to-one allowed. Empty `None identified` only when no eligible SPEC sources exist. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi GPT pass 3.
